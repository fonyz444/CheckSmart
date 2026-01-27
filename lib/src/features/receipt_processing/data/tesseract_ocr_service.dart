import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/receipt_processing_failure.dart';

/// Provider for TesseractOcrService
final tesseractOcrServiceProvider = Provider<TesseractOcrService>(
  (ref) => TesseractOcrService(),
);

/// Service for extracting text from images using Tesseract OCR
///
/// Uses Russian + English language models for better Cyrillic recognition
/// on Kazakhstan receipts.
class TesseractOcrService {
  static const _languages = 'rus+eng';
  bool _isInitialized = false;
  String? _tessdataPath;

  /// Initialize Tesseract by copying traineddata files from assets
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('=== Tesseract OCR Init ===');

      // Get app documents directory for tessdata
      final appDir = await getApplicationDocumentsDirectory();
      _tessdataPath = '${appDir.path}/tessdata';

      // Create tessdata directory if needed
      final tessdataDir = Directory(_tessdataPath!);
      if (!tessdataDir.existsSync()) {
        await tessdataDir.create(recursive: true);
        print('Created tessdata directory: $_tessdataPath');
      }

      // Copy traineddata files from assets
      await _copyTrainedDataIfNeeded('rus.traineddata');
      await _copyTrainedDataIfNeeded('eng.traineddata');

      _isInitialized = true;
      print('Tesseract initialized successfully');
      print('==========================');
    } catch (e) {
      print('Tesseract init error: $e');
      rethrow;
    }
  }

  /// Copy traineddata file from assets to documents directory
  Future<void> _copyTrainedDataIfNeeded(String filename) async {
    final targetFile = File('$_tessdataPath/$filename');

    if (await targetFile.exists()) {
      print('$filename already exists');
      return;
    }

    try {
      print('Copying $filename from assets...');
      final data = await rootBundle.load('assets/tessdata/$filename');
      final bytes = data.buffer.asUint8List();
      await targetFile.writeAsBytes(bytes);
      print('Copied $filename (${bytes.length} bytes)');
    } catch (e) {
      print('Failed to copy $filename: $e');
      // Don't rethrow - Tesseract can work with available languages
    }
  }

  /// Extracts text from an image file using Tesseract OCR
  ///
  /// [imagePath] - Absolute path to the image file
  /// Returns the raw extracted text
  Future<String> extractText(String imagePath) async {
    try {
      // Ensure initialized
      if (!_isInitialized) {
        await initialize();
      }

      print('=== Tesseract OCR ===');
      print('Processing: $imagePath');
      print('Languages: $_languages');

      // Check if file exists
      final file = File(imagePath);
      if (!await file.exists()) {
        throw OcrExtractionFailure(
          'Файл изображения не найден',
          imagePath: imagePath,
        );
      }

      // Run Tesseract OCR
      final text = await FlutterTesseractOcr.extractText(
        imagePath,
        language: _languages,
        args: {'tessdata': _tessdataPath!, 'preserve_interword_spaces': '1'},
      );

      print('Tesseract extracted ${text.length} characters');
      print('=====================');

      if (text.trim().isEmpty) {
        throw const EmptyTextFailure('Tesseract не распознал текст');
      }

      return text.trim();
    } on EmptyTextFailure {
      rethrow;
    } on OcrExtractionFailure {
      rethrow;
    } catch (e) {
      print('Tesseract error: $e');
      throw OcrExtractionFailure(
        'Ошибка Tesseract OCR: $e',
        imagePath: imagePath,
        originalError: e,
      );
    }
  }
}
