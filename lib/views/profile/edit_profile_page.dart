import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/models/user_model.dart';
import 'package:sse_market_x/core/services/storage_service.dart';
import 'package:sse_market_x/shared/components/utils/snackbar_helper.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

class EditProfilePage extends StatefulWidget {
  final ApiService apiService;
  final UserModel initialUser;

  const EditProfilePage({
    super.key,
    required this.apiService,
    required this.initialUser,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _introController;
  String _avatarUrl = '';
  bool _isSubmitting = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _avatarUrl = widget.initialUser.avatar;
    _nameController = TextEditingController(text: widget.initialUser.name);
    _introController = TextEditingController(text: widget.initialUser.intro);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _introController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    try {
      final bytes = await image.readAsBytes();
      final url = await widget.apiService.uploadPhoto(bytes, image.name);
      if (url != null) {
        setState(() {
          _avatarUrl = url;
        });
        SnackBarHelper.show(context, '头像上传成功');
      } else {
        SnackBarHelper.show(context, '头像上传失败');
      }
    } catch (e) {
      SnackBarHelper.show(context, '头像上传失败');
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final intro = _introController.text.trim();

    final originalName = widget.initialUser.name;
    final originalIntro = widget.initialUser.intro;
    final originalAvatar = widget.initialUser.avatar;

    if (name.isEmpty) {
      SnackBarHelper.show(context, '昵称不能为空');
      return;
    }

    // 简单防注入与非法字符校验
    final invalidPattern = RegExp(r'[<>]');
    if (invalidPattern.hasMatch(name) || invalidPattern.hasMatch(intro)) {
      SnackBarHelper.show(context, '内容中包含非法字符，请不要使用 < 或 >');
      return;
    }

    // 如果头像、昵称、简介都没有任何变化，则不提交
    if (_avatarUrl == originalAvatar && name == originalName && intro == originalIntro) {
      SnackBarHelper.show(context, '您还没有修改任何内容');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final success = await widget.apiService.updateUserInfo(
        avatarUrl: _avatarUrl,
        intro: intro,
        name: name,
        userId: widget.initialUser.userId,
      );

      if (!success) {
        if (mounted) {
          SnackBarHelper.show(context, '保存失败，请稍后重试');
        }
        return;
      }

      // 刷新用户信息并更新本地存储
      final basic = await widget.apiService.getUserInfo();
      UserModel detailed = basic;
      if (basic.phone.isNotEmpty) {
        final d = await widget.apiService.getDetailedUserInfo(basic.phone);
        detailed = basic.copyWith(score: d.score, intro: d.intro, avatar: d.avatar, name: d.name);
      }

      final storage = StorageService();
      final token = storage.token;
      await storage.setUser(detailed, token, rememberMe: storage.rememberMe);

      if (mounted) {
        SnackBarHelper.show(context, '修改成功');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.show(context, '保存失败，请检查网络');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '修改资料',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
        titleSpacing: 0,
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: Text(
              '提交',
              style: TextStyle(
                fontSize: 16,
                color: _isSubmitting ? AppColors.textSecondary : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 头像卡片
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _isSubmitting ? null : _pickAvatar,
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.background,
                      backgroundImage: _avatarUrl.isNotEmpty ? NetworkImage(_avatarUrl) : null,
                      child: _avatarUrl.isEmpty
                          ? const Icon(Icons.person, size: 40, color: AppColors.textSecondary)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '点击修改头像',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 信息编辑卡片
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '昵称',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _nameController,
                      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: '请输入昵称',
                        hintStyle: TextStyle(fontSize: 14, color: AppColors.textTertiary),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    '个人简介',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _introController,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: '简单介绍一下自己吧',
                        hintStyle: TextStyle(fontSize: 14, color: AppColors.textTertiary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
