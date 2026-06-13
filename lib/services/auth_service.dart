// lib/services/auth_service.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService extends ChangeNotifier {
  final firebase.FirebaseAuth _firebaseAuth = firebase.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
      clientId:
          '14579148353-dlbujv5h8tp1ueuh4ef0gs6adro82kva.apps.googleusercontent.com');
  final SupabaseClient _supabase = Supabase.instance.client;

  firebase.User? _currentUser;
  String? _userRole;
  bool _isLoading = false;
  String? _error;

  firebase.User? get currentUser => _currentUser;
  String? get userRole => _userRole;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Initialize auth - runs on app startup
  Future<void> initializeAuth() async {
    try {
      _isLoading = true;
      _error = null;
      //notifyListeners();

      // Check if user is already logged in
      _currentUser = _firebaseAuth.currentUser;

      if (_currentUser != null) {
        // Try to restore Google session silently
        final googleUser = await _googleSignIn.signInSilently();
        if (googleUser != null) {
          await _fetchUserRole(_currentUser!.uid);
        } else {
          // No Google session, sign out
          await logout();
        }
      }
    } catch (e) {
      _error = 'Failed to initialize auth: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      //notifyListeners();
    }
  }

  // Google Sign In
  Future<void> signInWithGoogle() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _error = 'Google sign-in cancelled';
        notifyListeners();
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = firebase.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );
      _currentUser = userCredential.user;

      // Check if user exists in Supabase, if not create as Director (first user)
      await _setupUserInDatabase(_currentUser!);
      await _fetchUserRole(_currentUser!.uid);
    } on firebase.FirebaseAuthException catch (e) {
      _error = 'Firebase Auth Error: ${e.message}';
      debugPrint(_error);
    } catch (e, stack) {
      _error = 'Sign-in failed: $e';
      debugPrint(_error);
      debugPrintStack(stackTrace: stack);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Setup user in Supabase database
  Future<void> _setupUserInDatabase(firebase.User firebaseUser) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', firebaseUser.uid)
          .single();

      // User already exists, no action needed
      return;
    } catch (e) {
      // User doesn't exist, create one
      // Check if this is the first user (becomes Director)
      final users = await _supabase.from('users').select('id');

      final role = (users as List).isEmpty ? 'Director' : 'Manager';

      await _supabase.from('users').insert({
        'id': firebaseUser.uid,
        'email': firebaseUser.email,
        'display_name': firebaseUser.displayName ?? 'User',
        'role': role,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  // Fetch user role from Supabase
  Future<void> _fetchUserRole(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select('role')
          .eq('id', userId)
          .single();

      _userRole = response['role'];
    } catch (e) {
      debugPrint('Error fetching user role: $e');
      _error = 'Failed to fetch user role';
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();
      _currentUser = null;
      _userRole = null;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Logout failed: $e';
      debugPrint(_error);
    }
  }

  // Change user role (Director/Co-Director only)
  Future<void> changeUserRole(String userId, String newRole) async {
    try {
      if (!['Director', 'Co-Director', 'Manager'].contains(newRole)) {
        throw Exception('Invalid role: $newRole');
      }

      // Permission check: Co-Director cannot change Director's role
      if (_userRole == 'Co-Director') {
        final targetUserRole = await _supabase
            .from('users')
            .select('role')
            .eq('id', userId)
            .single();

        if (targetUserRole['role'] == 'Director') {
          throw Exception('Co-Directors cannot change Director roles');
        }
      }

      await _supabase.from('users').update({'role': newRole}).eq('id', userId);

      // Log audit trail
      await _logAudit('users', userId, 'UPDATE', {'role': newRole});
    } catch (e) {
      _error = 'Failed to change user role: $e';
      debugPrint(_error);
      rethrow;
    }
  }

  // Log audit trail
  Future<void> _logAudit(
    String tableName,
    String recordId,
    String action,
    Map<String, dynamic> data,
  ) async {
    try {
      await _supabase.from('audit_log').insert({
        'table_name': tableName,
        'record_id': recordId,
        'action': action,
        'new_data': data,
        'performed_by': _currentUser!.uid,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Audit log failed: $e');
    }
  }

  // Check if user has permission
  bool hasPermission(String requiredRole) {
    if (_userRole == 'Director') return true;
    if (_userRole == 'Co-Director' && requiredRole != 'Director') return true;
    if (_userRole == 'Manager' && requiredRole == 'Manager') return true;
    return false;
  }
}
