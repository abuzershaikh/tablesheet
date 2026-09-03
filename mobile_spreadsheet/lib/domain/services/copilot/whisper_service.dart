import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WhisperService {
  /// Transcribes audio file at [filePath] using OpenAI / Groq Whisper API or Gemini multimodal transcription.
  static Future<String?> transcribeAudio(String filePath) async {
    final prefs = await SharedPreferences.getInstance();
    
    String apiKey = prefs.getString('whisper_api_key') ?? '';
    if (apiKey.isEmpty) {
      apiKey = prefs.getString('openai_api_key') ?? '';
    }

    final file = File(filePath);
    if (!await file.exists()) {
      debugPrint('[WhisperService] Audio file does not exist: $filePath');
      return null;
    }

    // 1. Try Cloudflare Worker Whisper Endpoint
    final cfWorkerUrl = prefs.getString('cloudflare_whisper_worker_url') ?? 'https://sheet-copilot-whisper-stt.zestbizar.workers.dev';
    try {
      final uri = Uri.parse(cfWorkerUrl);
      final request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('file', filePath));

      debugPrint('[WhisperService] Sending audio to Cloudflare Whisper Worker: $cfWorkerUrl');
      final streamedResponse = await request.send().timeout(const Duration(seconds: 12));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['text']?.toString().trim();
        if (text != null && text.isNotEmpty) {
          debugPrint('[WhisperService] Cloudflare Worker Transcribed text: $text');
          return text;
        }
      } else {
        debugPrint('[WhisperService] Cloudflare Worker error (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('[WhisperService] Cloudflare Worker exception: $e');
    }

    // 2. If explicit Whisper / OpenAI / Groq API Key is available
    if (apiKey.isNotEmpty) {
      try {
        final whisperUrl = prefs.getString('whisper_endpoint_url') ?? 
            (apiKey.startsWith('gsk_') 
                ? 'https://api.groq.com/openai/v1/audio/transcriptions'
                : 'https://api.openai.com/v1/audio/transcriptions');

        final uri = Uri.parse(whisperUrl);
        final request = http.MultipartRequest('POST', uri)
          ..headers['Authorization'] = 'Bearer $apiKey'
          ..fields['model'] = apiKey.startsWith('gsk_') ? 'whisper-large-v3' : 'whisper-1'
          ..fields['response_format'] = 'json'
          ..files.add(await http.MultipartFile.fromPath('file', filePath));

        debugPrint('[WhisperService] Sending audio to Whisper API: $whisperUrl');
        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final text = data['text']?.toString().trim();
          debugPrint('[WhisperService] Whisper Transcribed text: $text');
          return text;
        } else {
          debugPrint('[WhisperService] Whisper API error (${response.statusCode}): ${response.body}');
        }
      } catch (e) {
        debugPrint('[WhisperService] Whisper API exception: $e');
      }
    }

    // 3. Fallback: Transcribe using Gemini Multimodal Audio API
    final geminiKey = prefs.getString('gemini_api_key') ?? '';
    if (geminiKey.isNotEmpty) {
      debugPrint('[WhisperService] Falling back to Gemini Multimodal Audio Transcription...');
      return await _transcribeWithGemini(file, geminiKey);
    }


    return null;
  }

  /// Transcribe audio using Gemini Multimodal Audio Input API (with 1.5-flash and 2.5-flash fallbacks)
  static Future<String?> _transcribeWithGemini(File file, String apiKey) async {
    final modelsToTry = ['gemini-2.0-flash', 'gemini-1.5-flash', 'gemini-2.5-flash', 'gemini-2.0-flash-exp'];

    final bytes = await file.readAsBytes();
    final base64Audio = base64Encode(bytes);

    for (final model in modelsToTry) {
      try {
        final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');

        final body = jsonEncode({
          "contents": [{
            "parts": [
              {
                "inline_data": {
                  "mime_type": "audio/mp4",
                  "data": base64Audio
                }
              },
              {
                "text": "Transcribe this audio clip into plain text exactly as spoken in Hindi, English, or Urdu. Output ONLY the raw transcribed text. Do not add explanations or notes."
              }
            ]
          }]
        });

        debugPrint('[WhisperService/GeminiAudio] Trying model $model...');
        final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: body);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final transcribed = data['candidates']?[0]?['content']?['parts']?[0]?['text']?.toString().trim();
          if (transcribed != null && transcribed.isNotEmpty) {
            debugPrint('[WhisperService/GeminiAudio] Transcribed via $model: "$transcribed"');
            return transcribed;
          }
        } else {
          debugPrint('[WhisperService/GeminiAudio] Model $model returned (${response.statusCode}): ${response.body}');
        }
      } catch (e) {
        debugPrint('[WhisperService/GeminiAudio] Model $model exception: $e');
      }
    }
    return null;
  }

}
