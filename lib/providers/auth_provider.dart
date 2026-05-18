import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/api_service.dart';
import 'sync_providers.dart';

class AuthState {
  final bool loggedIn;
  final String username;

  AuthState({this.loggedIn = false, this.username = ''});

  AuthState copyWith({bool? loggedIn, String? username}) {
    return AuthState(
      loggedIn: loggedIn ?? this.loggedIn,
      username: username ?? this.username,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref ref;

  AuthNotifier(this.ref) : super(AuthState()) {
    _init();
  }

  Future<void> _init() async {
    try {
      SharedPreferences? prefs = ref.read(sharedPreferencesProvider);
      final sp = prefs ?? await SharedPreferences.getInstance();
      final logged = sp.getBool('auth_logged_in') ?? false;
      final user = sp.getString('auth_username') ?? '';
      state = AuthState(loggedIn: logged, username: user);
    } catch (_) {
      state = AuthState();
    }
  }

  Future<bool> login(String username, String password) async {
    try {
      if (kIsWeb) {
        final ok = await ApiService.login(username, password);
        if (ok) {
          SharedPreferences? prefs = ref.read(sharedPreferencesProvider);
          final sp = prefs ?? await SharedPreferences.getInstance();
          await sp.setBool('auth_logged_in', true);
          await sp.setString('auth_username', username);
          state = AuthState(loggedIn: true, username: username);
        }
        return ok;
      }

      // 原生平台：本地验证（首次默认 admin / coinscape），并允许用户后续修改保存到 SharedPreferences
      SharedPreferences? prefs = ref.read(sharedPreferencesProvider);
      final sp = prefs ?? await SharedPreferences.getInstance();
      final storedUser = sp.getString('local_auth_username') ?? 'admin';
      final storedPwd = sp.getString('local_auth_password') ?? 'coinscape';

      if (username == storedUser && password == storedPwd) {
        await sp.setBool('auth_logged_in', true);
        await sp.setString('auth_username', username);
        state = AuthState(loggedIn: true, username: username);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    SharedPreferences? prefs = ref.read(sharedPreferencesProvider);
    final sp = prefs ?? await SharedPreferences.getInstance();
    await sp.setBool('auth_logged_in', false);
    await sp.remove('auth_username');
    state = AuthState(loggedIn: false, username: '');
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
