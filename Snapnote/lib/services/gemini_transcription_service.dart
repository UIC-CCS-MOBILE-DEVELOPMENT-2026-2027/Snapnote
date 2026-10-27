import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// Thrown when the service can't do its job (missing key, empty response,
/// API-side failure, etc). Callers should catch this and show a message.
class TranscriptionException implements Exception {
  TranscriptionException(this.message);
  final String message;

  @override
  String toString() => 'TranscriptionException: $message';
}

/// Sends a photo of handwritten/printed notes to the Gemini API (free tier)
/// and gets back transcribed text, with any mathematical notation encoded
/// as LaTeX: `$...$` for inline math, `$$...$$` for block/display math.
class GeminiTranscriptionService {
  GeminiTranscriptionService({String? modelName})
      : _modelName = modelName ?? 'gemini-3.5-flash-lite';

  final String _modelName;

  static const _prompt = '''
Transcribe all text visible in this image exactly as written.

Rules:
- Preserve the original structure (paragraphs, lists, headings) as plain text.
- Any mathematical expression must be written as LaTeX.
  - Wrap inline math (math that sits within a line of text) as \$...\$
  - Wrap standalone/display equations as \$\$...\$\$
- Do not translate or paraphrase. Do not add commentary, headers, or
  markdown code fences. Output only the transcribed content.
- If the image contains no legible text, output exactly: (no text found)
''';

  GenerativeModel _buildModel() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null ||
        apiKey.isEmpty ||
        apiKey == 'your_gemini_api_key_here') {
      throw TranscriptionException(
        'GEMINI_API_KEY is not set. Copy .env.example to .env and add your '
        'free-tier key from https://aistudio.google.com/app/apikey',
      );
    }
    return GenerativeModel(model: _modelName, apiKey: apiKey);
  }

  /// Transcribes [imageFile] into text, preserving math as LaTeX.
  Future<String> transcribeImage(File imageFile) async {
    final model = _buildModel();
    final bytes = await imageFile.readAsBytes();
    final mimeType = _guessMimeType(imageFile.path);

    try {
      final response = await model.generateContent([
        Content.multi([
          TextPart(_prompt),
          DataPart(mimeType, bytes),
        ]),
      ]);

      final text = response.text?.trim();
      if (text == null || text.isEmpty) {
        throw TranscriptionException('Gemini returned an empty response.');
      }
      return text;
    } on TranscriptionException {
      rethrow;
    } on GenerativeAIException catch (e) {
      // The google_generative_ai package doesn't expose a structured HTTP
      // status code on its exceptions (GenerativeAIException/ServerException
      // only carry a `message` string), so detecting a 429/quota failure
      // means pattern-matching on that message. Google's server errors
      // typically surface the status code and/or "RESOURCE_EXHAUSTED" /
      // "quota" in the text, so we check for those case-insensitively.
      if (_isRateLimitError(e.message)) {
        throw TranscriptionException(
          "You've hit the free-tier rate limit — wait a moment and try again.",
        );
      }
      throw TranscriptionException('Transcription failed: ${e.message}');
    } catch (e) {
      throw TranscriptionException('Transcription failed: $e');
    }
  }

  bool _isRateLimitError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('429') ||
        lower.contains('quota') ||
        lower.contains('rate limit') ||
        lower.contains('resource_exhausted') ||
        lower.contains('resource exhausted');
  }

  String _guessMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }
}
