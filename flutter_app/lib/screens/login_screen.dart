import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/loading_overlay.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController();
  final _displayController = TextEditingController();
  String _realPassword = '';
  bool _obscurePassword = true;
  Timer? _revealTimer;

  @override
  void dispose() {
    _usernameController.dispose();
    _displayController.dispose();
    _revealTimer?.cancel();
    super.dispose();
  }

  void _onPasswordChanged(String value) {
    _revealTimer?.cancel();

    if (!_obscurePassword) {
      _realPassword = value;
      return;
    }

    // Figure out what changed
    final oldLen = _realPassword.length;
    final newLen = value.length;

    if (newLen > oldLen) {
      // Characters were added — extract the new ones from the non-masked part
      final newChars = value.substring(oldLen);
      _realPassword = _realPassword.substring(0, oldLen) + newChars;

      // Show last char briefly, mask the rest
      final maskedPart = '•' * (_realPassword.length - 1);
      _displayController.text = maskedPart + _realPassword[_realPassword.length - 1];
      _displayController.selection = TextSelection.collapsed(offset: _displayController.text.length);

      _revealTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted && _obscurePassword) {
          _displayController.text = '•' * _realPassword.length;
          _displayController.selection = TextSelection.collapsed(offset: _displayController.text.length);
        }
      });
    } else if (newLen < oldLen) {
      // Characters were deleted
      _realPassword = _realPassword.substring(0, newLen);
      _displayController.text = '•' * newLen;
      _displayController.selection = TextSelection.collapsed(offset: newLen);
    }
  }

  void _toggleObscure() {
    setState(() {
      _obscurePassword = !_obscurePassword;
      _revealTimer?.cancel();
      if (_obscurePassword) {
        _displayController.text = '•' * _realPassword.length;
      } else {
        _displayController.text = _realPassword;
      }
      _displayController.selection = TextSelection.collapsed(offset: _displayController.text.length);
    });
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _realPassword;

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci username e password')),
      );
      return;
    }

    await ref.read(authProvider.notifier).login(username, password);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final apiClient = ref.read(apiClientProvider);

    // Show kick reason if user was booted from another device
    final kickReason = apiClient.kickReason;
    if (kickReason != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && apiClient.kickReason != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(kickReason),
              backgroundColor: AppColors.warning,
              duration: const Duration(seconds: 5),
            ),
          );
          apiClient.kickReason = null; // Clear so it doesn't show again
        }
      });
    }

    // Navigate on successful auth
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated) {
        context.go('/home');
      }
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    });

    return Scaffold(
      body: LoadingOverlay(
        isLoading: authState.status == AuthStatus.loading,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo / Title
                  SvgPicture.asset(
                    'assets/fitos-logo.svg',
                    height: 80,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Accedi al tuo account',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Username
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      hintText: 'Username',
                      prefixIcon: Icon(Icons.person_outline, color: AppColors.textTertiary),
                    ),
                    style: const TextStyle(color: AppColors.textPrimary),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextField(
                    controller: _displayController,
                    obscureText: false,
                    onChanged: _onPasswordChanged,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textTertiary),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: AppColors.textTertiary,
                        ),
                        onPressed: _toggleObscure,
                      ),
                    ),
                    style: const TextStyle(color: AppColors.textPrimary),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: 16),

                  // Login button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: authState.status == AuthStatus.loading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        minimumSize: const Size(0, 48),
                      ),
                      child: const Text('Accedi'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Info text — no self-registration
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Chiedi le credenziali alla tua palestra',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
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
