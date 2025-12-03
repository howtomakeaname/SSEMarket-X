import 'package:flutter/material.dart';
import 'package:sse_market_x/shared/theme/app_colors.dart';

/// 评分分布组件 - 简洁风格
class RatingDistribution extends StatelessWidget {
  final List<int> stars; // 1-5星的数量 [1星数, 2星数, 3星数, 4星数, 5星数]
  final double averageRating;
  final int userRating;
  final bool isMobile;
  final bool showUserRating;
  final Function(int rating)? onRatingClick;

  const RatingDistribution({
    super.key,
    required this.stars,
    required this.averageRating,
    this.userRating = 0,
    this.isMobile = false,
    this.showUserRating = true,
    this.onRatingClick,
  });

  int get _totalRatings => stars.fold(0, (sum, count) => sum + count);

  List<int> get _normalizedStars {
    if (stars.length == 5) return stars;
    final list = List<int>.from(stars);
    while (list.length < 5) {
      list.add(0);
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity, // Ensure full width
      decoration: BoxDecoration(
        color: context.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 上部分：平均分和总人数 + 我的评分
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧：平均分
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        averageRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.ratingText, // Changed to gold/amber
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: Text(
                          '分',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF757575), // Colors.grey[600]
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_totalRatings 人参与',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF757575), // Colors.grey[600]
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // 右侧：我的评分
              if (showUserRating)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      '我的评分',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF757575), // Colors.grey[600]
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: List.generate(5, (index) {
                        final starNum = index + 1;
                        return GestureDetector(
                          onTap: () => onRatingClick?.call(starNum),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.star,
                              size: 24,
                              color: starNum <= userRating
                                  ? AppColors.primary
                                  : const Color(0xFFE0E0E0), // Colors.grey[300]
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userRating > 0 ? '$userRating 分' : '点击评分',
                      style: TextStyle(
                        fontSize: 11,
                        color: userRating > 0 ? AppColors.primary : const Color(0xFF9E9E9E), // Colors.grey[500]
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          // 下部分：评分分布条
          _buildRatingBars(),
        ],
      ),
    );
  }

  Widget _buildRatingBars() {
    final starCounts = _normalizedStars;
    return Column(
      children: List.generate(5, (index) {
        final starLevel = 5 - index;
        final count = starCounts.length > starLevel - 1 ? starCounts[starLevel - 1] : 0;
        final percentage = _totalRatings > 0 ? count / _totalRatings : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '$starLevel星',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF757575), // Colors.grey[600]
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5), // Colors.grey[100]
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Stack(
                    children: [
                      // 背景槽
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEEEEE), // Colors.grey[200]
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      // 进度条
                      if (percentage > 0)
                        FractionallySizedBox(
                          widthFactor: percentage,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.ratingStar, // Primary blue
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text(
                  '$count', // Show count instead of percentage
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF757575), // Colors.grey[600]
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
