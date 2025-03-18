import 'dart:convert';

class JsonHelper {
  /// Parses a string to a Map<String, dynamic>
  /// If the string is not valid JSON, attempts to fix it
  static Map<String, dynamic> parseJsonString(String? inputJson) {
    if (inputJson == null || inputJson.isEmpty) {
      return {};
    }

    try {
      // Try standard JSON parsing first
      return json.decode(inputJson);
    } catch (e) {
      // If it fails, try to fix the format
      return _attemptJsonFix(inputJson);
    }
  }

  /// Attempts to fix malformed JSON strings
  static Map<String, dynamic> _attemptJsonFix(String inputJson) {
    // If it starts with a '{' it might be JSON-like but malformed
    if (inputJson.trim().startsWith('{')) {
      try {
        // Try to convert keys without quotes to properly quoted keys
        String fixedJson = inputJson;

        // Replace occurrences of "key:" with "\"key\":" (for string keys)
        RegExp keyRegex = RegExp(r'([a-zA-Z_][a-zA-Z0-9_]*):');
        fixedJson = fixedJson.replaceAllMapped(keyRegex, (match) {
          return '"${match.group(1)}":';
        });

        // Try to parse the fixed JSON
        return json.decode(fixedJson);
      } catch (e) {
        print('Could not fix JSON format: $e');
        return {};
      }
    }

    return {};
  }

  /// Safely converts an object to a JSON string
  static String toJsonString(dynamic object) {
    if (object == null) {
      return '{}';
    }

    try {
      if (object is String) {
        // If it's already a string, try to parse it first to ensure it's valid JSON
        // then encode it back to a string
        try {
          var decoded = json.decode(object);
          return json.encode(decoded);
        } catch (e) {
          // If it's not valid JSON, try to fix it
          var fixed = _attemptJsonFix(object);
          return json.encode(fixed);
        }
      } else {
        // If it's another type, encode it directly
        return json.encode(object);
      }
    } catch (e) {
      print('Error converting to JSON string: $e');
      return '{}';
    }
  }

  /// Gets a safely typed value from a JSON map
  static T? getValue<T>(Map<String, dynamic> json, String key,
      {T? defaultValue}) {
    try {
      var value = json[key];
      if (value == null) return defaultValue;

      // Handle type conversions
      if (T == int && value is num) {
        return value.toInt() as T;
      } else if (T == double && value is num) {
        return value.toDouble() as T;
      } else if (value is T) {
        return value;
      }
      return defaultValue;
    } catch (e) {
      return defaultValue;
    }
  }

  /// Safely parses a string that might be in JavaScript object notation
  /// (with unquoted keys) instead of proper JSON format.
  static Map<String, dynamic> safelyParseJson(dynamic data) {
    if (data == null) {
      return {};
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    if (data is String) {
      try {
        // Check if it's a JavaScript object notation with unquoted keys
        String formattedJson = data;
        if (formattedJson.startsWith('{') &&
                (formattedJson.contains(RegExp(r'(\w+):')) &&
                    !formattedJson.contains(RegExp(r'"(\w+)":'))) ||
            formattedJson.contains("'")) {
          // Replace unquoted keys with quoted keys
          formattedJson = formattedJson
              .replaceAllMapped(
                  RegExp(r'(\w+):'), (match) => '"${match.group(1)}":')
              .replaceAll("'", '"');
        }

        return json.decode(formattedJson);
      } catch (e) {
        print('Error parsing JSON: $e\nInput data: $data');
        return {};
      }
    }

    return {};
  }
}
