/// 教师标签模型
class TeacherModel {
  final int tagId;
  final String name;
  final String value;
  final String type;
  final int num;

  const TeacherModel({
    required this.tagId,
    required this.name,
    required this.value,
    required this.type,
    required this.num,
  });

  factory TeacherModel.fromDynamic(dynamic data) {
    if (data is! Map) {
      return TeacherModel.empty();
    }
    final map = data as Map<String, dynamic>;
    return TeacherModel(
      tagId: map['TagID'] as int? ?? 0,
      name: map['Name'] as String? ?? '',
      value: map['Value'] as String? ?? '',
      type: map['Type'] as String? ?? '',
      num: map['Num'] as int? ?? 0,
    );
  }

  factory TeacherModel.empty() => const TeacherModel(
        tagId: 0,
        name: '',
        value: '',
        type: '',
        num: 0,
      );

  bool get isEmpty => tagId == 0 && name.isEmpty;
}
