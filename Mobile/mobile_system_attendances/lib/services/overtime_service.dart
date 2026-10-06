import 'dart:convert';
import 'package:intl/intl.dart';
import '../config/api_config.dart';
import 'http_client.dart';

class OvertimeService {
  final _client = HttpClient.instance;

  Future<List<Map<String, dynamic>>> getMine() async {
    final response = await _client.get(ApiConfig.myOvertimes);
    if (response.statusCode != 200) throw Exception('Data lembur tidak dapat dimuat.');
    final values = jsonDecode(response.body);
    if (values is! List) return [];
    return values.whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList();
  }

  Future<List<Map<String, dynamic>>> getSchedules() async {
    final response = await _client.get('/api/schedules');
    if (response.statusCode != 200) throw Exception('Jadwal lembur tidak dapat dimuat.');
    final values = jsonDecode(response.body);
    if (values is! List) return [];
    return values.whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList();
  }

  Future<void> createRequest({
    required DateTime date,
    required int scheduleId,
    String? note,
  }) async {
    final response = await _client.post(
      '/api/overtimes/request',
      data: {
        'date': DateFormat('yyyy-MM-dd').format(date),
        'scheduleId': scheduleId,
        'note': note,
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = jsonDecode(response.body);
      throw Exception(body is Map ? body['Message'] ?? body['message'] ?? 'Pengajuan lembur gagal.' : 'Pengajuan lembur gagal.');
    }
  }

  Future<void> updateDecision(int id, bool approve, {String? rejectionReason}) async {
    final response = await _client.put(
      '/api/overtimes/$id/${approve ? 'approve' : 'reject'}',
      data: rejectionReason == null ? {} : {'rejectionReason': rejectionReason},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Status lembur gagal diperbarui.');
    }
  }

  Future<void> deleteRequest(int id) async {
    final response = await _client.delete('/api/overtimes/$id');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Pengajuan lembur gagal dibatalkan.');
    }
  }
}
