import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Register with email and password
  Future<UserCredential?> registerWithEmailAndPassword({
    required String email,
    required String password,
    required Map<String, dynamic> userInfo
  }) async {
    try {
      // Create the user in Firebase Auth
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Store additional user info in Firestore
      if (userCredential.user != null) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          ...userInfo,
          'uid': userCredential.user!.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Registration failed: ${e.toString()}');
    }
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      return doc.exists ? doc.data() as Map<String, dynamic> : null;
    } catch (e) {
      print('Error getting user data: ${e.toString()}');
      return null;
    }
  }

  // Update user data
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update user data: ${e.toString()}');
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(
        email: email,
        actionCodeSettings: ActionCodeSettings(
          url: 'https://beyondborders.page.link/reset-password',
          handleCodeInApp: true,
          androidPackageName: 'com.example.beyond_borders',
          androidInstallApp: true,
          androidMinimumVersion: '1',
          dynamicLinkDomain: 'beyondborders.page.link',
        ),
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Password reset email failed: ${e.toString()}');
    }
  }

  // Verify password reset code
  Future<bool> verifyPasswordResetCode(String code) async {
    try {
      await _auth.verifyPasswordResetCode(code);
      return true;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Failed to verify reset code: ${e.toString()}');
    }
  }

  // Confirm password reset with new password
  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword
  }) async {
    try {
      await _auth.confirmPasswordReset(
        code: code,
        newPassword: newPassword,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Password reset failed: ${e.toString()}');
    }
  }

  // Enhanced check email method with extra validation layers
  Future<bool> checkEmailExists(String email) async {
    // Normalize email to handle case-insensitivity
    final normalizedEmail = email.trim().toLowerCase();
    print('Checking if email exists: $normalizedEmail');

    // 1. Try Firestore first (Avoids billing error for fetchSignInMethodsForEmail)
    try {
      final firestoreUsers = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();

      if (firestoreUsers.docs.isNotEmpty) {
        print('User found in Firestore database');
        return true;
      }
    } catch (e) {
      print('Firestore check error: $e');
      // Continue to other methods if this fails
    }

    // 2. Try fetchSignInMethodsForEmail (Might fail without billing)
    try {
      final methods = await _auth.fetchSignInMethodsForEmail(normalizedEmail);
      print('Sign-in methods found: ${methods.join(', ')}');

      if (methods.isNotEmpty) {
        return true;
      }
    } catch (e) {
      // Just log this error as it's likely the permission denied/billing error
      // and we want to avoid crashing the app because of it
      print('fetchSignInMethodsForEmail failed (billing might be required): $e');
    }

    // If all checks fail, assume email doesn't exist
    return false;
  }

// Add a debug method to try to reset password directly
  Future<bool> attemptDirectPasswordReset(String email) async {
    try {
      // Try to send a reset email directly without checking first
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
      print('Password reset email sent successfully');
      return true;
    } catch (e) {
      print('Error sending password reset: $e');
      return false;
    }
  }

  // Reset password (original method)
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Password reset failed: ${e.toString()}');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Sign out failed: ${e.toString()}');
    }
  }

  // Handle Firebase Auth Exceptions with user-friendly messages
  Exception _handleAuthException(FirebaseAuthException e) {
    String message;

    switch (e.code) {
      case 'email-already-in-use':
        message = 'This email is already registered. Please use a different email.';
        break;
      case 'invalid-email':
        message = 'The email address is not valid.';
        break;
      case 'weak-password':
        message = 'The password provided is too weak.';
        break;
      case 'user-disabled':
        message = 'This account has been disabled.';
        break;
      case 'user-not-found':
        message = 'No user found with this email.';
        break;
      case 'wrong-password':
        message = 'The password is incorrect.';
        break;
      case 'expired-action-code':
        message = 'The password reset link has expired.';
        break;
      case 'invalid-action-code':
        message = 'The password reset link is invalid.';
        break;
      case 'too-many-requests':
        message = 'Too many unsuccessful login attempts. Please try again later.';
        break;
      default:
        message = 'An error occurred: ${e.message}';
    }

    return Exception(message);
  }
}