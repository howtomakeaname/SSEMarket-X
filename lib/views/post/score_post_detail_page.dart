import 'package:flutter/material.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/views/post/post_detail_page.dart';
import 'package:sse_market_x/core/services/storage_service.dart';
import 'package:sse_market_x/shared/components/utils/snackbar_helper.dart';
import 'package:sse_market_x/shared/components/stats/rating_distribution.dart';

import 'package:sse_market_x/core/models/post_model.dart';

/// 打分帖子详情页 - 复用PostDetailPage的结构，添加评分功能
class ScorePostDetailPage extends StatefulWidget {
  final int postId;
  final ApiService apiService;
  final PostModel? initialPost;

  const ScorePostDetailPage({
    super.key,
    required this.postId,
    required this.apiService,
    this.initialPost,
  });

  @override
  State<ScorePostDetailPage> createState() => _ScorePostDetailPageState();
}

class _ScorePostDetailPageState extends State<ScorePostDetailPage> {
  // 评分相关状态
  List<int> _stars = [0, 0, 0, 0, 0];
  double _averageRating = 0.0;
  int _userRating = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialPost != null) {
      if (widget.initialPost!.stars.length == 5) {
        _stars = widget.initialPost!.stars;
      } else {
        _stars = [0, 0, 0, 0, 0];
      }
      _averageRating = widget.initialPost!.rating;
      _userRating = widget.initialPost!.userRating;
    }
    _loadRatingData();
  }

  Future<void> _loadRatingData() async {
    final ratingResults = await Future.wait([
      widget.apiService.getStarsDistribution(widget.postId),
      widget.apiService.getUserPostRating(widget.postId),
      widget.apiService.getAverageRating(widget.postId),
    ]);

    if (!mounted) return;

    setState(() {
      _stars = ratingResults[0] as List<int>;
      _userRating = ratingResults[1] as int;
      _averageRating = ratingResults[2] as double;
    });
  }

  Future<void> _handleRatingClick(int rating) async {
    final oldRating = _userRating;
    setState(() {
      _userRating = rating;
    });

    try {
      final userPhone = StorageService().user?.phone;
      if (userPhone == null || userPhone.isEmpty) {
          SnackBarHelper.show(context, '请先登录');
          setState(() {
            _userRating = oldRating;
          });
          return;
      }

      final success = await widget.apiService.submitRating(
        userPhone,
        widget.postId,
        rating,
      );

      if (success) {
        // 重新获取评分分布
        final results = await Future.wait([
          widget.apiService.getStarsDistribution(widget.postId),
          widget.apiService.getAverageRating(widget.postId),
        ]);
        
        if (mounted) {
          setState(() {
            _stars = results[0] as List<int>;
            _averageRating = results[1] as double;
          });
        }
        SnackBarHelper.show(context, '评分成功');
      } else {
        if (mounted) {
          setState(() {
            _userRating = oldRating;
          });
        }
        SnackBarHelper.show(context, '评分失败');
      }
    } catch (e) {
      debugPrint('Submit rating error: $e');
      if (mounted) {
        setState(() {
          _userRating = oldRating;
        });
        SnackBarHelper.show(context, '评分失败');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PostDetailPage(
      postId: widget.postId,
      apiService: widget.apiService,
      postType: 'rating',
      topContent: RatingDistribution(
        stars: _stars,
        averageRating: _averageRating,
        userRating: _userRating,
        isMobile: MediaQuery.of(context).size.width < 600,
        showUserRating: true,
        onRatingClick: _handleRatingClick,
      ),
      onSendComment: (content) async {
        final userPhone = StorageService().user?.phone;
        if (userPhone == null || userPhone.isEmpty) {
          SnackBarHelper.show(context, '请先登录');
          return false;
        }
        return await widget.apiService.sendRatingComment(
          content,
          widget.postId,
          userPhone,
          _userRating,
        );
      },
    );
  }
}
