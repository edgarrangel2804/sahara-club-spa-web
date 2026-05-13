import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/store_product.dart';

class StoreCatalogRepository {
  const StoreCatalogRepository();

  Future<List<StoreProduct>> loadProducts() async {
    try {
      final richData = await Supabase.instance.client
          .from('products')
          .select(
            'id, category_id, name, slug, description, short_description, '
            'price, currency, product_type, image_url, duration_minutes, '
            'is_active, is_featured, stock_quantity, digital_file_url, '
            'created_at, updated_at, category',
          )
          .or('is_active.eq.true,active.eq.true')
          .order('is_featured', ascending: false)
          .order('created_at', ascending: false);

      final parsed = (richData as List)
          .map((row) => StoreProduct.fromMap(Map<String, dynamic>.from(row)))
          .toList();
      if (parsed.isNotEmpty) return parsed;
    } catch (_) {}

    try {
      final simpleData = await Supabase.instance.client
          .from('products')
          .select('id, name, description, price, stock, category, active, created_at')
          .eq('active', true)
          .order('created_at', ascending: false);

      final parsed = (simpleData as List)
          .map((row) => StoreProduct.fromMap(Map<String, dynamic>.from(row)))
          .toList();
      if (parsed.isNotEmpty) return parsed;
    } catch (_) {}

    return _mockProducts;
  }
}

final List<StoreProduct> _mockProducts = <StoreProduct>[
  StoreProduct(
    id: 'svc-massage-relax',
    name: 'Masaje Relajante Sahara',
    slug: 'masaje-relajante-sahara',
    description:
        'Un masaje integral para soltar tension, calmar el sistema nervioso y devolverle al cuerpo un ritmo mas suave.',
    shortDescription: 'Masaje corporal premium para descanso profundo.',
    price: 1490,
    currency: 'MXN',
    type: StoreProductType.service,
    imageUrl: 'assets/images/01.png',
    categoryKey: 'massages',
    categoryLabel: 'Masajes',
    benefits: ['Descanso profundo', 'Aromaterapia', 'Cabina premium'],
    availability: 'Disponible para reservar',
    durationMinutes: 60,
    isFeatured: true,
  ),
  StoreProduct(
    id: 'svc-massage-oasis-signature',
    name: 'Masaje Oasis de Autor',
    slug: 'masaje-signature-oasis',
    description:
        'Un ritual de movimientos lentos y envolventes con aceites botanicos tibios para soltar tension, armonizar el cuerpo y llevar la mente a un estado de quietud profunda.',
    shortDescription: 'Ritual sensorial con aceites tibios y descanso profundo.',
    price: 2400,
    currency: 'MXN',
    type: StoreProductType.service,
    imageUrl: 'assets/images/hero.jpg',
    categoryKey: 'massages',
    categoryLabel: 'Masajes',
    benefits: ['Armonia sensorial', 'Aceites botanicos', 'Calma profunda'],
    availability: 'Disponible para reservar',
    durationMinutes: 90,
    isFeatured: true,
  ),
  StoreProduct(
    id: 'svc-massage-stone-therapy',
    name: 'Terapia Desert Heat Stone',
    slug: 'terapia-desert-heat-stone',
    description:
        'Piedras volcanicas templadas trabajan como extension de las manos de la terapeuta para aflojar zonas de rigidez, expandir el calor y devolver movilidad al cuerpo.',
    shortDescription: 'Piedras volcanicas y calor profundo para liberar tension.',
    price: 2800,
    currency: 'MXN',
    type: StoreProductType.service,
    imageUrl: 'assets/images/02.png',
    categoryKey: 'massages',
    categoryLabel: 'Masajes',
    benefits: ['Calor profundo', 'Libera rigidez', 'Recuperacion muscular'],
    availability: 'Disponible para reservar',
    durationMinutes: 100,
  ),
  StoreProduct(
    id: 'svc-massage-midnight-deep-tissue',
    name: 'Deep Tissue Midnight',
    slug: 'deep-tissue-midnight',
    description:
        'Presion enfocada y trabajo profundo para liberar tension cronica, realinear capas musculares y recuperar sensacion de ligereza en espalda, cuello y hombros.',
    shortDescription: 'Presion profunda para tension cronica y recuperacion corporal.',
    price: 2600,
    currency: 'MXN',
    type: StoreProductType.service,
    imageUrl: 'assets/images/01.png',
    categoryKey: 'massages',
    categoryLabel: 'Masajes',
    benefits: ['Presion profunda', 'Descarga muscular', 'Recuperacion dirigida'],
    availability: 'Disponible para reservar',
    durationMinutes: 90,
  ),
  StoreProduct(
    id: 'svc-facial-lux',
    name: 'Facial Luminosidad del Desierto',
    slug: 'facial-luminosidad-del-desierto',
    description:
        'Tratamiento facial enfocado en hidratar, iluminar y devolver textura suave con una experiencia serena.',
    shortDescription: 'Facial restaurativo con acabado luminoso.',
    price: 1690,
    currency: 'MXN',
    type: StoreProductType.service,
    imageUrl: 'assets/images/02.png',
    categoryKey: 'facials',
    categoryLabel: 'Faciales',
    benefits: ['Piel luminosa', 'Hidratacion intensa', 'Ritual sensorial'],
    availability: 'Disponible para reservar',
    durationMinutes: 75,
  ),
  StoreProduct(
    id: 'svc-facial-sand-drift',
    name: 'Facial Sand Drift',
    slug: 'facial-sand-drift',
    description:
        'Tratamiento mineral inspirado en texturas del desierto para pulir suavemente, suavizar la piel y devolver una sensacion de limpieza luminosa.',
    shortDescription: 'Ritual mineral para suavizar textura y revelar luminosidad.',
    price: 1800,
    currency: 'MXN',
    type: StoreProductType.service,
    imageUrl: 'assets/images/02.png',
    categoryKey: 'facials',
    categoryLabel: 'Faciales',
    benefits: ['Textura uniforme', 'Pulido suave', 'Luminosidad inmediata'],
    availability: 'Disponible para reservar',
    durationMinutes: 60,
    isFeatured: true,
  ),
  StoreProduct(
    id: 'svc-facial-golden-hour',
    name: 'Rejuvenecimiento Golden Hour',
    slug: 'rejuvenecimiento-golden-hour',
    description:
        'Nuestro ritual antiedad de autor combina activos revitalizantes y maniobras de precision para devolver firmeza, luminosidad y una apariencia descansada.',
    shortDescription: 'Ritual antiedad con luminosidad dorada y firmeza visible.',
    price: 2200,
    currency: 'MXN',
    type: StoreProductType.service,
    imageUrl: 'assets/images/hero.jpg',
    categoryKey: 'facials',
    categoryLabel: 'Faciales',
    benefits: ['Efecto glow', 'Firmeza visible', 'Ritual antiedad'],
    availability: 'Disponible para reservar',
    durationMinutes: 75,
    isFeatured: true,
  ),
  StoreProduct(
    id: 'svc-facial-pure-oasis',
    name: 'Detox Oasis Puro',
    slug: 'detox-pure-oasis',
    description:
        'Facial purificante con infusiones botanicas y arcillas termales para limpiar poros, refrescar la piel y liberar congestion urbana.',
    shortDescription: 'Purificacion profunda con botanicos y arcillas termales.',
    price: 1950,
    currency: 'MXN',
    type: StoreProductType.service,
    imageUrl: 'assets/images/03.png',
    categoryKey: 'facials',
    categoryLabel: 'Faciales',
    benefits: ['Purificacion profunda', 'Poro refinado', 'Sensacion fresca'],
    availability: 'Disponible para reservar',
    durationMinutes: 60,
  ),
  StoreProduct(
    id: 'svc-ritual-moon',
    name: 'Ritual Luna Sahara',
    slug: 'ritual-luna-sahara',
    description:
        'Un ritual multisensorial con respiracion guiada, calor suave y masaje para cerrar el dia con calma.',
    shortDescription: 'Ritual envolvente para cuerpo y mente.',
    price: 2190,
    currency: 'MXN',
    type: StoreProductType.service,
    imageUrl: 'assets/images/hero.jpg',
    categoryKey: 'rituals',
    categoryLabel: 'Rituales',
    benefits: ['Respiracion guiada', 'Desconexion total', 'Experiencia de autor'],
    availability: 'Disponible para reservar',
    durationMinutes: 90,
    isFeatured: true,
  ),
  StoreProduct(
    id: 'dig-meditacion-sue',
    name: 'Meditacion Sueno Profundo',
    slug: 'meditacion-sueno-profundo',
    description:
        'Audio guiado para acompanar el descanso nocturno con respiracion, visualizacion y musica sutil.',
    shortDescription: 'Audio premium para descanso y reparacion.',
    price: 249,
    currency: 'MXN',
    type: StoreProductType.digital,
    imageUrl: 'assets/images/03.png',
    categoryKey: 'digital',
    categoryLabel: 'Productos digitales',
    benefits: ['Acceso inmediato', 'Escucha ilimitada', 'Ritual guiado'],
    availability: 'Acceso inmediato despues del pago',
  ),
  StoreProduct(
    id: 'dig-music-calm',
    name: 'Musica Calma Sahara',
    slug: 'musica-calma-sahara',
    description:
        'Paisajes sonoros y texturas ambientales disenadas para meditar, descansar o acompanar un ritual en casa.',
    shortDescription: 'Coleccion de sonido para relajacion diaria.',
    price: 199,
    currency: 'MXN',
    type: StoreProductType.digital,
    imageUrl: 'assets/images/04.png',
    categoryKey: 'digital',
    categoryLabel: 'Productos digitales',
    benefits: ['Streaming privado', 'Uso diario', 'Ambiente inmersivo'],
    availability: 'Acceso inmediato despues del pago',
  ),
  StoreProduct(
    id: 'phy-oil-ritual',
    name: 'Aceite Ritual Sahara',
    slug: 'aceite-ritual-sahara',
    description:
        'Mezcla aromaticamente equilibrada para masajes ligeros, manos y cuello, pensada para extender el ritual en casa.',
    shortDescription: 'Aceite aromatico premium para tu ritual.',
    price: 790,
    currency: 'MXN',
    type: StoreProductType.physical,
    imageUrl: 'assets/images/05.png',
    categoryKey: 'physical',
    categoryLabel: 'Productos fisicos',
    benefits: ['Aromaterapia', 'Textura sedosa', 'Recoge en sucursal'],
    availability: 'Disponible para recoger en Sahara Club Spa',
    stockQuantity: 10,
  ),
  StoreProduct(
    id: 'phy-candle-nocturne',
    name: 'Vela Nocturne Sahara',
    slug: 'vela-nocturne-sahara',
    description:
        'Vela perfumada con notas calidas para transformar cualquier espacio en una pausa elegante.',
    shortDescription: 'Vela premium para ambientar rituales en casa.',
    price: 590,
    currency: 'MXN',
    type: StoreProductType.physical,
    imageUrl: 'assets/images/06.png',
    categoryKey: 'physical',
    categoryLabel: 'Productos fisicos',
    benefits: ['Aroma envolvente', 'Edicion boutique', 'Recoge en sucursal'],
    availability: 'Disponible para recoger en Sahara Club Spa',
    stockQuantity: 8,
  ),
  StoreProduct(
    id: 'mem-premium',
    name: 'Membresia Premium Sahara',
    slug: 'membresia-premium-sahara',
    description:
        'Beneficios VIP, acceso preferente y una capa extra de experiencia para quienes viven Sahara con frecuencia.',
    shortDescription: 'Acceso VIP y beneficios recurrentes.',
    price: 2490,
    currency: 'MXN',
    type: StoreProductType.membership,
    imageUrl: 'assets/images/07.png',
    categoryKey: 'memberships',
    categoryLabel: 'Membresias',
    benefits: ['Prioridad VIP', 'Beneficios exclusivos', 'Activacion inmediata'],
    availability: 'Activacion inmediata al confirmar pago',
    isFeatured: true,
  ),
  StoreProduct(
    id: 'gift-card-2500',
    name: 'Tarjeta de Regalo Sahara',
    slug: 'gift-card-sahara',
    description:
        'Tarjeta de regalo digital para compartir experiencias, servicios o productos con una presentacion premium.',
    shortDescription: 'Regala bienestar con saldo flexible.',
    price: 2500,
    currency: 'MXN',
    type: StoreProductType.giftCard,
    imageUrl: 'assets/images/08.png',
    categoryKey: 'gift_cards',
    categoryLabel: 'Tarjetas de regalo',
    benefits: ['Codigo unico', 'Canje futuro', 'Entrega digital'],
    availability: 'Codigo digital generado al pagar',
    isFeatured: true,
  ),
];
