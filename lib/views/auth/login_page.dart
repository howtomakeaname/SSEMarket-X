import 'package:flutter/material.dart';

import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/utils/email_validator.dart';
import 'package:sse_market_x/core/services/storage_service.dart';
import 'package:sse_market_x/views/auth/register_page.dart';
import 'package:sse_market_x/views/auth/reset_password_page.dart';
import 'package:sse_market_x/shared/components/layout/auth_desktop_layout.dart';
import 'package:sse_market_x/shared/components/utils/snackbar_helper.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';
import 'package:sse_market_x/views/index_page.dart';

const Color appBackgroundColor = AppColors.background;
const Color appSurfaceColor = AppColors.surface;
const Color appTextPrimary = AppColors.textPrimary;
const Color appTextSecondary = AppColors.textSecondary;
const Color appPrimaryColor = AppColors.primary;
const Color appDividerColor = AppColors.divider;

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appSurfaceColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 800) {
            return AuthDesktopLayout(
              enableScroll: false,
              child: Navigator(
                onGenerateRoute: (settings) {
                  return MaterialPageRoute(
                    builder: (_) => const LoginForm(isEmbedded: true),
                  );
                },
              ),
            );
          }
          return const LoginForm(isEmbedded: false);
        },
      ),
    );
  }
}

class LoginForm extends StatefulWidget {
  final bool isEmbedded;
  const LoginForm({super.key, this.isEmbedded = false});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _rememberMe = true;
  bool _obscurePassword = true;

  final ApiService _apiService = ApiService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLoginPressed() async {
    if (_isLoading) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    
    if (email.isEmpty || password.isEmpty) {
      SnackBarHelper.show(context, '请输入邮箱和密码');
      return;
    }

    // 邮箱验证
    final validation = EmailValidator.validateEmail(email);
    if (!validation.isValid) {
      SnackBarHelper.show(context, validation.message);
      return;
    }

    setState(() {
      _isLoading = true;
    });
    try {
      final token = await _apiService.login(email, password);

      if (!mounted) return;

      if (token.isNotEmpty) {
        // 设置 token 以便后续请求使用
        _apiService.setToken(token);

        // 获取用户信息
        final user = await _apiService.getUserInfo();

        if (!mounted) return;

        if (user.userId != 0) { // 简单检查 user 是否有效
           // 保存用户信息
           await StorageService().setUser(user, token, rememberMe: _rememberMe);
           
           SnackBarHelper.show(context, '登录成功');

           // Use rootNavigator: true to ensure we navigate out of the nested navigator if embedded
           Navigator.of(context, rootNavigator: true).pushReplacement(
             MaterialPageRoute(builder: (_) => IndexPage(apiService: _apiService)),
           );
        } else {
           SnackBarHelper.show(context, '获取用户信息失败');
        }
      } else {
        SnackBarHelper.show(context, '登录失败，请检查邮箱和密码', duration: const Duration(seconds: 2));
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.show(context, '登录出现错误: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onRegisterPressed() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RegisterPage(apiService: _apiService, fromLogin: true)),
    );
  }

  void _onResetPasswordPressed() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ResetPasswordPage(apiService: _apiService, fromLogin: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (widget.isEmbedded) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: Text(
                    '欢迎回来',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: appTextPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    '登录账号以继续',
                    style: TextStyle(
                      fontSize: 16,
                      color: appTextSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                _buildForm(theme, isDesktop: true),
                _buildFooter(theme),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: appSurfaceColor,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildHeader(),
            _buildForm(theme),
            _buildFooter(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 60, bottom: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/logo.png',
            width: 80,
            height: 80,
          ),
          const SizedBox(height: 16),
          const Text(
            'SSE Market',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: appPrimaryColor,
            ),
          ),
          SizedBox(height: 8),
          const Text(
            '软工集市',
            style: TextStyle(
              fontSize: 18,
              color: appTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(ThemeData theme, {bool isDesktop = false}) {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final canSubmit = !_isLoading && email.isNotEmpty && password.isNotEmpty;

    return Padding(
      padding: isDesktop ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildLabeledField(
            label: '邮箱',
            child: _buildTextField(
              controller: _emailController,
              hintText: '请输入邮箱',
              keyboardType: TextInputType.emailAddress,
            ),
          ),
          const SizedBox(height: 20),
          _buildLabeledField(
            label: '密码',
            child: _buildPasswordField(),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Checkbox(
                value: _rememberMe,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _rememberMe = value;
                  });
                },
                activeColor: appPrimaryColor,
              ),
              const SizedBox(width: 8),
              const Text(
                '记住我',
                style: TextStyle(
                  fontSize: 14,
                  color: appTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canSubmit ? _onLoginPressed : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: appPrimaryColor,
                disabledBackgroundColor: appPrimaryColor.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      '登录',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabeledField({
    required String label,
    required Widget child,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: appTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    String? hintText,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return SizedBox(
      height: 50,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        onChanged: (_) {
          setState(() {});
        },
        decoration: InputDecoration(
          hintText: hintText,
          filled: true,
          fillColor: appBackgroundColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return SizedBox(
      height: 50,
      child: TextField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        onChanged: (_) {
          setState(() {});
        },
        decoration: InputDecoration(
          hintText: '请输入密码',
          filled: true,
          fillColor: appBackgroundColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: appTextSecondary,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 40, bottom: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '还没账号？',
                style: TextStyle(
                  fontSize: 14,
                  color: appTextSecondary,
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: _onRegisterPressed,
                child: const Text(
                  '立即注册',
                  style: TextStyle(
                    fontSize: 14,
                    color: appPrimaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _onResetPasswordPressed,
            child: const Text(
              '忘记密码了？',
              style: TextStyle(
                fontSize: 14,
                color: appPrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
