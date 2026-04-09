import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
