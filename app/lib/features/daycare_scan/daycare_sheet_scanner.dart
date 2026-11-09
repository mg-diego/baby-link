import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'daycare_sheet_parser.dart';

/// OCR en el propio móvil (ML Kit): la foto no sale del teléfono.
class DaycareSheetScanner {
  static Future<String> readText(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(InputImage.fromFilePath(imagePath));
      return result.text;
    } finally {
      await recognizer.close();
    }
  }

  static Future<List<ScannedNap>> scanNaps(String imagePath, DateTime day) async =>
      parseNapRanges(await readText(imagePath), day);
}
