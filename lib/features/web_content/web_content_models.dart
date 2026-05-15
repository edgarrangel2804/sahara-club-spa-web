import 'package:intl/intl.dart';

class WebContentSectionDefinition {
  const WebContentSectionDefinition({
    required this.key,
    required this.label,
    required this.contentType,
    this.description = '',
  });

  final String key;
  final String label;
  final String contentType;
  final String description;
}

class WebContentBranch {
  const WebContentBranch({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}

class WebBusinessProfile {
  const WebBusinessProfile({
    required this.name,
    required this.address,
    required this.phone,
    required this.whatsapp,
    required this.email,
    required this.mapsLink,
  });

  final String name;
  final String address;
  final String phone;
  final String whatsapp;
  final String email;
  final String mapsLink;

  factory WebBusinessProfile.empty() => const WebBusinessProfile(
        name: 'Sahara Club Spa',
        address: '',
        phone: '',
        whatsapp: '',
        email: '',
        mapsLink: '',
      );
}

class WebCatalogLinkOption {
  const WebCatalogLinkOption({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle = '',
    this.description = '',
    this.imageUrl = '',
    this.category = '',
    this.price,
    this.isActive = true,
  });

  final String id;
  final String type;
  final String title;
  final String subtitle;
  final String description;
  final String imageUrl;
  final String category;
  final double? price;
  final bool isActive;

  String get priceLabel {
    if (price == null) return '';
    return NumberFormat.currency(
      locale: 'es_MX',
      symbol: '\$',
      decimalDigits: 0,
    ).format(price);
  }
}

class WebContentItem {
  const WebContentItem({
    this.id,
    this.branchId,
    required this.sectionKey,
    required this.contentType,
    required this.title,
    required this.subtitle,
    required this.shortDescription,
    required this.longDescription,
    this.price,
    this.promoPrice,
    required this.imageUrl,
    required this.videoUrl,
    required this.category,
    required this.ctaText,
    required this.ctaUrl,
    required this.displayOrder,
    required this.isActive,
    required this.isFeatured,
    this.startDate,
    this.endDate,
    this.linkedServiceId,
    this.linkedProductId,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String? branchId;
  final String sectionKey;
  final String contentType;
  final String title;
  final String subtitle;
  final String shortDescription;
  final String longDescription;
  final double? price;
  final double? promoPrice;
  final String imageUrl;
  final String videoUrl;
  final String category;
  final String ctaText;
  final String ctaUrl;
  final int displayOrder;
  final bool isActive;
  final bool isFeatured;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? linkedServiceId;
  final String? linkedProductId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static const List<WebContentSectionDefinition> sections =
      <WebContentSectionDefinition>[
        WebContentSectionDefinition(
          key: 'facials',
          label: 'Faciales',
          contentType: 'facial',
          description: 'Servicios faciales y rituales del rostro.',
        ),
        WebContentSectionDefinition(
          key: 'massages',
          label: 'Masajes',
          contentType: 'massage',
          description: 'Masajes, metodologias y experiencias corporales.',
        ),
        WebContentSectionDefinition(
          key: 'memberships',
          label: 'Membresias',
          contentType: 'membership',
          description: 'Contenido publico de membresias.',
        ),
        WebContentSectionDefinition(
          key: 'digital_products',
          label: 'Productos digitales',
          contentType: 'digital_product',
          description: 'Guias, audios y experiencias digitales.',
        ),
        WebContentSectionDefinition(
          key: 'physical_products',
          label: 'Productos fisicos',
          contentType: 'physical_product',
          description: 'Productos fisicos y retail.',
        ),
        WebContentSectionDefinition(
          key: 'gift_cards',
          label: 'Gift cards',
          contentType: 'gift_card',
          description: 'Tarjetas de regalo y presentaciones especiales.',
        ),
        WebContentSectionDefinition(
          key: 'promotions',
          label: 'Promociones',
          contentType: 'promotion',
          description: 'Promociones, descuentos y primera visita.',
        ),
        WebContentSectionDefinition(
          key: 'hero',
          label: 'Hero principal',
          contentType: 'hero',
          description: 'Mensaje principal de portada.',
        ),
        WebContentSectionDefinition(
          key: 'banners',
          label: 'Banners',
          contentType: 'banner',
          description: 'Banners informativos y campañas visuales.',
        ),
        WebContentSectionDefinition(
          key: 'featured_posts',
          label: 'Publicaciones destacadas',
          contentType: 'post',
          description: 'Servicios, posts o experiencias destacadas.',
        ),
        WebContentSectionDefinition(
          key: 'contact_info',
          label: 'Contacto principal',
          contentType: 'banner',
          description: 'Titulo, intro, CTA y mensaje de confianza del bloque de contacto.',
        ),
        WebContentSectionDefinition(
          key: 'contact_hours',
          label: 'Horarios y avisos',
          contentType: 'banner',
          description: 'Horarios visibles y nota informativa del bloque de contacto.',
        ),
        WebContentSectionDefinition(
          key: 'footer_brand',
          label: 'Footer marca',
          contentType: 'banner',
          description: 'Firma de marca y manifiesto corto en el footer.',
        ),
        WebContentSectionDefinition(
          key: 'footer_navigation',
          label: 'Footer navegacion',
          contentType: 'post',
          description: 'Links de navegacion del footer.',
        ),
        WebContentSectionDefinition(
          key: 'footer_services',
          label: 'Footer servicios',
          contentType: 'post',
          description: 'Links de servicios visibles en el footer.',
        ),
        WebContentSectionDefinition(
          key: 'footer_legal',
          label: 'Footer legal',
          contentType: 'banner',
          description: 'Textos finales, derechos y datos legales del footer.',
        ),
      ];

  static const Set<String> serviceTypes = <String>{'facial', 'massage'};
  static const Set<String> productTypes = <String>{
    'membership',
    'digital_product',
    'physical_product',
    'gift_card',
  };

  factory WebContentItem.empty({
    String? branchId,
    String sectionKey = 'hero',
    String contentType = 'hero',
  }) {
    return WebContentItem(
      branchId: branchId,
      sectionKey: sectionKey,
      contentType: contentType,
      title: '',
      subtitle: '',
      shortDescription: '',
      longDescription: '',
      price: null,
      promoPrice: null,
      imageUrl: '',
      videoUrl: '',
      category: '',
      ctaText: '',
      ctaUrl: '',
      displayOrder: 0,
      isActive: true,
      isFeatured: false,
    );
  }

  factory WebContentItem.fromMap(Map<String, dynamic> map) {
    return WebContentItem(
      id: map['id']?.toString(),
      branchId: map['branch_id']?.toString(),
      sectionKey: (map['section_key'] as String? ?? '').trim(),
      contentType: (map['content_type'] as String? ?? '').trim(),
      title: (map['title'] as String? ?? '').trim(),
      subtitle: (map['subtitle'] as String? ?? '').trim(),
      shortDescription: (map['short_description'] as String? ?? '').trim(),
      longDescription: (map['long_description'] as String? ?? '').trim(),
      price: (map['price'] as num?)?.toDouble(),
      promoPrice: (map['promo_price'] as num?)?.toDouble(),
      imageUrl: (map['image_url'] as String? ?? '').trim(),
      videoUrl: (map['video_url'] as String? ?? '').trim(),
      category: (map['category'] as String? ?? '').trim(),
      ctaText: (map['cta_text'] as String? ?? '').trim(),
      ctaUrl: (map['cta_url'] as String? ?? '').trim(),
      displayOrder: (map['display_order'] as num?)?.toInt() ?? 0,
      isActive: map['is_active'] as bool? ?? false,
      isFeatured: map['is_featured'] as bool? ?? false,
      startDate: _readDate(map['start_date']),
      endDate: _readDate(map['end_date']),
      linkedServiceId: map['linked_service_id']?.toString(),
      linkedProductId: map['linked_product_id']?.toString(),
      createdAt: _readDate(map['created_at']),
      updatedAt: _readDate(map['updated_at']),
    );
  }

  static DateTime? _readDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String && raw.trim().isNotEmpty) {
      return DateTime.tryParse(raw.trim());
    }
    return null;
  }

  WebContentItem copyWith({
    String? id,
    String? branchId,
    String? sectionKey,
    String? contentType,
    String? title,
    String? subtitle,
    String? shortDescription,
    String? longDescription,
    double? price,
    bool clearPrice = false,
    double? promoPrice,
    bool clearPromoPrice = false,
    String? imageUrl,
    String? videoUrl,
    String? category,
    String? ctaText,
    String? ctaUrl,
    int? displayOrder,
    bool? isActive,
    bool? isFeatured,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
    String? linkedServiceId,
    bool clearLinkedServiceId = false,
    String? linkedProductId,
    bool clearLinkedProductId = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WebContentItem(
      id: id ?? this.id,
      branchId: branchId ?? this.branchId,
      sectionKey: sectionKey ?? this.sectionKey,
      contentType: contentType ?? this.contentType,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      shortDescription: shortDescription ?? this.shortDescription,
      longDescription: longDescription ?? this.longDescription,
      price: clearPrice ? null : (price ?? this.price),
      promoPrice:
          clearPromoPrice ? null : (promoPrice ?? this.promoPrice),
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      category: category ?? this.category,
      ctaText: ctaText ?? this.ctaText,
      ctaUrl: ctaUrl ?? this.ctaUrl,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
      isFeatured: isFeatured ?? this.isFeatured,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      linkedServiceId: clearLinkedServiceId
          ? null
          : (linkedServiceId ?? this.linkedServiceId),
      linkedProductId: clearLinkedProductId
          ? null
          : (linkedProductId ?? this.linkedProductId),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toDatabaseMap() {
    return <String, dynamic>{
      'branch_id': branchId,
      'section_key': sectionKey,
      'content_type': contentType,
      'title': title.trim(),
      'subtitle': subtitle.trim(),
      'short_description': shortDescription.trim(),
      'long_description': longDescription.trim(),
      'price': price,
      'promo_price': promoPrice,
      'image_url': imageUrl.trim(),
      'video_url': videoUrl.trim(),
      'category': category.trim(),
      'cta_text': ctaText.trim(),
      'cta_url': ctaUrl.trim(),
      'display_order': displayOrder,
      'is_active': isActive,
      'is_featured': isFeatured,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'linked_service_id': linkedServiceId,
      'linked_product_id': linkedProductId,
    };
  }

  bool get isServiceLinkedType => serviceTypes.contains(contentType);

  bool get isProductLinkedType => productTypes.contains(contentType);

  bool get isCurrentlyVisible {
    if (!isActive) return false;
    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    return true;
  }

  String get sectionLabel =>
      sectionByKey(sectionKey)?.label ?? sectionKey;

  String get priceLabel {
    if (price == null) return '';
    return NumberFormat.currency(
      locale: 'es_MX',
      symbol: '\$',
      decimalDigits: 0,
    ).format(price);
  }

  String get promoPriceLabel {
    if (promoPrice == null) return '';
    return NumberFormat.currency(
      locale: 'es_MX',
      symbol: '\$',
      decimalDigits: 0,
    ).format(promoPrice);
  }

  static WebContentSectionDefinition? sectionByKey(String key) {
    for (final section in sections) {
      if (section.key == key) return section;
    }
    return null;
  }
}
