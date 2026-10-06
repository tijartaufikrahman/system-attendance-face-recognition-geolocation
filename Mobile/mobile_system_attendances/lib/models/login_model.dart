// Login Request Model
class LoginRequest {
  final String email;
  final String password;

  LoginRequest({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
    };
  }
}

// Login Response Model
class LoginResponse {
  final int id;
  final String token;
  final String name;
  final String email;
  final int roleId;
  final String role;
  final int? companyId;
  final String message;

  LoginResponse({
    required this.id,
    required this.token,
    required this.name,
    required this.email,
    required this.roleId,
    required this.role,
    this.companyId,
    required this.message,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      id: json['id'] ?? 0,
      token: json['token'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      roleId: json['roleId'] ?? 0,
      role: json['role'] ?? '',
      companyId: json['companyId'],
      message: json['message'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'token': token,
      'name': name,
      'email': email,
      'roleId': roleId,
      'role': role,
      'companyId': companyId,
      'message': message,
    };
  }
}
