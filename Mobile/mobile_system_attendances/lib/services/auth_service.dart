import 'dart:convert';
import 'package:http/http.dart' as http;
import 'http_client.dart';
import '../config/api_config.dart';

class AuthService {
  final HttpClient _httpClient = HttpClient.instance;

  // Login untuk Company Users (Admin HR, Employee)
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _httpClient.post(
        ApiConfig.login,
        data: {
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(body['Message'] ?? 'Login gagal');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Login untuk Platform Super Admin
  Future<Map<String, dynamic>> platformLogin({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _httpClient.post(
        ApiConfig.platformLogin,
        data: {
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(body['Message'] ?? 'Login gagal');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Forgot Password
  Future<Map<String, dynamic>> forgotPassword({required String email}) async {
    try {
      final response = await _httpClient.post(
        ApiConfig.forgotPassword,
        data: {
          'email': email,
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(body['Message'] ?? 'Gagal mengirim email');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Verify OTP (menggunakan form data)
  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await http.Client().post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.verifyOtp}'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: {
          'email': email,
          'otp': otp,
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(body['Message'] ?? 'Verifikasi OTP gagal');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Reset Password (menggunakan form data)
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String password,
  }) async {
    try {
      final response = await http.Client().post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.resetPassword}'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: {
          'email': email,
          'otp': otp,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        throw Exception(body['Message'] ?? 'Reset password gagal');
      }
    } catch (e) {
      rethrow;
    }
  }
}
