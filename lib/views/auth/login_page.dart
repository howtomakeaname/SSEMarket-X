import 'package:flutter/material.dart';

import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/utils/email_validator.dart';
import 'package:sse_market_x/core/services/storage_service.dart';
import 'package:sse_market_x/views/auth/register_page.dart';
import 'package:sse_market_x/views/auth/reset_password_page.dart';
import 'package:sse_market_x/views/auth/terms_of_service_page.dart';
import 'package:sse_market_x/views/auth/privacy_policy_page.dart';
import 'package:sse_market_x/shared/components/layout/auth_desktop_layout.dart';
import 'package:sse_market_x/shared/components/utils/snackbar_helper.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';
import 'package:sse_market_x/views/index_page.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaceColor,
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
  bool _agreedToTerms = true;
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

    final validation = EmailValidator.validateEmail(email);
    if (!validation.isValid) {
      SnackBarHelper.show(context, validation.message);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final token = await _apiService.login(email, password);
      if (!mounted) return;

      if (token.isNotEmpty) {
        _apiService.setToken(token);
        final user = await _apiService.getUserInfo();
        if (!mounted) return;

        if (user.userId != 0) {
          await StorageService().setUser(user, token, rememberMe: true);
          if (!mounted) return;
          SnackBarHelper.show(context, '登录成功');
          Navigator.of(context, rootNavigator: true).pushReplacement(
            MaterialPageRoute(
                builder: (_) => IndexPage(apiService: _apiService)),
          );
        } else {
          SnackBarHelper.show(context, '获取用户信息失败');
        }
      } else {
        SnackBarHelper.show(context, '登录失败，请检查邮箱和密码');
      }
    } catch (e) {
      if (mounted) SnackBarHelper.show(context, '登录出现错误: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onRegisterPressed() {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) =>
              RegisterPage(apiService: _apiService, fromLogin: true)),
    );
  }

  void _onResetPasswordPressed() {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) =>
              ResetPasswordPage(apiService: _apiService, fromLogin: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEmbedded) {
      return _buildDesktopLayout();
    }
    return _buildMobileLayout();
  }

  Widget _buildDesktopLayout() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Text(
                  '欢迎回来',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimaryColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '登录账号以继续',
                  style: TextStyle(
                    fontSize: 15,
                    color: context.textSecondaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              _buildForm(isDesktop: true),
              const SizedBox(height: 32),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SafeArea(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: context.surfaceColor,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                _buildHeader(),
                const SizedBox(height: 48),
                _buildForm(),
                const SizedBox(height: 24),
                _buildFooter(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            'assets/images/logo.png',
            width: 80,
            height: 80,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'SSE Market',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '软工集市',
          style: TextStyle(
            fontSize: 14,
            color: context.textSecondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildForm({bool isDesktop = false}) {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final canSubmit =
        !_isLoading && email.isNotEmpty && password.isNotEmpty && _agreedToTerms;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField(
          controller: _emailController,
          hintText: '邮箱',
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.email_outlined,
        ),
        const SizedBox(height: 16),
        _buildPasswordField(),
        const SizedBox(height: 20),
        _buildAgreementRow(),
        const SizedBox(height: 24),
        _buildLoginButton(canSubmit),
      ],
    );
  }

  Widget _buildLoginButton(bool canSubmit) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: canSubmit ? _onLoginPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
              disabledForegroundColor: Colors.white.withOpacity(0.6),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                '登录',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }

  Widget _buildAgreementRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Checkbox(
            value: _agreedToTerms,
            onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
            activeColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            side: BorderSide(
              color: context.textTertiaryColor,
              width: 1.5,
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '已阅读并同意',
                style: TextStyle(
                  fontSize: 13,
                  color: context.textSecondaryColor,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TermsOfServicePage()),
                ),
                child: const Text(
                  '《服务协议》',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '和',
                style: TextStyle(
                  fontSize: 13,
                  color: context.textSecondaryColor,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                ),
                child: const Text(
                  '《隐私政策》',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    String? hintText,
    TextInputType? keyboardType,
    IconData? prefixIcon,
  }) {
    // 登录页面背景是白色，输入框使用浅灰色背景以区分
    final inputBgColor =
        context.isDark ? context.inputFillColor : context.backgroundColor;

    return SizedBox(
      height: 52,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: (_) => setState(() {}),
        style: TextStyle(
          color: context.textPrimaryColor,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: context.textTertiaryColor,
            fontSize: 15,
          ),
          filled: true,
          fillColor: inputBgColor,
          prefixIcon: prefixIcon != null
              ? Padding(
                  padding: const EdgeInsets.only(left: 16, right: 12),
                  child: Icon(
                    prefixIcon,
                    color: context.textTertiaryColor,
                    size: 20,
                  ),
                )
              : null,
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.primary,
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    // 登录页面背景是白色，输入框使用浅灰色背景以区分
    final inputBgColor =
        context.isDark ? context.inputFillColor : context.backgroundColor;

    return SizedBox(
      height: 52,
      child: TextField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        onChanged: (_) => setState(() {}),
        style: TextStyle(
          color: context.textPrimaryColor,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: '密码',
          hintStyle: TextStyle(
            color: context.textTertiaryColor,
            fontSize: 15,
          ),
          filled: true,
          fillColor: inputBgColor,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(
              Icons.lock_outline,
              color: context.textTertiaryColor,
              size: 20,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.primary,
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: context.textTertiaryColor,
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 忘记密码放在右侧
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: _onResetPasswordPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '忘记密码？',
                style: TextStyle(
                  fontSize: 13,
                  color: context.textSecondaryColor,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // 分割线
        Row(
          children: [
            Expanded(child: Divider(color: context.dividerColor)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '还没有账号？',
                style: TextStyle(
                  fontSize: 13,
                  color: context.textTertiaryColor,
                ),
              ),
            ),
            Expanded(child: Divider(color: context.dividerColor)),
          ],
        ),
        const SizedBox(height: 24),
        // 注册按钮
        SizedBox(
          height: 48,
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _onRegisterPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '立即注册',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
