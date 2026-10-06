import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'http_client.dart';

class AttendanceService {
  final HttpClient _client = HttpClient.instance;

  Future<Map<String, dynamic>> getMyProfile() async {
    final response = await _client.get(ApiConfig.mobileMe);
    if (response.statusCode != 200) {
      throw Exception('Data pegawai tidak dapat dimuat.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getHistory(DateTime month) async {
    final response = await _client.get(
      ApiConfig.myAttendances,
      queryParams: {
        'year': month.year.toString(),
        'month': month.month.toString(),
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Riwayat absensi tidak dapat dimuat.');
    }
    final values = jsonDecode(response.body);
    if (values is! List) return [];
    return values
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
  }

  /// Status absensi hari ini: kehadiran reguler (check-in/out) & sesi lembur
  /// yang sudah disetujui dan masih perlu diabsen.
  Future<Map<String, dynamic>> getTodayStatus() async {
    final response = await _client.get(ApiConfig.attendanceTodayStatus);
    if (response.statusCode != 200) {
      throw Exception('Status absensi hari ini tidak dapat dimuat.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Check-in / check-out untuk Hadir atau sesi Lembur (melalui verifikasi wajah).
  Future<Map<String, dynamic>> submit({
    required String status,
    required String mode, // 'checkin' | 'checkout'
    int? overtimeId,
    required String note,
    required int? locationId,
    required double? latitude,
    required double? longitude,
    required double? accuracyMeters,
    required double? distanceMeters,
    required double? faceSimilarity,
    required double companyTolerance,
    required List<PlatformFile> files,
  }) async {
    return _post(
      fields: {
        'status': status,
        'mode': mode,
        if (overtimeId != null) 'overtimeId': overtimeId.toString(),
        'note': note,
        'locationId': locationId?.toString() ?? '',
        'latitude': latitude?.toString() ?? '',
        'longitude': longitude?.toString() ?? '',
        'accuracyMeters': accuracyMeters?.toString() ?? '',
        'distanceMeters': distanceMeters?.toString() ?? '',
        'faceSimilarity': faceSimilarity?.toString() ?? '',
        'companyTolerance': companyTolerance.toString(),
        'faceVerified': 'true',
        'livenessVerified': 'true',
      },
      files: files,
    );
  }

  /// Izin / Sakit: satu kali submit per hari, tanpa verifikasi wajah dan tanpa check-out.
  Future<Map<String, dynamic>> submitLeave({
    required String status,
    required String note,
    required List<PlatformFile> files,
  }) async {
    return _post(
      fields: {
        'status': status,
        'mode': 'leave',
        'note': note,
        'faceVerified': 'false',
        'livenessVerified': 'false',
      },
      files: files,
    );
  }

  Future<Map<String, dynamic>> _post({
    required Map<String, String> fields,
    required List<PlatformFile> files,
  }) async {
    final paths = files
        .map((file) => file.path)
        .whereType<String>()
        .map(File.new)
        .toList();
    final response = await _client.postMultipart(
      ApiConfig.createMobileAttendance,
      files: paths,
      fieldName: 'attachments',
      fields: fields,
    );
    final body = await http.Response.fromStream(response);
    if (body.statusCode < 200 || body.statusCode >= 300) {
      var message = 'Absensi gagal disimpan.';
      try {
        final data = jsonDecode(body.body) as Map<String, dynamic>;
        message = data['message']?.toString() ?? data['Message']?.toString() ?? message;
      } on FormatException {
        if (body.body.trim().isNotEmpty) message = body.body;
      }
      throw Exception(message);
    }
    return jsonDecode(body.body) as Map<String, dynamic>;
  }
}
