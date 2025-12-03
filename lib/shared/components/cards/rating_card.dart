import 'package:flutter/material.dart';
import 'package:sse_market_x/core/models/post_model.dart';
import 'package:sse_market_x/shared/components/cards/post_card.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

/// 打分帖子卡片组件
class RatingCard extends StatelessWidget {
  final PostModel post;
  final bool isDense;
  final VoidCallback? onTap;
  final Future<bool> Function()? onLikeTap;

  const RatingCard({
    super.key,
    required this.post,
    this.isDense = false,
    this.onTap,
    this.onLikeTap,
  });

  int _getTotalRatings() {
    return post.stars.fold(0, (sum, count) => sum + count);
  }

  @override
  Widget build(BuildContext context) {
    if (isDense) {
      return PostCard(
        post: post,
        isDense: isDense,
        showRating: false,
        topWidget: _buildEmbeddedRating(context),
        onTap: onTap,
        onLikeTap: onLikeTap,
      );
    }

    return Stack(
      children: [
        PostCard(
          post: post,
          isDense: isDense,
          showRating: false,
          onTap: onTap,
          onLikeTap: onLikeTap,
        ),
        // 评分徽章 - 右上角
        Positioned(
          top: 16,
          right: 16,
          child: _buildRatingBadge(context),
        ),
      ],
    );
  }

  Widget _buildEmbeddedRating(BuildContext context) {
    final totalRatings = _getTotalRatings();
    
    return Row(
      children: [
        // Rating Capsule
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.ratingBg, // Light blue background
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.star_rounded,
                size: 16,
                color: AppColors.ratingStar, // Primary blue
              ),
              const SizedBox(width: 4),
              Text(
                post.rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ratingText, // Primary blue
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$totalRatings人评分',
          style: TextStyle(
            fontSize: 12,
            color: context.textSecondaryColor,
          ),
        ),
        
        const Spacer(), // Push partition to the right
        
        // Partition info
        if (post.partition.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: context.backgroundColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '#${post.partition}',
              style: TextStyle(
                fontSize: 11,
                color: context.textSecondaryColor,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRatingBadge(BuildContext context) {
    final totalRatings = _getTotalRatings();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                post.rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 3),
              const Icon(
                Icons.star,
                size: 16,
                color: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '$totalRatings人',
            style: TextStyle(
              fontSize: 11,
              color: context.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
