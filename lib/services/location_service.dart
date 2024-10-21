import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire2/geoflutterfire2.dart';

class LocationService {
  static const double _dangerousLocationRadius = 150; // meters
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final GeoFlutterFire _geo = GeoFlutterFire();

  // Get current location of the user
  static Future<Position> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied.');
    }

    return await Geolocator.getCurrentPosition();
  }

  // Monitor real-time location of user and check if near a dangerous location
  static Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50, // Trigger every 50 meters
      ),
    );
  }

  // Check if user is near any dangerous location stored in Firebase
  static Future<bool> isNearDangerousLocation(Position position) async {
    GeoFirePoint center =
        _geo.point(latitude: position.latitude, longitude: position.longitude);

    // Get dangerous locations from Firebase
    final QuerySnapshot snapshot =
        await _firestore.collection('DangerousLocations').get();

    for (var doc in snapshot.docs) {
      GeoPoint geoPoint = doc['WGS84'];
      GeoFirePoint dangerousPoint = _geo.point(
          latitude: geoPoint.latitude, longitude: geoPoint.longitude);

      double distance = center.distance(
          lat: dangerousPoint.latitude, lng: dangerousPoint.longitude);
      if (distance <= _dangerousLocationRadius) {
        return true; // User is near a dangerous location
      }
    }
    return false; // No dangerous location nearby
  }
}
