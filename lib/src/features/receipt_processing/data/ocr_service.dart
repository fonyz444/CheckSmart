import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/receipt_processing_failure.dart';
import 'tesseract_ocr_service.dart';

/// Provider for OcrService (hybrid ML Kit + Tesseract)
final ocrServiceProvider = Provider<OcrService>((ref) {
  final tesseract = ref.watch(tesseractOcrServiceProvider);
  return OcrService(tesseract);
});

/// Hybrid OCR Service combining ML Kit and Tesseract
///
/// Strategy:
/// 1. First try ML Kit (faster, no setup needed)
/// 2. If result is poor quality, try Tesseract (better for Cyrillic)
/// 3. Return the better result
class OcrService {
  final TesseractOcrService _tesseract;
  TextRecognizer? _textRecognizer;

  OcrService(this._tesseract);

  /// Get or create the ML Kit text recognizer
  TextRecognizer get _recognizer {
    _textRecognizer ??= TextRecognizer();
    return _textRecognizer!;
  }

  /// Extracts text from an image file using hybrid OCR approach
  ///
  /// [imagePath] - Absolute path to the image file (PNG, JPG)
  /// Returns the raw extracted text from the best OCR engine
  Future<String> extractText(String imagePath) async {
    // Check if file exists first
    final file = File(imagePath);
    if (!await file.exists()) {
      throw OcrExtractionFailure(
        'Файл изображения не найден',
        imagePath: imagePath,
      );
    }

    final fileSize = await file.length();
    print('=== HYBRID OCR ===');
    print('Image: $imagePath');
    print('Size: $fileSize bytes');

    // Step 1: Try ML Kit first (faster)
    String mlKitText = '';
    try {
      mlKitText = await _extractWithMlKit(imagePath);
      print('ML Kit result: ${mlKitText.length} chars');
    } catch (e) {
      print('ML Kit failed: $e');
    }

    // Step 2: Check if we need Tesseract fallback
    final needsTesseract = _shouldUseTesseract(mlKitText);

    if (!needsTesseract && mlKitText.isNotEmpty) {
      print('Using ML Kit result');
      print('==================');
      return mlKitText;
    }

    // Step 3: Try Tesseract
    String tesseractText = '';
    try {
      tesseractText = await _tesseract.extractText(imagePath);
      print('Tesseract result: ${tesseractText.length} chars');
    } catch (e) {
      print('Tesseract failed: $e');
    }

    // Step 4: Choose best result
    final bestText = _chooseBestResult(mlKitText, tesseractText);
    print('Selected: ${bestText == mlKitText ? "ML Kit" : "Tesseract"}');
    print('==================');

    if (bestText.isEmpty) {
      throw const EmptyTextFailure(
        'Текст не распознан - попробуйте сделать более чёткое фото',
      );
    }

    return bestText;
  }

  /// Extract text using ML Kit
  Future<String> _extractWithMlKit(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizedText = await _recognizer.processImage(inputImage);

    final buffer = StringBuffer();
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        buffer.writeln(line.text);
      }
      buffer.writeln();
    }

    return buffer.toString().trim();
  }

  /// Check if we should try Tesseract based on ML Kit result quality
  bool _shouldUseTesseract(String mlKitText) {
    // Too short - probably missed text
    if (mlKitText.length < 50) {
      print('ML Kit text too short, trying Tesseract');
      return true;
    }

    // Check for keywords that indicate a receipt
    final hasReceiptKeywords = _containsReceiptKeywords(mlKitText);
    if (!hasReceiptKeywords) {
      print('No receipt keywords found, trying Tesseract');
      return true;
    }

    // Check for amount patterns - if none found, probably OCR quality issue
    final hasAmount = RegExp(r'\d{2,}[.,]?\d*').hasMatch(mlKitText);
    if (!hasAmount) {
      print('No amount found, trying Tesseract');
      return true;
    }

    return false;
  }

  /// Check if text contains receipt-related keywords (RU/KZ/EN)
  bool _containsReceiptKeywords(String text) {
    final lower = text.toLowerCase();
    final keywords = [
      'сумма',
      'итого',
      'барлығы',
      'total',
      'касса',
      'чек',
      'оплата',
      'төлем',
      'kaspi',
      'halyk',
      'jusan',
      'магнум',
      'magnum',
      'small',
    ];
    return keywords.any((kw) => lower.contains(kw));
  }

  /// Choose the better OCR result
  String _chooseBestResult(String mlKit, String tesseract) {
    if (mlKit.isEmpty) return tesseract;
    if (tesseract.isEmpty) return mlKit;

    // Prefer the one with more receipt keywords
    final mlKitScore = _scoreReceiptQuality(mlKit);
    final tesseractScore = _scoreReceiptQuality(tesseract);

    print('Quality scores - ML Kit: $mlKitScore, Tesseract: $tesseractScore');

    return tesseractScore > mlKitScore ? tesseract : mlKit;
  }

  /// Score the quality of OCR result for receipt parsing
  int _scoreReceiptQuality(String text) {
    int score = 0;
    final lower = text.toLowerCase();

    // Points for length (more text = probably better)
    score += (text.length ~/ 50).clamp(0, 10);

    // Points for receipt keywords
    final keywords = [
      'сумма',
      'итого',
      'total',
      'касса',
      'оплата',
      'kaspi',
      'halyk',
      'чек',
      'тнг',
      '₸',
    ];
    for (final kw in keywords) {
      if (lower.contains(kw)) score += 5;
    }

    // Points for amount patterns
    final amounts = RegExp(r'\d{3,}[.,]?\d{0,2}').allMatches(text);
    score += amounts.length * 3;

    return score;
  }

  /// Dispose resources
  void dispose() {
    _textRecognizer?.close();
    _textRecognizer = null;
  }
}
