import 'dart:convert';
import 'package:http/http.dart' as http;

class ConfigService {
  static Map<String, dynamic> _config = {};

  // Fetch configuration from the remote URL
  static Future<void> loadConfig() async {
    const url = 'https://pastebin.com/raw/kJdfXDpJ';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        _config = jsonDecode(response.body);
        print('Config loaded: $_config');
      } else {
        throw Exception(
            'Failed to load configuration. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading configuration: $e');
      throw e;
    }
  }

  // Access configuration values
  static String get(String key) {
    if (_config.isEmpty) {
      throw Exception('ConfigService: Configuration has not been loaded yet.');
    }
    return _config[key] ?? '';
  }
}
