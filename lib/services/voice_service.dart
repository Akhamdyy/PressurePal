import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceService {
  static final SpeechToText _speech = SpeechToText();
  
  /// Initialize the speech engine
  static Future<bool> init() async {
    // Request microphone permission explicitly
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      return false;
    }
    return await _speech.initialize();
  }

  /// Start listening and return the recognized numbers (Sys/Dia/Pulse)
  static Future<Map<String, int>?> listenForBloodPressure() async {
    bool available = await init();
    if (!available) return null;

    String fullText = "";
    
    // Listen for 5 seconds max (enough to say "120 over 80")
    await _speech.listen(
      localeId: "ar-EG", // Egyptian Arabic 🇪🇬
      onResult: (result) {
        fullText = result.recognizedWords;
      },
      listenFor: const Duration(seconds: 40),
      pauseFor: const Duration(seconds: 10),
      cancelOnError: false,
      partialResults: true,
    );

    // Wait loop to let the listener finish capturing
    int checks = 0;
    while (_speech.isListening && checks < 80) {
      await Future.delayed(const Duration(milliseconds: 500));
      checks++;
    }
    
    return _parseArabicNumbers(fullText);
  }

  /// Extracts numbers from Arabic text
  static Map<String, int>? _parseArabicNumbers(String text) {
    print("🗣️ I heard: $text");
    
    // 1. Normalize Arabic
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < arabicDigits.length; i++) {
      text = text.replaceAll(arabicDigits[i], i.toString());
    }

    // 2. Find numbers
    final regex = RegExp(r'\d+');
    final matches = regex.allMatches(text);
    final numbers = matches.map((m) => int.parse(m.group(0)!)).toList();

    // 3. Filter Logic (Smart Pulse Detection)
    // We look for numbers between 40 and 300
    final validNumbers = numbers.where((n) => n >= 40 && n <= 300).toList();

    if (validNumbers.length >= 2) {
      // Sort the first two (Sys/Dia)
      // Usually the two largest numbers are Sys and Dia
      // The Pulse is often smaller (60-100), but could be similar to Dia.
      
      // Let's assume the order spoken is meaningful: Sys, then Dia, then Pulse
      int sys = validNumbers[0];
      int dia = validNumbers[1];
      int pulse = 0;

      // Swap if user said "80 over 120" by mistake
      if (dia > sys) {
        final temp = sys;
        sys = dia;
        dia = temp;
      }

      // Check for Pulse (3rd number)
      if (validNumbers.length >= 3) {
        pulse = validNumbers[2];
      }

      return {
        'sys': sys,
        'dia': dia,
        'pulse': pulse,
      };
    }
    
    return null;
  }
}