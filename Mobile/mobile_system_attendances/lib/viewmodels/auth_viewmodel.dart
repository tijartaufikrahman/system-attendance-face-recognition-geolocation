import 'package:flutter/material.dart';
import '../models/login_model.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();

  // State
  bool _isLoading = false;
  bool _isSuccess = false;
  String _errorMessage = '';
  LoginResponse? _loginResponse;

  // Getters
  bool get isLoading => _isLoading;
  bool get isSuccess => _isSuccess;
  String get errorMessage => _errorMessage;
  LoginResponse? get loginResponse => _loginResponse;
  bool get isLoggedIn => _loginResponse != null;

  // Login
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = '';
    _isSuccess = false;
    notifyListeners();

    try {
      final response = await _authService.login(
        email: email,
        password: password,
      );

      _loginResponse = LoginResponse.fromJson(response);

      // Simpan data ke local storage
      final storage = await StorageService.instance;
      await storage.saveToken(_loginResponse!.token);
      await storage.saveUserData(
        userId: _loginResponse!.id,
        name: _loginResponse!.name,
        email: _loginResponse!.email,
        roleId: _loginResponse!.roleId,
        role: _loginResponse!.role,
        companyId: _loginResponse!.companyId,
      );

      _isSuccess = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } on Exception catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan yang tidak terduga';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    final storage = await StorageService.instance;
    await storage.clearAll();
    _loginResponse = null;
    _isSuccess = false;
    _errorMessage = '';
    notifyListeners();
  }

  // Cek status login dari storage
  Future<bool> checkLoginStatus() async {
    final storage = await StorageService.instance;
    if (storage.isLoggedIn()) {
      // TODO: bisa tambahkan logic refresh token atau validasi token
      return true;
    }
    return false;
  }
}
