import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as dart_crypto;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'package:sse_market_x/core/models/user_model.dart';
import 'package:sse_market_x/core/models/post_model.dart';
import 'package:sse_market_x/core/services/storage_service.dart';
import 'package:sse_market_x/core/models/comment_model.dart';
import 'package:sse_market_x/core/models/notice_model.dart';
import 'package:sse_market_x/core/models/product_model.dart';
import 'package:sse_market_x/core/models/chat_message_model.dart';

/// 帖子列表请求参数
class GetPostsParams {
  final int limit;
  final int offset;
  final String partition;
  final String searchsort;
  final String searchinfo;
  final String userTelephone;
  final String tag;

  const GetPostsParams({
    required this.limit,
    required this.offset,
    required this.partition,
    required this.searchsort,
    required this.searchinfo,
    required this.userTelephone,
    required this.tag,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'limit': limit,
        'offset': offset,
        'partition': partition,
        'searchsort': searchsort,
        'searchinfo': searchinfo,
        'userTelephone': userTelephone,
        'tag': tag,
      };
}

/// API 服务
class ApiService {
  static const String _baseUrl = 'https://ssemarket.cn/api';

  String get token => StorageService().token;

  void setToken(String token) {
    StorageService().setToken(token);
  }

  Future<String> login(String email, String password) async {
    final encryptedPassword = _encryptPassword(password, '16bit secret key');

    final uri = Uri.parse('$_baseUrl/auth/login');
    final body = jsonEncode(<String, dynamic>{
      'email': email,
      'password': encryptedPassword,
    });

    final response = await http.post(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      return '';
    }

    final Map<String, dynamic> json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['data'];
    if (data is Map<String, dynamic> && data['token'] is String) {
      final token = data['token'] as String;
      // Token is now managed by StorageService
      return token;
    }

    return '';
  }

  String _encryptPassword(String data, String key) {
    final keyBytes = _zeroPaddedKey(key, 16);

    final sha = dart_crypto.sha256.convert(utf8.encode(key));
    final ivHex = sha.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final ivUtf8 = utf8.encode(ivHex);
    final ivBytes = Uint8List.fromList(ivUtf8.sublist(0, 16));

    final aesKey = encrypt.Key(keyBytes);
    final iv = encrypt.IV(ivBytes);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(aesKey, mode: encrypt.AESMode.cbc),
    );

    final encrypted = encrypter.encrypt(data, iv: iv);
    final result = encrypted.base64;

    return result;
  }

  Uint8List _zeroPaddedKey(String key, int length) {
    final keyBytes = utf8.encode(key);
    if (keyBytes.length == length) {
      return Uint8List.fromList(keyBytes);
    }
    if (keyBytes.length > length) {
      return Uint8List.fromList(keyBytes.sublist(0, length));
    }
    final result = Uint8List(length);
    for (var i = 0; i < keyBytes.length; i++) {
      result[i] = keyBytes[i];
    }
    return result;
  }

  Future<UserModel> getUserInfo() async {
    if (token.isEmpty) return UserModel.empty();

    final uri = Uri.parse('$_baseUrl/auth/info');
    final response = await http.get(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      return UserModel.empty();
    }

    final dynamic json = jsonDecode(response.body);

    dynamic userRaw;
    if (json is Map<String, dynamic>) {
      final data = json['data'];
      if (data is Map<String, dynamic>) {
        if (data['user'] != null) {
          userRaw = data['user'];
        } else {
          userRaw = data;
        }
      } else {
        userRaw = json;
      }
    } else {
      userRaw = json;
    }

    return UserModel.fromDynamic(userRaw);
  }

  Future<UserModel> getDetailedUserInfo(String phone) async {
    if (token.isEmpty || phone.isEmpty) return UserModel.empty();

    final uri = Uri.parse('$_baseUrl/auth/getInfo');
    final body = jsonEncode(<String, dynamic>{
      'phone': phone,
    });

    final response = await http.post(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      return UserModel.empty();
    }

    final dynamic json = jsonDecode(response.body);
    return UserModel.fromDynamic(json);
  }

  Future<UserModel> getInfoById(int userId) async {
    if (token.isEmpty || userId == 0) return UserModel.empty();

    final uri = Uri.parse('$_baseUrl/auth/getInfo');
    final body = jsonEncode(<String, dynamic>{
      'userID': userId,
    });

    final response = await http.post(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      return UserModel.empty();
    }

    final dynamic json = jsonDecode(response.body);
    return UserModel.fromDynamic(json);
  }

  /// 获取帖子列表（对应 /auth/browse）
  Future<List<PostModel>> getPosts(GetPostsParams params) async {
    if (token.isEmpty) {
      return <PostModel>[];
    }

    final uri = Uri.parse('$_baseUrl/auth/browse');
    final body = jsonEncode(params.toJson());

    final response = await http.post(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      return <PostModel>[];
    }

    final dynamic json = jsonDecode(response.body);
    if (json is List) {
      return json.map<PostModel>((e) => PostModel.fromDynamic(e)).toList();
    }
    // 某些情况下后端可能返回 { data: [...] }
    if (json is Map<String, dynamic> && json['data'] is List) {
      final list = json['data'] as List<dynamic>;
      return list.map<PostModel>((e) => PostModel.fromDynamic(e)).toList();
    }
    return <PostModel>[];
  }

  /// 点赞帖子
  Future<bool> likePost(int postId, String userPhone) async {
    if (token.isEmpty || userPhone.isEmpty) return false;

    final uri = Uri.parse('$_baseUrl/auth/updateLike');
    final body = jsonEncode(<String, dynamic>{
      'postID': postId,
      'userTelephone': userPhone,
    });

    try {
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      return response.statusCode == 200;
    } catch (e) {
      // ignore: avoid_print
      print('点赞失败: $e');
      return false;
    }
  }

  /// 获取帖子详情
  Future<PostModel> getPostDetail(int postId, String userPhone) async {
    if (token.isEmpty) return PostModel.empty();

    final uri = Uri.parse('$_baseUrl/auth/showDetails');
    final body = jsonEncode(<String, dynamic>{
      'postID': postId,
      'userTelephone': userPhone,
    });

    try {
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (response.statusCode != 200) {
        return PostModel.empty();
      }

      final dynamic json = jsonDecode(response.body);
      if (json is Map<String, dynamic> && json['data'] != null) {
        return PostModel.fromDynamic(json['data']);
      }
      return PostModel.fromDynamic(json);
    } catch (e) {
      // ignore: avoid_print
      print('获取帖子详情失败: $e');
      return PostModel.empty();
    }
  }

  /// 获取帖子评论列表
  Future<List<CommentModel>> getComments(int postId, String userPhone, {String postType = 'post'}) async {
    if (token.isEmpty) return [];

    final uri = Uri.parse('$_baseUrl/auth/showPcomments');
    final body = jsonEncode(<String, dynamic>{
      'postID': postId,
      'userTelephone': userPhone,
      'postType': postType,
    });

    try {
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (response.statusCode != 200) {
        return [];
      }

      final dynamic json = jsonDecode(response.body);
      if (json is List) {
        return json.map<CommentModel>((e) => CommentModel.fromDynamic(e)).toList();
      }
      if (json is Map<String, dynamic> && json['data'] is List) {
        final list = json['data'] as List<dynamic>;
        return list.map<CommentModel>((e) => CommentModel.fromDynamic(e)).toList();
      }
      return [];
    } catch (e) {
      // ignore: avoid_print
      print('获取评论列表失败: $e');
      return [];
    }
  }

  /// 发送评论
  Future<bool> sendComment(String content, int postId, String userPhone) async {
    if (token.isEmpty || userPhone.isEmpty) return false;

    final uri = Uri.parse('$_baseUrl/auth/postPcomment');
    final body = jsonEncode(<String, dynamic>{
      'content': content,
      'postID': postId,
      'userTelephone': userPhone,
    });

    try {
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      return response.statusCode == 200;
    } catch (e) {
      // ignore: avoid_print
      print('发送评论失败: $e');
      return false;
    }
  }

  /// 发送评论（带评分）
  Future<bool> sendRatingComment(String content, int postId, String userPhone, int rating) async {
    if (token.isEmpty || userPhone.isEmpty) return false;

    final uri = Uri.parse('$_baseUrl/auth/postRcomment');
    final body = jsonEncode(<String, dynamic>{
      'content': content,
      'postID': postId,
      'userTelephone': userPhone,
      'rating': rating,
    });

    try {
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      return response.statusCode == 200;
    } catch (e) {
      // ignore: avoid_print
      print('发送带评分评论失败: $e');
      return false;
    }
  }

  /// 发送子评论（回复评论）
  Future<bool> sendSubComment({
    required String content,
    required int postId,
    required int parentCommentId,
    int? targetCommentId,
    String? targetUserName,
  }) async {
    if (token.isEmpty) return false;

    final uri = Uri.parse('$_baseUrl/auth/postCcomment');
    final body = <String, dynamic>{
      'content': content,
      'postID': postId,
      'pcommentID': parentCommentId,
      'userTelephone': await _getUserPhone(),
    };

    // 如果是回复子评论，添加额外参数
    if (targetCommentId != null) {
      body['ccommentID'] = targetCommentId;
    }
    if (targetUserName != null && targetUserName.isNotEmpty) {
      body['userTargetName'] = targetUserName;
    }

    try {
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      return response.statusCode == 200;
    } catch (e) {
      // ignore: avoid_print
      print('发送子评论失败: $e');
      return false;
    }
  }

  /// 获取当前用户手机号（从存储服务）
  Future<String> _getUserPhone() async {
    final storage = StorageService();
    final user = storage.user;
    return user?.phone ?? '';
  }

  /// 点赞评论
  Future<bool> likeComment(int commentId, String userPhone) async {
    if (token.isEmpty || userPhone.isEmpty) return false;

    final uri = Uri.parse('$_baseUrl/auth/updatePcommentLike');
    final body = jsonEncode(<String, dynamic>{
      'pcommentID': commentId,
      'userTelephone': userPhone,
    });

    try {
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      return response.statusCode == 200;
    } catch (e) {
      // ignore: avoid_print
      print('点赞评论失败: $e');
      return false;
    }
  }

  /// 点赞子评论
  Future<bool> likeSubComment(int subCommentId, String userPhone) async {
    if (token.isEmpty || userPhone.isEmpty) return false;

    final uri = Uri.parse('$_baseUrl/auth/updateCcommentLike');
    final body = jsonEncode(<String, dynamic>{
      'ccommentID': subCommentId,
      'userTelephone': userPhone,
    });

    try {
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      return response.statusCode == 200;
    } catch (e) {
      // ignore: avoid_print
      print('点赞子评论失败: $e');
      return false;
    }
  }

  /// 删除评论
  Future<bool> deleteComment(int commentId) async {
    if (token.isEmpty) return false;

    final uri = Uri.parse('$_baseUrl/auth/deletePcomment');
    final body = jsonEncode(<String, dynamic>{
      'pcommentID': commentId,
    });

    try {
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      return response.statusCode == 200;
    } catch (e) {
      // ignore: avoid_print
      print('删除评论失败: $e');
      return false;
    }
  }

  /// 删除子评论
  Future<bool> deleteSubComment(int subCommentId) async {
    if (token.isEmpty) return false;

    final uri = Uri.parse('$_baseUrl/auth/deleteCcomment');
    final body = jsonEncode(<String, dynamic>{
      'ccommentID': subCommentId,
    });

    try {
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      return response.statusCode == 200;
    } catch (e) {
      // ignore: avoid_print
      print('删除子评论失败: $e');
      return false;
    }
  }

  /// 上传图片
  /// 返回图片 URL，失败返回 null
  Future<String?> uploadPhoto(Uint8List imageBytes, String fileName) async {
    if (token.isEmpty) return null;

    // Use new API URL from newSSE
    final uri = Uri.parse('https://ssemarket.cn/api/auth/uploadPhotos');
    
    try {
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      
      MediaType? mediaType;
      final lowerName = fileName.toLowerCase();
      if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
        mediaType = MediaType('image', 'jpeg');
      } else if (lowerName.endsWith('.png')) {
        mediaType = MediaType('image', 'png');
      } else if (lowerName.endsWith('.gif')) {
        mediaType = MediaType('image', 'gif');
      } else if (lowerName.endsWith('.webp')) {
        mediaType = MediaType('image', 'webp');
      }
      
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: fileName,
          contentType: mediaType,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['fileURL'] as String?;
      } else {
        print('上传图片失败: ${response.statusCode} ${response.body}');
      }
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('上传图片失败: $e');
      return null;
    }
  }

  /// 更新用户信息（头像、简介、昵称）
  Future<bool> updateUserInfo({
    required String avatarUrl,
    required String intro,
    required String name,
    required int userId,
  }) async {
    if (token.isEmpty || userId == 0) return false;

    final uri = Uri.parse('$_baseUrl/auth/updateUserInfo');
    final body = jsonEncode(<String, dynamic>{
      'avatarURL': avatarUrl,
      'intro': intro,
      'name': name,
      'userID': userId,
    });

    try {
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['code'] == 200;
      }
      return false;
    } catch (e) {
      // ignore: avoid_print
      print('更新用户信息失败: $e');
      return false;
    }
  }

  /// 更新邮箱推送设置（切换开关）
  /// 注意：此 API 返回空响应体，状态码 200 表示成功
  Future<bool> updateEmailPush(int userId) async {
    if (token.isEmpty || userId == 0) return false;

    final uri = Uri.parse('$_baseUrl/auth/changeEmailPush');
    final body = jsonEncode(<String, dynamic>{
      'user_id': userId,
    });

    try {
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      // 此 API 返回空响应体，状态码 200 即表示成功
      return response.statusCode == 200;
    } catch (e) {
      // ignore: avoid_print
      print('更新邮箱推送设置失败: $e');
      return false;
    }
  }

  /// 发布帖子
  Future<bool> createPost(
    String title,
    String content,
    String partition,
    String userTelephone, {
    String photos = '',
    String tagList = '',
  }) async {
    if (token.isEmpty || userTelephone.isEmpty) return false;

    final uri = Uri.parse('$_baseUrl/auth/post');
    final body = jsonEncode(<String, dynamic>{
      'title': title,
      'content': content,
      'partition': partition,
      'photos': photos,
      'tagList': tagList,
      'userTelephone': userTelephone,
    });

    try {
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      return response.statusCode == 200;
    } catch (e) {
      // ignore: avoid_print
      print('发布帖子失败: $e');
      return false;
    }
  }

  /// 收藏/取消收藏帖子
  Future<bool> savePost(int postId, String userTelephone) async {
    if (token.isEmpty || userTelephone.isEmpty) return false;

    final uri = Uri.parse('$_baseUrl/auth/updateSave');
    final body = jsonEncode(<String, dynamic>{
      'postID': postId,
      'userTelephone': userTelephone,
    });

    try {
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      return response.statusCode == 200;
    } catch (e) {
      // ignore: avoid_print
      print('收藏帖子失败: $e');
      return false;
    }
  }

  /// 删除帖子
  Future<bool> deletePost(int postId) async {
    if (token.isEmpty) return false;

    final uri = Uri.parse('$_baseUrl/auth/deletePost');
    final body = jsonEncode(<String, dynamic>{
      'postID': postId,
    });

    try {
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      return response.statusCode == 200;
    } catch (e) {
      // ignore: avoid_print
      print('删除帖子失败: $e');
      return false;
    }
  }

  /// 提交评分
  Future<bool> submitRating(
    String userTelephone,
    int postId,
    int rating,
  ) async {
    if (token.isEmpty || userTelephone.isEmpty) return false;

    final uri = Uri.parse('$_baseUrl/auth/submitRating');
    final body = jsonEncode(<String, dynamic>{
      'UserTelephone': userTelephone,
      'PostID': postId,
      'Rating': rating,
    });

    try {
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      return response.statusCode == 200;
    } catch (e) {
      // ignore: avoid_print
      print('提交评分失败: $e');
      return false;
    }
  }

  /// 获取用户对帖子的评分
  Future<int> getUserPostRating(int postId) async {
    if (token.isEmpty) return 0;

    final uri = Uri.parse('$_baseUrl/auth/userPostRating');
    final body = jsonEncode(<String, dynamic>{
      'PostID': postId,
    });

    try {
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        // API might return data directly or wrapped in data field
        dynamic data = json;
        if (json is Map && json['data'] != null) {
          data = json['data'];
        }

        if (data is Map) {
          final rating = data['rating'] ?? data['Rating'];
          if (rating != null) {
            if (rating is int) return rating;
            if (rating is num) return rating.toInt();
          }
        }
      }
      return 0;
    } catch (e) {
      // ignore: avoid_print
      print('获取用户评分失败: $e');
      return 0;
    }
  }

  /// 获取评分分布（1-5星的数量）
  Future<List<int>> getStarsDistribution(int postId) async {
    if (token.isEmpty) return [0, 0, 0, 0, 0];

    final uri = Uri.parse('$_baseUrl/auth/getStars');
    final body = jsonEncode(<String, dynamic>{
      'PostID': postId,
    });

    try {
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        dynamic data = json;
        if (json is Map && json['data'] != null) {
          data = json['data'];
        }

        if (data is Map) {
          // newSSE parses fields star1, star2, star3, star4, star5
          // Assuming fields are camelCase or PascalCase? newSSE uses star1 (lowercase)
          int getCount(String key) {
            final val = data[key];
            if (val is int) return val;
            if (val is num) return val.toInt();
            // Try parsing string if needed
            if (val is String) return int.tryParse(val) ?? 0;
            return 0;
          }

          final s1 = getCount('star1');
          final s2 = getCount('star2');
          final s3 = getCount('star3');
          final s4 = getCount('star4');
          final s5 = getCount('star5');

          // Also try capitalized just in case
          if (s1 == 0 && s2 == 0 && s3 == 0 && s4 == 0 && s5 == 0) {
             final S1 = getCount('Star1');
             final S2 = getCount('Star2');
             final S3 = getCount('Star3');
             final S4 = getCount('Star4');
             final S5 = getCount('Star5');
             if (S1 != 0 || S2 != 0 || S3 != 0 || S4 != 0 || S5 != 0) {
               return [S1, S2, S3, S4, S5];
             }
          }

          return [s1, s2, s3, s4, s5];
        }
      }
      return [0, 0, 0, 0, 0];
    } catch (e) {
      // ignore: avoid_print
      print('获取评分分布失败: $e');
      return [0, 0, 0, 0, 0];
    }
  }

  /// 获取平均评分
  Future<double> getAverageRating(int postId) async {
    if (token.isEmpty) return 0.0;

    final uri = Uri.parse('$_baseUrl/auth/getAverageRating');
    final body = jsonEncode(<String, dynamic>{
      'PostID': postId,
    });

    try {
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        dynamic data = json;
        if (json is Map && json['data'] != null) {
          data = json['data'];
        }

        if (data is Map) {
          final avg = data['averageRating'] ?? data['AverageRating'] ?? data['rating'] ?? data['Rating'];
          if (avg != null) {
            if (avg is double) return avg;
            if (avg is num) return avg.toDouble();
          }
        }
      }
      return 0.0;
    } catch (e) {
      // ignore: avoid_print
      print('获取平均评分失败: $e');
      return 0.0;
    }
  }

  /// 获取热榜帖子
  Future<List<PostModel>> getHeatPosts() async {
    if (token.isEmpty) return [];

    final uri = Uri.parse('$_baseUrl/auth/calculateHeat');

    try {
      final response = await http.get(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.map((e) => PostModel.fromDynamic(e)).toList();
        }
        if (data is Map && data['data'] is List) {
          return (data['data'] as List)
              .map((e) => PostModel.fromDynamic(e))
              .toList();
        }
      }
      return [];
    } catch (e) {
      // ignore: avoid_print
      print('获取热榜帖子失败: $e');
      return [];
    }
  }

  /// 获取商品列表
  /// [type] - 'home' 热门商品, 'history' 我的商品
  Future<List<ProductModel>> getProducts(String searchSort) async {
    if (token.isEmpty) return [];

    final uri = Uri.parse('$_baseUrl/auth/getProducts');
    final body = jsonEncode(<String, dynamic>{
      'searchinfo': '',
      'searchsort': searchSort,
      'limit': 1000,
      'offset': 0,
    });

    try {
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.map((e) => ProductModel.fromDynamic(e)).toList();
        }
        if (data is Map && data['data'] is List) {
          return (data['data'] as List)
              .map((e) => ProductModel.fromDynamic(e))
              .toList();
        }
        // 某些接口可能直接返回 Map，如果不是 List 也不是带 data 的 Map，可能就是空列表或者错误格式
        // 这里可以加一个 fallback，比如看看是否有 code 字段等
        if (data is Map) {
           // 尝试解析为单条数据（虽然不太可能）或者如果确实是空数据
           return [];
        }
      }
      return [];
    } catch (e) {
      // ignore: avoid_print
      print('获取商品列表失败: $e');
      return [];
    }
  }

  /// 提交反馈
  Future<bool> submitFeedback(String content) async {
    if (token.isEmpty) return false;

    final uri = Uri.parse('$_baseUrl/auth/submitFeedback');
    final body = jsonEncode(<String, dynamic>{
      'ftext': content,
      'attachment': '',
    });

    try {
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['msg'] == 'success' || data['code'] == 200;
      }
      return false;
    } catch (e) {
      print('提交反馈失败: $e');
      return false;
    }
  }

  /// 获取商品详情
  Future<ProductModel> getProductDetail(int productId) async {
    if (token.isEmpty) return ProductModel.empty();

    final uri = Uri.parse('$_baseUrl/auth/getProductDetail');
    final body = jsonEncode(<String, dynamic>{
      'productID': productId,
    });

    try {
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        return ProductModel.fromDynamic(jsonDecode(response.body));
      }
      return ProductModel.empty();
    } catch (e) {
      // ignore: avoid_print
      print('获取商品详情失败: $e');
      return ProductModel.empty();
    }
  }

  /// 发送验证码
  /// [mode] 0: 注册, 1: 重置密码
  Future<String> sendCode(String email, int mode) async {
    final uri = Uri.parse('$_baseUrl/auth/validateEmail');
    final body = jsonEncode(<String, dynamic>{
      'email': email,
      'mode': mode,
    });

    try {
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 200) {
          return ''; // 成功
        }
        return json['msg'] ?? '发送验证码失败';
      }
      return '发送验证码失败: ${response.statusCode}';
    } catch (e) {
      return '发送验证码失败: $e';
    }
  }

  /// 注册
  Future<String> register(Map<String, dynamic> data) async {
    final uri = Uri.parse('$_baseUrl/auth/register');
    
    // 加密密码
    if (data['password'] != null) {
      data['password'] = _encryptPassword(data['password'], '16bit secret key');
    }
    if (data['password2'] != null) {
      data['password2'] = _encryptPassword(data['password2'], '16bit secret key');
    }

    final body = jsonEncode(data);

    try {
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 200) {
          return ''; // 成功
        }
        return json['msg'] ?? '注册失败';
      }
      return '注册失败: ${response.statusCode}';
    } catch (e) {
      return '注册失败: $e';
    }
  }

  /// 重置密码
  Future<String> resetPassword(String email, String password, String password2, String valiCode) async {
    final uri = Uri.parse('$_baseUrl/auth/modifyPassword');
    
    final encryptedPassword = _encryptPassword(password, '16bit secret key');
    final encryptedPassword2 = _encryptPassword(password2, '16bit secret key');

    final body = jsonEncode(<String, dynamic>{
      'email': email,
      'password': encryptedPassword,
      'password2': encryptedPassword2,
      'valiCode': valiCode,
    });

    try {
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 200) {
          return ''; // 成功
        }
        return json['msg'] ?? '重置密码失败';
      }
      return '重置密码失败: ${response.statusCode}';
    } catch (e) {
      return '重置密码失败: $e';
    }
  }

  /// 获取通知数量
  Future<NoticeNum> getNoticeNum() async {
    if (token.isEmpty) {
      return NoticeNum(totalNum: 0, unreadTotalNum: 0, readTotalNum: 0);
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/getNoticeNum'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return NoticeNum.fromJson(json);
      }
    } catch (e) {
      print('获取通知数量失败: $e');
    }
    return NoticeNum(totalNum: 0, unreadTotalNum: 0, readTotalNum: 0);
  }

  /// 获取通知列表
  Future<List<Notice>> getNotices({
    int requireId = 0,
    int pageSize = 20,
    required int read, // 0:未读, 1:已读
  }) async {
    if (token.isEmpty) return [];

    try {
      final uri = Uri.parse('$_baseUrl/auth/getNotice').replace(queryParameters: {
        'requireID': requireId.toString(),
        'pageSize': pageSize.toString(),
        'read': read.toString(),
      });

      final response = await http.get(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['noticeList'] is List) {
          return (json['noticeList'] as List)
              .map((e) => Notice.fromJson(e))
              .toList();
        }
      }
    } catch (e) {
      print('获取通知列表失败: $e');
    }
    return [];
  }

  /// 标记通知已读
  Future<bool> readNotice(int noticeId) async {
    if (token.isEmpty) return false;

    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/auth/readNotice/$noticeId'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['status'] == 'success';
      }
    } catch (e) {
      print('标记通知已读失败: $e');
    }
    return false;
  }

  /// 获取聊天记录
  Future<List<ChatMessageModel>> getChatHistory(int senderUserId, int targetUserId) async {
    if (token.isEmpty) return [];

    final uri = Uri.parse('$_baseUrl/auth/getChatHistory');
    final uriWithQuery = uri.replace(queryParameters: {
      'senderUserID': senderUserId.toString(),
      'targetUserID': targetUserId.toString(),
    });

    try {
      final response = await http.get(
        uriWithQuery,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 200 && json['data'] != null) {
          final data = json['data'];
          if (data['chatHistoryList'] is List) {
             return (data['chatHistoryList'] as List)
                .map((e) => ChatMessageModel.fromJson(e))
                .toList();
          }
        }
      }
      return [];
    } catch (e) {
      print('获取聊天记录失败: $e');
      return [];
    }
  }

  /// 发布闲置商品
  Future<bool> postProduct({
    required int userId,
    required int price,
    required String title,
    required String content,
    required List<String> photos,
  }) async {
    if (token.isEmpty || userId == 0) return false;

    final uri = Uri.parse('$_baseUrl/auth/postProduct');
    final body = jsonEncode(<String, dynamic>{
      'UserID': userId,
      'Price': price,
      'Title': title,
      'Content': content,
      'Photos': photos,
      'ISAnonymous': false,
    });

    try {
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      return response.statusCode == 200;
    } catch (e) {
      print('发布商品失败: $e');
      return false;
    }
  }

  /// 标记商品为已售出
  Future<bool> markProductSold(int productId) async {
    if (token.isEmpty) return false;

    final uri = Uri.parse('$_baseUrl/auth/saleProduct');
    final body = jsonEncode(<String, dynamic>{
      'productID': productId,
    });

    try {
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      return response.statusCode == 200;
    } catch (e) {
      print('标记商品售出失败: $e');
      return false;
    }
  }

  /// 删除商品
  Future<bool> deleteProduct(int productId) async {
    if (token.isEmpty) return false;

    final uri = Uri.parse('$_baseUrl/auth/deleteProduct');
    final body = jsonEncode(<String, dynamic>{
      'productID': productId,
    });

    try {
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      return response.statusCode == 200;
    } catch (e) {
      print('删除商品失败: $e');
      return false;
    }
  }

  /// 获取教师标签列表（课程专区）
  Future<List<Map<String, dynamic>>> getTeachers() async {
    if (token.isEmpty) return [];

    final uri = Uri.parse('$_baseUrl/auth/getTags?type=course');

    try {
      final response = await http.get(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['data'] != null && json['data']['tags'] is List) {
          return (json['data']['tags'] as List)
              .map((e) => e as Map<String, dynamic>)
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('获取教师列表失败: $e');
      return [];
    }
  }
}
