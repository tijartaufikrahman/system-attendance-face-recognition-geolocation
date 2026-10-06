import 'dart:convert';

import '../config/api_config.dart';
import 'http_client.dart';

class AnnouncementService {
  final HttpClient _client = HttpClient.instance;

  Future<List<Map<String, dynamic>>> getMine() async {
    final response = await _client.get(ApiConfig.myAnnouncements);
    if (response.statusCode != 200) {
      throw Exception('Pengumuman tidak dapat dimuat.');
    }
    final values = jsonDecode(response.body);
    if (values is! List) return [];
    return values
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
  }

  Future<int> getUnreadCount() async {
    final response = await _client.get('/api/announcements/unread-count');
    if (response.statusCode != 200) throw Exception('Jumlah informasi tidak dapat dimuat.');
    final value = jsonDecode(response.body);
    return value is Map && value['count'] is num ? (value['count'] as num).toInt() : 0;
  }

  Future<void> markRead(int id) async {
    final response = await _client.post('/api/announcements/$id/read', data: {});
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Informasi gagal ditandai sudah dibaca.');
    }
  }
}
