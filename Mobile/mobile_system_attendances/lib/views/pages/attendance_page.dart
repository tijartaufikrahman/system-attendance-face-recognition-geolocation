import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'camera_preview_page.dart';
import '../../models/company_location_model.dart';
import '../../services/attendance_service.dart';
import '../../services/location_service.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage>
    with SingleTickerProviderStateMixin {
  static const _navy = Color(0xFF1B2A4A);
  static const _pageBackground = Color(0xFFF6F8FC);
  static const _staticCompanyLocation = CompanyLocation(
    id: 0,
    name: 'Kantor Utama',
    latitude: -6.881605,
    longitude: 107.612699,
    radiusMeters: 50,
  );

  final _mapController = MapController();
  final _noteController = TextEditingController();
  final _attendanceService = AttendanceService();
  final _locationService = LocationService();
  final List<PlatformFile> _selectedFiles = [];
  late final AnimationController _pulseController;

  Position? _currentPosition;
  CompanyLocation _companyLocation = _staticCompanyLocation;
  StreamSubscription<Position>? _positionStream;
  _LocationState _locationState = _LocationState.loading;
  String? _locationError;
  _AttendanceType _selectedStatus = _AttendanceType.present;
  double _faceTolerance = 0.45;
  bool _loadingStatus = true;
  bool _submittingLeave = false;
  Map<String, dynamic>? _regularAttendance;
  List<Map<String, dynamic>> _overtimeTasks = [];
  bool _companyConfigReady = false;
  bool _settingsLoaded = false;
  bool _locationLoaded = false;
  double? _companyRadiusMeters;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat(reverse: true);
    _initLocation();
    _loadCompanySettings();
    _loadCompanyLocation();
    _loadTodayStatus();
  }

  Future<void> _loadTodayStatus() async {
    setState(() => _loadingStatus = true);
    try {
      final data = await _attendanceService.getTodayStatus();
      final regular = data['regular'] as Map<String, dynamic>?;
      final overtimes = (data['overtimes'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .where((task) => task['completed'] != true)
              .toList() ??
          [];
      if (mounted) {
        setState(() {
          _regularAttendance = regular;
          _overtimeTasks = overtimes;
          _loadingStatus = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStatus = false);
    }
  }

  bool get _regularDone {
    final regular = _regularAttendance;
    if (regular == null) return false;
    return regular['completed'] == true;
  }

  bool get _regularAwaitingCheckout {
    final regular = _regularAttendance;
    if (regular == null) return false;
    final status = regular['status']?.toString().toLowerCase() ?? '';
    return status == 'hadir' && regular['clockOut'] == null;
  }

  Future<void> _loadCompanyLocation() async {
    try {
      final location = await _locationService.getCompanyLocation();
      if (!mounted) return;
      setState(() {
        _companyLocation = CompanyLocation(
          id: location.id,
          name: location.name,
          address: location.address,
          latitude: location.latitude,
          longitude: location.longitude,
          radiusMeters: _companyRadiusMeters ?? location.radiusMeters,
        );
        _locationLoaded = true;
        _companyConfigReady = _settingsLoaded;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _locationLoaded = false;
        _companyConfigReady = false;
        _locationError = 'Lokasi perusahaan belum dikonfigurasi.';
      });
    }
  }

  Future<void> _loadCompanySettings() async {
    try {
      final profile = await _attendanceService.getMyProfile();
      final tolerance = (profile['faceTolerance'] as num?)?.toDouble();
      final radius = (profile['radiusMeters'] as num?)?.toDouble();
      if (!mounted) return;
      setState(() {
        if (tolerance != null) _faceTolerance = tolerance;
        if (radius != null && radius > 0) {
          _companyRadiusMeters = radius;
          _companyLocation = CompanyLocation(
            id: _companyLocation.id,
            name: _companyLocation.name,
            address: _companyLocation.address,
            latitude: _companyLocation.latitude,
            longitude: _companyLocation.longitude,
            radiusMeters: radius,
          );
        }
        _settingsLoaded = tolerance != null && radius != null;
        _companyConfigReady = _settingsLoaded && _locationLoaded;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _settingsLoaded = false;
        _companyConfigReady = false;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _positionStream?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    setState(() {
      _locationState = _LocationState.loading;
      _locationError = null;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _setLocationError('Aktifkan GPS untuk melanjutkan absensi.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _setLocationError('Izin lokasi diperlukan untuk absensi.');
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _setLocationError('Izin lokasi ditolak permanen di pengaturan.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;

      setState(() {
        _currentPosition = position;
        _locationState = _LocationState.ready;
      });

      _positionStream?.cancel();
      _positionStream =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 5,
            ),
          ).listen((position) {
            if (!mounted) return;
            setState(() {
              _currentPosition = position;
              _locationState = _LocationState.ready;
            });
          });
    } catch (_) {
      _setLocationError('Lokasi belum dapat diperbarui. Coba lagi.');
    }
  }

  void _setLocationError(String message) {
    if (!mounted) return;
    setState(() {
      _locationError = message;
      _locationState = _LocationState.error;
    });
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
    );

    if (result != null && mounted) {
      setState(() {
        final selectedNames = _selectedFiles.map((file) => file.name).toSet();
        _selectedFiles.addAll(
          result.files.where((file) => selectedNames.add(file.name)),
        );
      });
    }
  }

  void _removeFile(int index) {
    setState(() => _selectedFiles.removeAt(index));
  }

  void _recenterMap() {
    final position = _currentPosition;
    if (position == null) return;
    _mapController.move(LatLng(position.latitude, position.longitude), 17);
  }

  double? get _distanceToOffice {
    final user = _currentPosition;
    if (user == null) return null;
    return Geolocator.distanceBetween(
      user.latitude,
      user.longitude,
      _companyLocation.latitude,
      _companyLocation.longitude,
    );
  }

  bool get _isWithinOfficeRadius {
    if (!_companyConfigReady) return false;
    final distance = _distanceToOffice;
    return distance != null && distance <= _companyLocation.radiusMeters;
  }

  bool get _requiresOfficeLocation =>
      _selectedStatus == _AttendanceType.present;

  void _continueToFaceRecognition({String mode = 'checkin'}) {
    final position = _currentPosition;
    if (!_companyConfigReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengaturan perusahaan belum tersedia. Hubungi HR.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Menunggu lokasi Anda terdeteksi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!_isWithinOfficeRadius) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda berada di luar radius absensi kantor.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CameraPreviewPage(
          status: 'Hadir',
          mode: mode,
          note: _noteController.text.trim(),
          locationId: _companyLocation.id == 0 ? null : _companyLocation.id,
          files: List<PlatformFile>.unmodifiable(_selectedFiles),
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: position.accuracy,
          distanceMeters: _distanceToOffice,
          faceTolerance: _faceTolerance,
        ),
      ),
    ).then((result) {
      if (result == true) _loadTodayStatus();
    });
  }

  void _startOvertimeFlow(Map<String, dynamic> task, String mode) {
    final position = _currentPosition;
    if (!_companyConfigReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengaturan perusahaan belum tersedia. Hubungi HR.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Menunggu lokasi Anda terdeteksi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!_isWithinOfficeRadius) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda berada di luar radius absensi kantor.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CameraPreviewPage(
          status: 'Lembur',
          mode: mode,
          overtimeId: task['overtimeId'] as int?,
          note: '',
          locationId: _companyLocation.id == 0 ? null : _companyLocation.id,
          files: const [],
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: position.accuracy,
          distanceMeters: _distanceToOffice,
          faceTolerance: _faceTolerance,
        ),
      ),
    ).then((result) {
      if (result == true) _loadTodayStatus();
    });
  }

  Future<void> _submitLeaveNow() async {
    setState(() => _submittingLeave = true);
    try {
      await _attendanceService.submitLeave(
        status: _selectedStatus.label,
        note: _noteController.text.trim(),
        files: _selectedFiles,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Absensi berhasil dikirim.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _noteController.clear();
      setState(() => _selectedFiles.clear());
      await _loadTodayStatus();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _submittingLeave = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildMapContent(),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    _buildMapAction(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Kembali',
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: _buildMapStatus()),
                    const SizedBox(width: 10),
                    _buildMapAction(
                      icon: Icons.my_location_rounded,
                      tooltip: 'Kembali ke lokasi saya',
                      onPressed: _currentPosition == null ? null : _recenterMap,
                    ),
                  ],
                ),
              ),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.28,
            minChildSize: 0.18,
            maxChildSize: 0.9,
            snap: true,
            snapSizes: const [0.28, 0.9],
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 18,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [_buildAttendanceForm()],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMapAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: _navy),
      ),
    );
  }

  Widget _buildAttendanceForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFD0D5DD),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Kehadiran hari ini',
          style: TextStyle(
            color: _navy,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          _regularDone
              ? 'Absensi Anda hari ini sudah lengkap.'
              : _regularAwaitingCheckout
              ? 'Anda sudah check-in, jangan lupa check-out sebelum pulang.'
              : 'Pilih status kehadiran dan tambahkan keterangan bila diperlukan.',
          style: const TextStyle(color: Color(0xFF667085), fontSize: 13),
        ),
        const SizedBox(height: 20),
        if (_loadingStatus)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_regularDone)
          _buildRegularDoneCard()
        else if (_regularAwaitingCheckout)
          ..._buildCheckoutSection()
        else
          ..._buildNewAttendanceSection(),
        if (!_loadingStatus && _overtimeTasks.isNotEmpty) ...[
          const SizedBox(height: 28),
          _buildOvertimeSection(),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  List<Widget> _buildCheckoutSection() {
    final clockIn = _regularAttendance?['clockIn']?.toString();
    return [
      _buildLocationInfo(),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FBF4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFC7EAD4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF16803C)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Check-in tercatat pukul ${_formatTime(clockIn)}. Lakukan check-out saat selesai bekerja.',
                style: const TextStyle(color: _navy, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      _buildNotesField(),
      const SizedBox(height: 24),
      _buildAttachments(),
      const SizedBox(height: 28),
      SizedBox(
        height: 54,
        child: FilledButton.icon(
          onPressed:
              _locationState == _LocationState.ready && _isWithinOfficeRadius
              ? () => _continueToFaceRecognition(mode: 'checkout')
              : null,
          icon: const Icon(Icons.logout_rounded),
          label: const Text(
            'Absen Pulang (Check-out)',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: _navy,
            disabledBackgroundColor: _navy.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildNewAttendanceSection() {
    final isPresent = _selectedStatus == _AttendanceType.present;
    return [
      _buildLocationInfo(),
      const SizedBox(height: 24),
      _buildStatusSelector(),
      const SizedBox(height: 24),
      _buildNotesField(),
      const SizedBox(height: 24),
      _buildAttachments(),
      const SizedBox(height: 28),
      SizedBox(
        height: 54,
        child: FilledButton.icon(
          onPressed: isPresent
              ? (_locationState == _LocationState.ready &&
                        _isWithinOfficeRadius
                    ? () => _continueToFaceRecognition(mode: 'checkin')
                    : null)
              : (_submittingLeave ? null : _submitLeaveNow),
          icon: Icon(
            isPresent
                ? Icons.face_retouching_natural_rounded
                : Icons.send_rounded,
          ),
          label: Text(
            isPresent
                ? 'Lanjutkan ke verifikasi wajah (Check-in)'
                : (_submittingLeave ? 'Mengirim...' : 'Kirim'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: _navy,
            disabledBackgroundColor: _navy.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildRegularDoneCard() {
    final regular = _regularAttendance;
    final status = regular?['status']?.toString() ?? '-';
    final clockIn = regular?['clockIn']?.toString();
    final clockOut = regular?['clockOut']?.toString();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FBF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC7EAD4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_rounded,
            color: Color(0xFF16803C),
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status: $status',
                  style: const TextStyle(
                    color: _navy,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (clockIn != null || clockOut != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Masuk ${_formatTime(clockIn)} • Pulang ${_formatTime(clockOut)}',
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOvertimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lembur disetujui hari ini',
          style: TextStyle(
            color: _navy,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Lakukan check-in dan check-out terpisah untuk sesi lembur ini.',
          style: TextStyle(color: Color(0xFF667085), fontSize: 12),
        ),
        const SizedBox(height: 12),
        ..._overtimeTasks.map(_buildOvertimeCard),
      ],
    );
  }

  Widget _buildOvertimeCard(Map<String, dynamic> task) {
    final checkedIn = task['clockIn'] != null;
    final checkedOut = task['clockOut'] != null;
    final start = task['startTime']?.toString();
    final end = task['endTime']?.toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE2EA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, color: _navy),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lembur ${_formatDuration(start)} - ${_formatDuration(end)}',
                  style: const TextStyle(
                    color: _navy,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (checkedIn)
                  Text(
                    'Check-in ${_formatTime(task['clockIn']?.toString())}',
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: checkedOut
                ? null
                : () =>
                      _startOvertimeFlow(task, checkedIn ? 'checkout' : 'checkin'),
            style: FilledButton.styleFrom(
              backgroundColor: _navy,
              disabledBackgroundColor: _navy.withValues(alpha: 0.3),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: Text(
              checkedOut ? 'Selesai' : (checkedIn ? 'Check-out' : 'Check-in'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String? isoValue) {
    if (isoValue == null) return '-';
    final parsed = DateTime.tryParse(isoValue);
    if (parsed == null) return '-';
    final hh = parsed.hour.toString().padLeft(2, '0');
    final mm = parsed.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _formatDuration(String? timeSpan) {
    if (timeSpan == null) return '-';
    final parts = timeSpan.split(':');
    if (parts.length < 2) return timeSpan;
    return '${parts[0]}:${parts[1]}';
  }

  Widget _buildMapContent() {
    if (_locationState == _LocationState.loading) {
      return const ColoredBox(
        color: Color(0xFFEAF0F6),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text(
                'Memperbarui lokasi...',
                style: TextStyle(
                  color: _navy,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_locationState == _LocationState.error || _currentPosition == null) {
      return ColoredBox(
        color: const Color(0xFFEAF0F6),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_off_outlined,
                  color: Color(0xFFD92D20),
                  size: 38,
                ),
                const SizedBox(height: 10),
                Text(
                  _locationError ?? 'Lokasi belum tersedia.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _navy, fontSize: 13),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _initLocation,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final point = LatLng(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(initialCenter: point, initialZoom: 17),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.mobile_system_attendances',
        ),
        CircleLayer(
          circles: [
            CircleMarker(
              point: point,
              radius: _currentPosition!.accuracy,
              useRadiusInMeter: true,
              color: const Color(0xFF2176D2).withValues(alpha: 0.13),
              borderColor: const Color(0xFF2176D2).withValues(alpha: 0.36),
              borderStrokeWidth: 1.5,
            ),
            CircleMarker(
              point: LatLng(
                _companyLocation.latitude,
                _companyLocation.longitude,
              ),
              radius: _companyLocation.radiusMeters,
              useRadiusInMeter: true,
              color: const Color(0xFF16803C).withValues(alpha: 0.12),
              borderColor: const Color(0xFF16803C).withValues(alpha: 0.7),
              borderStrokeWidth: 2,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: point,
              width: 54,
              height: 54,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Center(
                    child: Container(
                      width: 20 + (_pulseController.value * 8),
                      height: 20 + (_pulseController.value * 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2176D2).withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2176D2),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Marker(
              point: LatLng(
                _companyLocation.latitude,
                _companyLocation.longitude,
              ),
              width: 58,
              height: 58,
              child: const Icon(
                Icons.business_rounded,
                color: Color(0xFF16803C),
                size: 34,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMapStatus() {
    final isReady = _locationState == _LocationState.ready;
    final distance = _distanceToOffice;
    final isInside = _isWithinOfficeRadius;
    final statusText = !isReady
        ? 'Lokasi sedang diperbarui'
        : distance == null
        ? 'Menentukan jarak ke kantor...'
        : isInside
        ? 'Dalam radius absensi'
        : 'Di luar radius absensi';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            isInside
                ? Icons.verified_rounded
                : isReady
                ? Icons.gps_fixed_rounded
                : Icons.gps_not_fixed_rounded,
            color: isInside
                ? const Color(0xFF16803C)
                : isReady
                ? const Color(0xFFB54708)
                : const Color(0xFF667085),
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusText,
              style: const TextStyle(
                color: _navy,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationInfo() {
    final accuracy = _currentPosition?.accuracy.round();
    final distance = _distanceToOffice;
    final distanceText = distance == null
        ? 'Jarak ke kantor sedang dihitung'
        : '${distance.round()} meter dari kantor';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD5E8FC)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined, color: Color(0xFF2176D2)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lokasi Anda',
                  style: TextStyle(
                    color: _navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  !_requiresOfficeLocation
                      ? 'Lokasi tidak diperlukan untuk status ${_selectedStatus.label}'
                      : accuracy == null
                      ? 'Menunggu akurasi lokasi'
                      : 'Akurasi lokasi sekitar $accuracy meter',
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  !_requiresOfficeLocation
                      ? 'Anda dapat melanjutkan tanpa berada di radius kantor'
                      : '${_companyLocation.name} • $distanceText • radius ${_companyLocation.radiusMeters.round()} m',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _isWithinOfficeRadius
                        ? const Color(0xFF16803C)
                        : const Color(0xFF667085),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Status kehadiran',
          style: TextStyle(
            color: _navy,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        SegmentedButton<_AttendanceType>(
          segments: _AttendanceType.values
              .map(
                (type) => ButtonSegment(
                  value: type,
                  icon: Icon(type.icon, size: 18),
                  label: Text(type.label),
                ),
              )
              .toList(),
          selected: {_selectedStatus},
          onSelectionChanged: (selection) {
            setState(() => _selectedStatus = selection.first);
          },
          style: const ButtonStyle(
            visualDensity: VisualDensity.comfortable,
            textStyle: WidgetStatePropertyAll(
              TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _selectedStatus == _AttendanceType.present
              ? 'Hadir: lakukan Check-in saat datang dan Check-out saat selesai bekerja.'
              : _selectedStatus == _AttendanceType.permission
              ? 'Izin: cukup kirim alasan dan lampiran, tidak perlu Check-out.'
              : 'Sakit: cukup kirim keterangan dan lampiran, tidak perlu Check-out.',
          style: const TextStyle(
            color: Color(0xFF667085),
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesField() {
    final hint = switch (_selectedStatus) {
      _AttendanceType.present => 'Tambahkan catatan jika diperlukan...',
      _AttendanceType.permission => 'Jelaskan alasan izin Anda...',
      _AttendanceType.sick => 'Jelaskan kondisi atau informasi sakit...',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Keterangan',
          style: TextStyle(
            color: _navy,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _noteController,
          minLines: 3,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: hint,
            alignLabelWithHint: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFDCE2EA)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFDCE2EA)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _navy, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttachments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Lampiran (opsional)',
                style: TextStyle(
                  color: _navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _pickFiles,
              icon: const Icon(Icons.add_rounded, size: 19),
              label: const Text('Tambah file'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Tambahkan dokumen atau foto pendukung bila diperlukan.',
          style: TextStyle(color: Color(0xFF667085), fontSize: 12),
        ),
        const SizedBox(height: 12),
        if (_selectedFiles.isEmpty) _buildEmptyAttachments(),
        ..._selectedFiles.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildAttachmentItem(entry.key, entry.value),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyAttachments() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE2EA)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.attach_file_rounded, color: Color(0xFF98A2B3)),
          SizedBox(width: 8),
          Text(
            'Belum ada file tambahan',
            style: TextStyle(color: Color(0xFF667085), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentItem(int index, PlatformFile file) {
    final type = (file.extension ?? 'file').toUpperCase();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE2EA)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF0F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_fileIcon(file.extension), color: _navy, size: 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$type - ${_formatFileSize(file.size)}',
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Hapus ${file.name}',
            onPressed: () => _removeFile(index),
            icon: const Icon(Icons.close_rounded, color: Color(0xFFD92D20)),
          ),
        ],
      ),
    );
  }

  IconData _fileIcon(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image_outlined;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'doc':
      case 'docx':
        return Icons.description_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

enum _LocationState { loading, ready, error }

enum _AttendanceType {
  present('Hadir', Icons.check_circle_outline_rounded),
  permission('Izin', Icons.event_note_outlined),
  sick('Sakit', Icons.medical_services_outlined);

  const _AttendanceType(this.label, this.icon);

  final String label;
  final IconData icon;
}
