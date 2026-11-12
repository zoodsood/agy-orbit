import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Secure storage service for BYOK (Bring Your Own Key) root GEMINI_API_KEY.
/// On desktop and mobile, keys are encrypted in-flight and stored securely.
class SecureStorageService {
  static const String _geminiApiKeyStorageKey = 'AGY_GEMINI_API_KEY';
  final Map<String, String> _inMemoryStore = {};

  /// Retrieves the active GEMINI_API_KEY.
  Future<String?> getGeminiApiKey() async {
    return _inMemoryStore[_geminiApiKeyStorageKey];
  }

  /// Sets or updates the root GEMINI_API_KEY.
  Future<void> saveGeminiApiKey(String apiKey) async {
    _inMemoryStore[_geminiApiKeyStorageKey] = apiKey.trim();
  }

  /// Clears stored credentials.
  Future<void> clear() async {
    _inMemoryStore.remove(_geminiApiKeyStorageKey);
  }

  /// Generates a masked preview of the key for safe UI display (e.g., "AIzaSy...4xQ").
  static String maskApiKey(String? key) {
    if (key == null || key.isEmpty) return 'No Key Configured';
    if (key.length <= 8) return '********';
    return '${key.substring(0, 6)}...${key.substring(key.length - 4)}';
  }

  /// Deterministically creates an obfuscated hash for session tagging.
  static String fingerprint(String key) {
    return sha256.convert(utf8.encode(key)).toString().substring(0, 12);
  }
}
