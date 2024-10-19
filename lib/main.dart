import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'widget/YoloVideo.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:audioplayers/audioplayers.dart';

// final callable = FirebaseFunctions.instance.httpsCallable('hashApiKey');
// final result = await callable.call({'apiKey': userApiKey});
// final hashedKey = result.data['hashedKey'];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  // await Firebase.initializeApp(
  //     // options: DefaultFirebaseOptions.currentPlatform,
  //     demoProjectId: "wakeup-74d89");
  runApp(MaterialApp(
    title: "wakeup",
    home: YoloVideo(cameras: cameras),
  ));
}
