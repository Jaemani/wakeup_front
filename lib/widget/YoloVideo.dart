import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'dart:math' as math;

class YoloVideo extends StatefulWidget {
  final List<CameraDescription> cameras;

  const YoloVideo({super.key, required this.cameras});

  @override
  _YoloVideoState createState() => _YoloVideoState();
}

class _YoloVideoState extends State<YoloVideo> {
  late CameraController controller;
  late FlutterVision vision;
  List<Map<String, dynamic>> yoloResults = [];
  CameraImage? cameraImage;
  bool isLoaded = false;
  bool isDetecting = false;
  int currentCameraIndex = 0;
  double confidenceThreshold = 0.5;

  @override
  void initState() {
    super.initState();
    init();
  }

  init() async {
    vision = FlutterVision();
    controller = CameraController(widget.cameras[0], ResolutionPreset.high);
    await controller.initialize();
    await loadYoloModel();
    await switchCamera(0);
    setState(() {
      isLoaded = true;
      isDetecting = false;
      yoloResults = [];
    });
  }

  Future loadYoloModel() async {
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
  }

  Future yoloOnFrame(CameraImage cameraImage) async {
    final result = await vision.yoloOnFrame(
      bytesList: cameraImage.planes.map((plane) => plane.bytes).toList(),
      imageHeight: cameraImage.height,
      imageWidth: cameraImage.width,
      iouThreshold: 0.4,
      confThreshold: confidenceThreshold,
      classThreshold: 0.5,
    );
    if (result.isNotEmpty) {
      setState(() {
        yoloResults = result;
      });
    }
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
    final Size size = MediaQuery.of(context).size;
    final deviceRatio = size.width / size.height;

    if (!isLoaded) {
      return const Scaffold(
        body: Center(
          child: Text("Model not loaded, waiting for it"),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          buildCameraPreview(deviceRatio),
          ...displayBoxesAroundRecognizedObjects(MediaQuery.of(context).size),
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
      ),
    );
  }

  List displayBoxesAroundRecognizedObjects(Size screen) {
    if (yoloResults.isEmpty) return [];

    double scaleX = screen.width / (cameraImage?.height ?? 1);
    double scaleY = screen.height / (cameraImage?.width ?? 1);
    final bool isFrontCamera =
        widget.cameras[currentCameraIndex].lensDirection ==
            CameraLensDirection.front;

    Color colorPick = const Color.fromARGB(255, 50, 233, 30);

    return yoloResults.map((result) {
      double left = result["box"][0] * scaleX;
      final double top = result["box"][1] * scaleY;
      double right = result["box"][2] * scaleX;
      final double bottom = result["box"][3] * scaleY;

      if (isFrontCamera) {
        // For front camera, flip horizontally
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
            "${result['tag']} ${(result['box'][4] * 100).toStringAsFixed(1)}%",
            style: TextStyle(
              background: Paint()..color = colorPick,
              color: const Color.fromARGB(255, 115, 0, 255),
              fontSize: 18.0,
            ),
          ),
        ),
      );
    }).toList();
  }

  Future startDetection() async {
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

  Future stopDetection() async {
    setState(() {
      isDetecting = false;
      yoloResults.clear();
    });
  }

  Future<void> switchCamera(int cameraIndex) async {
    await controller.dispose();
    controller = CameraController(
      widget.cameras[cameraIndex],
      ResolutionPreset.high,
    );
    await controller.initialize();
    setState(() {
      currentCameraIndex = cameraIndex;
      yoloResults.clear(); // Clear results when switching camera
    });
  }

  void flipCamera() {
    final nextCameraIndex = (currentCameraIndex + 1) % widget.cameras.length;
    switchCamera(nextCameraIndex);
  }

  @override
  void dispose() {
    controller.dispose();
    vision.closeYoloModel();
    super.dispose();
  }
}
