import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/services/storage_service.dart';
import 'package:sse_market_x/shared/components/media/image_editor.dart';
import 'package:sse_market_x/shared/components/loading/loading_indicator.dart';
import 'package:sse_market_x/shared/components/utils/snackbar_helper.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

/// 发布闲置物品页面
class CreateProductPage extends StatefulWidget {
  final ApiService apiService;

  const CreateProductPage({
    super.key,
    required this.apiService,
  });

  @override
  State<CreateProductPage> createState() => _CreateProductPageState();
}

class _CreateProductPageState extends State<CreateProductPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final List<Uint8List> _selectedImages = []; // 存储编辑后的图片字节
  final int _maxImages = 5;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickAndEditImage() async {
    if (_selectedImages.length >= _maxImages) {
      SnackBarHelper.show(context, '最多只能上传$_maxImages张图片');
      return;
    }

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
    );

    if (image == null) return;

    final imageBytes = await image.readAsBytes();

    if (!mounted) return;

    // 打开图片编辑器
    final editedBytes = await ImageEditorPage.show(
      context,
      imageBytes: imageBytes,
      enableCrop: true,
      enableAdjust: true,
    );

    if (editedBytes != null && mounted) {
      setState(() {
        _selectedImages.add(editedBytes);
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  bool _validateForm() {
    if (_nameController.text.trim().isEmpty) {
      SnackBarHelper.show(context, '请输入商品名称');
      return false;
    }
    if (_priceController.text.trim().isEmpty) {
      SnackBarHelper.show(context, '请输入商品价格');
      return false;
    }
    final price = int.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) {
      SnackBarHelper.show(context, '请输入有效的商品价格');
      return false;
    }
    if (_descriptionController.text.trim().isEmpty) {
      SnackBarHelper.show(context, '请输入商品描述');
      return false;
    }
    return true;
  }


  Future<void> _submitProduct() async {
    if (!_validateForm()) return;
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 上传图片
      final List<String> imageUrls = [];
      for (int i = 0; i < _selectedImages.length; i++) {
        final bytes = _selectedImages[i];
        final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}_$i.png';
        final url = await widget.apiService.uploadPhoto(bytes, fileName);
        if (url != null) {
          imageUrls.add(url);
        } else {
          if (mounted) {
            SnackBarHelper.show(context, '部分图片上传失败，请重试');
            setState(() {
              _isSubmitting = false;
            });
          }
          return;
        }
      }

      // 发布商品
      final user = StorageService().user;
      if (user == null || user.userId == 0) {
        if (mounted) {
          SnackBarHelper.show(context, '请先登录');
          setState(() {
            _isSubmitting = false;
          });
        }
        return;
      }

      final success = await widget.apiService.postProduct(
        userId: user.userId,
        price: int.parse(_priceController.text.trim()),
        title: _nameController.text.trim(),
        content: _descriptionController.text.trim(),
        photos: imageUrls,
      );

      if (mounted) {
        if (success) {
          SnackBarHelper.show(context, '发布成功');
          Navigator.of(context).pop(true);
        } else {
          SnackBarHelper.show(context, '发布失败，请重试');
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.show(context, '发布失败: $e');
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.textPrimaryColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '发布闲置',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.textPrimaryColor,
          ),
        ),
        centerTitle: false,
        titleSpacing: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: TextButton(
              onPressed: _isSubmitting ? null : _submitProduct,
              child: Text(
                '发布',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _isSubmitting ? context.textTertiaryColor : AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isSubmitting
          ? const LoadingIndicator.center(message: '发布中...')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField(
                    controller: _nameController,
                    label: '商品名称',
                    hint: '请输入商品名称',
                  ),
                  const SizedBox(height: 16),
                  _buildPriceField(),
                  const SizedBox(height: 16),
                  _buildImagePicker(),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _descriptionController,
                    label: '商品描述',
                    hint: '请输入商品详细描述',
                    maxLines: 6,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }


  Widget _buildPriceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '商品价格',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: context.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _priceController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(color: context.textPrimaryColor),
          decoration: InputDecoration(
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 16, right: 8),
              child: Text(
                '¥',
                style: TextStyle(
                  color: context.textPrimaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            hintText: '请输入价格（整数）',
            hintStyle: TextStyle(color: context.textTertiaryColor),
            filled: true,
            fillColor: context.surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
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
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: context.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(color: context.textPrimaryColor),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: context.textTertiaryColor),
            filled: true,
            fillColor: context.surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '商品图片（最多$_maxImages张）',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: context.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ..._selectedImages.asMap().entries.map((entry) {
                return _buildImageItem(entry.key, entry.value);
              }),
              if (_selectedImages.length < _maxImages) _buildAddImageButton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageItem(int index, Uint8List imageBytes) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            imageBytes,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeImage(index),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddImageButton() {
    return GestureDetector(
      onTap: _pickAndEditImage,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: context.backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: context.dividerColor,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add,
              size: 24,
              color: context.textSecondaryColor,
            ),
            const SizedBox(height: 4),
            Text(
              '添加',
              style: TextStyle(
                fontSize: 12,
                color: context.textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

}
