import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// Google ML Kit — baca teks dari gambar resit (Android/iOS sahaja).
class ReceiptOcrService {
  ReceiptOcrService() : _recognizer = TextRecognizer();

  final TextRecognizer _recognizer;

  bool get isSupported => !kIsWeb;

  Future<String> recognizeReceipt(XFile file) async {
    if (kIsWeb) {
      throw UnsupportedError('ML Kit OCR hanya disokong pada Android/iOS.');
    }

    final inputImage = InputImage.fromFilePath(file.path);
    final result = await _recognizer
        .processImage(inputImage)
        .timeout(
          const Duration(seconds: 45),
          onTimeout: () => throw TimeoutException(
            'Scan took too long. Try a clearer photo or smaller image.',
          ),
        );
    return result.text.trim();
  }

  void dispose() => _recognizer.close();
}
