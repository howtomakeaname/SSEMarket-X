/// 商品数据模型
class ProductModel {
  final int id;
  final int sellerId;
  final String sellerName;
  final double price;
  final String name;
  final String description;
  final List<String> photos;
  final bool isSold;
  final bool isAnonymous;

  const ProductModel({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    required this.price,
    required this.name,
    required this.description,
    required this.photos,
    this.isSold = false,
    this.isAnonymous = false,
  });

  factory ProductModel.empty() {
    return const ProductModel(
      id: 0,
      sellerId: 0,
      sellerName: '',
      price: 0,
      name: '',
      description: '',
      photos: [],
      isSold: false,
      isAnonymous: false,
    );
  }

  factory ProductModel.fromDynamic(dynamic raw) {
    if (raw is! Map) {
      return ProductModel.empty();
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

    double _readDouble(List<String> keys) {
      for (final key in keys) {
        final v = map[key];
        if (v is double) return v;
        if (v is num) return v.toDouble();
        if (v is String) {
          final parsed = double.tryParse(v);
          if (parsed != null) return parsed;
        }
      }
      return 0.0;
    }

    String _readString(List<String> keys) {
      for (final key in keys) {
        final v = map[key];
        if (v is String) return v;
      }
      return '';
    }

    bool _readBool(List<String> keys) {
      for (final key in keys) {
        final v = map[key];
        if (v is bool) return v;
        if (v is int) return v != 0;
        if (v is String) return v.toLowerCase() == 'true' || v == '1';
      }
      return false;
    }

    List<String> _readPhotos() {
      final v = map['Photos'] ?? map['photos'];
      if (v is List) {
        return v.map((e) => e.toString()).toList();
      }
      if (v is String && v.isNotEmpty) {
        return v.split(',');
      }
      return [];
    }

    return ProductModel(
      id: _readInt(['ProductID', 'productID', 'id']),
      sellerId: _readInt(['SellerID', 'sellerID', 'UserID', 'userID']),
      sellerName: _readString(['Seller', 'seller', 'SellerName', 'sellerName']),
      price: _readDouble(['Price', 'price']),
      name: _readString(['Name', 'name', 'Title', 'title']),
      description: _readString(['Description', 'description', 'Content', 'content']),
      photos: _readPhotos(),
      isSold: _readBool(['ISSold', 'isSold', 'IsSold']),
      isAnonymous: _readBool(['ISAnonymous', 'isAnonymous', 'IsAnonymous']),
    );
  }

  /// 获取第一张图片URL
  String get firstPhoto => photos.isNotEmpty ? photos.first : '';
}
