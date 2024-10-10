import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({Key? key, required this.cameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Camera App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: CameraScreen(cameras: cameras),
    );
  }
}

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isFrontCamera = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _gpsTimer;

  @override
  void initState() {
    super.initState();
    _initializeCamera(widget.cameras[0]);
    _startGPSLogging();
  }

  void _initializeCamera(CameraDescription camera) {
    _controller = CameraController(camera, ResolutionPreset.medium);
    _initializeControllerFuture = _controller.initialize();
  }

  Future<void> _toggleCamera() async {
    final cameras = widget.cameras;
    final newIndex = _isFrontCamera ? 0 : 1;
    _isFrontCamera = !_isFrontCamera;
    await _controller.dispose();
    _initializeCamera(cameras[newIndex]);
    setState(() {});
  }

  void _playSound() async {
    // Replace 'sound.mp3' with your actual sound file path
    await _audioPlayer.play(AssetSource('notification.mp3'));
  }

  void _startGPSLogging() {
    _gpsTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        print(
            "${DateTime.now()}: Lat: ${position.latitude}, Lon: ${position.longitude}");
      } catch (e) {
        print("Error getting location: $e");
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioPlayer.dispose();
    _gpsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Camera App')),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Column(
              children: [
                Expanded(child: CameraPreview(_controller)),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: Icon(_isFrontCamera
                            ? Icons.camera_rear
                            : Icons.camera_front),
                        onPressed: _toggleCamera,
                      ),
                      IconButton(
                        icon: const Icon(Icons.volume_up),
                        onPressed: _playSound,
                      ),
                    ],
                  ),
                ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
