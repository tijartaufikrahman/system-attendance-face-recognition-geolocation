import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/overtime_service.dart';

class OvertimePage extends StatefulWidget {
  const OvertimePage({super.key});
  @override
  State<OvertimePage> createState() => _OvertimePageState();
}

class _OvertimePageState extends State<OvertimePage>
    with SingleTickerProviderStateMixin {
  // ── Palette ──────────────────────────────────────────────
  static const _bg = Color(0xFFFAFBFC);
  static const _white = Colors.white;
  static const _navy = Color(0xFF1A202C);
  static const _muted = Color(0xFF9CA3AF);
  static const _border = Color(0xFFE5E7EB);
  static const _surface = Color(0xFFF9FAFB);

  final service = OvertimeService();
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? error;
  int? processingId;
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final values = await service.getMine();
      if (mounted) setState(() => items = values);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ── Actions ──────────────────────────────────────────────

  Future<void> decide(Map<String, dynamic> item, bool approve) async {
    final id = (item['id'] as num).toInt();
    if (processingId != null) return;
    setState(() => processingId = id);
    try {
      await service.updateDecision(id, approve);
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? 'Lembur disetujui.' : 'Lembur ditolak.'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => processingId = null);
    }
  }

  Future<void> cancelRequest(Map<String, dynamic> item) async {
    final id = (item['id'] as num).toInt();
    if (processingId != null) return;
    setState(() => processingId = id);
    try {
      await service.deleteRequest(id);
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengajuan lembur berhasil dihapus.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => processingId = null);
    }
  }

  Future<void> createRequest() async {
    try {
      final schedules = await service.getSchedules();
      if (!mounted) return;
      if (schedules.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Belum ada jadwal yang tersedia.')),
        );
        return;
      }
      DateTime selectedDate = DateTime.now();
      int? selectedSchedule = (schedules.first['id'] as num?)?.toInt();
      final noteController = TextEditingController();
      final submitted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: _white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Ajukan Lembur',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: _navy),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Date picker
                _buildDialogOption(
                  icon: Icons.calendar_today_outlined,
                  label: 'Tanggal',
                  value:
                      DateFormat('dd MMM yyyy', 'id_ID').format(selectedDate),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null && context.mounted) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                // Schedule dropdown
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: selectedSchedule,
                      isExpanded: true,
                      hint: const Text('Pilih jadwal'),
                      style: const TextStyle(
                          color: _navy,
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                      items: schedules.map((schedule) {
                        final id = (schedule['id'] as num).toInt();
                        final name =
                            schedule['name']?.toString() ?? 'Jadwal';
                        final clockIn = _time(schedule['clockIn']);
                        final clockOut = _time(schedule['clockOut']);
                        return DropdownMenuItem(
                          value: id,
                          child: Text(
                            '$name  ($clockIn \u2013 $clockOut)',
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setDialogState(() => selectedSchedule = value),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Note
                TextField(
                  controller: noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Catatan (opsional)',
                    hintStyle: const TextStyle(color: _muted, fontSize: 13),
                    filled: true,
                    fillColor: _surface,
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: _navy, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child:
                    const Text('Batal', style: TextStyle(color: _muted)),
              ),
              ElevatedButton(
                onPressed: selectedSchedule == null
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Ajukan'),
              ),
            ],
          ),
        ),
      );
      if (submitted == true && selectedSchedule != null) {
        await service.createRequest(
          date: selectedDate,
          scheduleId: selectedSchedule!,
          note: noteController.text.trim().isEmpty
              ? null
              : noteController.text.trim(),
        );
        await load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengajuan lembur dikirim untuk ditinjau.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      noteController.dispose();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final monthItems = items.where((item) {
      final value = DateTime.tryParse(item['date']?.toString() ?? '');
      return value != null &&
          value.year == selectedMonth.year &&
          value.month == selectedMonth.month;
    }).toList();

    final pendingEmployee = monthItems
        .where((v) =>
            v['status']?.toString().toUpperCase() == 'PENDING_EMPLOYEE')
        .toList();
    final pendingSupervisor = monthItems
        .where((v) =>
            v['status']?.toString().toUpperCase() == 'PENDING_SUPERVISOR' &&
            v['requestType']?.toString().toUpperCase() ==
                'EMPLOYEE_REQUEST')
        .toList();

    final actionableIds = {
      ...pendingEmployee.map((v) => v['id']),
      ...pendingSupervisor.map((v) => v['id']),
    };

    final historyRequests = monthItems
        .where((item) =>
            !actionableIds.contains(item['id']) &&
            item['requestType']?.toString().toUpperCase() ==
                'EMPLOYEE_REQUEST')
        .toList();
    final historyAssignments = monthItems
        .where((item) =>
            !actionableIds.contains(item['id']) &&
            item['requestType']?.toString().toUpperCase() !=
                'EMPLOYEE_REQUEST')
        .toList();

    final counts = [
      pendingEmployee.length,
      pendingSupervisor.length,
      historyRequests.length + historyAssignments.length,
    ];

    return Container(
      color: _bg,
      child: Column(
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lembur',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: _navy,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kelola pengajuan dan riwayat lembur Anda',
                        style: TextStyle(color: _muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                _PrimaryButton(
                  label: '+ Ajukan',
                  onPressed: loading ? null : createRequest,
                ),
              ],
            ),
          ),

          // ── Month Filter ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _buildMonthFilter(),
          ),

          // ── Tab Bar ──
          if (!loading && error == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: _navy,
                  unselectedLabelColor: _muted,
                  indicatorColor: _navy,
                  indicatorWeight: 2.5,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                  tabs: List.generate(
                    3,
                    (i) => Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(['Tugas', 'Pengajuan', 'Riwayat'][i]),
                          if (counts[i] > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: _navy.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${counts[i]}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _navy,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── Content ──
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: _navy, strokeWidth: 2.5))
                : error != null
                    ? _buildErrorState()
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildTaskList(pendingEmployee),
                          _buildSubmissionList(pendingSupervisor),
                          _buildHistoryList(
                              historyRequests, historyAssignments),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 40, color: _muted),
            const SizedBox(height: 12),
            Text(error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, fontSize: 13)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: load,
              child: const Text('Coba lagi',
                  style: TextStyle(color: _navy)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Month filter ──────────────────────────────────────────

  Widget _buildMonthFilter() {
    final months = List.generate(13, (index) {
      final now = DateTime.now();
      return DateTime(now.year, now.month - index);
    });
    final validMonth = months.any((m) =>
            m.year == selectedMonth.year && m.month == selectedMonth.month)
        ? selectedMonth
        : months.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined, size: 17, color: _navy),
          const SizedBox(width: 10),
          const Text('Periode',
              style: TextStyle(
                  fontSize: 12,
                  color: _muted,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<DateTime>(
                value: validMonth,
                isExpanded: true,
                style: const TextStyle(
                    color: _navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
                items: months
                    .map((month) => DropdownMenuItem(
                          value: month,
                          child: Text(
                            DateFormat('MMMM yyyy', 'id_ID')
                                .format(month),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => selectedMonth = value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab content builders ──────────────────────────────────

  Widget _buildTaskList(List<Map<String, dynamic>> values) {
    if (values.isEmpty) {
      return _emptyView('Tidak ada tugas lembur', Icons.assignment_outlined);
    }
    return RefreshIndicator(
      onRefresh: load,
      color: _navy,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        itemCount: values.length,
        itemBuilder: (context, i) => _TaskCard(
          item: values[i],
          onApprove:
              processingId == null ? () => decide(values[i], true) : null,
          onReject:
              processingId == null ? () => decide(values[i], false) : null,
        ),
      ),
    );
  }

  Widget _buildSubmissionList(List<Map<String, dynamic>> values) {
    if (values.isEmpty) {
      return _emptyView(
          'Tidak ada pengajuan tertunda', Icons.hourglass_empty_rounded);
    }
    return RefreshIndicator(
      onRefresh: load,
      color: _navy,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        itemCount: values.length,
        itemBuilder: (context, i) => _SubmissionCard(
          item: values[i],
          onDelete: processingId == null
              ? () => cancelRequest(values[i])
              : null,
        ),
      ),
    );
  }

  Widget _buildHistoryList(
    List<Map<String, dynamic>> requests,
    List<Map<String, dynamic>> assignments,
  ) {
    if (requests.isEmpty && assignments.isEmpty) {
      return _emptyView('Belum ada riwayat', Icons.history_rounded);
    }
    final all = [...requests, ...assignments];
    return RefreshIndicator(
      onRefresh: load,
      color: _navy,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        itemCount: all.length,
        itemBuilder: (context, i) => _HistoryCard(item: all[i]),
      ),
    );
  }

  Widget _emptyView(String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: const Color(0xFFD1D5DB)),
            const SizedBox(height: 10),
            Text(message,
                style: const TextStyle(color: _muted, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────

  static String _date(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed == null
        ? '-'
        : DateFormat('dd MMM yyyy', 'id_ID').format(parsed);
  }

  static String _time(dynamic value) {
    final text = value?.toString() ?? '';
    return text.isEmpty
        ? '-'
        : text.substring(0, text.length < 5 ? text.length : 5);
  }
}

// ═══════════════════════════════════════════════════════════════
// Helper: dialog option row
// ═══════════════════════════════════════════════════════════════

Widget _buildDialogOption({
  required IconData icon,
  required String label,
  required String value,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      color: Color(0xFF1A202C),
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const Spacer(),
          const Icon(Icons.chevron_right_rounded,
              size: 18, color: Color(0xFF9CA3AF)),
        ],
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════
// Shared card widgets
// ═══════════════════════════════════════════════════════════════

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.item, this.onApprove, this.onReject});
  final Map<String, dynamic> item;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final dateStr = _OvertimePageState._date(item['date']);
    final schedule = item['scheduleName']?.toString() ?? '';
    final start = _OvertimePageState._time(item['startTime']);
    final end = _OvertimePageState._time(item['endTime']);
    final note = item['note']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _OvertimePageState._border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _OvertimePageState._navy.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.work_outline_rounded,
                    size: 18, color: _OvertimePageState._navy),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(dateStr,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _OvertimePageState._navy,
                        fontSize: 15)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _OvertimePageState._navy.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Perlu tindakan',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _OvertimePageState._navy)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (schedule.isNotEmpty)
            _DetailRow(icon: Icons.event_available_outlined, text: schedule),
          _DetailRow(
              icon: Icons.schedule_outlined, text: '$start \u2013 $end'),
          if (note.isNotEmpty)
            _DetailRow(icon: Icons.notes_outlined, text: note),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _OvertimePageState._navy,
                    side: const BorderSide(
                        color: _OvertimePageState._border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Tolak'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _OvertimePageState._navy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Setujui'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({required this.item, this.onDelete});
  final Map<String, dynamic> item;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final dateStr = _OvertimePageState._date(item['date']);
    final schedule = item['scheduleName']?.toString() ?? '';
    final start = _OvertimePageState._time(item['startTime']);
    final end = _OvertimePageState._time(item['endTime']);
    final note = item['note']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _OvertimePageState._border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _OvertimePageState._navy.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.send_outlined,
                    size: 18, color: _OvertimePageState._navy),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(dateStr,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _OvertimePageState._navy,
                        fontSize: 15)),
              ),
              const Text('Menunggu',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _OvertimePageState._muted)),
            ],
          ),
          const SizedBox(height: 14),
          if (schedule.isNotEmpty)
            _DetailRow(icon: Icons.event_available_outlined, text: schedule),
          _DetailRow(
              icon: Icons.schedule_outlined, text: '$start \u2013 $end'),
          if (note.isNotEmpty)
            _DetailRow(icon: Icons.notes_outlined, text: note),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onDelete,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete_outline,
                      size: 16, color: Colors.red.shade400),
                  const SizedBox(width: 4),
                  Text('Hapus',
                      style: TextStyle(
                          color: Colors.red.shade400,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final rawStatus = (item['status']?.toString() ?? '').toLowerCase();
    final dateStr = _OvertimePageState._date(item['date']);
    final schedule = item['scheduleName']?.toString() ?? '';
    final start = _OvertimePageState._time(item['startTime']);
    final end = _OvertimePageState._time(item['endTime']);
    final note = item['note']?.toString() ?? '';
    final rejectionReason = item['rejectionReason']?.toString() ?? '';
    final checkedIn = item['checkedIn'] == true;
    final checkedOut = item['checkedOut'] == true;

    final statusLabel = rawStatus == 'approved'
        ? 'Disetujui'
        : rawStatus == 'rejected'
            ? 'Ditolak'
            : rawStatus == 'cancelled'
                ? 'Dibatalkan'
                : 'Menunggu';

    final statusColor = rawStatus == 'approved'
        ? const Color(0xFF16803C)
        : rawStatus == 'rejected'
            ? const Color(0xFFD92D20)
            : const Color(0xFF9CA3AF);

    String attendanceHint = '';
    if (rawStatus == 'approved') {
      attendanceHint = checkedOut
          ? '  \u2022  Absen selesai'
          : checkedIn
              ? '  \u2022  Sudah check-in'
              : '  \u2022  Belum absen';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _OvertimePageState._border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  rawStatus == 'approved'
                      ? Icons.check_circle_outline_rounded
                      : rawStatus == 'rejected'
                          ? Icons.cancel_outlined
                          : Icons.schedule_outlined,
                  size: 18,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(dateStr,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _OvertimePageState._navy,
                        fontSize: 15)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(statusLabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (schedule.isNotEmpty)
            _DetailRow(
                icon: Icons.event_available_outlined, text: schedule),
          _DetailRow(
            icon: Icons.schedule_outlined,
            text: '$start \u2013 $end$attendanceHint',
          ),
          if (note.isNotEmpty)
            _DetailRow(icon: Icons.notes_outlined, text: note),
          if (rawStatus == 'rejected' && rejectionReason.isNotEmpty)
            _DetailRow(
              icon: Icons.info_outline,
              text: rejectionReason,
              textColor: Colors.red.shade400,
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Shared UI pieces
// ═══════════════════════════════════════════════════════════════

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text, this.textColor});
  final IconData icon;
  final String text;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: _OvertimePageState._muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: textColor ?? _OvertimePageState._muted,
                    fontSize: 13,
                    height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: _OvertimePageState._navy,
        foregroundColor: Colors.white,
        elevation: 0,
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label,
          style:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
