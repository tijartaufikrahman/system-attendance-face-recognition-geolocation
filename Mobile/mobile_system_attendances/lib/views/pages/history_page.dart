import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../services/attendance_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  static const _navy = Color(0xFF1B2A4A);
  DateTime _selectedMonth = DateTime.now();
  _HistoryViewState _viewState = _HistoryViewState.loading;
  final _attendanceService = AttendanceService();
  List<_AttendanceRecord> _records = [];


  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _viewState = _HistoryViewState.loading);
    try {
      await initializeDateFormatting('id_ID');
      final values = await _attendanceService.getHistory(_selectedMonth);
      if (!mounted) return;
      setState(() {
        _records = values.map(_recordFromJson).toList();
        _viewState = _HistoryViewState.success;
      });
    } catch (_) {
      if (mounted) setState(() => _viewState = _HistoryViewState.error);
    }
  }

  _AttendanceRecord _recordFromJson(Map<String, dynamic> value) {
    final rawStatus = value['status']?.toString().toLowerCase() ?? '';
    final status = rawStatus.contains('sakit')
        ? _AttendanceStatus.sick
        : rawStatus.contains('izin')
        ? _AttendanceStatus.permission
        : _AttendanceStatus.present;
    final date = DateTime.tryParse(value['date']?.toString() ?? '') ?? DateTime.now();
    final location = value['location'];
    final locationName = location is Map
        ? location['name']?.toString()
        : null;
    final accuracy = (value['accuracyMeters'] as num?)?.toStringAsFixed(0);
    final similarity = (value['faceSimilarity'] as num?)?.toStringAsFixed(1);
    return _AttendanceRecord(
      date: date.toIso8601String(),
      checkIn: _formatTime(value['clockIn']),
      checkOut: _formatTime(value['clockOut']),
      status: status,
      location: locationName ?? 'Lokasi absensi tersimpan',
      detail: [
        if (accuracy != null) 'Akurasi ${accuracy} m',
        if (similarity != null) 'Similarity ${similarity}%',
        if (value['note']?.toString().trim().isNotEmpty == true)
          value['note'].toString(),
      ].join(' • '),
    );
  }

  String? _formatTime(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    return date == null ? null : DateFormat('HH:mm').format(date);
  }

  List<_AttendanceRecord> get _visibleRecords {
    return _records.where((record) {
      final date = DateTime.parse(record.date);
      return date.year == _selectedMonth.year && date.month == _selectedMonth.month;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: _buildPeriodFilter(),
          ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildPeriodFilter() {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _selectMonth,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3E8EF)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_outlined, color: _navy),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Periode absensi',
                    style: TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth),
                    style: const TextStyle(
                      color: _navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: _navy),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_viewState) {
      case _HistoryViewState.loading:
        return const _HistoryLoadingState();
      case _HistoryViewState.error:
        return _HistoryErrorState(onRetry: _loadHistory);
      case _HistoryViewState.success:
        if (_visibleRecords.isEmpty) {
          return const _HistoryEmptyState();
        }
        return RefreshIndicator(
          onRefresh: _loadHistory,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            itemCount: _visibleRecords.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _HistoryCard(record: _visibleRecords[index]);
            },
          ),
        );
    }
  }

  Future<void> _selectMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Pilih periode absensi',
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
      _loadHistory();
    }
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.record});

  final _AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF1B2A4A);
    final status = record.status;
    final date = DateTime.parse(record.date);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8ECF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(status.icon, color: status.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date),
                      style: const TextStyle(
                        color: navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      record.detail,
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: status),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1),
          ),
          if (record.checkIn != null) ...[
            Row(
              children: [
                const Icon(
                  Icons.schedule_outlined,
                  size: 18,
                  color: Color(0xFF667085),
                ),
                const SizedBox(width: 8),
                Text(
                  'Masuk ${record.checkIn}  -  Pulang ${record.checkOut}',
                  style: const TextStyle(
                    color: navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 18,
                color: Color(0xFF667085),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  record.location,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final _AttendanceStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: status.color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HistoryLoadingState extends StatelessWidget {
  const _HistoryLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(height: 14),
          Text(
            'Memuat riwayat absensi...',
            style: TextStyle(color: Color(0xFF667085), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_note_outlined,
              size: 52,
              color: Color(0xFF98A2B3),
            ),
            SizedBox(height: 16),
            Text(
              'Belum ada riwayat absensi',
              style: TextStyle(
                color: Color(0xFF1B2A4A),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Riwayat untuk periode ini akan tampil di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF667085), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryErrorState extends StatelessWidget {
  const _HistoryErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 52,
              color: Color(0xFFD92D20),
            ),
            const SizedBox(height: 16),
            const Text(
              'Riwayat tidak dapat dimuat',
              style: TextStyle(
                color: Color(0xFF1B2A4A),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Periksa koneksi Anda dan coba lagi.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF667085), fontSize: 13),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _HistoryViewState { loading, success, error }

enum _AttendanceStatus {
  present('Hadir', Color(0xFF16803C), Icons.check_circle_outline_rounded),
  permission('Izin', Color(0xFF266CCB), Icons.event_note_outlined),
  sick('Sakit', Color(0xFFE17812), Icons.medical_services_outlined);

  const _AttendanceStatus(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;
}

class _AttendanceRecord {
  const _AttendanceRecord({
    required this.date,
    required this.status,
    required this.location,
    required this.detail,
    this.checkIn,
    this.checkOut,
  });

  final String date;
  final String? checkIn;
  final String? checkOut;
  final _AttendanceStatus status;
  final String location;
  final String detail;
}
