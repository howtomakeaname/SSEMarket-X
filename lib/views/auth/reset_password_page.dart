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

  const ResetPasswordPage({
    super.key,
    required this.apiService,
    this.initialEmail,
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
    _countdown = 60;
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
    if (_newPasswordController.text.length < 6) {
      _showMessage('密码长度至少6位');
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showMessage('两次输入的密码不一致');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await widget.apiService.resetPassword(
      _emailController.text.trim(),
      _newPasswordController.text,
      _confirmPasswordController.text,
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            if (_currentStep > 1) {
              setState(() {
                _currentStep--;
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: const Text(
          '重置密码',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
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
                onPressed: () {
                  if (_currentStep > 1) {
                    setState(() {
                      _currentStep--;
                    });
                  } else {
                    Navigator.of(context).pop();
                  }
                },
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
        _buildStepItem(1, '验证'),
        _buildStepLine(),
        _buildStepItem(2, '输入'),
        _buildStepLine(),
        _buildStepItem(3, '完成'),
      ],
    );
  }

  Widget _buildStepItem(int step, String label) {
    final isActive = _currentStep >= step;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AppColors.primary : AppColors.divider,
          ),
          alignment: Alignment.center,
          child: Text(
            '$step',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine() {
    return Container(
      width: 40,
      height: 2,
      color: AppColors.divider,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
    );
  }

  Widget _buildStep1() {
    return Column(
      children: [
        _buildTextField(
          controller: _emailController,
          label: '邮箱',
          hint: '请输入邮箱',
          icon: Icons.email_outlined,
          readOnly: widget.initialEmail != null, // If email is pre-filled, make it read-only (optional)
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _sendCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
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
          hint: '请输入验证码',
          icon: Icons.security,
        ),
        const SizedBox(height: 16),
        if (_countdown > 0)
          Text(
            '$_countdown秒后可重新发送',
            style: const TextStyle(color: AppColors.textSecondary),
          )
        else
          TextButton(
            onPressed: _sendCode,
            child: const Text('重新发送'),
          ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _verifyCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              '下一步',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      children: [
        _buildTextField(
          controller: _newPasswordController,
          label: '新密码',
          hint: '请输入新密码（至少6位）',
          icon: Icons.lock_outline,
          obscureText: true,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _confirmPasswordController,
          label: '确认新密码',
          hint: '请再次输入新密码',
          icon: Icons.lock_outline,
          obscureText: true,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _resetPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
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
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppColors.textSecondary),
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
