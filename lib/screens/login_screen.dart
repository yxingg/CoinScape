import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _remember = true;
  String? _error;

  @override
  void dispose() {
    _userCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final username = _userCtrl.text.trim();
    final password = _pwdCtrl.text;
    final ok = await ref.read(authProvider.notifier).login(username, password);
    setState(() {
      _loading = false;
    });
    if (!ok) {
      setState(() {
        _error = '登录失败，请检查用户名或密码';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
          decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.colorScheme.primary.withAlpha((0.06 * 255).round()), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                elevation: 10,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundColor: theme.colorScheme.primary,
                        child: Icon(Icons.account_balance_wallet, size: 40, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      Text('CoinScape', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text('纪念币收藏管理工具', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                      const SizedBox(height: 20),

                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _userCtrl,
                              decoration: const InputDecoration(labelText: '用户名', prefixIcon: Icon(Icons.person)),
                              textInputAction: TextInputAction.next,
                              autofocus: true,
                              validator: (v) => (v == null || v.trim().isEmpty) ? '请输入用户名' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _pwdCtrl,
                              decoration: InputDecoration(
                                labelText: '密码',
                                prefixIcon: const Icon(Icons.lock),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                ),
                              ),
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              validator: (v) => (v == null || v.isEmpty) ? '请输入密码' : null,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Checkbox(value: _remember, onChanged: (v) => setState(() => _remember = v ?? true)),
                                const Text('记住我'),
                                const Spacer(),
                                TextButton(onPressed: () {}, child: const Text('忘记密码?')),
                              ],
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 8),
                              Text(_error!, style: const TextStyle(color: Colors.red)),
                            ],
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  minimumSize: const Size.fromHeight(48),
                                ),
                                child: _loading
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text('登录'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('默认账户: admin / coinscape', style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
