import 'package:flutter/material.dart';

class OvertimeDetailPage extends StatelessWidget {
  const OvertimeDetailPage({super.key});

  static const _bg = Color(0xFFFAFBFC);
  static const _white = Colors.white;
  static const _navy = Color(0xFF1A202C);
  static const _muted = Color(0xFF9CA3AF);
  static const _border = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: _navy, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Detail Lembur',
          style: TextStyle(
              color: _navy, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: _border,
            height: 1,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status Card ──
            _buildStatusCard(),
            const SizedBox(height: 16),

            // ── Timeline Card ──
            _buildTimelineCard(),
            const SizedBox(height: 16),

            // ── Reason ──
            _buildReasonCard(),
            const SizedBox(height: 28),

            // ── Action Buttons ──
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF97316).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.approval_rounded,
                color: Color(0xFFF97316), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Menunggu Persetujuan',
                    style: TextStyle(
                        color: _navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text('Anda diminta untuk menyetujui lembur ini',
                    style: TextStyle(
                        color: _muted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Informasi Lembur',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _navy)),
          const SizedBox(height: 20),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline dots + line
              SizedBox(
                width: 28,
                child: Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF16803C),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFFBBF7D0), width: 3),
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF16803C),
                            Color(0xFFD92D20)
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD92D20),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFFFECACA), width: 3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Date/time content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('MULAI',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16803C),
                            letterSpacing: 0.8)),
                    const SizedBox(height: 3),
                    const Text('28/08/2026  17:00',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _navy)),
                    const SizedBox(height: 3),
                    Text('Kamis',
                        style: TextStyle(
                            fontSize: 12, color: _muted)),

                    const SizedBox(height: 28),

                    const Text('SELESAI',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFD92D20),
                            letterSpacing: 0.8)),
                    const SizedBox(height: 3),
                    const Text('29/08/2026  20:00',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _navy)),
                    const SizedBox(height: 3),
                    Text('Jumat',
                        style: TextStyle(
                            fontSize: 12, color: _muted)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Duration badge
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _navy.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timelapse_rounded,
                    size: 18, color: _navy),
                const SizedBox(width: 8),
                Text('Durasi Lembur  :  ',
                    style: TextStyle(
                        fontSize: 13, color: _muted)),
                const Text('2 Hari  (3 Jam)',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _navy)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Alasan',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _navy)),
          const SizedBox(height: 10),
          Text(
            'Deadline project yang harus diselesaikan minggu ini. Client meminta presentasi akhir pada hari Jumat.',
            style: TextStyle(
                fontSize: 13,
                color: _muted,
                height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Lembur ditolak'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: _navy,
              side: const BorderSide(color: _border),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Tolak', style: TextStyle(fontSize: 15)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Lembur disetujui'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _navy,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Setuju',
                style: TextStyle(fontSize: 15)),
          ),
        ),
      ],
    );
  }
}
