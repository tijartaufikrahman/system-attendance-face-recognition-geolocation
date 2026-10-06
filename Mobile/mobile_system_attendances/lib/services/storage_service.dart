import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class StorageService {
  static StorageService? _instance;
  late SharedPreferences _prefs;

  StorageService._();

  // Singleton instance
  static Future<StorageService> get instance async {
    _instance ??= StorageService._();
    _instance!._prefs = await SharedPreferences.getInstance();
    return _instance!;
  }

  // Simpan token
  Future<void> saveToken(String token) async {
    await _prefs.setString(ApiConfig.tokenKey, token);
  }

  // Ambil token
  String? getToken() {
    return _prefs.getString(ApiConfig.tokenKey);
  }

  // Simpan data user
  Future<void> saveUserData({
    required int userId,
    required String name,
    required String email,
    required int roleId,
    required String role,
    int? companyId,
  }) async {
    await _prefs.setInt(ApiConfig.userIdKey, userId);
    await _prefs.setString(ApiConfig.userNameKey, name);
    await _prefs.setString(ApiConfig.userEmailKey, email);
    await _prefs.setInt(ApiConfig.userRoleIdKey, roleId);
    await _prefs.setString(ApiConfig.userRoleKey, role);
    if (companyId != null) {
      await _prefs.setInt(ApiConfig.companyIdKey, companyId);
    }
  }

  // Ambil data user
  int? getUserId() => _prefs.getInt(ApiConfig.userIdKey);
  String? getUserName() => _prefs.getString(ApiConfig.userNameKey);
  String? getUserEmail() => _prefs.getString(ApiConfig.userEmailKey);
  int? getUserRoleId() => _prefs.getInt(ApiConfig.userRoleIdKey);
  String? getUserRole() => _prefs.getString(ApiConfig.userRoleKey);
  int? getCompanyId() => _prefs.getInt(ApiConfig.companyIdKey);

  // Cek apakah user sudah login
  bool isLoggedIn() {
    final token = getToken();
    return token != null && token.isNotEmpty;
  }

  // Logout - hapus semua data
  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
