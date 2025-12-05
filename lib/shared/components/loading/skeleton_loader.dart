import 'package:flutter/material.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

/// 骨架屏加载组件 - 提供更自然的加载体验
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
    
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(4),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: isDark
                  ? [
                      context.backgroundColor,
                      context.backgroundColor.withOpacity(0.7),
                      context.backgroundColor,
                    ]
                  : [
                      context.dividerColor.withOpacity(0.3),
                      context.dividerColor.withOpacity(0.15),
                      context.dividerColor.withOpacity(0.3),
                    ],
              stops: [
                _animation.value - 0.3,
                _animation.value,
                _animation.value + 0.3,
              ].map((e) => e.clamp(0.0, 1.0)).toList(),
            ),
          ),
        );
      },
    );
  }
}

/// 帖子卡片骨架屏
class PostCardSkeleton extends StatelessWidget {
  final bool isDense;

  const PostCardSkeleton({
    super.key,
    this.isDense = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: isDense ? const EdgeInsets.all(12) : const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 非紧凑模式显示用户信息行
          if (!isDense) ...[
            Row(
              children: [
                SkeletonLoader(
                  width: 40,
                  height: 40,
                  borderRadius: BorderRadius.circular(20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLoader(
                        width: 100,
                        height: 16,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 4),
                      SkeletonLoader(
                        width: 60,
                        height: 12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          // 标题 - 更接近实际高度
          SkeletonLoader(
            width: double.infinity,
            height: isDense ? 16 : 18,
            borderRadius: BorderRadius.circular(4),
          ),
          if (!isDense) ...[
            const SizedBox(height: 6),
            SkeletonLoader(
              width: MediaQuery.of(context).size.width * 0.6,
              height: 18,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
          SizedBox(height: isDense ? 4 : 8),
          // 内容预览 - 非紧凑模式显示
          if (!isDense) ...[
            SkeletonLoader(
              width: double.infinity,
              height: 14,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 6),
            SkeletonLoader(
              width: double.infinity,
              height: 14,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 6),
            SkeletonLoader(
              width: MediaQuery.of(context).size.width * 0.5,
              height: 14,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 12),
          ],
          // 底部统计信息 - 使用更真实的间距
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMetaSkeleton(),
              _buildMetaSkeleton(),
              _buildMetaSkeleton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaSkeleton() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SkeletonLoader(
          width: 18,
          height: 18,
          borderRadius: BorderRadius.circular(2),
        ),
        const SizedBox(width: 4),
        SkeletonLoader(
          width: 30,
          height: 13,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}

/// 商品卡片骨架屏
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 商品图片 - 使用 Expanded 保持比例
          Expanded(
            child: Container(
              width: double.infinity,
              color: context.backgroundColor,
              child: Center(
                child: Icon(
                  Icons.image_outlined,
                  size: 48,
                  color: context.dividerColor,
                ),
              ),
            ),
          ),
          // 商品信息
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 商品名称
                SkeletonLoader(
                  width: double.infinity,
                  height: 14,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 4),
                // 价格
                Row(
                  children: [
                    SkeletonLoader(
                      width: 70,
                      height: 16,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 列表骨架屏 - 显示多个帖子卡片骨架
class PostListSkeleton extends StatelessWidget {
  final int itemCount;
  final bool isDense;

  const PostListSkeleton({
    super.key,
    this.itemCount = 3,
    this.isDense = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return PostCardSkeleton(isDense: isDense);
      },
    );
  }
}

/// 网格骨架屏 - 显示多个商品卡片骨架
class ProductGridSkeleton extends StatelessWidget {
  final int itemCount;

  const ProductGridSkeleton({
    super.key,
    this.itemCount = 4,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return const ProductCardSkeleton();
      },
    );
  }
}

/// 评论骨架屏 - 与 CommentCard 样式保持一致
class CommentSkeleton extends StatelessWidget {
  const CommentSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 用户信息行
          Row(
            children: [
              // 头像
              SkeletonLoader(
                width: 32,
                height: 32,
                borderRadius: BorderRadius.circular(16),
              ),
              const SizedBox(width: 8),
              // 用户名和时间
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SkeletonLoader(
                          width: 70,
                          height: 14,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(width: 4),
                        SkeletonLoader(
                          width: 24,
                          height: 10,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    SkeletonLoader(
                      width: 50,
                      height: 12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 评论内容
          SkeletonLoader(
            width: double.infinity,
            height: 14,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          // 操作按钮行
          Row(
            children: [
              // 点赞
              SkeletonLoader(
                width: 40,
                height: 12,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(width: 16),
              // 回复
              SkeletonLoader(
                width: 40,
                height: 12,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 评论列表骨架屏
class CommentListSkeleton extends StatelessWidget {
  final int itemCount;

  const CommentListSkeleton({
    super.key,
    this.itemCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 与真实评论列表的 padding 保持一致，包括顶部 12px 间距
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: List.generate(
          itemCount,
          (index) => const CommentSkeleton(),
        ),
      ),
    );
  }
}
