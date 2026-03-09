import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';

class AiService {
  // ⚠️ SECURITY NOTE: In a real production app, use an Env variable. 
  // For this personal project, pasting it here is fine.
  static final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  

  /// The main function: Takes the user's question, gathers their health context, 
  /// and gets a smart answer.
  static Future<String> askDoctor(String userQuestion) async {
    try {
      final _model = GenerativeModel(
        model: 'gemini-flash-latest', 
        apiKey: _apiKey,
      );
      // 1. GATH
      //ER CONTEXT (The "Smart" part)
      final contextData = await _getPatientContext();
      
      // 2. BUILD THE SYSTEM PROMPT
      final prompt = '''
You are "Dr. PressurePal", a helpful, empathetic medical assistant for a hypertension patient.
Here is the patient's real-time data:
$contextData

User Question: "$userQuestion"

INSTRUCTIONS:
- Analyze the user's data if relevant to the question.
- Be concise, encouraging, and clear.
- Use emojis slightly (🩺, 💊) to be friendly.
- CRITICAL: You are an AI, not a human doctor. If the user reports severe symptoms (chest pain, difficulty breathing, reading > 180/120), tell them to go to the hospital immediately.
- Answer in the same language the user asks (English or Arabic).
''';

      // 3. SEND TO GEMINI
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      return response.text ?? "I'm having trouble thinking right now. Please try again.";
    } catch (e) {
      return "Error connecting to AI Doctor: $e";
    }
  }

  /// Fetches the last 7 days of BP readings and Meds to give the AI "Memory"
  static Future<String> _getPatientContext() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final dateStr = DateFormat('yyyy-MM-dd').format(sevenDaysAgo);

    try {
      // Fetch recent BP readings
      final bpData = await client
          .from('readings')
          .select()
          .gte('date', dateStr)
          .order('date', ascending: false)
          .limit(10); // Last 10 readings

      // Fetch Medications
      final medData = await client.from('medications').select();

      // Format for the AI
      StringBuffer buffer = StringBuffer();
      
      buffer.writeln("--- RECENT BLOOD PRESSURE READINGS (Last 7 Days) ---");
      if (bpData.isEmpty) {
        buffer.writeln("No readings recorded recently.");
      } else {
        for (var r in bpData) {
          buffer.writeln("- ${r['date']} (${r['time_of_day']}): ${r['systolic']}/${r['diastolic']}, Pulse: ${r['pulse']}");
        }
      }

      buffer.writeln("\n--- MEDICATIONS LIST ---");
      if (medData.isEmpty) {
        buffer.writeln("No medications on file.");
      } else {
        for (var m in medData) {
          buffer.writeln("- ${m['name']} (${m['dosage']}), Freq: ${m['frequency']}x/day");
        }
      }

      return buffer.toString();
    } catch (e) {
      return "Error loading medical context: $e";
    }
  }
}