import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/receipt_processing_failure.dart';

/// Provider for OcrService
final ocrServiceProvider = Provider<OcrService>((ref) => OcrService());

/// Service for extracting text from images using Google ML Kit
///
/// Benefits over Tesseract:
/// - No traineddata files needed
/// - Works offline
/// - Better accuracy for printed text
/// - Supports Latin and Cyrillic scripts automatically
class OcrService {
  TextRecognizer? _textRecognizer;

  /// Get or create the text recognizer
  /// Using default (no script) enables multi-script recognition including Cyrillic
  TextRecognizer get _recognizer {
    _textRecognizer ??= TextRecognizer();
    return _textRecognizer!;
  }

  /// Extracts text from an image file using Google ML Kit
  ///
  /// [imagePath] - Absolute path to the image file (PNG, JPG)
  ///
  /// Returns the raw extracted text
  /// Throws [OcrExtractionFailure] if extraction fails
  Future<String> extractText(String imagePath) async {
    try {
      print('=== ML Kit OCR ===');
      print('Processing: $imagePath');

      // Check if file exists
      final file = File(imagePath);
      if (!await file.exists()) {
        throw OcrExtractionFailure(
          'Файл изображения не найден',
          imagePath: imagePath,
        );
      }

      final fileSize = await file.length();
      print('File size: $fileSize bytes');

      // Create input image
      final inputImage = InputImage.fromFilePath(imagePath);

      // Run text recognition
      print('Running ML Kit text recognition...');
      final recognizedText = await _recognizer.processImage(inputImage);

      print('Recognition complete!');
      print('Blocks found: ${recognizedText.blocks.length}');

      // Build the full text from all blocks
      final buffer = StringBuffer();
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          buffer.writeln(line.text);
        }
        buffer.writeln(); // Empty line between blocks
      }

      final extractedText = buffer.toString().trim();
      print('Total text length: ${extractedText.length}');
      print('==================');

      if (extractedText.isEmpty) {
        throw const EmptyTextFailure(
          'Текст не распознан - попробуйте сделать более чёткое фото',
        );
      }

      return extractedText;
    } on EmptyTextFailure {
      rethrow;
    } on OcrExtractionFailure {
      rethrow;
    } catch (e) {
      print('ML Kit error: $e');
      throw OcrExtractionFailure(
        'Ошибка распознавания: $e',
        imagePath: imagePath,
        originalError: e,
      );
    }
  }

  /// Dispose resources
  void dispose() {
    _textRecognizer?.close();
    _textRecognizer = null;
  }
}
