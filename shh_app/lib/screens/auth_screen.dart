import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../providers/app_provider.dart';
import '../widgets/widgets.dart';
import 'conversations_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _isPasswordVisible = false;
  
  final _formKey = GlobalKey<FormState>();
  final _uniqueUsernameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _uniqueUsernameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _formKey.currentState?.reset();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<AppProvider>();
    bool success;

    if (_isLogin) {
      success = await provider.login(
        uniqueUsername: _uniqueUsernameController.text.trim(),
        password: _passwordController.text,
      );
    } else {
      success = await provider.register(
        uniqueUsername: _uniqueUsernameController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
    }

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ConversationsScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          return ScanlineOverlay(
            child: NoiseOverlay(
              opacity: 0.03,
              child: GridBackground(
                child: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 40),
                        _buildHeader(),
                        const SizedBox(height: 48),
                        _buildForm(provider),
                        const SizedBox(height: 24),
                        CyberButton(
                          text: _isLogin ? 'ACCESS_SYSTEM' : 'CREATE_IDENTITY',
                          onPressed: _submit,
                          isLoading: provider.isLoading,
                          icon: _isLogin ? Icons.login : Icons.person_add,
                        ),
                        const SizedBox(height: 16),
                        _buildToggle(),
                        if (provider.error != null) ...[
                          const SizedBox(height: 24),
                          _buildError(provider.error!),
                        ],
                        const SizedBox(height: 48),
                        _buildFooter(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          '''
███████╗██╗  ██╗██╗  ██╗██╗  ██╗
██╔════╝██║  ██║██║  ██║██║  ██║
███████╗███████║███████║███████║
╚════██║██╔══██║██╔══██║██╔══██║
███████║██║  ██║██║  ██║██║  ██║
╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝''',
          style: AppTextStyles.code.copyWith(
            fontSize: 8,
            height: 1.0,
            letterSpacing: 0,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const GlitchText(
          text: 'SHHH',
          glitchIntensity: 0.05,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const BlinkingCursor(width: 8, height: 16),
            const SizedBox(width: 8),
            Text(
              _isLogin ? 'AUTHENTICATION_REQUIRED' : 'IDENTITY_CREATION',
              style: AppTextStyles.terminal,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildForm(AppProvider provider) {
    return Form(
      key: _formKey,
      child: CyberBorder(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    color: AppColors.neonGreen,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isLogin ? 'LOGIN_CREDENTIALS' : 'NEW_USER_DATA',
                    style: AppTextStyles.headlineSmall,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              CyberTextField(
                label: 'UNIQUE_ID',
                hint: 'your_unique_identifier',
                controller: _uniqueUsernameController,
                prefixIcon: const Icon(Icons.fingerprint, color: AppColors.neonGreen),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'UNIQUE_ID_REQUIRED';
                  }
                  if (value.length < 3) {
                    return 'MIN_3_CHARACTERS';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (!_isLogin) ...[
                CyberTextField(
                  label: 'DISPLAY_NAME',
                  hint: 'Your display name',
                  controller: _usernameController,
                  prefixIcon: const Icon(Icons.badge, color: AppColors.neonGreen),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'DISPLAY_NAME_REQUIRED';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
              
              CyberTextField(
                label: 'PASSWORD',
                hint: '••••••••••••',
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                prefixIcon: const Icon(Icons.lock, color: AppColors.neonGreen),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'PASSWORD_REQUIRED';
                  }
                  if (value.length < 6) {
                    return 'MIN_6_CHARACTERS';
                  }
                  return null;
                },
              ),
              if (!_isLogin) ...[
                const SizedBox(height: 16),
                CyberTextField(
                  label: 'CONFIRM_PASSWORD',
                  hint: '••••••••••••',
                  controller: _confirmPasswordController,
                  obscureText: !_isPasswordVisible,
                  prefixIcon: const Icon(Icons.lock_outline, color: AppColors.neonGreen),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'PASSWORDS_DO_NOT_MATCH';
                    }
                    return null;
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggle() {
    return TextButton(
      onPressed: _toggleMode,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _isLogin ? '// NEW_USER? ' : '// EXISTING_USER? ',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          Text(
            _isLogin ? 'CREATE_IDENTITY' : 'LOGIN',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.hotPink,
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        border: Border.all(color: AppColors.error, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'ERROR: $error',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Divider(color: AppColors.borderColor),
        const SizedBox(height: 16),
        Text(
          '// END-TO-END ENCRYPTED',
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const RandomCounter(digits: 6),
            const SizedBox(width: 16),
            Text(
              '|',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.borderColor),
            ),
            const SizedBox(width: 16),
            Text(
              'RSA-2048 + AES-GCM',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.neonGreen),
            ),
          ],
        ),
      ],
    );
  }
}
