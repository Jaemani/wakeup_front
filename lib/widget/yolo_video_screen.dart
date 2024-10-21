import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_vision/flutter_vision.dart';
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
  bool showInfo =
      true; // New: Controls visibility of eye-closed status, FPS, and detection time
  int currentCameraIndex = 0;

  DateTime? eyesClosedStartTime;
  bool isWarning = false;
  String debugInfo = '';
  int frameCount = 0;
  double fps = 0;
  double detectionTime = 0;

  late AnimationController _slideController;
  final GlobalKey<LogWindowState> _logWindowKey = GlobalKey<LogWindowState>();

  Position? currentPosition;
  String safetyStatus = "Safe"; // New: Stores location safety status

  final AudioPlayer _audioPlayer = AudioPlayer();

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

    Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        fps = frameCount.toDouble();
        frameCount = 0;
      });
    });
    _initAudioPlayer();
  }

  Future<void> init() async {
    try {
      vision = FlutterVision();
      controller = CameraController(widget.cameras[0], ResolutionPreset.high);
      await controller.initialize();
      await loadYoloModel();
      _startMonitoringLocation(); // New: Start location monitoring
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

  void _startMonitoringLocation() {
    LocationService.getLocationStream().listen((Position position) async {
      bool isNearDanger =
          await LocationService.isNearDangerousLocation(position);
      setState(() {
        safetyStatus = isNearDanger ? "Dangerous Location Nearby!" : "Safe";
      });
    });
  }

  Future<void> yoloOnFrame(CameraImage cameraImage) async {
    try {
      final startTime = DateTime.now();

      final result = await vision.yoloOnFrame(
        bytesList: cameraImage.planes.map((plane) => plane.bytes).toList(),
        imageHeight: cameraImage.height,
        imageWidth: cameraImage.width,
        confThreshold: 0.5,
        iouThreshold: 0.4,
        classThreshold: 0.5,
      );
      final endTime = DateTime.now();
      detectionTime = endTime.difference(startTime).inMilliseconds.toDouble();
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
      debugInfo =
          'Eyes were closed for: ${closedDuration.inMilliseconds / 1000} s';
      eyesClosedStartTime = null;
      isWarning = false;
    } else if (eyesClosedStartTime != null) {
      final currentClosedDuration =
          DateTime.now().difference(eyesClosedStartTime!);
      debugInfo =
          'Eyes closed for: ${currentClosedDuration.inMilliseconds / 1000} s';

      if (currentClosedDuration.inMilliseconds >= 1200 && !isWarning) {
        _logWarning(currentClosedDuration);
        isWarning = true;
        _playAlertSound();
      }
    }
  }

  void _logWarning(Duration closedDuration) {
    final warningMessage =
        'WARNING: Eyes closed for ${closedDuration.inMilliseconds / 1000} s';
    print(warningMessage);
    _logWindowKey.currentState?.addLog(warningMessage);
  }

  // Toggle the visibility of eye-closed status, FPS, and detection time
  void _toggleInfoVisibility() {
    setState(() {
      showInfo = !showInfo;
    });
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
            ...displayBoxesAroundRecognizedObjects(MediaQuery.of(context).size),
            // Safety messages on top of the screen
            Positioned(
              top: 40,
              left: 20,
              child: Text(
                safetyStatus,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: safetyStatus == "Safe"
                      ? Colors.green
                      : Colors.red, // Green for Safe, Red for Danger
                ),
              ),
            ),

            // Eye-closed status, FPS, and detection time (can be toggled)
            if (showInfo)
              Positioned(
                top: 82.5,
                left: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debugInfo,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                    ),
                    Text(
                      'FPS: ${fps.toStringAsFixed(1)}',
                      style: const TextStyle(
                          color: Color.fromARGB(255, 203, 188, 20),
                          fontSize: 16),
                    ),
                    Text(
                      'Detection Time: ${detectionTime.toStringAsFixed(0)} ms',
                      style: const TextStyle(
                          color: Color.fromARGB(255, 25, 118, 195),
                          fontSize: 16),
                    ),
                  ],
                ),
              ),
            if (!showInfo)
              Positioned(
                top: 82.5,
                left: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debugInfo,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  ],
                ),
              ),
            // Drowsiness warning message
            if (isWarning)
              const Center(
                child: Text(
                  'WAKE UP!!!',
                  style: TextStyle(
                      color: Colors.red,
                      fontSize: 38,
                      fontWeight: FontWeight.bold),
                ),
              ),

            // Log window on top of all other elements
            AnimatedBuilder(
              animation: _slideController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                      MediaQuery.of(context).size.width *
                          (1 - _slideController.value),
                      0),
                  child: Opacity(
                    opacity: _slideController.value,
                    child: child,
                  ),
                );
              },
              child: LogWindow(
                key: _logWindowKey,
                onApiKeySubmitted: (apiKey) {
                  print('API Key submitted: $apiKey');
                },
              ),
            ),

            // Controls for starting detection, flipping camera, and toggling info visibility
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
                      isDetecting
                          ? Icons.remove_red_eye_outlined
                          : Icons.visibility_off,
                      color: isDetecting ? Colors.red : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 20),
                  FloatingActionButton(
                    onPressed: flipCamera,
                    child: const Icon(Icons.flip_camera_ios),
                  ),
                  const SizedBox(width: 20),
                  // Button to toggle the visibility of info
                  FloatingActionButton(
                    onPressed: _toggleInfoVisibility,
                    child: Icon(
                      showInfo ? Icons.notes_outlined : Icons.remove_outlined,
                    ),
                  ),
                ],
              ),
            ),
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

    return yoloResults.map((result) {
      List<dynamic>? box = result["box"] as List<dynamic>?;
      if (box == null || box.length < 5) return Container();

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

      return Stack(
        children: [
          // Box remains in its original position
          Positioned(
            left: left,
            top: top,
            width: right - left,
            height: bottom - top,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(10.0)),
                border: Border.all(color: Colors.indigoAccent, width: 2.0),
              ),
            ),
          ),
          // Text appears above the box, positioned independently
          Positioned(
            left: left,
            top: top - 20, // Position text above the box
            child: Text(
              "${result['tag'] ?? 'Unknown'} ${(confidence * 100).toStringAsFixed(1)}%",
              style: const TextStyle(
                color: Colors.black,
                backgroundColor: Color.fromARGB(255, 166, 166, 166),
                fontSize: 14.0,
              ),
            ),
          ),
        ],
      );
    }).toList();
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

  void flipCamera() {
    final nextCameraIndex = (currentCameraIndex + 1) % widget.cameras.length;
    switchCamera(nextCameraIndex);
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

  Future<void> _playAlertSound() async {
    await _audioPlayer.resume();
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
  void dispose() {
    controller.dispose();
    vision.closeYoloModel();
    _slideController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}
