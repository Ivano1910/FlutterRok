import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../widgets/app_shell.dart';
import 'login_screen.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  final String token;

  const VerifyEmailScreen({
    super.key,
    required this.token,
  });

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _isLoading = true;
  bool _isSuccess = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _verifyEmail();
  }

  Future<void> _verifyEmail() async {
    final token = widget.token.trim();

    if (token.isEmpty) {
      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _message = 'Nevažeći link za potvrdu emaila.';
      });
      return;
    }

    try {
      final api = ref.read(apiServiceProvider);
      await api.verifyEmail(token);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isSuccess = true;
        _message = 'Email je uspješno potvrđen. Sada se možete prijaviti.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _message = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Potvrda emaila'),
      ),
      body: AppShell(
        maxWidth: 480,
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isLoading) ...[
                      const Icon(
                        Icons.mark_email_read_outlined,
                        size: 64,
                        color: Colors.teal,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Potvrđujemo email...',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 24),
                      const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ] else ...[
                      Icon(
                        _isSuccess ? Icons.check_circle : Icons.error_outline,
                        size: 72,
                        color: _isSuccess ? Colors.green : Colors.red,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _isSuccess ? 'Email potvrđen' : 'Potvrda nije uspjela',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _message ?? '',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                            (route) => false,
                          );
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          _isSuccess ? 'Idi na prijavu' : 'Natrag na prijavu',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}