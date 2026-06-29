import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../models/auth_models.dart';
import '../storage/token_storage.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Holds the session and drives login / restore / logout.
/// Exposed via Provider; the router redirects on [status].
class AuthController extends ChangeNotifier {
  AuthController({required this.api, required this.tokenStorage});

  final ApiClient api;
  final TokenStorage tokenStorage;

  AuthStatus status = AuthStatus.unknown;
  AppUser? user;
  String? errorMessage;
  bool busy = false;

  /// Called once at startup: if a token exists, validate it via /auth/me.
  Future<void> restore() async {
    final token = await tokenStorage.read();
    if (token == null || token.isEmpty) {
      _set(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final data = await api.get(ApiEndpoints.me);
      final userJson = data is Map && data['user'] is Map
          ? Map<String, dynamic>.from(data['user'])
          : Map<String, dynamic>.from(data as Map);
      if (data is Map && data['capabilities'] is Map) {
        userJson['capabilities'] = data['capabilities'];
      }
      user = AppUser.fromJson(userJson);
      _set(status: AuthStatus.authenticated);
    } catch (_) {
      await tokenStorage.clear();
      _set(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login({
    required String email,
    required String password,
    required String deviceName,
  }) async {
    _set(busy: true, error: null);
    try {
      final data = await api.post(ApiEndpoints.login, body: {
        'email': email.trim(),
        'password': password,
        'device_name': deviceName,
      });
      final session = AuthSession.fromJson(Map<String, dynamic>.from(data as Map));
      if (session.token.isEmpty) {
        _set(busy: false, error: 'Login failed — no token returned.');
        return false;
      }
      await tokenStorage.save(session.token);
      user = session.user;
      _set(busy: false, status: AuthStatus.authenticated);
      return true;
    } on ApiException catch (e) {
      _set(busy: false, error: e.message);
      return false;
    } catch (e) {
      _set(busy: false, error: 'Login failed. Please try again.');
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await api.post(ApiEndpoints.logout);
    } catch (_) {
      // ignore network errors on logout
    }
    await tokenStorage.clear();
    user = null;
    _set(status: AuthStatus.unauthenticated);
  }

  void _set({AuthStatus? status, AppUser? user, bool? busy, String? error}) {
    if (status != null) this.status = status;
    if (busy != null) this.busy = busy;
    errorMessage = error;
    notifyListeners();
  }
}
