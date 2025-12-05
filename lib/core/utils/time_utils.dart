/// 时间格式化工具类
class TimeUtils {
  TimeUtils._();

  /// 格式化时间为相对时间（如：刚刚、5分钟前、3小时前、2天前）
  static String formatRelativeTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) {
      return '';
    }

    try {
      final date = DateTime.parse(timeStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) {
        return '刚刚';
      }
      if (diff.inMinutes < 60) {
        return '${diff.inMinutes}分钟前';
      }
      if (diff.inHours < 24) {
        return '${diff.inHours}小时前';
      }
      if (diff.inDays < 7) {
        return '${diff.inDays}天前';
      }

      // 超过7天显示日期
      // 如果不是同一年，显示年份
      if (date.year != now.year) {
        return '${date.year}年${date.month}月${date.day}日';
      }
      
      // 同一年只显示月日
      return '${date.month}月${date.day}日';
    } catch (e) {
      return timeStr;
    }
  }

  /// 格式化为完整日期时间
  static String formatDateTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) {
      return '';
    }

    try {
      final date = DateTime.parse(timeStr);
      return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} '
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timeStr;
    }
  }

  static String formatNoticeTime(String timeStr) {
    if (timeStr.isEmpty) {
      return '';
    }
    try {
      final dateTime = DateTime.parse(timeStr).toLocal();
      final year = dateTime.year;
      final month = dateTime.month.toString().padLeft(2, '0');
      final day = dateTime.day.toString().padLeft(2, '0');
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final second = dateTime.second.toString().padLeft(2, '0');
      return '$year-$month-$day $hour:$minute:$second';
    } catch (e) {
      return timeStr;
    }
  }

}
