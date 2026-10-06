import 'dart:convert';
import 'http_client.dart';
import '../config/api_config.dart';
import '../models/company_location_model.dart';

class LocationService {
  final HttpClient _httpClient = HttpClient.instance;

  Future<bool> hasCompanyLocation() async {
    try {
      await getCompanyLocation();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<CompanyLocation> getCompanyLocation() async {
    final response = await _httpClient.get(ApiConfig.companyLocation);
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return CompanyLocation.fromJson(Map<String, dynamic>.from(json));
    }

    String? message;
    try {
      final json = jsonDecode(response.body);
      message = json['Message']?.toString() ?? json['message']?.toString();
    } catch (_) {
      message = null;
    }

    throw Exception(message ?? 'Lokasi kantor belum tersedia.');
  }
}
