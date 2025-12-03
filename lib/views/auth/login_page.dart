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
          SnackBarHelper.show(context, '登录成功');
          Navigator.of(context, rootNavigator: true).pushReplacement(
            MaterialPageRoute(builder: (_) => IndexPage(apiService: _apiService)),
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
                Center(
                  child: Text(
                    '欢迎回来',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '登录账号以继续',
                    style: TextStyle(fontSize: 16, color: context.textSecondaryColor),
                  ),
                ),
                const SizedBox(height: 48),
                _buildForm(isDesktop: true),
                _buildFooter(),
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
        color: context.surfaceColor,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildHeader(),
            _buildForm(),
            _buildFooter(),
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
          Image.asset('assets/images/logo.png', width: 80, height: 80),
          const SizedBox(height: 16),
          const Text(
            'SSE Market',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '软工集市',
            style: TextStyle(fontSize: 18, color: context.textSecondaryColor),
          ),
        ],
      ),
    );
  }


  Widget _buildForm({bool isDesktop = false}) {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final canSubmit = !_isLoading && email.isNotEmpty && password.isNotEmpty && _agreedToTerms;

    return Padding(
      padding: isDesktop ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildLabeledField(label: '邮箱', child: _buildTextField(
            controller: _emailController,
            hintText: '请输入邮箱',
            keyboardType: TextInputType.emailAddress,
          )),
          const SizedBox(height: 20),
          _buildLabeledField(label: '密码', child: _buildPasswordField()),
          const SizedBox(height: 20),
          _buildAgreementRow(),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: canSubmit ? _onLoginPressed : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                    )
                  : const Text('登录', style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgreementRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 24, height: 24,
          child: Checkbox(
            value: _agreedToTerms,
            onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
            activeColor: AppColors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('已阅读并同意', style: TextStyle(fontSize: 14, color: context.textSecondaryColor)),
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TermsOfServicePage())),
                child: const Text('《服务协议》', style: TextStyle(fontSize: 14, color: AppColors.primary)),
              ),
              Text('和', style: TextStyle(fontSize: 14, color: context.textSecondaryColor)),
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyPage())),
                child: const Text('《隐私政策》', style: TextStyle(fontSize: 14, color: AppColors.primary)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLabeledField({required String label, required Widget child}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 16, color: context.textPrimaryColor)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    String? hintText,
    TextInputType? keyboardType,
  }) {
    return SizedBox(
      height: 50,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: (_) => setState(() {}),
        style: TextStyle(color: context.textPrimaryColor),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: context.textTertiaryColor),
          filled: true,
          fillColor: context.inputFillColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
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
        onChanged: (_) => setState(() {}),
        style: TextStyle(color: context.textPrimaryColor),
        decoration: InputDecoration(
          hintText: '请输入密码',
          hintStyle: TextStyle(color: context.textTertiaryColor),
          filled: true,
          fillColor: context.inputFillColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: context.textSecondaryColor),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 40, bottom: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('还没账号？', style: TextStyle(fontSize: 14, color: context.textSecondaryColor)),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: _onRegisterPressed,
                child: const Text('立即注册', style: TextStyle(fontSize: 14, color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _onResetPasswordPressed,
            child: const Text('忘记密码了？', style: TextStyle(fontSize: 14, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}
