import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/announcement_service.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final _service = AnnouncementService();
  List<Map<String, dynamic>> _announcements = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final announcements = await _service.getMine();
      if (mounted) setState(() => _announcements = announcements);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }

  }

  Future<void> _openAnnouncement(Map<String, dynamic> announcement) async {
    final id = (announcement['id'] as num?)?.toInt();
    if (id != null && announcement['isRead'] != true) {
      await _service.markRead(id);
      if (mounted) {
        setState(() => announcement['isRead'] = true);
      }
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(announcement['title']?.toString() ?? 'Pengumuman'),
        content: SingleChildScrollView(
          child: Text(announcement['content']?.toString() ?? ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadAnnouncements,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Pengumuman',
            style: TextStyle(
              color: Color(0xFF1B2A4A),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Informasi dari perusahaan yang ditujukan untuk Anda.',
            style: TextStyle(color: Color(0xFF667085), fontSize: 13),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _buildError()
          else if (_announcements.isEmpty)
            _buildEmpty()
          else
            ..._announcements.map(_buildAnnouncementCard),
        ],
      ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> announcement) {
    final createdAt = DateTime.tryParse(announcement['createdAt']?.toString() ?? '');
    final isRead = announcement['isRead'] == true;
    return GestureDetector(
      onTap: () => _openAnnouncement(announcement),
      child: Stack(
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.campaign_rounded, color: Color(0xFF2196F3)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _truncateWords(announcement['title']?.toString() ?? 'Pengumuman', 10),
                        style: const TextStyle(
                          color: Color(0xFF1B2A4A),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _truncateWords(announcement['content']?.toString() ?? '', 35),
                        style: const TextStyle(color: Color(0xFF667085), fontSize: 13),
                      ),
                      if (createdAt != null) ...[
                        const SizedBox(height: 9),
                        Text(
                          DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(createdAt.toLocal()),
                          style: const TextStyle(color: Color(0xFF98A2B3), fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isRead)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF22C55E),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _truncateWords(String value, int maxWords) {
    final words = value.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
    if (words.length <= maxWords) return value;
    return '${words.take(maxWords).join(' ')}...';
  }

  Widget _buildEmpty() => const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(
          child: Text(
            'Belum ada pengumuman untuk Anda.',
            style: TextStyle(color: Color(0xFF667085)),
          ),
        ),
      );

  Widget _buildError() => Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loadAnnouncements,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      );
}
