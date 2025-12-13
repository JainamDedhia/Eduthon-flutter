import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
          print('🔍 [AuthProvider] Fetching user data for: ${firebaseUser.uid}');
          
          // First check if we have cached role locally (for offline support)
          final cachedRole = await _getCachedUserRole(firebaseUser.uid);
          if (cachedRole != null) {
            print('✅ [AuthProvider] Using cached role: $cachedRole');
            _userRole = cachedRole;
            _userModel = UserModel(
              uid: firebaseUser.uid,
              email: firebaseUser.email ?? '',
              name: firebaseUser.email?.split('@')[0] ?? 'User',
              role: cachedRole,
              createdAt: DateTime.now().toIso8601String(),
            );
            _loading = false;
            notifyListeners();
          }
          
          // Try to fetch from Firestore (will work if online)
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
            
            // Cache the role locally for offline use
            await _cacheUserRole(firebaseUser.uid, _userRole!);
            print('✅ [AuthProvider] User role loaded from Firestore: $_userRole');
          } else {
            print('⚠️ [AuthProvider] User document does not exist in Firestore');
            // Keep cached role if Firestore fetch fails
            if (cachedRole == null) {
              _userModel = null;
              _userRole = null;
            }
          }
        } catch (e) {
          print('❌ [AuthProvider] Error fetching user data (may be offline): $e');
          // Keep using cached role if Firestore is unavailable (offline)
          final cachedRole = await _getCachedUserRole(firebaseUser.uid);
          if (cachedRole != null) {
            print('✅ [AuthProvider] Using cached role due to network error: $cachedRole');
            _userRole = cachedRole;
            _userModel = UserModel(
              uid: firebaseUser.uid,
              email: firebaseUser.email ?? '',
              name: firebaseUser.email?.split('@')[0] ?? 'User',
              role: cachedRole,
              createdAt: DateTime.now().toIso8601String(),
            );
          } else {
            _userModel = null;
            _userRole = null;
          }
        }
      } else {
        print('ℹ️ [AuthProvider] User logged out');
        _userModel = null;
        _userRole = null;
      }

      _loading = false;
      notifyListeners();
    });
  }

  // Cache user role locally using SharedPreferences
  Future<void> _cacheUserRole(String uid, String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role_$uid', role);
      print('💾 [AuthProvider] Cached role: $role for user: $uid');
    } catch (e) {
      print('⚠️ [AuthProvider] Failed to cache role: $e');
    }
  }

  // Get cached user role
  Future<String?> _getCachedUserRole(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('user_role_$uid');
      return role;
    } catch (e) {
      print('⚠️ [AuthProvider] Failed to get cached role: $e');
      return null;
    }
  }

  // Login - FIXED: Wait for role to be fetched
  Future<void> login(String email, String password) async {
    try {
      print('🔐 [AuthProvider] Attempting login for: $email');
      
      await FirebaseConfig.auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // CRITICAL FIX: Wait for the role to be fetched from Firestore
      print('⏳ [AuthProvider] Waiting for user role to be fetched...');
      
      // Wait until role is loaded (max 5 seconds)
      int attempts = 0;
      while (_userRole == null && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }

      if (_userRole != null) {
        print('✅ [AuthProvider] Login successful! Role: $_userRole');
      } else {
        print('⚠️ [AuthProvider] Login successful but role not found in Firestore');
      }
    } catch (e) {
      print('❌ [AuthProvider] Login failed: $e');
      rethrow;
    }
  }

  // Register
  Future<void> register(String email, String password) async {
    try {
      print('📝 [AuthProvider] Attempting registration for: $email');
      
      await FirebaseConfig.auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      print('✅ [AuthProvider] Registration successful');
    } catch (e) {
      print('❌ [AuthProvider] Registration failed: $e');
      rethrow;
    }
  }

  // Set user role
  Future<void> setUserRole(String role) async {
    try {
      final user = FirebaseConfig.auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      print('💾 [AuthProvider] Setting user role to: $role');

      await FirebaseConfig.firestore.collection('users').doc(user.uid).set({
        'name': user.email?.split('@')[0] ?? 'User',
        'email': user.email,
        'role': role,
        'createdAt': DateTime.now().toIso8601String(),
      });

      _userRole = role;
      
      // Update userModel as well
      _userModel = UserModel(
        uid: user.uid,
        email: user.email ?? '',
        name: user.email?.split('@')[0] ?? 'User',
        role: role,
        createdAt: DateTime.now().toIso8601String(),
      );
      
      notifyListeners();
      
      print('✅ [AuthProvider] User role set successfully: $role');
    } catch (e) {
      print('❌ [AuthProvider] Error setting user role: $e');
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      print('👋 [AuthProvider] Logging out...');
      await FirebaseConfig.auth.signOut();
      print('✅ [AuthProvider] Logout successful');
    } catch (e) {
      print('❌ [AuthProvider] Logout failed: $e');
      rethrow;
    }
  }

  // Refresh user data manually
  Future<void> refreshUserData() async {
    final user = FirebaseConfig.auth.currentUser;
    if (user == null) return;

    try {
      print('🔄 [AuthProvider] Refreshing user data...');
      
      final userDoc = await FirebaseConfig.firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        _userModel = UserModel.fromFirestore(
          userDoc.data()!,
          user.uid,
        );
        _userRole = _userModel?.role;
        notifyListeners();
        print('✅ [AuthProvider] User data refreshed. Role: $_userRole');
      }
    } catch (e) {
      print('❌ [AuthProvider] Error refreshing user data: $e');
    }
  }
}