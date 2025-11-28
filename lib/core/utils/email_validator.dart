class EmailValidator {
  static const List<String> validDomains = [
    'mail.sysu.edu.cn',
    'mail2.sysu.edu.cn',
    'mail3.sysu.edu.cn',
    'stu.sysu.edu.cn',
    'alumni.sysu.edu.cn',
    'sysu.edu.cn',
    'sysu.org.cn',
    'qq.com',
    '126.com',
    '163.com',
    'sina.com',
    'gmail.com',
    'yahoo.com',
    'yandex.com',
    'foxmail.com',
    'outlook.com',
    'hotmail.com',
    'msn.cn',
    'live.com',
    'live.cn',
    '139.com',
    '189.com',
    'sina.com',
    'sina.cn',
  ];

  static ({bool isValid, String message}) validateEmail(String email) {
    if (email.trim().isEmpty) {
      return (isValid: false, message: '请输入邮箱地址');
    }

    // 基本邮箱格式验证
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      return (isValid: false, message: '邮箱格式不正确');
    }

    // 域名验证
    final parts = email.split('@');
    if (parts.length != 2) {
       return (isValid: false, message: '邮箱格式不正确');
    }
    final domain = parts[1].toLowerCase();
    if (!validDomains.contains(domain)) {
      return (isValid: false, message: '暂不支持该类邮箱，请联系管理员');
    }

    return (isValid: true, message: '邮箱验证通过');
  }
}
