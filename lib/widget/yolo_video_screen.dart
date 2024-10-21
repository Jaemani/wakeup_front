import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wakeup/services/location_service.dart';
import 'package:wakeup/services/firebase_service.dart';
import 'package:wakeup/widget/log_window.dart';
import 'package:audioplayers/audioplayers.dart';

class YoloVideo extends StatefulWidget {
  final List<CameraDescription> cameras;

  const YoloVideo({super.key, required this.cameras});

  @override
  _YoloVideoState createState() => _YoloVideoState();
}

class _YoloVideoState extends State<YoloVideo> with TickerProviderStateMixin {
  late CameraController controller;
  late FlutterVision vision;
  List<Map<String, dynamic>> yoloResults = [];
  CameraImage? cameraImage;
  bool isLoaded = false;
  bool isDetecting = false;
  int currentCameraIndex = 0;
  double confidenceThreshold = 0.5;

  late AnimationController _slideController;
  bool isLogPageVisible = false;
  final GlobalKey<LogWindowState> _logWindowKey = GlobalKey<LogWindowState>();

  Position? currentPosition;
  final AudioPlayer _audioPlayer = AudioPlayer();

  DateTime? eyesClosedStartTime;
  bool isWarning = false;
  String debugInfo = '';

  int frameCount = 0;
  double fps = 0;
  double detectionTime = 0;

  @override
  void initState() {
    super.initState();
    init();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideController.addListener(() {
      if (_slideController.value == 1.0) {
        stopDetection();
      } else if (_slideController.value == 0.0) {
        if (isDetecting) startDetection();
      }
    });

    _initAudioPlayer();

    Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        fps = frameCount.toDouble();
        frameCount = 0;
      });
    });
  }

  Future<void> init() async {
    try {
      vision = FlutterVision();
      controller = CameraController(widget.cameras[0], ResolutionPreset.high);
      await controller.initialize();
      await loadYoloModel();
      setState(() {
        isLoaded = true;
      });
    } catch (e) {
      print('Error in init: $e');
    }
  }

  Future<void> _initAudioPlayer() async {
    try {
      await _audioPlayer.setSource(AssetSource('alert_sound.mp3'));
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
    } catch (e) {
      print('Error initializing audio player: $e');
    }
  }

  Future<void> loadYoloModel() async {
    try {
      await vision.loadYoloModel(
        labels: 'assets/labels.txt',
        modelPath: 'assets/yolov5n_320_V1-fp16.tflite',
        modelVersion: "yolov5",
        quantization: true,
        numThreads: 1,
        useGpu: true,
      );
      setState(() {
        isLoaded = true;
      });
    } catch (e) {
      print('Error loading YOLO model: $e');
    }
  }

  Future<void> yoloOnFrame(CameraImage cameraImage) async {
    try {
      final result = await vision.yoloOnFrame(
        bytesList: cameraImage.planes.map((plane) => plane.bytes).toList(),
        imageHeight: cameraImage.height,
        imageWidth: cameraImage.width,
        confThreshold: confidenceThreshold,
        iouThreshold: 0.4,
        classThreshold: 0.5,
      );

      frameCount++;

      bool eyesClosed = result.any((detection) => detection['tag'] == 'closed');
      bool eyesOpened = result.any((detection) => detection['tag'] == 'opened');

      if (result.isNotEmpty) {
        setState(() {
          yoloResults = result;
        });
      }

      _updateEyeState(eyesClosed, eyesOpened);
    } catch (e) {
      print('Error in yoloOnFrame: $e');
    }
  }

  void _updateEyeState(bool closed, bool opened) {
    if (closed && eyesClosedStartTime == null) {
      eyesClosedStartTime = DateTime.now();
      debugInfo = 'Eyes just closed';
    } else if (opened && eyesClosedStartTime != null) {
      final closedDuration = DateTime.now().difference(eyesClosedStartTime!);
      debugInfo = 'Eyes were closed for: ${closedDuration.inMilliseconds} ms';
      eyesClosedStartTime = null;
      isWarning = false;
    } else if (eyesClosedStartTime != null) {
      final currentClosedDuration =
          DateTime.now().difference(eyesClosedStartTime!);
      debugInfo = 'Eyes closed for: ${currentClosedDuration.inMilliseconds} ms';

      if (currentClosedDuration.inMilliseconds >= 1200 && !isWarning) {
        _logWarning(currentClosedDuration);
        isWarning = true;
        _playAlertSound();
      }
    }
  }

  void _logWarning(Duration closedDuration) {
    final warningMessage =
        'WARNING: Eyes closed for ${closedDuration.inMilliseconds} ms';
    print(warningMessage);
    _logWindowKey.currentState?.addLog(warningMessage);
  }

  Widget buildCameraPreview(double deviceRatio) {
    final scale = 1 / (controller.value.aspectRatio * deviceRatio);
    final mirror = widget.cameras[currentCameraIndex].lensDirection ==
            CameraLensDirection.front
        ? math.pi
        : 0.0;

    return Transform.scale(
      scale: scale,
      child: Center(
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.rotationY(mirror),
          child: CameraPreview(controller),
        ),
      ),
    );
  }

  void _handleApiKeySubmitted(String apiKey) {
    print('API Key submitted: $apiKey');
    _logWindowKey.currentState?.addLog('API Key submitted successfully');
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _slideController.value -= details.primaryDelta! / context.size!.width;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_slideController.isAnimating) return;
    final double flingVelocity =
        details.velocity.pixelsPerSecond.dx / context.size!.width;
    if (flingVelocity < 0) {
      _slideController.fling(velocity: math.max(2.0, -flingVelocity));
    } else if (flingVelocity > 0) {
      _slideController.fling(velocity: math.min(-2.0, -flingVelocity));
    } else {
      _slideController.fling(
          velocity: _slideController.value < 0.5 ? -2.0 : 2.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoaded) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: GestureDetector(
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        child: Stack(
          children: [
            buildMainPage(),
            // Log window (covers full screen)
            AnimatedBuilder(
              animation: _slideController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                      MediaQuery.of(context).size.width *
                          (1 - _slideController.value),
                      0),
                  child: child,
                );
              },
              child: LogWindow(
                key: _logWindowKey,
                onApiKeySubmitted: _handleApiKeySubmitted,
              ),
            ),
            Positioned(
              top: 50,
              left: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    debugInfo,
                    style: const TextStyle(color: Colors.red, fontSize: 18),
                  ),
                  Text(
                    'FPS: ${fps.toStringAsFixed(1)}',
                    style: const TextStyle(color: Colors.green, fontSize: 18),
                  ),
                  Text(
                    'Detection Time: ${detectionTime.toStringAsFixed(1)} ms',
                    style: const TextStyle(color: Colors.blue, fontSize: 18),
                  ),
                ],
              ),
            ),
            if (isWarning)
              const Center(
                child: Text(
                  'WAKE UP!',
                  style: TextStyle(
                      color: Colors.red,
                      fontSize: 36,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ...displayBoxesAroundRecognizedObjects(MediaQuery.of(context).size),
          ],
        ),
      ),
    );
  }

  Widget buildMainPage() {
    final Size size = MediaQuery.of(context).size;
    final deviceRatio = size.width / size.height;

    return Stack(
      fit: StackFit.expand,
      children: [
        buildCameraPreview(deviceRatio),
        ...displayBoxesAroundRecognizedObjects(size),
        Positioned(
          bottom: 75,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FloatingActionButton(
                onPressed: isDetecting ? stopDetection : startDetection,
                child: Icon(
                  isDetecting ? Icons.stop : Icons.play_arrow,
                  color: isDetecting ? Colors.red : Colors.white,
                ),
              ),
              const SizedBox(width: 20),
              FloatingActionButton(
                onPressed: flipCamera,
                child: const Icon(Icons.flip_camera_ios),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> displayBoxesAroundRecognizedObjects(Size screen) {
    if (yoloResults.isEmpty) return [];

    double scaleX = screen.width / (cameraImage?.height ?? 1);
    double scaleY = screen.height / (cameraImage?.width ?? 1);
    final bool isFrontCamera =
        widget.cameras[currentCameraIndex].lensDirection ==
            CameraLensDirection.front;

    Color colorPick = const Color.fromARGB(255, 50, 233, 30);

    return yoloResults
        .map((result) {
          // Safely access box values with null checks
          List<dynamic>? box = result["box"] as List<dynamic>?;
          if (box == null || box.length < 5)
            return Container(); // Skip invalid results

          double left = (box[0] as num?)?.toDouble() ?? 0;
          double top = (box[1] as num?)?.toDouble() ?? 0;
          double right = (box[2] as num?)?.toDouble() ?? 0;
          double bottom = (box[3] as num?)?.toDouble() ?? 0;
          double confidence = (box[4] as num?)?.toDouble() ?? 0;

          left *= scaleX;
          top *= scaleY;
          right *= scaleX;
          bottom *= scaleY;

          if (isFrontCamera) {
            final double tmp = left;
            left = screen.width - right;
            right = screen.width - tmp;
          }

          return Positioned(
            left: isFrontCamera ? screen.width - right : left,
            top: top,
            width: right - left,
            height: bottom - top,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(10.0)),
                border: Border.all(color: Colors.pink, width: 2.0),
              ),
              child: Text(
                "${result['tag'] ?? 'Unknown'} ${(confidence * 100).toStringAsFixed(1)}%",
                style: TextStyle(
                  background: Paint()..color = colorPick,
                  color: const Color.fromARGB(255, 115, 0, 255),
                  fontSize: 18.0,
                ),
              ),
            ),
          );
        })
        .whereType<Positioned>()
        .toList();
  }

  Future<void> startDetection() async {
    setState(() {
      isDetecting = true;
    });
    if (controller.value.isStreamingImages) return;

    await controller.startImageStream((image) async {
      if (isDetecting) {
        cameraImage = image;
        yoloOnFrame(image);
      }
    });
  }

  Future<void> stopDetection() async {
    setState(() {
      isDetecting = false;
      yoloResults.clear();
    });
  }

  Future<void> switchCamera(int cameraIndex) async {
    stopDetection();
    await controller.dispose();
    controller = CameraController(
      widget.cameras[cameraIndex],
      ResolutionPreset.high,
    );
    await controller.initialize();
    setState(() {
      currentCameraIndex = cameraIndex;
      yoloResults.clear();
    });
  }

  void flipCamera() {
    final nextCameraIndex = (currentCameraIndex + 1) % widget.cameras.length;
    switchCamera(nextCameraIndex);
  }

  Future<void> _playAlertSound() async {
    await _audioPlayer.resume();
  }

  @override
  void dispose() {
    controller.dispose();
    vision.closeYoloModel();
    _slideController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}
