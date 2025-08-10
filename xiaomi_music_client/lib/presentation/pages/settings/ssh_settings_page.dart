import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ssh_settings_provider.dart';

class SshSettingsPage extends ConsumerStatefulWidget {
  const SshSettingsPage({super.key});

  @override
  ConsumerState<SshSettingsPage> createState() => _SshSettingsPageState();
}

class _SshSettingsPageState extends ConsumerState<SshSettingsPage> {
  late final TextEditingController _hostCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _userCtrl;
  late final TextEditingController _passCtrl;

  @override
  void initState() {
    super.initState();
    final s = ref.read(sshSettingsProvider);
    _hostCtrl = TextEditingController(text: s.host);
    _portCtrl = TextEditingController(text: s.port.toString());
    _userCtrl = TextEditingController(text: s.username);
    _passCtrl = TextEditingController(text: s.password);
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      appBar: AppBar(title: const Text('SCP 上传设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _hostCtrl,
            decoration: const InputDecoration(labelText: 'Host (IP)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _portCtrl,
            decoration: const InputDecoration(labelText: 'Port'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _userCtrl,
            decoration: const InputDecoration(labelText: 'Username'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passCtrl,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () async {
              final port = int.tryParse(_portCtrl.text.trim()) ?? 22;
              final settings = SshSettings(
                host: _hostCtrl.text.trim(),
                port: port,
                username: _userCtrl.text.trim(),
                password: _passCtrl.text,
              );
              await ref.read(sshSettingsProvider.notifier).save(settings);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('SCP 设置已保存'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            icon: const Icon(Icons.save_rounded),
            label: const Text('保存'),
          ),
          const SizedBox(height: 12),
          Text(
            '提示：保存后，在曲库页可选择“通过SCP上传”把音乐直接上传到 /opt/xiaomusic/music/。',
            style: TextStyle(color: onSurface.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }
}


