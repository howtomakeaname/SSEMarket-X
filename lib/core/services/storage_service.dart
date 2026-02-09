import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sse_market_x/core/models/user_model.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  late SharedPreferences _prefs;
  bool _isInitialized = false;

  UserModel? _user;
  String _token = '';
  String _refreshToken = '';
  int _refreshTokenExpiry = 0; //ms
  bool _isLoggedIn = false;
  bool _rememberMe = false;

  static const String _keyToken = 'user_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyRefreshTokenExpiry = 'refresh_token_expiry';
  static const String _keyUserInfo = 'user_info';
  static const String _keyLoginStatus = 'login_status'; // remember me

  static const int _thirtyDaysMs = 30 * 24 * 60 * 60 * 1000;

  final ValueNotifier<UserModel?> userNotifier = ValueNotifier<UserModel?>(null);

  Future<void> init() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();
    _restoreLoginState();
    _isInitialized = true;
  }

  void _restoreLoginState() {
    final token = _prefs.getString(_keyToken) ?? '';
    final refreshToken = _prefs.getString(_keyRefreshToken) ?? '';
    final expiry = _prefs.getInt(_keyRefreshTokenExpiry) ?? 0;
    final userJson = _prefs.getString(_keyUserInfo);
    final rememberMeString = _prefs.getString(_keyLoginStatus) ?? 'false';
    _rememberMe = rememberMeString == 'true';
    _refreshToken = refreshToken;
    _refreshTokenExpiry = expiry;

    if (token.isNotEmpty && userJson != null) {
      try {
        final userMap = jsonDecode(userJson);
        _user = UserModel.fromDynamic(userMap);
        _token = token;
        _isLoggedIn = true;
        userNotifier.value = _user;
      } catch (e) {
        logout();
      }
    }
  }

  // Getters
  UserModel? get user => _user;
  String get token => _token;
  String get refreshToken => _refreshToken;
  int get refreshTokenExpiry => _refreshTokenExpiry;
  bool get isLoggedIn => _isLoggedIn;
  bool get rememberMe => _rememberMe;

  // Actions
  void setToken(String token) {
    _token = token;
    _prefs.setString(_keyToken, token);
  }

  Future<void> setUser(
    UserModel user,
    String token, {
    bool rememberMe = false,
    String? refreshToken,
  }) async {
    _user = user;
    _token = token;
    _isLoggedIn = true;
    _rememberMe = rememberMe;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      final expiry = DateTime.now().millisecondsSinceEpoch + _thirtyDaysMs;
      _refreshToken = refreshToken;
      _refreshTokenExpiry = expiry;
      await _prefs.setString(_keyRefreshToken, refreshToken);
      await _prefs.setInt(_keyRefreshTokenExpiry, expiry);
    }

    userNotifier.value = _user;

    await _prefs.setString(_keyToken, token);
    await _prefs.setString(_keyUserInfo, jsonEncode(user.toJson()));
    await _prefs.setString(_keyLoginStatus, rememberMe.toString());
  }

  Future<void> logout() async {
    _user = null;
    _token = '';
    _refreshToken = '';
    _refreshTokenExpiry = 0;
    _isLoggedIn = false;

    userNotifier.value = _user;

    await _prefs.remove(_keyToken);
    await _prefs.remove(_keyRefreshToken);
    await _prefs.remove(_keyRefreshTokenExpiry);
    await _prefs.remove(_keyUserInfo);
    await _prefs.remove(_keyLoginStatus);
  }
}
