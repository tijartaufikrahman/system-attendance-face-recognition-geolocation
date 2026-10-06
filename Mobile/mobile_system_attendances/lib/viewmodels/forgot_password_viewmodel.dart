import 'package:flutter/material.dart';
import '../services/auth_service.dart';

enum ForgotPasswordStep {
  email,      // Step 1: Input email
  otp,        // Step 2: Input OTP
  reset,      // Step 3: Input new password
}

class ForgotPasswordViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();

  // State
  ForgotPasswordStep _currentStep = ForgotPasswordStep.email;
  bool _isLoading = false;
  String _errorMessage = '';
  String _successMessage = '';
  String _email = '';
  String _otp = '';

  // Getters
  ForgotPasswordStep get currentStep => _currentStep;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  String get successMessage => _successMessage;
  String get email => _email;
  String get otp => _otp;

  // Step 1: Kirim OTP ke email
  Future<bool> sendOtp({required String email}) async {
    _isLoading = true;
    _errorMessage = '';
    _successMessage = '';
    notifyListeners();

    try {
      final response = await _authService.forgotPassword(email: email);

      _email = email;
      _successMessage = response['Message'] ?? 'OTP berhasil dikirim';
      _currentStep = ForgotPasswordStep.otp;
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

  // Step 2: Verifikasi OTP
  Future<bool> verifyOtp({required String otp}) async {
    _isLoading = true;
    _errorMessage = '';
    _successMessage = '';
    notifyListeners();

    try {
      final response = await _authService.verifyOtp(
        email: _email,
        otp: otp,
      );

      _otp = otp;
      _successMessage = response['Message'] ?? 'OTP berhasil diverifikasi';
      _currentStep = ForgotPasswordStep.reset;
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

  // Step 3: Reset password
  Future<bool> resetPassword({required String newPassword}) async {
    _isLoading = true;
    _errorMessage = '';
    _successMessage = '';
    notifyListeners();

    try {
      final response = await _authService.resetPassword(
        email: _email,
        otp: _otp,
        password: newPassword,
      );

      _successMessage = response['Message'] ?? 'Password berhasil direset';
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

  // Kembali ke step sebelumnya
  void goBack() {
    _errorMessage = '';
    _successMessage = '';
    switch (_currentStep) {
      case ForgotPasswordStep.otp:
        _currentStep = ForgotPasswordStep.email;
        break;
      case ForgotPasswordStep.reset:
        _currentStep = ForgotPasswordStep.otp;
        break;
      case ForgotPasswordStep.email:
        break;
    }
    notifyListeners();
  }

  // Reset semua state
  void reset() {
    _currentStep = ForgotPasswordStep.email;
    _isLoading = false;
    _errorMessage = '';
    _successMessage = '';
    _email = '';
    _otp = '';
    notifyListeners();
  }
}
