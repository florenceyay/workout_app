import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'workout_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final WorkoutService _workoutService = WorkoutService();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<User?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final result = await _auth.signInWithCredential(credential);
    final user = result.user;
    if (user == null) return null;

    // Save profile if first login
    final profileRef = _db.collection('users').doc(user.uid).collection('profile').doc('data');
    final existing = await profileRef.get();
    if (!existing.exists) {
      await profileRef.set({
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'unitPreference': 'kg',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _workoutService.seedExercisesIfNeeded();
    }

    return user;
  }

  /// Generates a random nonce string for Apple sign-in.
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// SHA256 hash of a string (used for Apple nonce).
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<User?> signInWithApple() async {
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
    );

    final result = await _auth.signInWithCredential(oauthCredential);
    final user = result.user;
    if (user == null) return null;

    // Apple only sends the name on the FIRST sign-in, so save it now.
    final displayName = [
      appleCredential.givenName ?? '',
      appleCredential.familyName ?? '',
    ].where((s) => s.isNotEmpty).join(' ');

    final profileRef = _db.collection('users').doc(user.uid).collection('profile').doc('data');
    final existing = await profileRef.get();
    if (!existing.exists) {
      await profileRef.set({
        'name': displayName.isNotEmpty
            ? displayName
            : (user.email?.split('@').first ?? 'User'),
        'email': user.email ?? appleCredential.email ?? '',
        'unitPreference': 'kg',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _workoutService.seedExercisesIfNeeded();
    }

    return user;
  }

  Future<User?> registerWithEmail(String email, String password) async {
    final result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    final user = result.user;
    if (user == null) return null;
    final profileRef = _db.collection('users').doc(user.uid).collection('profile').doc('data');
    final existing = await profileRef.get();
    if (!existing.exists) {
      await profileRef.set({
        'name': email.split('@').first,
        'email': email,
        'unitPreference': 'kg',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _workoutService.seedExercisesIfNeeded();
    }
    return user;
  }

  Future<User?> signInWithEmail(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return result.user;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<String> getUnitPreference(String uid) async {
    final doc = await _db.collection('users').doc(uid).collection('profile').doc('data').get();
    return doc.data()?['unitPreference'] as String? ?? 'kg';
  }

  Future<void> setUnitPreference(String uid, String unit) async {
    await _db.collection('users').doc(uid).collection('profile').doc('data').update({'unitPreference': unit});
  }
}
