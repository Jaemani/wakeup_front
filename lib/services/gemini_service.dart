import 'package:http/http.dart' as http;
import 'dart:convert';

class GeminiService {
  static const String apiUrl = "https://api.gemini.example.com/get-suggestion";

  // Get a suggestion from the Gemini API
  static Future<String> getSuggestion() async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        body: jsonEncode({
          'prompt':
              'The driver appears drowsy. Suggest a short rest or stretch.',
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['suggestion'] ?? 'Take a short rest or stretch!';
      } else {
        return 'Unable to fetch suggestion. Please rest or stretch.';
      }
    } catch (e) {
      return 'Error fetching suggestion.';
    }
  }
}
