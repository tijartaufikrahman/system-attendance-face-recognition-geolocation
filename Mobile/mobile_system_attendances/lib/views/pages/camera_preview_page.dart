import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../services/face_embedding_service.dart';
import '../../services/attendance_service.dart';

class CameraPreviewPage extends StatefulWidget {
  const CameraPreviewPage({
    super.key,
    required this.status,
    required this.note,
    required this.locationId,
    required this.files,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.distanceMeters,
    required this.faceTolerance,
    this.mode = 'checkin',
    this.overtimeId,
  });

  final String status;
  final String note;
  final int? locationId;
  final List<PlatformFile> files;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final double? distanceMeters;
  final double faceTolerance;
  final String mode; // 'checkin' | 'checkout'
  final int? overtimeId;

  @override
  State<CameraPreviewPage> createState() => _CameraPreviewPageState();
}

class _CameraPreviewPageState extends State<CameraPreviewPage>
    with WidgetsBindingObserver {
  final _faceService = FaceEmbeddingService();
  final _attendanceService = AttendanceService();
  final _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableLandmarks: true,
      enableContours: true,
    ),
  );

  CameraController? _cameraController;
  Interpreter? _interpreter;
  Timer? _recognitionTimer;
  List<List<double>>? _registeredEmbeddings;
  Face? _detectedFace;
  Size? _sourceImageSize;
  String? _errorMessage;
  String _recognitionMessage = 'Memuat data wajah Anda...';
  double? _similarity;
  bool _isInitializing = true;
  bool _isProcessingFrame = false;
  bool _isClosingCamera = false;
  bool _allowPop = false;
  bool _showLandmarks = false;
  int _livenessStep = -1;
  DateTime? _livenessStarted;
  bool _attendanceSubmitted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recognitionTimer?.cancel();
    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) {
      unawaited(_disposeCamera(controller));
    }
    _interpreter?.close();
    _detector.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _recognitionTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      if (_cameraController?.value.isInitialized == true) {
        _startRecognition();
      } else {
        _initializeCamera();
      }
    }
  }

  Future<void> _initializeCamera() async {
    if (_isClosingCamera || _isInitializing && _cameraController != null) {
      return;
    }
    _recognitionTimer?.cancel();
    if (mounted) {
      setState(() {
        _isInitializing = true;
        _errorMessage = null;
      });
    }

    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.cast<CameraDescription?>().firstWhere(
        (camera) => camera?.lensDirection == CameraLensDirection.front,
        orElse: () => null,
      );
      if (frontCamera == null) {
        _setError('Kamera depan tidak tersedia pada perangkat ini.');
        return;
      }

      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      final interpreter =
          _interpreter ??
          await Interpreter.fromAsset('assets/mobilefacenet.tflite');
      final embeddings =
          _registeredEmbeddings ?? await _faceService.getMyEmbeddings();

      if (!mounted) {
        await controller.dispose();
        if (_interpreter == null) interpreter.close();
        return;
      }
      final previousController = _cameraController;
      if (previousController != null) {
        await _disposeCamera(previousController);
      }
      setState(() {
        _cameraController = controller;
        _interpreter = interpreter;
        _registeredEmbeddings = embeddings;
        _isInitializing = false;
        _recognitionMessage = 'Arahkan wajah ke dalam bingkai';
      });
      _startRecognition();
    } on CameraException catch (error) {
      _setError(_cameraErrorMessage(error.code));
    } catch (error) {
      _setError(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _startRecognition() {
    _recognitionTimer?.cancel();
    _recognitionTimer = Timer.periodic(
      const Duration(milliseconds: 900),
      (_) => _evaluateCurrentFace(),
    );
  }

  Future<void> _evaluateCurrentFace() async {
    final camera = _cameraController;
    final interpreter = _interpreter;
    final embeddings = _registeredEmbeddings;
    if (_isClosingCamera ||
        _isProcessingFrame ||
        camera == null ||
        !camera.value.isInitialized ||
        interpreter == null ||
        embeddings == null ||
        embeddings.isEmpty) {
      return;
    }

    _isProcessingFrame = true;
    try {
      final file = await camera.takePicture();
      final faces = await _detector.processImage(
        InputImage.fromFilePath(file.path),
      );
      if (!mounted) return;
      if (faces.length != 1) {
        setState(() {
          _similarity = null;
          _detectedFace = null;
          _sourceImageSize = null;
          _recognitionMessage = faces.isEmpty
              ? 'Wajah belum terdeteksi'
              : 'Pastikan hanya satu wajah di kamera';
        });
        return;
      }

      final decoded = img.decodeImage(await file.readAsBytes());
      if (decoded == null) return;
      final source = img.bakeOrientation(decoded);
      final bounds = faces.single.boundingBox;
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
      final faceImage = img.copyResize(
        img.copyCrop(source, x: left, y: top, width: edge, height: edge),
        width: 112,
        height: 112,
      );
      final input = [
        List.generate(
          112,
          (y) => List.generate(112, (x) {
            final pixel = faceImage.getPixel(x, y);
            return [
              (pixel.r - 127.5) / 128,
              (pixel.g - 127.5) / 128,
              (pixel.b - 127.5) / 128,
            ];
          }),
        ),
      ];
      final output = [List.filled(embeddings.first.length, 0.0)];
      interpreter.run(input, output);
      final currentEmbedding = _normalize(List<double>.from(output.first));
      final similarities = embeddings
          .map((embedding) => _cosineSimilarity(currentEmbedding, embedding))
          .toList();
      final highestSimilarity = similarities.reduce(
        (highest, value) => value > highest ? value : highest,
      );

      if (!mounted) return;
      setState(() {
        _similarity = highestSimilarity;
        _detectedFace = faces.single;
        _sourceImageSize = Size(
          source.width.toDouble(),
          source.height.toDouble(),
        );
        if (highestSimilarity >= widget.faceTolerance && _livenessStep < 0) {
          _livenessStep = 0;
          _livenessStarted = DateTime.now();
        }
        if (_livenessStep >= 0 && !_attendanceSubmitted) {
          _advanceLiveness(faces.single);
        }
        _recognitionMessage = _livenessStep >= 0
            ? _livenessInstruction
            : highestSimilarity >= widget.faceTolerance
            ? 'Wajah sesuai'
            : 'Wajah belum sesuai';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _similarity = null;
          _detectedFace = null;
          _sourceImageSize = null;
          _recognitionMessage = 'Menunggu wajah terdeteksi';
        });
      }

    } finally {
      _isProcessingFrame = false;
    }
  }

  String get _livenessInstruction => switch (_livenessStep) {
        0 => 'Liveness 1/3: hadap kiri',
        1 => 'Liveness 2/3: hadap kanan',
        2 => 'Liveness 3/3: buka mulut lebar',
        3 => 'Liveness berhasil, menyimpan absensi...',
        _ => 'Arahkan wajah ke dalam bingkai',
      };

  void _advanceLiveness(Face face) {
    final started = _livenessStarted;
    if (started == null ||
        DateTime.now().difference(started).inMilliseconds < 350) {
      return;
    }
    final yaw = face.headEulerAngleY ?? 0;
    final mouthTop = face.contours[FaceContourType.upperLipTop]?.points;
    final mouthBottom = face.contours[FaceContourType.lowerLipBottom]?.points;
    final mouthOpen = _isMouthOpen(mouthTop, mouthBottom, face.boundingBox.height);
    final passed = _livenessStep == 0
        ? yaw > 15
        : _livenessStep == 1
        ? yaw < -15
        : _livenessStep == 2 && mouthOpen;
    if (!passed) return;
    if (_livenessStep < 2) {
      _livenessStep++;
      _livenessStarted = DateTime.now();
      return;
    }
    _livenessStep = 3;
    _submitAttendance();
  }

  bool _isMouthOpen(
    List<math.Point<int>>? upperLip,
    List<math.Point<int>>? lowerLip,
    double faceHeight,
  ) {
    if (upperLip == null ||
        lowerLip == null ||
        upperLip.isEmpty ||
        lowerLip.isEmpty ||
        faceHeight <= 0) {
      return false;
    }

    // Kontur bibir dimulai dari sudut yang berbeda-beda. Menggunakan titik
    // pertama membuat mulut terbuka sering terbaca sebagai tertutup.
    final upperAverageY =
        upperLip.map((point) => point.y).reduce((a, b) => a + b) /
        upperLip.length;
    final lowerAverageY =
        lowerLip.map((point) => point.y).reduce((a, b) => a + b) /
        lowerLip.length;
    final averageGap = lowerAverageY - upperAverageY;
    final maximumGap = lowerLip
        .expand(
          (lowerPoint) => upperLip.map(
            (upperPoint) => lowerPoint.y - upperPoint.y,
          ),
        )
        .reduce((a, b) => a > b ? a : b);

    // Ambang dibuat adaptif terhadap ukuran wajah di kamera.
    return averageGap > faceHeight * 0.025 ||
        maximumGap > faceHeight * 0.09;
  }

  Future<void> _submitAttendance() async {
    if (_attendanceSubmitted) return;
    _attendanceSubmitted = true;
    try {
      await _attendanceService.submit(
        status: widget.status,
        mode: widget.mode,
        overtimeId: widget.overtimeId,
        note: widget.note,
        locationId: widget.locationId,
        latitude: widget.latitude,
        longitude: widget.longitude,
        accuracyMeters: widget.accuracyMeters,
        distanceMeters: widget.distanceMeters,
        faceSimilarity: _similarity,
        companyTolerance: widget.faceTolerance,
        files: widget.files,
      );
      if (!mounted) return;
      // Tutup kamera sebelum mengosongkan seluruh stack absensi agar kembali ke beranda.
      await _closeCameraBeforeLeaving();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      _attendanceSubmitted = false;
      if (mounted) {
        setState(() => _recognitionMessage = 'Gagal menyimpan: $error');
      }
    }
  }

  Future<void> _closeCameraBeforeLeaving() async {
    if (_isClosingCamera) return;
    _isClosingCamera = true;
    _recognitionTimer?.cancel();

    var attempts = 0;
    while (_isProcessingFrame && attempts < 25) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      attempts++;
    }

    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) await _disposeCamera(controller);
    if (mounted) setState(() => _allowPop = true);
  }

  Future<void> _disposeCamera(CameraController controller) async {
    try {
      await controller.dispose();
    } on PlatformException catch (error) {
      debugPrint('Camera preview disposal failed: ${error.message}');
    } on CameraException catch (error) {
      debugPrint('Camera disposal failed: ${error.description}');
    }
  }

  List<double> _normalize(List<double> vector) {
    final length = math.sqrt(
      vector.fold(0.0, (sum, value) => sum + value * value),
    );
    return length == 0
        ? vector
        : vector.map((value) => value / length).toList();
  }

  double _cosineSimilarity(List<double> first, List<double> second) {
    if (first.length != second.length) return 0;
    var similarity = 0.0;
    for (var index = 0; index < first.length; index++) {
      similarity += first[index] * second[index];
    }
    return similarity.clamp(-1, 1).toDouble();
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _isInitializing = false;
    });
  }

  String _cameraErrorMessage(String code) {
    return switch (code) {
      'CameraAccessDenied' =>
        'Izin kamera ditolak. Izinkan akses kamera dari pengaturan.',
      'CameraAccessRestricted' => 'Akses kamera dibatasi pada perangkat ini.',
      _ => 'Kamera tidak dapat dibuka. Coba lagi.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Verifikasi Wajah'),
        backgroundColor: const Color(0xFF1B2A4A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: _showLandmarks
                ? 'Sembunyikan landmark'
                : 'Tampilkan landmark',
            onPressed: () => setState(() => _showLandmarks = !_showLandmarks),
            icon: Icon(
              _showLandmarks
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
            ),
          ),
          IconButton(
            tooltip: 'Muat ulang kamera',
            onPressed: _initializeCamera,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: PopScope(
        canPop: _allowPop,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop || _isClosingCamera) return;
          await _closeCameraBeforeLeaving();
          if (context.mounted) Navigator.of(context).pop(result);
        },
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(child: _buildCameraArea()),
              _buildBottomInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraArea() {
    if (_isInitializing) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white70,
                size: 48,
              ),
              const SizedBox(height: 14),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _initializeCamera,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba lagi'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return Center(
      child: AspectRatio(
        aspectRatio: 1 / controller.value.aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(controller),
            if (_showLandmarks &&
                _detectedFace != null &&
                _sourceImageSize != null)
              CustomPaint(
                painter: _FaceLandmarkPainter(
                  face: _detectedFace!,
                  sourceImageSize: _sourceImageSize!,
                ),
              ),
            Center(
              child: Container(
                width: 220,
                height: 290,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.85),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(110),
                ),
              ),
            ),
            Positioned(
              top: 18,
              left: 18,
              right: 18,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.52),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Posisikan wajah di dalam bingkai',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
            Positioned(right: 18, bottom: 18, child: _buildLandmarkToggle()),
          ],
        ),
      ),
    );
  }

  Widget _buildLandmarkToggle() {
    return Material(
      color: Colors.black.withValues(alpha: 0.52),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => setState(() => _showLandmarks = !_showLandmarks),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _showLandmarks
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                _showLandmarks ? 'Sembunyikan titik' : 'Lihat titik',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomInfo() {
    final similarity = _similarity;
    final isMatch = similarity != null && similarity >= widget.faceTolerance;
    final similarityText = similarity == null
        ? '--'
        : '${(similarity * 100).toStringAsFixed(1)}%';
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _recognitionMessage,
                    style: const TextStyle(
                      color: Color(0xFF1B2A4A),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Similarity tertinggi: $similarityText • Ambang ${(widget.faceTolerance * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: isMatch
                    ? const Color(0xFFEAF7EF)
                    : const Color(0xFFFFF4E5),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(
                isMatch ? 'Cocok' : 'Memeriksa',
                style: TextStyle(
                  color: isMatch
                      ? const Color(0xFF16803C)
                      : const Color(0xFFB54708),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaceLandmarkPainter extends CustomPainter {
  const _FaceLandmarkPainter({
    required this.face,
    required this.sourceImageSize,
  });

  final Face face;
  final Size sourceImageSize;

  @override
  void paint(Canvas canvas, Size size) {
    final contourPaint = Paint()
      ..color = const Color(0xFF44E38A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final landmarkPaint = Paint()..color = const Color(0xFFFFD54F);

    Offset toCanvasPoint(int x, int y) {
      final dx = size.width - (x * size.width / sourceImageSize.width);
      final dy = y * size.height / sourceImageSize.height;
      return Offset(dx, dy);
    }

    for (final contour in face.contours.values) {
      if (contour == null || contour.points.isEmpty) continue;
      final first = contour.points.first;
      final start = toCanvasPoint(first.x, first.y);
      final path = Path()..moveTo(start.dx, start.dy);
      for (final point in contour.points.skip(1)) {
        final offset = toCanvasPoint(point.x, point.y);
        path.lineTo(offset.dx, offset.dy);
      }
      canvas.drawPath(path, contourPaint);
    }
    for (final landmark in face.landmarks.values) {
      if (landmark == null) continue;
      final point = landmark.position;
      canvas.drawCircle(toCanvasPoint(point.x, point.y), 3.5, landmarkPaint);
    }
  }

  @override
  bool shouldRepaint(_FaceLandmarkPainter oldDelegate) {
    return oldDelegate.face != face ||
        oldDelegate.sourceImageSize != sourceImageSize;
  }
}
