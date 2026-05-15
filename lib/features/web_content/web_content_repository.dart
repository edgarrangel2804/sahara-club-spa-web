import 'package:supabase_flutter/supabase_flutter.dart';

import 'web_content_models.dart';

class WebContentRepository {
  WebContentRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<WebContentItem>> loadContent({
    String? sectionKey,
    bool activeOnly = false,
  }) async {
    dynamic query = _client
        .from('web_content_sections')
        .select()
        .order('section_key')
        .order('display_order')
        .order('created_at');

    if (sectionKey != null && sectionKey.trim().isNotEmpty) {
      query = query.eq('section_key', sectionKey.trim());
    }
    if (activeOnly) {
      query = query.eq('is_active', true);
    }

    final data = await query;
    var items = (data as List)
        .map((row) => WebContentItem.fromMap(
              Map<String, dynamic>.from(row as Map),
            ))
        .toList();

    if (activeOnly) {
      items = items.where((item) => item.isCurrentlyVisible).toList();
    }

    items.sort((a, b) {
      final sectionCompare = a.sectionKey.compareTo(b.sectionKey);
      if (sectionCompare != 0) return sectionCompare;
      final orderCompare = a.displayOrder.compareTo(b.displayOrder);
      if (orderCompare != 0) return orderCompare;
      return a.title.compareTo(b.title);
    });

    return items;
  }

  Future<List<WebCatalogLinkOption>> loadCatalogOptions() async {
    final List<WebCatalogLinkOption> options = <WebCatalogLinkOption>[];

    try {
      final services = await _client
          .from('services')
          .select('id, name, description, price, category, active, duration')
          .order('category')
          .order('name');
      options.addAll((services as List).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        return WebCatalogLinkOption(
          id: map['id'].toString(),
          type: 'service',
          title: map['name'] as String? ?? 'Servicio',
          subtitle: '${map['category'] ?? 'Servicio'} · ${map['duration'] ?? 60} min',
          description: map['description'] as String? ?? '',
          category: map['category'] as String? ?? '',
          price: (map['price'] as num?)?.toDouble(),
          isActive: map['active'] as bool? ?? true,
        );
      }));
    } catch (_) {}

    try {
      final products = await _client
          .from('products')
          .select(
            'id, name, description, short_description, price, category, '
            'product_type, image_url, is_active, active',
          )
          .order('category')
          .order('name');
      options.addAll((products as List).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        final category = (map['category'] as String? ?? '').trim();
        final type = (map['product_type'] as String? ?? category).trim();
        return WebCatalogLinkOption(
          id: map['id'].toString(),
          type: 'product',
          title: map['name'] as String? ?? 'Producto',
          subtitle: type.isEmpty ? category : type,
          description: (map['short_description'] as String? ??
                  map['description'] as String? ??
                  '')
              .trim(),
          imageUrl: (map['image_url'] as String? ?? '').trim(),
          category: category,
          price: (map['price'] as num?)?.toDouble(),
          isActive:
              (map['is_active'] as bool?) ?? (map['active'] as bool?) ?? true,
        );
      }));
    } catch (_) {}

    return options;
  }

  Future<WebBusinessProfile> loadBusinessProfile() async {
    try {
      final rows = await _client
          .from('sucursales')
          .select(
            'nombre, direccion_completa, telefono_contacto, whatsapp, email, link_maps',
          )
          .limit(1);

      final list = rows as List;
      if (list.isEmpty) return WebBusinessProfile.empty();

      final map = Map<String, dynamic>.from(list.first as Map);
      return WebBusinessProfile(
        name: (map['nombre'] as String? ?? 'Sahara Club Spa').trim(),
        address: (map['direccion_completa'] as String? ?? '').trim(),
        phone: (map['telefono_contacto'] as String? ?? '').trim(),
        whatsapp: (map['whatsapp'] as String? ?? '').trim(),
        email: (map['email'] as String? ?? '').trim(),
        mapsLink: (map['link_maps'] as String? ?? '').trim(),
      );
    } catch (_) {
      return WebBusinessProfile.empty();
    }
  }

  Future<WebContentItem> saveContent(WebContentItem item) async {
    final payload = item.toDatabaseMap();
    Map<String, dynamic> saved;

    if (item.id == null) {
      final inserted = await _client
          .from('web_content_sections')
          .insert(payload)
          .select()
          .single();
      saved = Map<String, dynamic>.from(inserted);
    } else {
      final updated = await _client
          .from('web_content_sections')
          .update(payload)
          .eq('id', item.id!)
          .select()
          .single();
      saved = Map<String, dynamic>.from(updated);
    }

    final resolved = WebContentItem.fromMap(saved);
    await _syncLinkedPrice(resolved);
    return resolved;
  }

  Future<void> deleteContent(String id) async {
    await _client.from('web_content_sections').delete().eq('id', id);
  }

  Future<void> _syncLinkedPrice(WebContentItem item) async {
    final price = item.price;
    if (price == null) return;

    if (item.linkedServiceId != null && item.isServiceLinkedType) {
      await _client
          .from('services')
          .update(<String, dynamic>{'price': price})
          .eq('id', item.linkedServiceId!);
      return;
    }

    if (item.linkedProductId != null && item.isProductLinkedType) {
      await _client
          .from('products')
          .update(<String, dynamic>{'price': price})
          .eq('id', item.linkedProductId!);
    }
  }
}
