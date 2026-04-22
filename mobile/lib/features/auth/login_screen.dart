import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/auth/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _business = TextEditingController();
  bool _registering = false;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ctrl = ref.read(authControllerProvider.notifier);
      if (_registering) {
        await ctrl.register(
          businessName: _business.text.trim(),
          countryCode: 'ZW',
          currency: 'USD',
          ownerEmail: _email.text.trim(),
          password: _password.text,
        );
      } else {
        await ctrl.login(_email.text.trim(), _password.text);
      }
      if (mounted) context.go('/pos');
    } catch (e) {
      setState(() => _error = 'Could not sign in. Check your details.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Premium Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFEEF2FF), Color(0xFFC7D2FE), Color(0xFFE0E7FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Icon(Icons.point_of_sale, size: 64, color: Color(0xFF4F46E5))
                                .animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                            const SizedBox(height: 16),
                            Text('TillPro',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1E293B),
                                    )).animate().fadeIn(delay: 200.ms),
                            Text(_registering ? 'Create your shop' : 'Welcome back',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: const Color(0xFF64748B),
                                    )).animate().fadeIn(delay: 300.ms),
                            const SizedBox(height: 32),
                            if (_registering)
                              TextField(
                                controller: _business,
                                decoration: const InputDecoration(labelText: 'Shop name', prefixIcon: Icon(Icons.storefront)),
                              ).animate().slideX(begin: 0.2, curve: Curves.easeOut).fadeIn(),
                            if (_registering) const SizedBox(height: 16),
                            TextField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                            ).animate().slideX(begin: 0.2, delay: 100.ms, curve: Curves.easeOut).fadeIn(delay: 100.ms),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _password,
                              obscureText: true,
                              decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                            ).animate().slideX(begin: 0.2, delay: 200.ms, curve: Curves.easeOut).fadeIn(delay: 200.ms),
                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                              ).animate().shake(),
                            ],
                            const SizedBox(height: 32),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _busy ? null : _submit,
                              child: _busy
                                  ? const SizedBox(
                                      height: 20, width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Text(_registering ? 'Create shop' : 'Sign in', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ).animate().scale(delay: 400.ms),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () =>
                                  setState(() => _registering = !_registering),
                              child: Text(_registering
                                  ? 'Already have an account? Sign in'
                                  : 'New shop? Create an account', style: const TextStyle(color: Color(0xFF4F46E5))),
                            ).animate().fadeIn(delay: 500.ms),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
