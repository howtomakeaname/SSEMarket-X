import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:sse_market_x/core/services/storage_service.dart';

class ChatContact {
  final int userId;
  final String name;
  final String email;
  final String avatarUrl;
  final String identity;
  final int score;
  int unreadCount;
  String? lastMessage;
  DateTime? lastMessageTime;
  String? intro;

  ChatContact({
    required this.userId,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.identity,
    required this.score,
    this.unreadCount = 0,
    this.lastMessage,
    this.lastMessageTime,
    this.intro,
  });

  factory ChatContact.fromJson(Map<String, dynamic> json) {
    return ChatContact(
      userId: json['userID'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      avatarUrl: json['avatarURL'] ?? '',
      identity: json['identity'] ?? '',
      score: json['score'] ?? 0,
      unreadCount: json['unRead'] ?? 0,
      intro: json['intro'] ?? '',
    );
  }
}

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  Timer? _pingTimer;
  final _messageController = StreamController<dynamic>.broadcast();
  final _relevantUsersController = StreamController<List<dynamic>>.broadcast();
  final _contactsController = StreamController<List<ChatContact>>.broadcast();
  final _unreadCountController = StreamController<int>.broadcast();
  
  // 本地缓存联系人列表
  final List<ChatContact> _contacts = [];
  int _totalUnreadCount = 0;
  
  Stream<dynamic> get messages => _messageController.stream;
  Stream<List<dynamic>> get relevantUsers => _relevantUsersController.stream;
  Stream<List<ChatContact>> get contacts => _contactsController.stream;
  Stream<int> get unreadCount => _unreadCountController.stream;
  List<ChatContact> get currentContacts => List.unmodifiable(_contacts);
  int get totalUnreadCount => _totalUnreadCount;
  bool get isConnected => _channel != null;

  void connect() {
    final token = StorageService().token;
    final user = StorageService().user;
    if (token.isEmpty || user == null) return;

    // If already connected, don't reconnect unless we want to force it?
    // For now, if channel exists, assume connected.
    if (_channel != null) return;

    final uri = Uri.parse('wss://ssemarket.cn/websocket/auth/chat?token=$token');
    
    try {
      print('Connecting to WebSocket: $uri');
      _channel = WebSocketChannel.connect(uri);
      
      _channel!.stream.listen(
        (data) {
          try {
            final decoded = jsonDecode(data);
            if (decoded is Map && decoded.containsKey('relevantUsers')) {
              final list = decoded['relevantUsers'];
              if (list is List) {
                _relevantUsersController.add(list);
                _processRelevantUsers(list);
              }
            } else if (decoded is Map && decoded.containsKey('chatMsgID')) {
              // 新消息
              _messageController.add(decoded);
              _processNewMessage(Map<String, dynamic>.from(decoded));
            } else {
              _messageController.add(decoded);
            }
          } catch (e) {
            print('WebSocket decode error: $e');
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
          _closeConnection();
        },
        onDone: () {
          print('WebSocket closed');
          _closeConnection();
        },
      );

      // Start heartbeat
      _startPing(user.userId);
      
    } catch (e) {
      print('WebSocket connection failed: $e');
      _closeConnection();
    }
  }

  void disconnect() {
    _closeConnection();
  }

  void _closeConnection() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _channel?.sink.close(status.goingAway);
    _channel = null;
  }

  void _startPing(int userId) {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_channel != null) {
        final beat = {
          'userID': userId,
          'beat': 1,
        };
        try {
          _channel!.sink.add(jsonEncode(beat));
        } catch (e) {
          print('WebSocket ping failed: $e');
          disconnect();
        }
      } else {
        timer.cancel();
      }
    });
  }

  bool sendMessage(int targetUserId, String content, {bool isAnonymous = false}) {
    final user = StorageService().user;
    if (_channel == null || user == null) {
      // Try to connect if not connected
      if (StorageService().isLoggedIn) {
        connect();
        // We might fail this send, but next attempt might work. 
        // Or we can wait? For simplicity, return false if not connected immediately.
        // If connect() is synchronous in setting _channel (it is), we can try again?
        if (_channel == null) return false;
      } else {
        return false;
      }
    }

    try {
      final message = {
        'senderUserID': user!.userId,
        'targetUserID': targetUserId,
        'content': content,
        'isAnonymous': isAnonymous,
      };
      _channel!.sink.add(jsonEncode(message));
      
      // 更新本地联系人的最新消息
      _updateContactLastMessage(targetUserId, content, DateTime.now());
      
      return true;
    } catch (e) {
      print('Send message failed: $e');
      return false;
    }
  }

  void _processRelevantUsers(List<dynamic> users) {
    _contacts.clear();
    _totalUnreadCount = 0;
    
    for (final userData in users) {
      if (userData is Map) {
        try {
          final contact = ChatContact.fromJson(Map<String, dynamic>.from(userData));
          _contacts.add(contact);
          _totalUnreadCount += contact.unreadCount;
        } catch (e) {
          print('Error parsing contact: $e');
        }
      }
    }
    
    _contactsController.add(List.from(_contacts));
    _unreadCountController.add(_totalUnreadCount);
  }

  void _processNewMessage(Map<String, dynamic> messageData) {
    final senderId = messageData['senderUserID'] as int?;
    final content = messageData['content'] as String?;
    final createdAt = messageData['createdAt'] as String?;
    final currentUser = StorageService().user;
    
    if (senderId == null || content == null || currentUser == null) return;
    
    // 只处理发给我的消息
    final targetId = messageData['targetUserID'] as int?;
    if (targetId != currentUser.userId) return;
    
    // 更新联系人的最新消息和未读数
    final contactIndex = _contacts.indexWhere((c) => c.userId == senderId);
    if (contactIndex != -1) {
      _contacts[contactIndex].lastMessage = content;
      _contacts[contactIndex].lastMessageTime = createdAt != null 
          ? DateTime.tryParse(createdAt) ?? DateTime.now()
          : DateTime.now();
      _contacts[contactIndex].unreadCount++;
      _totalUnreadCount++;
      
      // 将该联系人移到列表顶部
      final contact = _contacts.removeAt(contactIndex);
      _contacts.insert(0, contact);
      
      _contactsController.add(List.from(_contacts));
      _unreadCountController.add(_totalUnreadCount);
    }
  }

  void _updateContactLastMessage(int userId, String content, DateTime time) {
    final contactIndex = _contacts.indexWhere((c) => c.userId == userId);
    if (contactIndex != -1) {
      _contacts[contactIndex].lastMessage = content;
      _contacts[contactIndex].lastMessageTime = time;
      _contactsController.add(List.from(_contacts));
    }
  }

  /// 标记与某用户的对话为已读
  void markAsRead(int userId) {
    final contactIndex = _contacts.indexWhere((c) => c.userId == userId);
    if (contactIndex != -1) {
      _totalUnreadCount -= _contacts[contactIndex].unreadCount;
      if (_totalUnreadCount < 0) _totalUnreadCount = 0;
      _contacts[contactIndex].unreadCount = 0;
      
      _contactsController.add(List.from(_contacts));
      _unreadCountController.add(_totalUnreadCount);
    }
  }
}
