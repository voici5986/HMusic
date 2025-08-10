import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SshSettings {
  final String host;
  final int port;
  final String username;
  final String password;

  const SshSettings({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
  });

  SshSettings copyWith({
    String? host,
    int? port,
    String? username,
    String? password,
  }) {
    return SshSettings(
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }
}

class SshSettingsNotifier extends StateNotifier<SshSettings> {
  static const _kHost = 'ssh_host';
  static const _kPort = 'ssh_port';
  static const _kUser = 'ssh_user';
  static const _kPass = 'ssh_pass';

  SshSettingsNotifier()
      : super(const SshSettings(
          host: '192.168.31.2',
          port: 22,
          username: 'root',
          password: 'hpc19970122',
        )) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString(_kHost);
    final port = prefs.getInt(_kPort);
    final user = prefs.getString(_kUser);
    final pass = prefs.getString(_kPass);
    if (host != null || port != null || user != null || pass != null) {
      state = state.copyWith(
        host: host ?? state.host,
        port: port ?? state.port,
        username: user ?? state.username,
        password: pass ?? state.password,
      );
    }
  }

  Future<void> save(SshSettings settings) async {
    state = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kHost, settings.host);
    await prefs.setInt(_kPort, settings.port);
    await prefs.setString(_kUser, settings.username);
    await prefs.setString(_kPass, settings.password);
  }
}

final sshSettingsProvider =
    StateNotifierProvider<SshSettingsNotifier, SshSettings>((ref) {
  return SshSettingsNotifier();
});


