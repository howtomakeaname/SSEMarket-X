class UserModel {
  final int userId;
  final String name;
  final String email;
  final String phone;
  final String avatar;
  final int score;
  final String identity;
  final String intro;

  const UserModel({
    required this.userId,
    required this.name,
    required this.email,
    required this.phone,
    required this.avatar,
    required this.score,
    required this.identity,
    required this.intro,
  });

  factory UserModel.empty() {
    return const UserModel(
      userId: 0,
      name: '',
      email: '',
      phone: '',
      avatar: '',
      score: 0,
      identity: '',
      intro: '',
    );
  }

  factory UserModel.fromDynamic(dynamic raw) {
    if (raw is! Map) {
      return UserModel.empty();
    }
    final map = raw.cast<String, dynamic>();

    int _readInt(List<String> keys) {
      for (final key in keys) {
        final v = map[key];
        if (v is int) return v;
        if (v is num) return v.toInt();
        if (v is String) {
          final parsed = int.tryParse(v);
          if (parsed != null) return parsed;
        }
      }
      return 0;
    }

    String _readString(List<String> keys) {
      for (final key in keys) {
        final v = map[key];
        if (v is String) return v;
      }
      return '';
    }

    return UserModel(
      userId: _readInt(['userID', 'UserID', 'id']),
      name: _readString(['name', 'Name']),
      email: _readString(['email', 'Email']),
      phone: _readString(['phone', 'Phone']),
      avatar: _readString(['avatarURL', 'Avatar', 'avatar']),
      score: _readInt(['score', 'Score']),
      identity: _readString(['identity', 'Identity']),
      intro: _readString(['intro', 'Intro']),
    );
  }

  UserModel copyWith({
    int? userId,
    String? name,
    String? email,
    String? phone,
    String? avatar,
    int? score,
    String? identity,
    String? intro,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      score: score ?? this.score,
      identity: identity ?? this.identity,
      intro: intro ?? this.intro,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'UserID': userId,
      'Name': name,
      'Email': email,
      'Phone': phone,
      'Avatar': avatar,
      'Score': score,
      'Identity': identity,
      'Intro': intro,
    };
  }
}
