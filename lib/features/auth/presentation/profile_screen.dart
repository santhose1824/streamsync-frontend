import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/network/api_exception.dart';
import 'package:frontend/core/services/awesome_notification_service.dart';
import 'package:frontend/features/auth/bloc/auth_bloc.dart';
import 'package:frontend/features/auth/repositories/auth_repository.dart';
import 'package:frontend/features/notifications/bloc/notification_bloc.dart';
import 'package:frontend/features/notifications/bloc/notification_event.dart';
import 'package:frontend/features/notifications/repositories/notifications_repositories.dart';
import 'package:frontend/widgets/auth_text_field.dart';
import 'package:frontend/widgets/error_box.dart';
import 'package:frontend/widgets/option_card.dart';
import 'package:frontend/widgets/option_header.dart';
import 'package:frontend/widgets/password_field.dart';
import 'package:frontend/core/theme/theme_cubit.dart';

class ProfileScreen extends StatefulWidget {
  final AuthRepository authRepository;
  const ProfileScreen({super.key, required this.authRepository});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = false;
  String? _error;

  void _showSnackbar(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _onLogout() async {
    setState(() => _loading = true);
    try {
      print('DEBUG ProfileScreen: Starting logout');
      context.read<AuthBloc>().add(LoggedOut());
      print('DEBUG ProfileScreen: LoggedOut event dispatched');
      // Note: Don't set loading to false here as the widget will be unmounted
    } catch (e) {
      print('DEBUG ProfileScreen: Logout error - $e');
      _showSnackbar('Logout error', error: true);
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onRefreshToken() async {
    setState(() => _loading = true);
    try {
      await widget.authRepository.manualRefresh();
      _showSnackbar('Tokens refreshed');
    } on ApiException catch (api) {
      _showSnackbar(api.message, error: true);
    } catch (_) {
      _showSnackbar('Refresh failed', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onSendTestNotification() async {
    await AwesomeNotificationService.showTestNotification();

    // Test 2: Send via backend
    context.read<NotificationsBloc>().add(
      SendTestNotificationRequested(
        title: 'Test from Flutter ${DateTime.now().hour}:${DateTime.now().minute}',
        body: 'Testing notification system',
        idempotencyKey: 'test-${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
  }


  Future<void> _onUpdateProfile() async {
    final nameCtrl = TextEditingController(text: context.read<AuthBloc>().state.user?.name ?? '');
    final emailCtrl = TextEditingController(text: context.read<AuthBloc>().state.user?.email ?? '');
    final formKey = GlobalKey<FormState>();
    String? localError;

    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Update Profile',style:TextStyle(
        fontSize: 16
        ),),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AuthTextField(
                  controller: nameCtrl,
                  label: 'Full name',
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                AuthTextField(
                  controller: emailCtrl,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                if (localError != null) ...[
                  const SizedBox(height: 12),
                  ErrorBox(message: localError!),
                ]
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(ctx).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (res != true) return;

    setState(() => _loading = true);
    try {
      final updated = await widget.authRepository.updateProfile(
        name: nameCtrl.text.trim(),
        email: emailCtrl.text.trim(),
      );
      context.read<AuthBloc>().add(LoggedIn(updated));
      _showSnackbar('Profile updated');
    } on ApiException catch (api) {
      _showSnackbar(api.message, error: true);
    } catch (e) {
      print(e);
      _showSnackbar('Update failed', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onChangePassword() async {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lock_outline, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Change Password',style:TextStyle(
              fontSize: 16
            ),),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PasswordField(
                controller: oldCtrl,
                label: 'Current password',
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              PasswordField(
                controller: newCtrl,
                label: 'New password',
                validator: (v) => (v == null || v.length < 6) ? 'Min 6 chars' : null,
                showStrength: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(ctx).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Change'),
          ),
        ],
      ),
    );

    if (res != true) return;

    setState(() => _loading = true);
    try {
      await widget.authRepository.changePassword(
        currentPassword: oldCtrl.text,
        newPassword: newCtrl.text,
      );
      _showSnackbar('Password changed');
    } on ApiException catch (api) {
      _showSnackbar(api.message, error: true);
    } catch (_) {
      _showSnackbar('Change password failed', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onDeleteAccount() async {
    final passCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.warning_rounded, color: Colors.red.shade700, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Delete Account'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This will permanently delete your account. Type your password to confirm.',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 16),
            PasswordField(
              controller: passCtrl,
              label: 'Password',
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              if (passCtrl.text.isEmpty) return;
              Navigator.of(ctx).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await widget.authRepository.deleteAccount(password: passCtrl.text);
      context.read<AuthBloc>().add(LoggedOut());
      _showSnackbar('Account deleted');
    } on ApiException catch (api) {
      _showSnackbar(api.message, error: true);
    } catch (_) {
      _showSnackbar('Delete failed', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  void _showThemeBottomSheet() {
    final cubit = context.read<ThemeCubit>();
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Text('Choose theme', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Divider(),
              BlocBuilder<ThemeCubit, ThemeMode>(
                builder: (context, mode) {
                  return Column(
                    children: [
                      RadioListTile<ThemeMode>(
                        title: const Text('Light'),
                        value: ThemeMode.light,
                        groupValue: mode,
                        onChanged: (v) {
                          if (v == null) return;
                          cubit.setThemeMode(v);
                          Navigator.of(ctx).pop();
                        },
                      ),
                      RadioListTile<ThemeMode>(
                        title: const Text('Dark'),
                        value: ThemeMode.dark,
                        groupValue: mode,
                        onChanged: (v) {
                          if (v == null) return;
                          cubit.setThemeMode(v);
                          Navigator.of(ctx).pop();
                        },
                      ),
                      RadioListTile<ThemeMode>(
                        title: const Text('System'),
                        value: ThemeMode.system,
                        groupValue: mode,
                        onChanged: (v) {
                          if (v == null) return;
                          cubit.setThemeMode(v);
                          Navigator.of(ctx).pop();
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc b) => b.state.user);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [
              const Color(0xFF667eea).withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with gradient background
              Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Profile Avatar with gradient border
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF667eea), Color(0xFF764ba2), Color(0xFFf093fb)],
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: const Color(0xFF667eea).withOpacity(0.15),
                          child: Text(
                            (user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'U'),
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF667eea),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user?.name ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? '',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // Options List
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView(
                    children: [
                      const SizedBox(height: 8),

                      // Account Section
                      OptionHeader(title: 'ACCOUNT'),

                      OptionCard(
                        icon: Icons.edit_outlined,
                        title: 'Update Profile',
                        subtitle: 'Change name or email',
                        onTap: _onUpdateProfile,
                      ),

                      OptionCard(
                        icon: Icons.lock_outline,
                        title: 'Change Password',
                        subtitle: 'Update your password',
                        onTap: _onChangePassword,
                      ),

                      OptionCard(
                        icon: Icons.notifications_outlined,
                        title: 'Test Notification',
                        subtitle: 'Send test push to this device',
                        onTap: _onSendTestNotification,
                      ),

                      const SizedBox(height: 16),

                      // inside ListView children, e.g., under Developer or a new "Appearance" section:
                     OptionHeader(title: 'APPEARANCE'),

                      OptionCard(
                        icon: Icons.brightness_6_outlined,
                        title: 'Theme',
                        subtitle: 'Light / Dark / System',
                        onTap: () => _showThemeBottomSheet(),
                        iconColor: Colors.purple.shade700,
                        backgroundColor: Colors.purple.shade50,
                      ),

                      // Developer Section
                      OptionHeader(title: 'DEVELOPER'),

                      OptionCard(
                        icon: Icons.refresh,
                        title: 'Refresh Tokens',
                        subtitle: 'Rotate access & refresh tokens',
                        onTap: _onRefreshToken,
                        iconColor: Colors.orange.shade700,
                        backgroundColor: Colors.orange.shade50,
                      ),

                      const SizedBox(height: 16),

                      // Actions Section
                     OptionHeader(title: 'ACTIONS'),

                      OptionCard(
                        icon: Icons.logout,
                        title: 'Logout',
                        subtitle: 'Sign out of this device',
                        onTap: _onLogout,
                        iconColor: Colors.blue.shade700,
                        backgroundColor: Colors.blue.shade50,
                      ),

                      OptionCard(
                        icon: Icons.delete_forever_outlined,
                        title: 'Delete Account',
                        subtitle: 'Permanently delete your account',
                        onTap: _onDeleteAccount,
                        iconColor: Colors.red.shade700,
                        backgroundColor: Colors.red.shade50,
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              if (_loading)
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    ),
                  ),
                  child: const LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.transparent),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}