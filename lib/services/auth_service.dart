// services/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Register new user
  Future<User?> registerUser(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = userCredential.user;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'email': email,
          'qrCode': generateUniqueQrCode(user.uid),
          'points': 150,
          'createdAt': FieldValue.serverTimestamp(),
          'totalRecycled': 0,
          'recyclingHistory': [],
        });
      }
      return user;
    } catch (e) {
      print("Error registering user: $e");
      return null;
    }
  }

  // Sign in existing user
  Future<User?> signInUser(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      print("Error signing in user: $e");
      return null;
    }
  }

  // Get current authenticated user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Sign out user
  Future<void> signOutUser() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print("Error signing out user: $e");
    }
  }

  // Generate unique QR code for user
  String generateUniqueQrCode(String userId) {
    return 'uco_user_$userId';
  }

  // Get user document from Firestore
  Future<DocumentSnapshot?> getUserData(String uid) async {
    try {
      return await _firestore.collection('users').doc(uid).get();
    } catch (e) {
      print("Error getting user data: $e");
      return null;
    }
  }

  // Helper method to get user data as Map
  Future<Map<String, dynamic>?> getUserDataAsMap(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print("Error getting user data as map: $e");
      return null;
    }
  }

  // Update user points
  Future<bool> updateUserPoints(String uid, int points) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'points': FieldValue.increment(points),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print("Error updating user points: $e");
      return false;
    }
  }

  // Deduct points for rewards
  Future<bool> deductUserPoints(String uid, int points) async {
    try {
      // First check if user has enough points
      final userData = await getUserDataAsMap(uid);
      if (userData != null) {
        final currentPoints = userData['points'] ?? 0;
        if (currentPoints >= points) {
          await _firestore.collection('users').doc(uid).update({
            'points': FieldValue.increment(-points),
            'lastUpdated': FieldValue.serverTimestamp(),
          });
          return true;
        }
      }
      return false;
    } catch (e) {
      print("Error deducting user points: $e");
      return false;
    }
  }

  // Add recycling activity to history
  Future<bool> addRecyclingActivity(String uid, Map<String, dynamic> activity) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'recyclingHistory': FieldValue.arrayUnion([activity]),
        'totalRecycled': FieldValue.increment(activity['amount'] ?? 0),
        'lastRecycling': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print("Error adding recycling activity: $e");
      return false;
    }
  }

  // Get user's recycling history
  Future<List<Map<String, dynamic>>> getRecyclingHistory(String uid) async {
    try {
      final userData = await getUserDataAsMap(uid);
      if (userData != null) {
        final history = userData['recyclingHistory'] as List<dynamic>?;
        return history?.cast<Map<String, dynamic>>() ?? [];
      }
      return [];
    } catch (e) {
      print("Error getting recycling history: $e");
      return [];
    }
  }

  // Add reward redemption to history
  Future<bool> addRewardRedemption(String uid, Map<String, dynamic> reward) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'rewardHistory': FieldValue.arrayUnion([reward]),
        'lastRedemption': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print("Error adding reward redemption: $e");
      return false;
    }
  }

  // Get user's reward redemption history
  Future<List<Map<String, dynamic>>> getRewardHistory(String uid) async {
    try {
      final userData = await getUserDataAsMap(uid);
      if (userData != null) {
        final history = userData['rewardHistory'] as List<dynamic>?;
        return history?.cast<Map<String, dynamic>>() ?? [];
      }
      return [];
    } catch (e) {
      print("Error getting reward history: $e");
      return [];
    }
  }

  // Update user profile information
  Future<bool> updateUserProfile(String uid, Map<String, dynamic> updates) async {
    try {
      updates['lastUpdated'] = FieldValue.serverTimestamp();
      await _firestore.collection('users').doc(uid).update(updates);
      return true;
    } catch (e) {
      print("Error updating user profile: $e");
      return false;
    }
  }

  // Check if user exists in Firestore
  Future<bool> userExists(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.exists;
    } catch (e) {
      print("Error checking if user exists: $e");
      return false;
    }
  }

  // Get user stats
  Future<Map<String, dynamic>?> getUserStats(String uid) async {
    try {
      final userData = await getUserDataAsMap(uid);
      if (userData != null) {
        return {
          'totalPoints': userData['points'] ?? 0,
          'totalRecycled': userData['totalRecycled'] ?? 0,
          'recyclingCount': (userData['recyclingHistory'] as List?)?.length ?? 0,
          'rewardCount': (userData['rewardHistory'] as List?)?.length ?? 0,
          'memberSince': userData['createdAt'],
          'lastActivity': userData['lastUpdated'],
        };
      }
      return null;
    } catch (e) {
      print("Error getting user stats: $e");
      return null;
    }
  }

  // Stream for real-time user data updates
  Stream<DocumentSnapshot> getUserDataStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  // Delete user account and data
  Future<bool> deleteUserAccount(String uid) async {
    try {
      // Delete user data from Firestore
      await _firestore.collection('users').doc(uid).delete();
      
      // Delete authentication account
      final user = _auth.currentUser;
      if (user != null && user.uid == uid) {
        await user.delete();
      }
      
      return true;
    } catch (e) {
      print("Error deleting user account: $e");
      return false;
    }
  }

  // Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      print("Error sending password reset email: $e");
      return false;
    }
  }

  // Change user password
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user != null && user.email != null) {
        // Re-authenticate user
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        );
        await user.reauthenticateWithCredential(credential);
        
        // Update password
        await user.updatePassword(newPassword);
        return true;
      }
      return false;
    } catch (e) {
      print("Error changing password: $e");
      return false;
    }
  }

  // Get authentication error message
  String getAuthErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}