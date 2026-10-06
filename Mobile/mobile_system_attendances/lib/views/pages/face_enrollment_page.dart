import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../services/face_embedding_service.dart';

class FaceEnrollmentPage extends StatefulWidget {
  const FaceEnrollmentPage({super.key});

  @override
  State<FaceEnrollmentPage> createState() => _FaceEnrollmentPageState();
}

class _FaceGuidePainter extends CustomPainter {
  const _FaceGuidePainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final oval = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    final background = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawOval(oval, background);

    if (progress <= 0) return;
    final foreground = Paint()
      ..color = const Color(0xFF58E88E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      oval,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      foreground,
    );
  }

  @override
  bool shouldRepaint(_FaceGuidePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _FaceEnrollmentPageState extends State<FaceEnrollmentPage> {
  static const _holdDuration = Duration(seconds: 2);
  static const _steps = [
    ('Hadap depan', 'Tatap kamera dengan wajah lurus.'),
    ('Hadap kiri', 'Putar kepala perlahan ke kiri.'),
    ('Hadap kanan', 'Putar kepala perlahan ke kanan.'),
  ];

  final _faceService = FaceEmbeddingService();
  final _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableLandmarks: false,
      enableContours: false,
    ),
  );

  CameraController? _camera;
  Interpreter? _interpreter;
  int _step = -1;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _scanFeedback = 'Mencari wajah...';
  Timer? _captureTimer;
  double? _firstSideYaw;
  DateTime? _poseStableSince;
  Offset? _lastFaceCenter;
  double? _lastFaceYaw;
  double _holdProgress = 0;
  final List<List<double>> _embeddings = [];
  final List<String> _photoPaths = [];

  bool get _isIntro => _step == -1;
  bool get _isComplete => _step >= _steps.length;

  @override
  void initState() {
    super.initState();
    _prepareCamera();
  }

  @override
  void dispose() {
    _captureTimer?.cancel();
    _camera?.dispose();
    _detector.close();
    _interpreter?.close();
    super.dispose();
  }

  Future<void> _prepareCamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final camera = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await camera.initialize();
      final interpreter = await Interpreter.fromAsset(
        'assets/mobilefacenet.tflite',
      );
      if (!mounted) {
        camera.dispose();
        interpreter.close();
        return;
      }
      setState(() {
        _camera = camera;
        _interpreter = interpreter;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Kamera atau model wajah tidak dapat disiapkan: $error';
      });
    }
  }

  void _startScan() {
    setState(() {
      _step = 0;
      _error = null;
      _scanFeedback = 'Arahkan wajah ke dalam bingkai';
    });
    _resetPoseStability();
    _scheduleAutomaticCapture(const Duration(milliseconds: 1500));
  }

  void _scheduleAutomaticCapture(Duration delay) {
    _captureTimer?.cancel();
    _captureTimer = Timer(delay, _captureStep);
  }

  Future<void> _captureStep() async {
    final camera = _camera;
    final interpreter = _interpreter;
    if (camera == null || interpreter == null || _saving || _isComplete) return;

    setState(() => _saving = true);
    try {
      final file = await camera.takePicture();
      final faces = await _detector.processImage(
        InputImage.fromFilePath(file.path),
      );
      if (faces.length != 1) {
        _resetPoseStability();
        _setScanFeedback(
          faces.isEmpty
              ? 'Wajah belum terdeteksi'
              : 'Pastikan hanya satu wajah di kamera',
        );
        _scheduleAutomaticCapture(const Duration(milliseconds: 350));
        return;
      }
      final face = faces.single;
      if (!_matchesRequestedPose(face)) {
        _resetPoseStability();
        _setScanFeedback(_poseHint);
        _scheduleAutomaticCapture(const Duration(milliseconds: 350));
        return;
      }
      if (!_hasHeldPose(face)) {
        final remainingSeconds =
            ((_holdDuration.inMilliseconds * (1 - _holdProgress)) / 1000)
                .clamp(0.1, 2.0)
                .toStringAsFixed(1);
        _setScanFeedback('Tahan posisi... $remainingSeconds detik');
        _scheduleAutomaticCapture(const Duration(milliseconds: 250));
        return;
      }
      if (_step == 1) {
        _firstSideYaw = face.headEulerAngleY;
      }
      _resetPoseStability();

      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) throw Exception('Foto wajah tidak dapat dibaca.');
      final source = img.bakeOrientation(decoded);
      final cropped = _cropFaceWithMargin(source, face.boundingBox);
      final directory = await getTemporaryDirectory();
      final croppedFile = File(
        '${directory.path}${Platform.pathSeparator}face_${DateTime.now().microsecondsSinceEpoch}_$_step.jpg',
      );
      await croppedFile.writeAsBytes(
        img.encodeJpg(cropped, quality: 92),
        flush: true,
      );
      final resized = img.copyResize(cropped, width: 112, height: 112);
      final input = [
        List.generate(
          112,
          (y) => List.generate(112, (x) {
            final pixel = resized.getPixel(x, y);
            return [
              (pixel.r - 127.5) / 128,
              (pixel.g - 127.5) / 128,
              (pixel.b - 127.5) / 128,
            ];
          }),
        ),
      ];
      final output = [List.filled(192, 0.0)];
      interpreter.run(input, output);
      final vector = List<double>.from(output.first);
      final norm = math.sqrt(
        vector.fold(0.0, (sum, value) => sum + value * value),
      );
      _embeddings.add(
        norm == 0 ? vector : vector.map((value) => value / norm).toList(),
      );
      _photoPaths.add(croppedFile.path);

      if (_step == _steps.length - 1) {
        await _saveEmbedding();
      }
      if (!mounted) return;
      setState(() {
        _step++;
        _error = null;
        _scanFeedback = 'Pose berhasil direkam';
      });
      if (!_isComplete) {
        _scheduleAutomaticCapture(const Duration(milliseconds: 1400));
      }
    } catch (error) {
      if (_embeddings.length > _step) {
        _embeddings.removeLast();
        final photoPath = _photoPaths.removeLast();
        final photo = File(photoPath);
        if (await photo.exists()) await photo.delete();
      }
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
      _scheduleAutomaticCapture(const Duration(milliseconds: 900));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _setScanFeedback(String message) {
    if (!mounted) return;
    setState(() {
      _error = null;
      _scanFeedback = message;
    });
  }

  void _resetPoseStability() {
    _poseStableSince = null;
    _lastFaceCenter = null;
    _lastFaceYaw = null;
    _holdProgress = 0;
  }

  bool _hasHeldPose(Face face) {
    final now = DateTime.now();
    final center = face.boundingBox.center;
    final yaw = face.headEulerAngleY ?? 0;
    final previousCenter = _lastFaceCenter;
    final previousYaw = _lastFaceYaw;
    final moved =
        previousCenter == null ||
        (center - previousCenter).distance > 18 ||
        previousYaw == null ||
        (yaw - previousYaw).abs() > 4;

    if (moved) _poseStableSince = now;
    _lastFaceCenter = center;
    _lastFaceYaw = yaw;
    final elapsed = now.difference(_poseStableSince ?? now);
    _holdProgress = (elapsed.inMilliseconds / _holdDuration.inMilliseconds)
        .clamp(0, 1);
    return elapsed >= _holdDuration;
  }

  bool _matchesRequestedPose(Face face) {
    final horizontal = face.headEulerAngleY ?? 0;
    return switch (_step) {
      0 => horizontal.abs() <= 10,
      1 => horizontal.abs() >= 12,
      2 => _firstSideYaw != null && horizontal * _firstSideYaw! < -144,
      _ => true,
    };
  }

  img.Image _cropFaceWithMargin(img.Image source, Rect bounds) {
    final edge = (math.max(bounds.width, bounds.height) * 1.35)
        .round()
        .clamp(1, math.min(source.width, source.height))
        .toInt();
    final left = (bounds.center.dx - edge / 2)
        .round()
        .clamp(0, source.width - edge)
        .toInt();
    final top = (bounds.center.dy - edge / 2)
        .round()
        .clamp(0, source.height - edge)
        .toInt();
    return img.copyCrop(source, x: left, y: top, width: edge, height: edge);
  }

  String get _poseHint => switch (_step) {
    0 => 'Hadapkan wajah lurus ke kamera, lalu coba lagi.',
    1 => 'Putar kepala sedikit ke kiri, lalu coba lagi.',
    2 => 'Putar kepala ke sisi kanan, berlawanan dari foto sebelumnya.',
    _ => 'Ikuti petunjuk di layar, lalu coba lagi.',
  };

  Future<void> _saveEmbedding() async {
    await _faceService.saveEnrollment(
      photoPaths: _photoPaths,
      embeddings: _embeddings,
    );
    for (final path in _photoPaths) {
      final photo = File(path);
      if (await photo.exists()) await photo.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text('Daftarkan Wajah'),
        backgroundColor: const Color(0xFF1B2A4A),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _isIntro
          ? _buildIntroduction()
          : _isComplete
          ? _buildSuccess()
          : _buildScanner(),
    );
  }

  Widget _buildIntroduction() {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            const Icon(
              Icons.face_retouching_natural_rounded,
              size: 72,
              color: Color(0xFF1B2A4A),
            ),
            const SizedBox(height: 24),
            const Text(
              'Siapkan wajah Anda',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1B2A4A),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Lepaskan kacamata, masker, atau topi. Setelah dimulai, ikuti instruksi di layar. Foto akan diambil otomatis.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF667085), height: 1.5),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _error == null ? _startScan : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1B2A4A),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Mulai pemindaian'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFD92D20)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScanner() {
    final camera = _camera;
    if (camera == null) {
      return const Center(child: Text('Kamera tidak tersedia'));
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: Colors.black,
          child: Center(
            child: AspectRatio(
              aspectRatio: 1 / camera.value.aspectRatio,
              child: CameraPreview(camera),
            ),
          ),
        ),
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: _holdProgress),
            duration: const Duration(milliseconds: 220),
            builder: (context, progress, _) => CustomPaint(
              size: const Size(240, 310),
              painter: _FaceGuidePainter(progress),
            ),
          ),
        ),
        Positioned(
          top: 18,
          left: 20,
          right: 20,
          child: SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    _steps[_step].$1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _steps[_step].$2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _scanFeedback,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFB8F5CE),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_holdProgress > 0) ...[
                    const SizedBox(height: 5),
                    Text(
                      '${(_holdProgress * 100).round()}% - jangan bergerak',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFFFB4AB)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 20,
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Pemindaian ${_step + 1} dari ${_steps.length}',
                    style: const TextStyle(
                      color: Color(0xFF1B2A4A),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Foto akan diambil otomatis setelah posisi stabil.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF667085), fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: _saving ? null : _step / _steps.length,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF16803C),
              size: 76,
            ),
            const SizedBox(height: 18),
            const Text(
              'Wajah berhasil didaftarkan',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1B2A4A),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Data wajah Anda sudah tersimpan dan dapat digunakan untuk absensi.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF667085)),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Selesai'),
            ),
          ],
        ),
      ),
    );
  }
}
