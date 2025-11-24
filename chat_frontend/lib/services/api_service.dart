import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Base URL

  static const String baseUrl = 'http://192.168.100.16:3000/api';

  // Store and retrieve auth token

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // Login API call
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Save token for future requests
        if (data['token'] != null) {
          await saveToken(data['token']);
        }
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': jsonDecode(response.body)['message'] ?? 'Login failed',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Signup API call
  Future<Map<String, dynamic>> signup(
    String name,
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['token'] != null) {
          await saveToken(data['token']);
        }
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': jsonDecode(response.body)['message'] ?? 'Signup failed',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Get chat list
  Future<Map<String, dynamic>> getChatList() async {
    try {
      final token = await getToken();
      print(token);
      final response = await http.get(
        Uri.parse('$baseUrl/chats'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': 'Failed to load chats'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Get messages with specific user
  Future<Map<String, dynamic>> getMessages(String otherUserId) async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/messages/$otherUserId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': 'Failed to load messages'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Send a message (REST fallback, mainly you'll use Socket.IO)
  Future<Map<String, dynamic>> sendMessage(
    String chatId,
    String message,
  ) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/send/$chatId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'message': message}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': 'Failed to send message'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }
}
