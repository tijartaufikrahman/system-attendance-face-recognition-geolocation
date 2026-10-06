import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/attendance_service.dart';
import '../../services/face_embedding_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../login_view.dart';
import 'face_enrollment_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _service = AttendanceService();
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _service.getMyProfile();
      if (mounted) setState(() => _profile = profile);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadProfile,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Consumer<AuthViewModel>(
          builder: (context, auth, child) {
            final user = auth.loginResponse;
            final name = _profile?['name']?.toString() ?? user?.name ?? '-';
            final email = _profile?['email']?.toString() ?? user?.email ?? '-';
            final position = _profile?['position']?.toString() ?? '-';
            final company = _profile?['companyName']?.toString() ?? '-';
            final schedule = _profile?['schedule'] as Map?;
            final scheduleName = schedule?['name']?.toString() ?? '-';
            return Column(
              children: [
                _buildProfileHeader(name, email, position),
                const SizedBox(height: 16),
                _buildInfoCard('Informasi Pribadi', [
                  _buildInfoRow(Icons.badge_rounded, 'ID Karyawan', '${_profile?['id'] ?? user?.id ?? '-'}'),
                  _buildInfoRow(Icons.person_rounded, 'Nama Lengkap', name),
                  _buildInfoRow(Icons.email_rounded, 'Email', email),
                ]),
                const SizedBox(height: 12),
                _buildInfoCard('Informasi Pekerjaan', [
                  _buildInfoRow(Icons.business_rounded, 'Company', company),
                  _buildInfoRow(Icons.work_rounded, 'Posisi/Jabatan', position),
                  _buildInfoRow(Icons.location_on_rounded, 'Lokasi', _profile?['location']?.toString() ?? '-'),
                ]),
                const SizedBox(height: 12),
                _buildInfoCard('Jam Kerja', [
                  _buildInfoRow(Icons.schedule_rounded, 'Nama Jadwal', scheduleName),
                  _buildInfoRow(Icons.login_rounded, 'Jam Masuk', _formatTime(schedule?['clockIn'])),
                  _buildInfoRow(Icons.logout_rounded, 'Jam Keluar', _formatTime(schedule?['clockOut'])),
                ]),
                const SizedBox(height: 12),
                _buildFaceSection(context, _profile?['faceRegistered'] == true),
                const SizedBox(height: 16),
                _buildLogoutButton(context),
                if (_loading) const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatTime(dynamic value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) return '-';
    return text.length >= 5 ? text.substring(0, 5) : text;
  }

  Widget _buildProfileHeader(String name, String email, String position) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF1B2A4A), Color(0xFF2D4373)]),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(children: [
      CircleAvatar(
        radius: 42,
        backgroundColor: const Color(0xFF2D4373),
        child: Text(name.isNotEmpty && name != '-' ? name[0].toUpperCase() : '?',
            style: const TextStyle(fontSize: 32, color: Color(0xFFC9A84C))),
      ),
      const SizedBox(height: 12),
      Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(email, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      const SizedBox(height: 8),
      Text(position, style: const TextStyle(color: Color(0xFFC9A84C), fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _buildInfoCard(String title, List<Widget> children) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1B2A4A))),
      const SizedBox(height: 10),
      ...children,
    ]),
  );

  Widget _buildInfoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Icon(icon, size: 18, color: const Color(0xFF667085)),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF667085), fontSize: 12))),
      Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
    ]),
  );

  Widget _buildFaceSection(BuildContext context, bool registered) => _buildInfoCard('Face Recognition', [
    Text(registered ? 'Wajah sudah terdaftar' : 'Wajah belum terdaftar',
        style: TextStyle(color: registered ? Colors.green : Colors.orange, fontWeight: FontWeight.w600)),
    const SizedBox(height: 10),
    ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.face_retouching_natural),
      title: const Text('Ubah Wajah'),
      subtitle: const Text('Perbarui data wajah Anda'),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FaceEnrollmentPage())),
    ),
    ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
      title: const Text('Hapus Wajah'),
      onTap: () async {
        await FaceEmbeddingService().deleteEnrollment();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data wajah dihapus.')));
          _loadProfile();
        }
      },
    ),
  ]);

  Widget _buildLogoutButton(BuildContext context) => FilledButton.icon(
    onPressed: () async {
      await context.read<AuthViewModel>().logout();
      if (context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginView()));
    },
    icon: const Icon(Icons.logout_rounded),
    label: const Text('Keluar'),
  );
}
