import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<Position?> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Consider handling this case in the UI
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Consider handling this case in the UI
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Consider handling this case in the UI
      return null;
    }

    return await Geolocator.getCurrentPosition();
  }
}
