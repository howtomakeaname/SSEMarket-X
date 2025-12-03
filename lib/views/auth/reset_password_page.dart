import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/shared/components/layout/auth_desktop_layout.dart';
import 'package:sse_market_x/shared/components/loading/loading_indicator.dart';
import 'package:sse_market_x/shared/components/utils/snackbar_helper.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

class ResetPasswordPage extends StatefulWidget {
  final ApiService apiService;
  final String? initialEmail;
  final bool fromLogin;

  const ResetPasswordPage({
    super.key,
    required this.apiService,
    this.initialEmail,
    this.fromLogin = false,
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  int _currentStep = 1;
  bool _isLoading = false;

  // Step 1
  final TextEditingController _emailController = TextEditingController();

  // Step 2
  final TextEditingController _valiCodeController = TextEditingController();
  Timer? _countdownTimer;
  int _countdown = 0;

  // Step 3
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null) {
      _emailController.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _valiCodeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }


  void _showMessage(String message) {
    SnackBarHelper.show(context, message);
  }

  /// 验证密码强度
  /// 密码长度10-72位，包含大小写字母、数字、特殊字符
  bool _isValidPassword(String password) {
    if (password.length < 10 || password.length > 72) {
      return false;
    }
    // 必须包含大小写字母、数字、特殊字符中的至少三种
    final hasUpperCase = password.contains(RegExp(r'[A-Z]'));
    final hasLowerCase = password.contains(RegExp(r'[a-z]'));
    final hasDigit = password.contains(RegExp(r'[0-9]'));
    final hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\\/`~]'));
    
    int typeCount = 0;
    if (hasUpperCase) typeCount++;
    if (hasLowerCase) typeCount++;
    if (hasDigit) typeCount++;
    if (hasSpecialChar) typeCount++;
    
    return typeCount >= 3;
  }

  /// 返回上一步
  void _goBack() {
    if (_currentStep > 1) {
      setState(() {
        _currentStep--;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _sendCode() async {
    if (_emailController.text.trim().isEmpty) {
      _showMessage('请输入邮箱');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await widget.apiService.sendCode(_emailController.text.trim(), 1); // 1: Reset Password

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      if (result.isEmpty) {
        _showMessage('验证码已发送');
        _startCountdown();
        setState(() {
          _currentStep = 2;
        });
      } else {
        _showMessage(result);
      }
    }
  }

  void _startCountdown() {
    _countdown = 300; // 5分钟
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_countdown > 0) {
            _countdown--;
          } else {
            timer.cancel();
          }
        });
      }
    });
  }

  Future<void> _verifyCode() async {
    if (_valiCodeController.text.trim().isEmpty) {
      _showMessage('请输入验证码');
      return;
    }
    // Client side validation passed, move to next step
    setState(() {
      _currentStep = 3;
    });
  }

  Future<void> _resetPassword() async {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.isEmpty) {
      _showMessage('请输入新密码');
      return;
    }

    if (!_isValidPassword(newPassword)) {
      _showMessage('密码必须包含大小写字母、数字、特殊字符中的至少三种，长度10-72位');
      return;
    }

    if (confirmPassword.isEmpty) {
      _showMessage('请确认新密码');
      return;
    }

    if (newPassword != confirmPassword) {
      _showMessage('两次输入的密码不一致');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await widget.apiService.resetPassword(
      _emailController.text.trim(),
      newPassword,
      confirmPassword,
      _valiCodeController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      if (result.isEmpty) {
        _showMessage('密码重置成功，请重新登录');
        Navigator.of(context).pop();
      } else {
        _showMessage(result);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 800) {
          return Scaffold(
            backgroundColor: AppColors.surface,
            body: _buildDesktopLayout(),
          );
        }
        return _buildMobileLayout();
      },
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: _goBack,
        ),
        title: const Text(
          '重置密码',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: _buildBodyContent(),
    );
  }

  Widget _buildDesktopLayout() {
    return AuthDesktopLayout(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                onPressed: _goBack,
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    '重置密码',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 48), // Balance the back button
            ],
          ),
          const SizedBox(height: 48),
          _buildBodyContent(isDesktop: true),
        ],
      ),
    );
  }

  Widget _buildBodyContent({bool isDesktop = false}) {
    if (_isLoading) {
      return const LoadingIndicator.center(message: '处理中...');
    }
    return SingleChildScrollView(
      padding: isDesktop ? EdgeInsets.zero : const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildStepIndicator(),
          const SizedBox(height: 32),
          if (_currentStep == 1) _buildStep1(),
          if (_currentStep == 2) _buildStep2(),
          if (_currentStep == 3) _buildStep3(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepItem(1, '输入邮箱'),
        _buildStepLine(1),
        _buildStepItem(2, '验证码'),
        _buildStepLine(2),
        _buildStepItem(3, '新密码'),
      ],
    );
  }

  Widget _buildStepItem(int step, String label) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AppColors.primary : AppColors.divider,
            border: isCurrent
                ? Border.all(color: AppColors.primary, width: 2)
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            '$step',
            style: TextStyle(
              color: isActive ? Colors.white : AppColors.textSecondary,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? AppColors.primary : AppColors.textSecondary,
            fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int beforeStep) {
    final isActive = _currentStep > beforeStep;
    return Container(
      width: 40,
      height: 2,
      color: isActive ? AppColors.primary : AppColors.divider,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
    );
  }


  Widget _buildStep1() {
    return Column(
      children: [
        _buildTextField(
          controller: _emailController,
          label: '邮箱',
          hint: '请输入注册时的邮箱',
          icon: Icons.email_outlined,
          readOnly: widget.initialEmail != null,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _emailController.text.trim().isNotEmpty ? _sendCode : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              '发送验证码',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ),
        if (widget.fromLogin) ...[
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '想起密码了？',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Text(
                  '返回登录',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      children: [
        Text(
          '验证码已发送至 ${_emailController.text}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _valiCodeController,
          label: '验证码',
          hint: '请输入收到的验证码',
          icon: Icons.security,
        ),
        const SizedBox(height: 16),
        if (_countdown > 0)
          Text(
            '${_countdown ~/ 60}分${_countdown % 60}秒后可重新发送',
            style: const TextStyle(color: AppColors.textSecondary),
          )
        else
          TextButton(
            onPressed: _sendCode,
            child: const Text('重新发送'),
          ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: _goBack,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '返回上一步',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _valiCodeController.text.isNotEmpty ? _verifyCode : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '继续',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }


  Widget _buildStep3() {
    return Column(
      children: [
        _buildPasswordField(
          controller: _newPasswordController,
          label: '新密码',
          hint: '请输入新密码（至少10位）',
          obscureText: _obscureNewPassword,
          onToggleObscure: () {
            setState(() {
              _obscureNewPassword = !_obscureNewPassword;
            });
          },
        ),
        const SizedBox(height: 8),
        const Text(
          '密码需包含大小写字母、数字、特殊字符中的至少三种',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        _buildPasswordField(
          controller: _confirmPasswordController,
          label: '确认新密码',
          hint: '请再次输入新密码',
          obscureText: _obscureConfirmPassword,
          onToggleObscure: () {
            setState(() {
              _obscureConfirmPassword = !_obscureConfirmPassword;
            });
          },
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: _goBack,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '返回上一步',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: (_newPasswordController.text.length >= 10 &&
                          _confirmPasswordController.text.isNotEmpty)
                      ? _resetPassword
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '重置密码',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          readOnly: readOnly,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Icon(icon, color: AppColors.textSecondary),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 48),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscureText,
    required VoidCallback onToggleObscure,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 12, right: 8),
              child: Icon(Icons.lock_outline, color: AppColors.textSecondary),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 48),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textSecondary,
                ),
                onPressed: onToggleObscure,
              ),
            ),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }
}
