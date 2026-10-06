import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'login_view.dart';
import 'pages/dashboard_page.dart';
import 'pages/attendance_page.dart';
import 'pages/announcements_page.dart';
import 'pages/profile_page.dart';
import 'pages/overtime_page.dart';
import 'pages/history_page.dart';
import '../services/face_embedding_service.dart';
import '../services/announcement_service.dart';
import 'pages/face_enrollment_page.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _currentIndex = 0;
  final _faceService = FaceEmbeddingService();
  final _announcementService = AnnouncementService();
  int _unreadAnnouncements = 0;

  final List<String> _titles = ['Dashboard', 'Info', 'Profil'];

  @override
  void initState() {
    super.initState();
    _loadUnreadAnnouncements();
  }

  Future<void> _loadUnreadAnnouncements() async {
    try {
      final count = await _announcementService.getUnreadCount();
      if (mounted) setState(() => _unreadAnnouncements = count);
    } catch (_) {}
  }

  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return DashboardPage(
          onMenuTap: (route) {
            _showSubMenu(route);
          },
        );
      case 1:
        return const AnnouncementsPage();
      case 2:
        return const ProfilePage();
      default:
        return DashboardPage(
          onMenuTap: (route) {
            _showSubMenu(route);
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF1B2A4A);
    const gold = Color(0xFFC9A84C);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: navy,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
          onPressed: _showDrawer,
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
        title: Text(
          _titles[_currentIndex],
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.notifications_none_rounded, color: gold, size: 18),
          ),
        ],
      ),
      body: _buildCurrentPage(),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, 'Beranda'),
              _buildNavItem(1, Icons.notifications_active_rounded, 'Info',
                  badge: _unreadAnnouncements > 0 ? '$_unreadAnnouncements' : null),
              _buildNavItem(2, Icons.person_rounded, 'Profil'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, {String? badge}) {
    final isSelected = _currentIndex == index;
    final activeColor = const Color(0xFF1B2A4A);

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
        if (index == 0 || index == 1) _loadUnreadAnnouncements();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 104,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFC9A84C).withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isSelected ? activeColor : Colors.grey[500],
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? activeColor : Colors.grey[500],
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (badge != null)
              Positioned(
                top: -6,
                right: -10,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE57373),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildDrawer(),
    );
  }

  Widget _buildDrawer() {
    return Consumer<AuthViewModel>(
      builder: (context, auth, child) {
        final user = auth.loginResponse;

        return Container(
          height: MediaQuery.of(context).size.height * 0.68,
          decoration: const BoxDecoration(
            color: Color(0xFF1B2A4A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFC9A84C),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 31,
                        backgroundColor: const Color(0xFF2D4373),
                        child: Text(
                          user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFC9A84C),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? '-',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? '-',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _buildDrawerItem(
                      icon: Icons.fingerprint_rounded,
                      title: 'Absen',
                      onTap: () {
                        Navigator.pop(context);
                        _showSubMenu('absen');
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.history_rounded,
                      title: 'Riwayat',
                      onTap: () {
                        Navigator.pop(context);
                        _showSubMenu('riwayat');
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.work_rounded,
                      title: 'Lembur',
                      onTap: () {
                        Navigator.pop(context);
                        _showSubMenu('lembur');
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.notifications_active_outlined,
                      title: 'Info',
                      badge: _unreadAnnouncements > 0 ? '$_unreadAnnouncements' : null,
                      onTap: () {
                        Navigator.pop(context);
                        _showSubMenu('info');
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  tileColor: Colors.white.withValues(alpha: 0.06),
                  leading: const Icon(Icons.logout_rounded, color: Color(0xFFFF8A80)),
                  title: const Text(
                    'Keluar',
                    style: TextStyle(
                      color: Color(0xFFFF8A80),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final authViewModel = context.read<AuthViewModel>();
                    final shouldLogout = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: const Text('Keluar'),
                        content: const Text('Apakah Anda yakin ingin keluar?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: Text(
                              'Batal',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text(
                              'Keluar',
                              style: TextStyle(color: Color(0xFFE57373)),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (shouldLogout == true && context.mounted) {
                      await authViewModel.logout();
                      if (context.mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginView()),
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? badge,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: Colors.white.withValues(alpha: 0.8),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: badge != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: const BoxDecoration(
                color: Color(0xFFE57373),
                shape: BoxShape.circle,
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white38,
            ),
      onTap: onTap,
    );
  }

  Future<void> _showSubMenu(String type) async {
    if (type == 'absen') {
      bool registered;
      try {
        registered = await _faceService.isRegistered();
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status wajah belum dapat diperiksa. Coba lagi.')),
        );
        return;
      }
      if (!registered) {
        if (!mounted) return;
        final enroll = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Wajah belum terdaftar'),
            content: const Text(
              'Anda harus mendaftarkan wajah sebelum dapat melakukan absensi.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Nanti'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Daftarkan sekarang'),
              ),
            ],
          ),
        );
        if (enroll == true && mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FaceEnrollmentPage()),
          );
        }
        return;
      }
    }

    Widget page;
    String title;

    switch (type) {
      case 'absen':
        page = const AttendancePage();
        title = 'Absensi';
        break;
      case 'riwayat':
        page = const HistoryPage();
        title = 'Riwayat';
        break;
      case 'lembur':
        page = const OvertimePage();
        title = 'Lembur';
        break;
      case 'info':
        page = const AnnouncementsPage();
        title = 'Info';
        break;
      default:
        return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: const Color(0xFFF5F7FB),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: const Color(0xFF1B2A4A),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            centerTitle: true,
          ),
          body: page,
        ),
      ),
    );
  }
}
