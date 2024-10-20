import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> logWarning(
      String userId, double duration, GeoPoint location) async {
    await _firestore.collection('warnLogs').add({
      'userId': userId,
      'timestamp': FieldValue.serverTimestamp(),
      'duration': duration,
      'location': location,
    });
  }

  static Future<List<GeoPoint>> getDangerousLocations() async {
    final dangerousLocations =
        await _firestore.collection('dangerousLocations').get();
    return dangerousLocations.docs
        .map((doc) => doc['location'] as GeoPoint)
        .toList();
  }

  static Future<bool> isNearDangerousLocation(GeoPoint currentLocation) async {
    final dangerousLocations = await getDangerousLocations();
    for (var location in dangerousLocations) {
      double distance = Geolocator.distanceBetween(currentLocation.latitude,
          currentLocation.longitude, location.latitude, location.longitude);
      if (distance < 100) {
        // Within 100 meters
        return true;
      }
    }
    return false;
  }
}
