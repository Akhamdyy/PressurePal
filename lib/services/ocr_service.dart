import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class OcrService {
  static final _textRecognizer = TextRecognizer();

  /// Takes a photo and returns a Map with {systolic, diastolic, pulse} or null
  static Future<Map<String, int>?> scanImage() async {
    try {
      // 1. Pick Image
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);
      
      if (photo == null) return null; // User cancelled

      // 2. Process Image
      final inputImage = InputImage.fromFilePath(photo.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      // 3. Extract Numbers
      return _parseBloodPressure(recognizedText.text);
    } catch (e) {
      print("OCR Error: $e");
      return null;
    }
  }

  /// The Logic: Finds numbers that look like BP readings
  static Map<String, int>? _parseBloodPressure(String fullText) {
    // Clean text: remove non-numbers except spaces and slashes
    // This helps if the OCR misreads "120/80" as "120l80" or "120 80"
    String cleaned = fullText.replaceAll(RegExp(r'[^0-9/\n ]'), '');

    // Strategy A: Look for "120/80" format
    final slashRegex = RegExp(r'(\d{2,3})\s*/\s*(\d{2,3})');
    final slashMatch = slashRegex.firstMatch(fullText);

    if (slashMatch != null) {
      int sys = int.parse(slashMatch.group(1)!);
      int dia = int.parse(slashMatch.group(2)!);
      
      // Basic sanity check (Systolic must be > Diastolic)
      if (sys > dia && sys > 50 && sys < 250) {
        return {'sys': sys, 'dia': dia, 'pulse': _findPulse(fullText, sys, dia)};
      }
    }

    // Strategy B: Look for independent numbers (vertical layout)
    // Often monitors show:
    // 120
    // 80
    // 72
    final numbers = RegExp(r'\d{2,3}').allMatches(fullText)
        .map((m) => int.parse(m.group(0)!))
        .where((n) => n > 40 && n < 250) // Filter realistic range
        .toList();

    if (numbers.length >= 2) {
      // Assume highest number is Systolic, 2nd highest is Diastolic
      numbers.sort((a, b) => b.compareTo(a)); // Descending
      return {
        'sys': numbers[0],
        'dia': numbers[1],
        'pulse': numbers.length > 2 ? numbers[2] : 0
      };
    }

    return null; // Could not find valid data
  }

  static int _findPulse(String text, int sys, int dia) {
    // Try to find a 3rd number that isn't the sys or dia
    final allNumbers = RegExp(r'\d{2,3}').allMatches(text)
        .map((m) => int.parse(m.group(0)!))
        .toList();
    
    for (var n in allNumbers) {
      if (n != sys && n != dia && n > 40 && n < 150) {
        return n;
      }
    }
    return 0; // Pulse not found
  }
}