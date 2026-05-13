import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum StoreProductType {
  service,
  digital,
  physical,
  membership,
  giftCard,
}

extension StoreProductTypeX on StoreProductType {
  String get label {
    switch (this) {
      case StoreProductType.service:
        return 'Servicio';
      case StoreProductType.digital:
        return 'Digital';
      case StoreProductType.physical:
        return 'Fisico';
      case StoreProductType.membership:
        return 'Membresia';
      case StoreProductType.giftCard:
        return 'Tarjeta de regalo';
    }
  }

  IconData get icon {
    switch (this) {
      case StoreProductType.service:
        return Icons.spa_outlined;
      case StoreProductType.digital:
        return Icons.graphic_eq_rounded;
      case StoreProductType.physical:
        return Icons.shopping_bag_outlined;
      case StoreProductType.membership:
        return Icons.workspace_premium_outlined;
      case StoreProductType.giftCard:
        return Icons.redeem_outlined;
    }
  }
}

class StoreProduct {
  StoreProduct({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.shortDescription,
    required this.price,
    required this.currency,
    required this.type,
    required this.imageUrl,
    required this.categoryKey,
    required this.categoryLabel,
    required this.benefits,
    required this.availability,
    this.durationMinutes,
    this.stockQuantity,
    this.isFeatured = false,
  });

  final String id;
  final String name;
  final String slug;
  final String description;
  final String shortDescription;
  final double price;
  final String currency;
  final StoreProductType type;
  final String imageUrl;
  final String categoryKey;
  final String categoryLabel;
  final List<String> benefits;
  final String availability;
  final int? durationMinutes;
  final int? stockQuantity;
  final bool isFeatured;

  String get priceLabel {
    final format = NumberFormat.currency(
      locale: 'es_MX',
      symbol: '\$',
      decimalDigits: 0,
    );
    return format.format(price);
  }

  String get typeLabel => type.label;

  factory StoreProduct.fromMap(Map<String, dynamic> map) {
    final name = (map['name'] as String? ?? 'Experiencia Sahara').trim();
    final category = (map['category'] as String? ??
            map['category_key'] as String? ??
            'general')
        .trim()
        .toLowerCase();
    final rawType =
        (map['product_type'] as String? ?? map['type'] as String? ?? category)
            .trim()
            .toLowerCase();
    final type = _typeFromRaw(rawType, category, name);
    final imageUrl = (map['image_url'] as String? ??
            map['image'] as String? ??
            _fallbackImageForType(type))
        .trim();
    final shortDescription = (map['short_description'] as String? ??
            map['description'] as String? ??
            'Ritual premium Sahara')
        .trim();
    final description = (map['description'] as String? ?? shortDescription).trim();
    final price = (map['price'] as num?)?.toDouble() ?? 0;
    final durationMinutes = (map['duration_minutes'] as num?)?.toInt();
    final stockQuantity = (map['stock_quantity'] as num?)?.toInt() ??
        (map['stock'] as num?)?.toInt();

    return StoreProduct(
      id: (map['id'] ?? name).toString(),
      name: name,
      slug: ((map['slug'] as String?)?.trim().isNotEmpty ?? false)
          ? (map['slug'] as String).trim()
          : _slugify(name),
      description: description,
      shortDescription: shortDescription,
      price: price,
      currency: (map['currency'] as String? ?? 'MXN').trim(),
      type: type,
      imageUrl: imageUrl,
      categoryKey: _categoryKeyFromRaw(type, category, name),
      categoryLabel: _categoryLabelFromRaw(type, category, name),
      benefits: _readBenefits(map, type),
      availability: _availabilityFromType(type),
      durationMinutes: durationMinutes,
      stockQuantity: stockQuantity,
      isFeatured: map['is_featured'] as bool? ?? false,
    );
  }

  static List<String> _readBenefits(
    Map<String, dynamic> map,
    StoreProductType type,
  ) {
    final dynamic raw = map['benefits'] ?? map['wellness_benefits'];
    if (raw is List) {
      final parsed = raw.whereType<String>().map((item) => item.trim()).toList();
      if (parsed.isNotEmpty) return parsed.take(3).toList();
    }
    return _defaultBenefits(type);
  }

  static StoreProductType _typeFromRaw(
    String rawType,
    String category,
    String name,
  ) {
    final haystack = '$rawType $category $name'.toLowerCase();
    if (haystack.contains('membership') ||
        haystack.contains('membres') ||
        haystack.contains('vip')) {
      return StoreProductType.membership;
    }
    if (haystack.contains('gift')) return StoreProductType.giftCard;
    if (haystack.contains('digital') ||
        haystack.contains('audio') ||
        haystack.contains('medita') ||
        haystack.contains('music') ||
        haystack.contains('musica') ||
        haystack.contains('download')) {
      return StoreProductType.digital;
    }
    if (haystack.contains('service') ||
        haystack.contains('masaje') ||
        haystack.contains('facial') ||
        haystack.contains('ritual') ||
        haystack.contains('spa')) {
      return StoreProductType.service;
    }
    return StoreProductType.physical;
  }

  static List<String> _defaultBenefits(StoreProductType type) {
    switch (type) {
      case StoreProductType.service:
        return ['Bienestar profundo', 'Atencion premium', 'Experiencia guiada'];
      case StoreProductType.digital:
        return ['Acceso inmediato', 'Ritual on demand', 'Uso personal'];
      case StoreProductType.physical:
        return ['Recoge en sucursal', 'Seleccion curada', 'Calidad Sahara'];
      case StoreProductType.membership:
        return ['Beneficios exclusivos', 'Prioridad VIP', 'Acceso extendido'];
      case StoreProductType.giftCard:
        return ['Regalo flexible', 'Canje futuro', 'Presentacion premium'];
    }
  }

  static String _availabilityFromType(StoreProductType type) {
    switch (type) {
      case StoreProductType.service:
        return 'Disponible para reservar';
      case StoreProductType.digital:
        return 'Acceso inmediato despues del pago';
      case StoreProductType.physical:
        return 'Disponible para recoger en Sahara Club Spa';
      case StoreProductType.membership:
        return 'Activacion inmediata al confirmar pago';
      case StoreProductType.giftCard:
        return 'Codigo digital generado al pagar';
    }
  }

  static String _categoryKeyFromRaw(
    StoreProductType type,
    String category,
    String name,
  ) {
    final haystack = '$category $name'.toLowerCase();
    if (type == StoreProductType.digital) return 'digital';
    if (type == StoreProductType.physical) return 'physical';
    if (type == StoreProductType.membership) return 'memberships';
    if (type == StoreProductType.giftCard) return 'gift_cards';
    if (haystack.contains('masaje')) return 'massages';
    if (haystack.contains('facial')) return 'facials';
    if (haystack.contains('ritual')) return 'rituals';
    return 'services';
  }

  static String _categoryLabelFromRaw(
    StoreProductType type,
    String category,
    String name,
  ) {
    switch (_categoryKeyFromRaw(type, category, name)) {
      case 'massages':
        return 'Masajes';
      case 'facials':
        return 'Faciales';
      case 'rituals':
        return 'Rituales';
      case 'digital':
        return 'Productos digitales';
      case 'physical':
        return 'Productos fisicos';
      case 'memberships':
        return 'Membresias';
      case 'gift_cards':
        return 'Tarjetas de regalo';
      default:
        return 'Servicios';
    }
  }

  static String _fallbackImageForType(StoreProductType type) {
    switch (type) {
      case StoreProductType.service:
        return 'assets/images/hero.jpg';
      case StoreProductType.digital:
        return 'assets/images/03.png';
      case StoreProductType.physical:
        return 'assets/images/06.png';
      case StoreProductType.membership:
        return 'assets/images/07.png';
      case StoreProductType.giftCard:
        return 'assets/images/08.png';
    }
  }

  static String _slugify(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }
}
