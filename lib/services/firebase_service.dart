import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Method to check if the user's current location is near a dangerous location
  static Future<bool> isNearDangerousLocation(GeoPoint currentLocation) async {
    try {
      // Get all dangerous locations from Firestore
      QuerySnapshot snapshot =
          await _firestore.collection('DangerousLocations').get();

      // Loop through each document and check the distance
      for (var doc in snapshot.docs) {
        GeoPoint dangerousLocation = doc['location'] as GeoPoint;

        // You can set a radius to define "near" (e.g., 0.001 degree ≈ 100 meters)
        const double dangerRadius = 0.001;

        // Calculate the difference in latitudes and longitudes
        double latDiff =
            (currentLocation.latitude - dangerousLocation.latitude).abs();
        double lonDiff =
            (currentLocation.longitude - dangerousLocation.longitude).abs();

        // Check if the current location is within the danger radius
        if (latDiff <= dangerRadius && lonDiff <= dangerRadius) {
          return true; // Dangerous location found
        }
      }

      // No dangerous location found nearby
      return false;
    } catch (e) {
      print('Error checking dangerous locations: $e');
      return false;
    }
  }
}
