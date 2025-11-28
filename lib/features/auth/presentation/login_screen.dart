import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/network/api_exception.dart';
import 'package:frontend/features/auth/bloc/auth_bloc.dart';
import 'package:frontend/features/auth/presentation/register_screen.dart';
import 'package:frontend/features/auth/repositories/auth_repository.dart';
import 'package:frontend/widgets/auth_header.dart';
import 'package:frontend/widgets/auth_text_field.dart';
import 'package:frontend/widgets/error_box.dart';
import 'package:frontend/widgets/link_text_button.dart';
import 'package:frontend/widgets/password_field.dart';
import 'package:frontend/widgets/primary_button.dart';

class LoginScreen extends StatefulWidget {
  final AuthRepository authRepository;
  const LoginScreen({super.key, required this.authRepository});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      print('DEBUG LoginScreen: Attempting login for ${_emailCtrl.text.trim()}');
      final user = await widget.authRepository.login(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      print('DEBUG LoginScreen: Login successful, dispatching LoggedIn event');
      if (mounted) {
        context.read<AuthBloc>().add(LoggedIn(user));
        print('DEBUG LoginScreen: LoggedIn event dispatched');
      }
    } on ApiException catch (apiErr) {
      print('DEBUG LoginScreen: ApiException - ${apiErr.message}');
      final code = apiErr.statusCode;
      final serverMessage = apiErr.message;
      String friendly;
      if (code == 400) {
        friendly = serverMessage.isNotEmpty ? serverMessage : 'Invalid request. Check inputs.';
      } else if (code == 401) {
        friendly = serverMessage.isNotEmpty ? serverMessage : 'Wrong email or password.';
      } else if (code == 429) {
        friendly = 'Too many attempts. Try again later.';
      } else if (code != null && code >= 500) {
        friendly = 'Server error ($code). Try again later.';
      } else {
        friendly = serverMessage.isNotEmpty ? serverMessage : 'Login failed. Please try again.';
      }
      if (mounted) setState(() => _error = friendly);
    } on Exception catch (e) {
      print('DEBUG LoginScreen: Exception - $e');
      final msg = e.toString().toLowerCase();
      if (msg.contains('socket') || msg.contains('network') || msg.contains('failed host lookup')) {
        if (mounted) setState(() => _error = 'No internet connection. Check your network.');
      } else {
        if (mounted) setState(() => _error = 'An unexpected error occurred. Try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2), Color(0xFFf093fb)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AuthHeader(text: 'Welcome back! Sign in to continue'),
                        // Card container
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.14),
                                blurRadius: 28,
                                offset: const Offset(0, 12),
                              )
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  AuthTextField(
                                    controller: _emailCtrl,
                                    label: 'Email',
                                    keyboardType: TextInputType.emailAddress,
                                    prefixIcon: const Icon(Icons.email_outlined),
                                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                                  ),
                                  const SizedBox(height: 14),
                                  PasswordField(
                                    controller: _passCtrl,
                                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                                  ),
                                  const SizedBox(height: 12),
                                  if (_error != null) ...[
                                    ErrorBox(message: _error!),
                                    const SizedBox(height: 12),
                                  ],
                                  const SizedBox(height: 8),
                                  PrimaryButton(
                                    onPressed: _loading ? null : _submit,
                                    label: 'Sign In',
                                    loading: _loading,
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    children: [
                                      const Text(
                                        'Don\'t have an account? ',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                      LinkTextButton(
                                        text: 'Create Account',
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => RegisterScreen(
                                                authRepository: widget.authRepository,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'By signing in, you agree to our Terms & Privacy Policy',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12,
                            ),
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
      ),
    );
  }
}