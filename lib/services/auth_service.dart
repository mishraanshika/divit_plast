// lib/services/auth_service.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'company_service.dart';

class AuthService extends ChangeNotifier {
  AuthService({CompanyService? companyService})
      : _companyService = companyService ?? CompanyService.instance;

  final CompanyService _companyService;
  final firebase.FirebaseAuth _firebaseAuth = firebase.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static const String _googleServerClientId =
      '14579148353-dlbujv5h8tp1ueuh4ef0gs6adro82kva.apps.googleusercontent.com';

  firebase.User? _currentUser;
  String? _userRole;
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _googleInitialized = false;
  String? _error;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _googleAuthSubscription;
  RealtimeChannel? _userRoleChannel;

  firebase.User? get currentUser => _currentUser;
  String? get userRole => _userRole;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  List<CompanyConfig> get companies => _companyService.companies;
  CompanyConfig? get selectedCompany => _companyService.selectedCompany;
  bool get needsCompanySelection => _companyService.needsCompanySelection;
  SupabaseClient get _supabase => _companyService.client;

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;

    if (kIsWeb) {
      _googleInitialized = true;
      return;
    }

    await _googleSignIn.initialize(serverClientId: _googleServerClientId);
    _googleAuthSubscription = _googleSignIn.authenticationEvents.listen(
      (event) => unawaited(_handleGoogleAuthenticationEvent(event)),
      onError: _handleGoogleAuthenticationError,
    );
    _googleInitialized = true;

    _googleSignIn.attemptLightweightAuthentication();
  }

  Future<void> _handleGoogleAuthenticationEvent(
    GoogleSignInAuthenticationEvent event,
  ) async {
    if (event is GoogleSignInAuthenticationEventSignIn) {
      try {
        _isLoading = true;
        _error = null;
        notifyListeners();

        await _signInToFirebase(event.user);
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
    } else if (event is GoogleSignInAuthenticationEventSignOut) {
      _currentUser = null;
      _userRole = null;
      notifyListeners();
    }
  }

  void _handleGoogleAuthenticationError(Object error, StackTrace stackTrace) {
    if (error is GoogleSignInException &&
        (error.code == GoogleSignInExceptionCode.canceled ||
            error.code == GoogleSignInExceptionCode.interrupted ||
            error.code == GoogleSignInExceptionCode.uiUnavailable)) {
      return;
    }

    _error = 'Google Sign-In Error: $error';
    _isLoading = false;
    debugPrint(_error);
    debugPrintStack(stackTrace: stackTrace);
    notifyListeners();
  }

  // Initialize auth - runs on app startup
  Future<void> initializeAuth() async {
    if (_isInitialized) return;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      await _ensureGoogleInitialized();

      _currentUser = _firebaseAuth.currentUser;

      if (_currentUser != null) {
        await _setupCurrentCompanyUserIfReady();
      }
    } catch (e) {
      _error = 'Failed to initialize auth: $e';
      debugPrint(_error);
    } finally {
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  // Google Sign In
  Future<void> signInWithGoogle() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      await _ensureGoogleInitialized();

      if (kIsWeb) {
        final provider = firebase.GoogleAuthProvider()
          ..setCustomParameters({'prompt': 'select_account'});
        final userCredential = await _firebaseAuth.signInWithPopup(provider);
        await _completeFirebaseSignIn(userCredential);
        return;
      }

      if (!_googleSignIn.supportsAuthenticate()) {
        throw Exception('Google sign-in is not available on this platform');
      }

      final googleUser = await _googleSignIn.authenticate();
      await _signInToFirebase(googleUser);
    } on GoogleSignInException catch (e) {
      final description = e.description ?? e.code.name;
      _error = e.code == GoogleSignInExceptionCode.canceled
          ? 'Google sign-in could not complete. If you selected an account and returned here, check the Android OAuth SHA fingerprints in Firebase.'
          : 'Google Sign-In Error: $description';
      debugPrint(_error);
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

  Future<void> _signInToFirebase(GoogleSignInAccount googleUser) async {
    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;

    if (idToken == null) {
      throw Exception('Google did not return an ID token');
    }

    final credential = firebase.GoogleAuthProvider.credential(
      idToken: idToken,
    );

    final userCredential = await _firebaseAuth.signInWithCredential(
      credential,
    );
    await _completeFirebaseSignIn(userCredential);
  }

  Future<void> _completeFirebaseSignIn(
    firebase.UserCredential userCredential,
  ) async {
    _currentUser = userCredential.user;

    if (_companyService.companies.length > 1) {
      await _companyService.clearSelection();
    }

    await _setupCurrentCompanyUserIfReady();
  }

  Future<void> selectCompany(String companyId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _companyService.selectCompany(companyId);
      await _setupCurrentCompanyUserIfReady();
    } catch (e, stack) {
      _error = 'Failed to select company: $e';
      debugPrint(_error);
      debugPrintStack(stackTrace: stack);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _setupCurrentCompanyUserIfReady() async {
    final user = _currentUser;
    if (user == null) return;

    if (_companyService.needsCompanySelection) {
      _userRole = null;
      await _userRoleChannel?.unsubscribe();
      _userRoleChannel = null;
      return;
    }

    await _setupUserInDatabase(user);
    await _fetchUserRole(user.uid);
    _subscribeToRoleChanges(user.uid);
  }

  // Subscribes to realtime postgres_changes on this user's row so that role
  // promotions/demotions made by a Director are reflected immediately.
  void _subscribeToRoleChanges(String userId) {
    _userRoleChannel?.unsubscribe();
    _userRoleChannel = _supabase
        .channel('user-role-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (PostgresChangePayload payload) {
            final newRole = payload.newRecord['role'] as String?;
            if (newRole != null && newRole != _userRole) {
              _userRole = newRole;
              notifyListeners();
            }
          },
        )
        .subscribe();
  }

  // Setup user in Supabase database
  Future<void> _setupUserInDatabase(firebase.User firebaseUser) async {
    try {
      final existingUser = await _supabase
          .from('users')
          .select('id')
          .eq('id', firebaseUser.uid)
          .maybeSingle();

      if (existingUser != null) return;

      final users = await _supabase.from('users').select('id');

      final role = (users as List).isEmpty ? 'Director' : 'Manager';

      await _supabase.from('users').insert({
        'id': firebaseUser.uid,
        'email': firebaseUser.email,
        'display_name': firebaseUser.displayName ?? 'User',
        'role': role,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('User setup failed: $e');
      rethrow;
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
      await _userRoleChannel?.unsubscribe();
      _userRoleChannel = null;

      if (!kIsWeb) {
        try {
          await _googleSignIn.disconnect();
        } catch (e) {
          debugPrint('Google disconnect skipped: $e');
        }
      }

      await _firebaseAuth.signOut();
      _currentUser = null;
      _userRole = null;
      _error = null;
      await _companyService.clearSelection();
      notifyListeners();
    } catch (e) {
      _error = 'Logout failed: $e';
      debugPrint(_error);
    }
  }

  // Change user role (Director/Co-Director only)
  Future<void> changeUserRole(String userId, String newRole) async {
    try {
      if (!hasPermission('Co-Director')) {
        throw Exception('Only Directors and Co-Directors can change roles');
      }

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

  // Update display name across Firebase + all companies' Supabase users tables
  Future<void> updateDisplayName(String newName) async {
    final user = _currentUser;
    if (user == null) throw Exception('Not logged in');

    await user.updateDisplayName(newName);
    await user.reload();
    _currentUser = _firebaseAuth.currentUser;

    for (final company in _companyService.companies) {
      final client = _companyService.clientFor(company.id);
      await client
          .from('users')
          .update({'display_name': newName}).eq('id', user.uid);
    }

    await _logAudit('users', user.uid, 'UPDATE', {'display_name': newName});
    notifyListeners();
  }

  // Check if user has permission
  bool hasPermission(String requiredRole) {
    if (_userRole == 'Director') return true;
    if (_userRole == 'Co-Director' && requiredRole != 'Director') return true;
    if (_userRole == 'Manager' && requiredRole == 'Manager') return true;
    return false;
  }

  @override
  void dispose() {
    _googleAuthSubscription?.cancel();
    unawaited(_userRoleChannel?.unsubscribe());
    super.dispose();
  }
}
