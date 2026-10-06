class ApiConfig {
  // Base URL API (HTTPS port 7262)
  // Android Emulator: https://10.0.2.2:7262
  // iOS Simulator: https://localhost:7262
  // Device fisik via WiFi: https://<IP_LAPTOP>:7262
  // Untuk production ganti ke URL server production

  // === GANTI IP INI SESUAI IP LAPTOP ANDA ===
  static const String baseUrl = 'https://192.168.2.166:7262';

  // API Endpoints
  static const String login = '/api/auth/mobile/login'; // Login khusus mobile
  static const String platformLogin = '/api/auth/platform/login';
  static const String forgotPassword = '/api/auth/forgot-password';
  static const String verifyOtp = '/api/auth/verify-otp';
  static const String resetPassword = '/api/auth/reset-password';

  // Location
  static const String companyLocation = '/api/locations/company';
  static const String myFaceEmbedding = '/api/face-embeddings/me';
  static const String myFaceEmbeddingVector = '/api/face-embeddings/me/vector';
  static const String mobileMe = '/api/mobile/me';
  static const String myAttendances = '/api/attendances/me';
  static const String createMobileAttendance = '/api/attendances/mobile';
  static const String attendanceTodayStatus = '/api/attendances/today-status';
  static const String myAnnouncements = '/api/announcements/me';
  static const String myOvertimes = '/api/overtimes/me';

  // Timeout Settings (dalam detik)
  static const int connectTimeout = 15;
  static const int receiveTimeout = 15;

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userIdKey = 'user_id';
  static const String userNameKey = 'user_name';
  static const String userEmailKey = 'user_email';
  static const String userRoleIdKey = 'user_role_id';
  static const String userRoleKey = 'user_role';
  static const String companyIdKey = 'company_id';
}
