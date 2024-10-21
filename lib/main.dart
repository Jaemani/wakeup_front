import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:wakeup/widget/yolo_video_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:wakeup/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MaterialApp(
    title: "WakeUp",
    home: YoloVideo(cameras: cameras),
  ));
}
