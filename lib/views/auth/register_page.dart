import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/shared/components/layout/auth_desktop_layout.dart';
import 'package:sse_market_x/shared/components/loading/loading_indicator.dart';
import 'package:sse_market_x/shared/components/utils/snackbar_helper.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

class RegisterPage extends StatefulWidget {
  final ApiService apiService;
  final bool fromLogin;

  const RegisterPage({super.key, required this.apiService, this.fromLogin = false});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  int _currentStep = 1;
  bool _isLoading = false;
  
  // Step 1
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _cdKeyController = TextEditingController();
  
  // Step 2
  final TextEditingController _valiCodeController = TextEditingController();
  Timer? _countdownTimer;
  int _countdown = 0;
  
  // Step 3
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _password2Controller = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _cdKeyController.dispose();
    _valiCodeController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _password2Controller.dispose();
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
    if (_cdKeyController.text.trim().isEmpty) {
      _showMessage('请输入邀请码');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await widget.apiService.sendCode(_emailController.text.trim(), 0); // 0: Register

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
    // Actual validation happens at registration
    setState(() {
      _currentStep = 3;
    });
  }

  Future<void> _register() async {
    if (_usernameController.text.trim().isEmpty) {
      _showMessage('请输入用户名');
      return;
    }
    if (_passwordController.text.length < 6) {
      _showMessage('密码长度至少6位');
      return;
    }
    if (_passwordController.text != _password2Controller.text) {
      _showMessage('两次输入的密码不一致');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final data = {
      'CDKey': _cdKeyController.text.trim(),
      'email': _emailController.text.trim(),
      'name': _usernameController.text.trim(),
      'password': _passwordController.text,
      'password2': _password2Controller.text,
      'phone': '',
      'valiCode': _valiCodeController.text.trim(),
    };

    final result = await widget.apiService.register(data);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      if (result.isEmpty) {
        _showMessage('注册成功，请登录');
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
        titleSpacing: 0,
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
          '注册',
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
                    '注册新账号',
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
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _cdKeyController,
          label: '邀请码',
          hint: '请输入邀请码',
          icon: Icons.key_outlined,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: (_emailController.text.trim().isNotEmpty && _cdKeyController.text.trim().isNotEmpty) ? _sendCode : null,
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
                '已有账号？',
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
          hint: '请输入验证码',
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
                  onPressed: () {
                    setState(() {
                      _currentStep--;
                    });
                  },
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
                  onPressed: _valiCodeController.text.trim().isNotEmpty ? _verifyCode : null,
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
        _buildTextField(
          controller: _usernameController,
          label: '用户名',
          hint: '请输入用户名',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _passwordController,
          label: '密码',
          hint: '请输入密码（至少6位）',
          icon: Icons.lock_outline,
          obscureText: true,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _password2Controller,
          label: '确认密码',
          hint: '请再次输入密码',
          icon: Icons.lock_outline,
          obscureText: true,
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _currentStep--;
                    });
                  },
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
                  onPressed: (_usernameController.text.trim().isNotEmpty &&
                          _passwordController.text.length >= 6 &&
                          _password2Controller.text.isNotEmpty)
                      ? _register
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '注册',
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
}
