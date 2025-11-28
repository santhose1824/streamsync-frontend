import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/network/api_exception.dart';
import 'package:frontend/features/auth/bloc/auth_bloc.dart';
import 'package:frontend/features/auth/repositories/auth_repository.dart';
import 'package:frontend/widgets/auth_header.dart';
import 'package:frontend/widgets/auth_text_field.dart';
import 'package:frontend/widgets/error_box.dart';
import 'package:frontend/widgets/link_text_button.dart';
import 'package:frontend/widgets/password_field.dart';
import 'package:frontend/widgets/primary_button.dart';

class RegisterScreen extends StatefulWidget {
  final AuthRepository authRepository;
  const RegisterScreen({super.key, required this.authRepository});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _animationController.forward();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await widget.authRepository.register(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      context.read<AuthBloc>().add(LoggedIn(user));
    } on ApiException catch (apiErr) {
      final code = apiErr.statusCode;
      final serverMessage = apiErr.message;
      String friendly;
      if (code == 400) {
        friendly = serverMessage.isNotEmpty ? serverMessage : 'Invalid request. Check inputs.';
      } else if (code == 401) {
        friendly = 'Unauthorized. Please try again.';
      } else if (code == 409) {
        friendly = serverMessage.isNotEmpty ? serverMessage : 'Email already in use.';
      } else if (code == 422) {
        friendly = serverMessage.isNotEmpty ? serverMessage : 'Validation failed. Check the fields.';
      } else if (code != null && code >= 500) {
        friendly = 'Server error ($code). Try again later.';
      } else {
        friendly = serverMessage.isNotEmpty ? serverMessage : 'Registration failed. Please try again.';
      }
      if (mounted) setState(() => _error = friendly);
    } on Exception {
      if (mounted) setState(() => _error = 'An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state.isAuthenticated) {
          if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF667eea), Color(0xFF764ba2), Color(0xFFf093fb)]),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AuthHeader(text: "Create your Account"),
                        Container(
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 28, offset: const Offset(0, 12))
                          ]),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  AuthTextField(controller: _nameCtrl, label: 'Full name', prefixIcon: const Icon(Icons.person_outline), validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
                                  const SizedBox(height: 12),
                                  AuthTextField(controller: _emailCtrl, label: 'Email', keyboardType: TextInputType.emailAddress, prefixIcon: const Icon(Icons.email_outlined), validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
                                  const SizedBox(height: 12),
                                  PasswordField(controller: _passCtrl, validator: (v) => (v == null || v.length < 6) ? 'Min 6 chars' : null, showStrength: true),
                                  const SizedBox(height: 12),
                                  if (_error != null) ...[ErrorBox(message: _error!), const SizedBox(height: 12)],
                                  const SizedBox(height: 8),
                                  PrimaryButton(onPressed: _loading ? null : _submit, label: 'Create Account', loading: _loading),
                                  const SizedBox(height: 12),
                                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    const Text('Already have an account? ', style: TextStyle(color: Colors.grey)),
                                    LinkTextButton(text: 'Sign In', onTap: () => Navigator.of(context).pop()),
                                  ]),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('By signing up, you agree to our Terms & Privacy Policy', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12))),
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
