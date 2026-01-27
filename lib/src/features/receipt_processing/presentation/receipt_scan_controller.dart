import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/constants.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/domain/transaction_entity.dart';
import '../data/pdf_service.dart';
import '../data/ocr_service.dart';
import '../data/receipt_parser.dart';
import '../domain/parsed_receipt.dart';
import '../domain/receipt_processing_failure.dart';

/// State for the receipt scanning process
class ReceiptScanState {
  final bool isProcessing;
  final String? statusMessage;
  final ParsedReceipt? result;
  final ReceiptProcessingFailure? error;

  const ReceiptScanState({
    this.isProcessing = false,
    this.statusMessage,
    this.result,
    this.error,
  });

  ReceiptScanState copyWith({
    bool? isProcessing,
    String? statusMessage,
    ParsedReceipt? result,
    ReceiptProcessingFailure? error,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return ReceiptScanState(
      isProcessing: isProcessing ?? this.isProcessing,
      statusMessage: statusMessage ?? this.statusMessage,
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Provider for ReceiptScanController
final receiptScanControllerProvider =
    StateNotifierProvider<ReceiptScanController, ReceiptScanState>((ref) {
      return ReceiptScanController(
        pdfService: ref.watch(pdfServiceProvider),
        ocrService: ref.watch(ocrServiceProvider),
        parser: ref.watch(receiptParserProvider),
        transactionRepository: ref.watch(transactionRepositoryProvider),
      );
    });

/// Controller that orchestrates the complete receipt scanning pipeline:
///
/// **Camera Flow:**
/// 1. Pick image from camera/gallery
/// 2. Run OCR on image
/// 3. Parse extracted text
/// 4. Save to Hive
///
/// **PDF Flow:**
/// 1. Pick PDF file
/// 2. Render PDF to image (via pdfx)
/// 3. Run OCR on rendered image
/// 4. Parse extracted text
/// 5. Cleanup temp file
/// 6. Save to Hive
class ReceiptScanController extends StateNotifier<ReceiptScanState> {
  final PdfService _pdfService;
  final OcrService _ocrService;
  final ReceiptParser _parser;
  final TransactionRepository _transactionRepository;

  final _imagePicker = ImagePicker();

  ReceiptScanController({
    required PdfService pdfService,
    required OcrService ocrService,
    required ReceiptParser parser,
    required TransactionRepository transactionRepository,
  }) : _pdfService = pdfService,
       _ocrService = ocrService,
       _parser = parser,
       _transactionRepository = transactionRepository,
       super(const ReceiptScanState());

  /// Scans a receipt using the camera
  Future<void> scanFromCamera() async {
    try {
      state = state.copyWith(
        isProcessing: true,
        statusMessage: 'Открытие камеры...',
        clearError: true,
        clearResult: true,
      );

      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100, // Max quality for OCR
      );

      if (image == null) {
        state = state.copyWith(isProcessing: false, statusMessage: null);
        return;
      }

      await _processImage(image.path, ReceiptSource.camera);
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: OcrExtractionFailure('Ошибка камеры: $e', originalError: e),
      );
    }
  }

  /// Scans a receipt from an image in the gallery
  Future<void> scanFromGallery() async {
    try {
      state = state.copyWith(
        isProcessing: true,
        statusMessage: 'Выбор изображения...',
        clearError: true,
        clearResult: true,
      );

      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (image == null) {
        state = state.copyWith(isProcessing: false, statusMessage: null);
        return;
      }

      await _processImage(image.path, ReceiptSource.camera);
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: OcrExtractionFailure(
          'Ошибка выбора файла: $e',
          originalError: e,
        ),
      );
    }
  }

  /// Scans a receipt from a PDF file (Kaspi/Halyk export)
  Future<void> scanFromPdf() async {
    String? tempImagePath;

    try {
      state = state.copyWith(
        isProcessing: true,
        statusMessage: 'Выбор PDF файла...',
        clearError: true,
        clearResult: true,
      );

      // Step 1: Pick PDF file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.isEmpty) {
        state = state.copyWith(isProcessing: false, statusMessage: null);
        return;
      }

      final pdfPath = result.files.first.path;
      if (pdfPath == null) {
        throw const FileOperationFailure('Не удалось получить путь к файлу');
      }

      // Detect source from filename
      final fileName = result.files.first.name.toLowerCase();
      final sourceHint =
          fileName.contains('kaspi')
              ? ReceiptSource.pdfKaspi
              : fileName.contains('halyk')
              ? ReceiptSource.pdfHalyk
              : null;

      // Step 2: Convert PDF to image
      state = state.copyWith(statusMessage: 'Обработка PDF...');
      tempImagePath = await _pdfService.renderPdfToImage(pdfPath);

      // Step 3: Process the image
      await _processImage(tempImagePath, sourceHint ?? ReceiptSource.pdfKaspi);
    } on ReceiptProcessingFailure catch (e) {
      state = state.copyWith(isProcessing: false, error: e);
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: FileOperationFailure(
          'Ошибка обработки PDF: $e',
          originalError: e,
        ),
      );
    } finally {
      // Cleanup temp file
      if (tempImagePath != null) {
        await _pdfService.cleanupTempFile(tempImagePath);
      }
    }
  }

  /// Internal method to process an image through OCR and parsing
  Future<void> _processImage(String imagePath, ReceiptSource source) async {
    try {
      // Run OCR
      state = state.copyWith(statusMessage: 'Распознавание текста...');
      final rawText = await _ocrService.extractText(imagePath);

      // Debug: Log OCR result
      print('=== OCR DEBUG ===');
      print('Image path: $imagePath');
      print('Raw text length: ${rawText.length}');
      print('Raw text: $rawText');
      print('=================');

      // Check if OCR returned any text
      if (rawText.trim().isEmpty) {
        state = state.copyWith(
          isProcessing: false,
          error: const OcrExtractionFailure(
            'Не удалось распознать текст. Попробуйте сделать более чёткое фото.',
          ),
        );
        return;
      }

      // Parse the text
      state = state.copyWith(statusMessage: 'Анализ чека...');
      final parsedReceipt = _parser.parse(rawText, sourceHint: source);

      // Debug: Log parsed result
      print('=== PARSER DEBUG ===');
      print('Amount: ${parsedReceipt.amount}');
      print('Merchant: ${parsedReceipt.merchant}');
      print('Date: ${parsedReceipt.date}');
      print(
        'Suggested Category: ${parsedReceipt.suggestedCategory?.displayName ?? 'none'}',
      );
      print('Confidence: ${parsedReceipt.confidence}');
      print('Is Valid: ${parsedReceipt.isValid}');
      print('====================');

      // If no amount found, show warning but still show result
      if (parsedReceipt.amount == null) {
        state = state.copyWith(
          isProcessing: false,
          error: const ParsingFailure(
            'Сумма не распознана. Попробуйте ввести вручную или сфотографировать ближе.',
          ),
          result: parsedReceipt,
        );
        return;
      }

      state = state.copyWith(
        isProcessing: false,
        statusMessage: null,
        result: parsedReceipt,
      );
    } on ReceiptProcessingFailure catch (e) {
      print('=== PROCESSING ERROR ===');
      print('Error: ${e.message}');
      print('========================');
      state = state.copyWith(isProcessing: false, error: e);
    } catch (e) {
      print('=== UNEXPECTED ERROR ===');
      print('Error: $e');
      print('========================');
      state = state.copyWith(
        isProcessing: false,
        error: OcrExtractionFailure('Ошибка обработки: $e', originalError: e),
      );
    }
  }

  /// Saves the current parsed receipt as a transaction
  Future<TransactionEntity?> saveTransaction({
    required ExpenseCategory category,
    String? note,
    String? customCategoryId,
  }) async {
    final result = state.result;
    if (result == null || !result.isValid) {
      return null;
    }

    try {
      // Use parsed date/time from receipt if available, otherwise use current date/time
      final transactionDate = result.date ?? DateTime.now();

      final transaction = await _transactionRepository.add(
        amount: result.amount!,
        category: category,
        date: transactionDate,
        source: result.detectedSource,
        merchant: result.merchant,
        receiptNumber: result.receiptNumber,
        rawOcrText: result.rawText,
        note: note,
        customCategoryId: customCategoryId,
      );

      // Clear state after saving
      state = const ReceiptScanState();
      return transaction;
    } catch (e) {
      state = state.copyWith(
        error: StorageFailure('Ошибка сохранения: $e', originalError: e),
      );
      return null;
    }
  }

  /// Clears the current scan result
  void clear() {
    state = const ReceiptScanState();
  }
}
