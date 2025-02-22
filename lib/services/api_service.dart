import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final String _clientId = '5c66a0001059406b8989bd179ab8897d';
  final String _clientSecret = '5de5f12d25e4418b8c78e6b80e78d9f7';
  String? _accessToken;
  DateTime? _tokenExpiry;

  String? get accessToken => _accessToken;

  Future<String?> getAccessToken() async {
    // Return existing token if it's still valid
    if (_accessToken != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken;
    }

    try {
      final response = await http.post(
        Uri.parse('https://oauth.fatsecret.com/connect/token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_clientId:$_clientSecret'))}',
        },
        body: {
          'grant_type': 'client_credentials',
          'scope': 'premier',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['access_token'];
        // Set token expiry to slightly less than the actual expiry time
        _tokenExpiry = DateTime.now().add(Duration(seconds: (data['expires_in'] as int) - 60));
        return _accessToken;
      }
    } catch (e) {
      print('Error getting access token: $e');
    }
    return null;
  }
}