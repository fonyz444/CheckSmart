/// Sealed class hierarchy for receipt processing errors
/// Uses Dart 3 sealed classes for exhaustive pattern matching
sealed class ReceiptProcessingFailure {
  final String message;
  final Object? originalError;

  const ReceiptProcessingFailure(this.message, [this.originalError]);

  @override
  String toString() => '$runtimeType: $message';
}

/// Error during PDF rendering (pdfx)
class PdfRenderingFailure extends ReceiptProcessingFailure {
  final String? filePath;

  const PdfRenderingFailure(
    String message, {
    this.filePath,
    Object? originalError,
  }) : super(message, originalError);
}

/// Error during OCR text extraction (Tesseract)
class OcrExtractionFailure extends ReceiptProcessingFailure {
  final String? imagePath;
  final String? language;

  const OcrExtractionFailure(
    String message, {
    this.imagePath,
    this.language,
    Object? originalError,
  }) : super(message, originalError);
}

/// Error during receipt text parsing (regex matching)
class ParsingFailure extends ReceiptProcessingFailure {
  final String? rawText;

  const ParsingFailure(String message, {this.rawText, Object? originalError})
    : super(message, originalError);
}

/// Error during Hive storage operations
class StorageFailure extends ReceiptProcessingFailure {
  final String? boxName;

  const StorageFailure(String message, {this.boxName, Object? originalError})
    : super(message, originalError);
}

/// Error during file operations (reading, writing temp files)
class FileOperationFailure extends ReceiptProcessingFailure {
  final String? filePath;

  const FileOperationFailure(
    String message, {
    this.filePath,
    Object? originalError,
  }) : super(message, originalError);
}

/// Error when the image/PDF contains no readable text
class EmptyTextFailure extends ReceiptProcessingFailure {
  const EmptyTextFailure([
    super.message = 'No text could be extracted from the image',
  ]);
}

/// Error when required traineddata files are missing
class TesseractConfigFailure extends ReceiptProcessingFailure {
  final List<String> missingLanguages;

  const TesseractConfigFailure(
    super.message, {
    this.missingLanguages = const [],
  });
}
