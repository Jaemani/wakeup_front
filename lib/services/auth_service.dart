import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Method to ensure user is signed in (anonymous if necessary)
  Future<void> ensureLoggedIn() async {
    try {
      if (_auth.currentUser == null) {
        // Log in anonymously if not already logged in
        await _auth.signInAnonymously();
        print(
            "Anonymous sign-in successful, user UID: ${_auth.currentUser?.uid}");
      }
    } catch (e) {
      print("Error during sign-in: $e");
      rethrow;
    }
  }

  // Method to store API key in Firestore
  Future<void> storeApiKey(String apiKey) async {
    try {
      await ensureLoggedIn(); // Ensure user is logged in before storing the API key

      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Log for debugging
      print("Storing API Key for user: ${user.uid}");

      // Store the API key in Firestore under the Users collection
      await _firestore.collection('Users').doc(user.uid).set({
        'hashed_API': apiKey, // Replace this with hashed API if needed
      }, SetOptions(merge: true)); // Merge with existing data if any

      // Store the API key securely in local storage
      await _storage.write(key: 'api_key', value: apiKey);

      print("API key successfully stored in Firebase and local storage");
    } catch (e) {
      print("Error storing API key: $e");
    }
  }

  // Retrieve stored API key
  Future<String?> getStoredApiKey() async {
    return await _storage.read(key: 'api_key');
  }
}
