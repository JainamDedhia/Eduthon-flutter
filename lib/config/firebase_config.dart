import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseConfig {
  static FirebaseOptions get firebaseOptions => const FirebaseOptions(
    apiKey: "AIzaSyAkRR3hEW9ZG---AF2sTBZHfoXiAFtAMjo",
    authDomain: "medical-9530c.firebaseapp.com",
    projectId: "medical-9530c",
    storageBucket: "medical-9530c.firebasestorage.app",
    messagingSenderId: "829045368261",
    appId: "1:829045368261:android:3a1418d1599554a41997ac",
  );

  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: firebaseOptions,
    );
    
    // Enable offline persistence for Firestore
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    
    print('✅ Firebase initialized with persistence enabled');
  }

  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;
}