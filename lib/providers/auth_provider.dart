import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/firebase_config.dart';
import '../models/models.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  UserModel? _userModel;
  String? _userRole;
  bool _loading = true;

  User? get user => _user;
  UserModel? get userModel => _userModel;
  String? get userRole => _userRole;
  bool get loading => _loading;

  AuthProvider() {
    _initAuth();
  }

  void _initAuth() {
    FirebaseConfig.auth.authStateChanges().listen((User? firebaseUser) async {
      _user = firebaseUser;

      if (firebaseUser != null) {
        // Fetch user role from Firestore
        try {
          final userDoc = await FirebaseConfig.firestore
              .collection('users')
              .doc(firebaseUser.uid)
              .get();

          if (userDoc.exists) {
            _userModel = UserModel.fromFirestore(
              userDoc.data()!,
              firebaseUser.uid,
            );
            _userRole = _userModel?.role;
          }
        } catch (e) {
          print('Error fetching user data: $e');
        }
      } else {
        _userModel = null;
        _userRole = null;
      }

      _loading = false;
      notifyListeners();
    });
  }

  // Login
  Future<void> login(String email, String password) async {
    try {
      await FirebaseConfig.auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Register
  Future<void> register(String email, String password) async {
    try {
      await FirebaseConfig.auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Set user role
  Future<void> setUserRole(String role) async {
    try {
      final user = FirebaseConfig.auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      await FirebaseConfig.firestore.collection('users').doc(user.uid).set({
        'name': user.email?.split('@')[0] ?? 'User',
        'email': user.email,
        'role': role,
        'createdAt': DateTime.now().toIso8601String(),
      });

      _userRole = role;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await FirebaseConfig.auth.signOut();
    } catch (e) {
      rethrow;
    }
  }
}