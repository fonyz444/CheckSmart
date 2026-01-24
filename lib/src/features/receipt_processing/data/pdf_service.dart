import 'dart:io';
import 'package:pdfx/pdfx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/receipt_processing_failure.dart';

/// Provider for PdfService
final pdfServiceProvider = Provider<PdfService>((ref) => PdfService());

/// Service for converting PDF receipts to images for OCR processing
///
/// **Critical Pipeline Step:**
/// Tesseract OCR can only process image files, not PDFs directly.
/// This service bridges that gap by:
/// 1. Opening a PDF file using pdfx
/// 2. Rendering the first page at high resolution (2x scale for OCR quality)
/// 3. Saving as a temporary PNG file
/// 4. Returning the temp file path for OCR processing
class PdfService {
  /// Renders the first page of a PDF to a temporary image file
  ///
  /// [pdfPath] - Absolute path to the PDF file (e.g., Kaspi/Halyk receipt)
  ///
  /// Returns the path to the temporary PNG image file
  /// Throws [PdfRenderingFailure] if rendering fails
  Future<String> renderPdfToImage(String pdfPath) async {
    PdfDocument? document;
    PdfPage? page;

    try {
      // Step 1: Open the PDF document
      final file = File(pdfPath);
      if (!await file.exists()) {
        throw PdfRenderingFailure('PDF file not found', filePath: pdfPath);
      }

      document = await PdfDocument.openFile(pdfPath);

      if (document.pagesCount == 0) {
        throw PdfRenderingFailure('PDF has no pages', filePath: pdfPath);
      }

      // Step 2: Get the first page (receipts are typically single-page)
      page = await document.getPage(1);

      // Step 3: Render at 2x resolution for better OCR accuracy
      // Higher resolution = clearer text = better OCR results
      final pageImage = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: PdfPageImageFormat.png,
        // Use full quality for OCR
        quality: 100,
      );

      if (pageImage == null || pageImage.bytes.isEmpty) {
        throw PdfRenderingFailure(
          'Failed to render PDF page to image',
          filePath: pdfPath,
        );
      }

      // Step 4: Save to temporary directory
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempImagePath = '${tempDir.path}/receipt_$timestamp.png';

      final imageFile = File(tempImagePath);
      await imageFile.writeAsBytes(pageImage.bytes);

      return tempImagePath;
    } on PdfRenderingFailure {
      rethrow;
    } catch (e) {
      throw PdfRenderingFailure(
        'Unexpected error rendering PDF: $e',
        filePath: pdfPath,
        originalError: e,
      );
    } finally {
      // Clean up resources
      await page?.close();
      await document?.close();
    }
  }

  /// Cleans up temporary files created during PDF processing
  Future<void> cleanupTempFile(String? tempPath) async {
    if (tempPath == null) return;

    try {
      final file = File(tempPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Ignore cleanup errors - temp files will be cleared eventually
    }
  }
}
