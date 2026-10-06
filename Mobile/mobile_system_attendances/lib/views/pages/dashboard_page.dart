import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../services/location_service.dart';
import '../../services/face_embedding_service.dart';
import '../../services/announcement_service.dart';
import '../../services/overtime_service.dart';
import 'overtime_page.dart';
import 'face_enrollment_page.dart';

class DashboardPage extends StatefulWidget {
  final Function(String) onMenuTap;

  const DashboardPage({super.key, required this.onMenuTap});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _hasOvertimeRequest = false;
  bool _hasOvertimeSubmission = false;
  bool _dismissedOvertimeSubmission = false;
  bool _overtimeAccepted = false;
  bool? _hasLocation;
  bool _locationLoading = true;
  final _locationService = LocationService();
  bool? _hasFace;
  bool _faceLoading = true;
  final _faceService = FaceEmbeddingService();
  final _announcementService = AnnouncementService();
  List<Map<String, dynamic>> _recentAnnouncements = [];
  final _overtimeService = OvertimeService();

  @override
  void initState() {
    super.initState();
    _checkLocation();
    _checkFaceRegistration();
    _loadRecentAnnouncements();
    _loadOvertimeRequest();
  }

  Future<void> _loadOvertimeRequest() async {
    try {
      final values = await _overtimeService.getMine();
      final pending = values.any((item) =>
          (item['status']?.toString().toUpperCase() ?? '') == 'PENDING_EMPLOYEE');
      final submission = values.any((item) =>
          (item['status']?.toString().toUpperCase() ?? '') == 'PENDING_SUPERVISOR' &&
          (item['requestType']?.toString().toUpperCase() ?? '') == 'EMPLOYEE_REQUEST');
      if (mounted) {
        setState(() {
          _hasOvertimeRequest = pending;
          _hasOvertimeSubmission = submission;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasOvertimeRequest = false;
          _hasOvertimeSubmission = false;
        });
      }
    }
  }

  Future<void> _loadRecentAnnouncements() async {
    try {
      final values = await _announcementService.getMine();
      if (mounted) setState(() => _recentAnnouncements = values.take(2).toList());
    } catch (_) {
      if (mounted) setState(() => _recentAnnouncements = []);
    }
  }

  Future<void> _checkFaceRegistration() async {
    try {
      final registered = await _faceService.isRegistered();
      if (!mounted) return;
      setState(() {
        _hasFace = registered;
        _faceLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasFace = false;
        _faceLoading = false;
      });
    }
  }

  Future<void> _checkLocation() async {
    try {
      final exists = await _locationService.hasCompanyLocation();
      if (mounted) {
        setState(() {
          _hasLocation = exists;
          _locationLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasLocation = false;
          _locationLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeCard(context),
          const SizedBox(height: 16),
          if (!_locationLoading && _hasLocation == false) ...[
            _buildLocationWarningCard(),
            const SizedBox(height: 16),
          ],
          if (!_faceLoading && _hasFace == false) ...[
            _buildFaceRegistrationCard(),
            const SizedBox(height: 16),
          ],
          if (_hasOvertimeRequest && !_overtimeAccepted) ...[
            _buildOvertimeRequestCard(),
            const SizedBox(height: 16),
          ],
          if (_hasOvertimeSubmission && !_dismissedOvertimeSubmission) ...[
            _buildOvertimeSubmissionCard(),
            const SizedBox(height: 16),
          ],
          if (_overtimeAccepted) ...[
            _buildOvertimeAcceptedCard(),
            const SizedBox(height: 16),
          ],
          _buildMenuGrid(context),
          const SizedBox(height: 18),
          _buildRecentAnnouncements(),
        ],
      ),
    );
  }

  Widget _buildFaceRegistrationCard() {
    return InkWell(
      onTap: () async {
        final registered = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const FaceEnrollmentPage()),
        );
        if (registered == true && mounted) {
          setState(() => _hasFace = true);
        }
      },
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF2FF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFC7DCFF)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFF1B2A4A).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.face_retouching_natural_rounded,
                color: Color(0xFF1B2A4A),
                size: 26,
              ),
            ),
            const SizedBox(width: 13),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daftarkan wajah Anda',
                    style: TextStyle(
                      color: Color(0xFF1B2A4A),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Lengkapi pendaftaran wajah agar dapat melakukan absensi.',
                    style: TextStyle(color: Color(0xFF667085), fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF1B2A4A)),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, auth, child) {
        final user = auth.loginResponse;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B2A4A), Color(0xFF2D4373)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1B2A4A).withValues(alpha: 0.20),
                blurRadius: 16,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selamat Datang,',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.name ?? 'User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getCurrentDate(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: Color(0xFFC9A84C),
                  size: 22,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOvertimeRequestCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OvertimePage()),
        ).then((result) {
          if (result == 'accepted') {
            setState(() {
              _hasOvertimeRequest = false;
              _overtimeAccepted = true;
            });
          } else if (result == 'rejected') {
            setState(() {
              _hasOvertimeRequest = false;
            });
          }

        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade400, Colors.deepOrange.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.28),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.approval_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Butuh Persetujuan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.26),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '1 Request',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Klik untuk melihat detail',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _hasOvertimeRequest = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  color: Colors.white.withValues(alpha: 0.8),
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOvertimeSubmissionCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OvertimePage()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F1FF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF9FC5F8)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1B2A4A).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.hourglass_top_rounded,
                color: Color(0xFF1B2A4A),
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pengajuan Lembur Diproses',
                    style: TextStyle(
                      color: Color(0xFF1B2A4A),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Menunggu persetujuan admin atau atasan',
                    style: TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF667085),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () {
                setState(() => _dismissedOvertimeSubmission = true);
              },
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  color: Color(0xFF667085),
                  size: 19,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOvertimeAcceptedCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lembur Disetujui',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Lembur telah disetujui',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationWarningCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
        gradient: const LinearGradient(
          colors: [Color(0xFFFEF9C3), Color(0xFFFEF3C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Top accent bar ──
          Container(
            width: double.infinity,
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Badge ──
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PulsingDot(),
                      SizedBox(width: 6),
                      Text(
                        'PERHATIAN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // ── Icon + text ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDE68A).withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.location_off_rounded,
                        color: Color(0xFF92400E),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Lokasi Kantor Belum Diatur',
                            style: TextStyle(
                              color: Color(0xFF92400E),
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Anda belum menetapkan lokasi kantor. Karyawan tidak bisa melakukan presensi geofencing.',
                            style: TextStyle(
                              color: const Color(
                                0xFF78350F,
                              ).withValues(alpha: 0.8),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // ── Steps ──
                Row(
                  children: [
                    _buildLocationStep('1', 'Cari lokasi'),
                    _buildStepConnector(),
                    _buildLocationStep('2', 'Atur radius'),
                    _buildStepConnector(),
                    _buildLocationStep('3', 'Simpan'),
                  ],
                ),
                const SizedBox(height: 16),
                // ── CTA Button ──
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to attendance page which has map
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Silakan hubungi admin untuk mengatur lokasi kantor.',
                          ),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Color(0xFFD97706),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      size: 18,
                    ),
                    label: const Text(
                      'Atur Lokasi Kantor',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationStep(String num, String text) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: const Color(0xFF92400E),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                num,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF78350F),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector() {
    return Container(
      width: 24,
      height: 2,
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFD97706).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  Widget _buildMenuGrid(BuildContext context) {
    final menus = [
      {
        'icon': Icons.fingerprint_rounded,
        'title': 'Absen',
        'color': const Color(0xFF2E7D32),
        'route': 'absen',
      },
      {
        'icon': Icons.work_outline_rounded,
        'title': 'Lembur',
        'color': const Color(0xFFE65100),
        'route': 'lembur',
      },
      {
        'icon': Icons.receipt_long_rounded,
        'title': 'Riwayat',
        'color': const Color(0xFF1565C0),
        'route': 'riwayat',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Menu',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1B2A4A),
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: menus.length,
          itemBuilder: (context, index) {
            final menu = menus[index];
            return _buildMenuCard(
              context: context,
              icon: menu['icon'] as IconData,
              title: menu['title'] as String,
              color: menu['color'] as Color,
              onTap: () => widget.onMenuTap(menu['route'] as String),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMenuCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1B2A4A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentAnnouncements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pengumuman',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1B2A4A),
          ),
        ),
        const SizedBox(height: 12),
        if (_recentAnnouncements.isEmpty)
          const Text(
            'Belum ada pengumuman untuk Anda.',
            style: TextStyle(color: Color(0xFF667085), fontSize: 12),
          ),
        ..._recentAnnouncements.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildAnnouncementCard(
              item['title']?.toString() ?? 'Pengumuman',
              item['content']?.toString() ?? '',
              Icons.campaign_rounded,
              const Color(0xFF2196F3),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnnouncementCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF1B2A4A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    final months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }
}

/// A small pulsing dot indicator.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: Colors.white.withValues(
              alpha: 0.4 + _controller.value * 0.6,
            ),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
