import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/role_permissions.dart';
import 'web_content_models.dart';
import 'web_content_repository.dart';

enum _WebsiteBlockStatus { editable, pending }

class _WebsiteBlockDefinition {
  const _WebsiteBlockDefinition({
    required this.key,
    required this.title,
    required this.description,
    required this.mappedSectionKeys,
    required this.status,
    this.primarySectionKey,
  });

  final String key;
  final String title;
  final String description;
  final List<String> mappedSectionKeys;
  final String? primarySectionKey;
  final _WebsiteBlockStatus status;
}

class WebContentModule extends StatefulWidget {
  const WebContentModule({
    super.key,
    required this.currentRole,
    required this.branches,
  });

  final String currentRole;
  final List<WebContentBranch> branches;

  @override
  State<WebContentModule> createState() => _WebContentModuleState();
}

class _WebContentModuleState extends State<WebContentModule> {
  final WebContentRepository _repository = WebContentRepository();
  static const List<_WebsiteBlockDefinition> _websiteBlocks =
      <_WebsiteBlockDefinition>[
        _WebsiteBlockDefinition(
          key: 'navbar',
          title: 'Header y navegacion',
          description:
              'Menu superior, links visibles y accesos principales como Tienda y Recepcion.',
          mappedSectionKeys: <String>[],
          primarySectionKey: null,
          status: _WebsiteBlockStatus.pending,
        ),
        _WebsiteBlockDefinition(
          key: 'hero_block',
          title: 'Hero principal',
          description:
              'Imagen principal, mensaje de bienvenida y CTA superior de la portada.',
          mappedSectionKeys: <String>['hero'],
          primarySectionKey: 'hero',
          status: _WebsiteBlockStatus.editable,
        ),
        _WebsiteBlockDefinition(
          key: 'services_catalog',
          title: 'Rituales y experiencias',
          description:
              'Bloque donde el cliente explora masajes, faciales, membresias, gift cards y otras categorias.',
          mappedSectionKeys: <String>[
            'massages',
            'facials',
            'memberships',
            'digital_products',
            'physical_products',
            'gift_cards',
          ],
          primarySectionKey: 'massages',
          status: _WebsiteBlockStatus.editable,
        ),
        _WebsiteBlockDefinition(
          key: 'experience_manifesto',
          title: 'Experiencia Sahara',
          description:
              'Manifiesto, texto institucional y pilares visuales de la experiencia.',
          mappedSectionKeys: <String>[],
          primarySectionKey: null,
          status: _WebsiteBlockStatus.pending,
        ),
        _WebsiteBlockDefinition(
          key: 'featured_news',
          title: 'Destacados, banners y noticias',
          description:
              'Promociones, publicaciones destacadas y vitrinas de contenido que empujan conversion.',
          mappedSectionKeys: <String>[
            'featured_posts',
            'banners',
            'promotions',
          ],
          primarySectionKey: 'featured_posts',
          status: _WebsiteBlockStatus.editable,
        ),
        _WebsiteBlockDefinition(
          key: 'contact_block',
          title: 'Contacto, horarios y CTA final',
          description:
              'Datos reales del negocio, horarios, botones de contacto y mensaje de confianza.',
          mappedSectionKeys: <String>['contact_info', 'contact_hours'],
          primarySectionKey: 'contact_info',
          status: _WebsiteBlockStatus.editable,
        ),
        _WebsiteBlockDefinition(
          key: 'footer_legal',
          title: 'Footer, legales y politicas',
          description:
              'Footer completo, privacidad, terminos y datos corporativos finales.',
          mappedSectionKeys: <String>[
            'footer_brand',
            'footer_navigation',
            'footer_services',
            'footer_legal',
          ],
          primarySectionKey: 'footer_brand',
          status: _WebsiteBlockStatus.editable,
        ),
        _WebsiteBlockDefinition(
          key: 'map_qr_apps',
          title: 'Mapa, geolocalizacion y QR app',
          description:
              'Mapa del lugar, ubicacion real y descargas Android/iOS desde QR o links.',
          mappedSectionKeys: <String>[],
          primarySectionKey: null,
          status: _WebsiteBlockStatus.pending,
        ),
      ];

  bool _loading = true;
  String _selectedWebsiteBlockKey = _websiteBlocks.first.key;
  String _selectedSectionKey = WebContentItem.sections.first.key;
  String _search = '';
  List<WebContentItem> _items = <WebContentItem>[];
  List<WebCatalogLinkOption> _catalogOptions = <WebCatalogLinkOption>[];

  bool get _canDelete => RolePermissions.isAdminLevel(widget.currentRole);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() => _loading = true);
    }
    try {
      final items = await _repository.loadContent();
      final catalog = await _repository.loadCatalogOptions();
      if (!mounted) return;
      setState(() {
        _items = items;
        _catalogOptions = catalog;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<WebContentItem> _itemsForSection(String sectionKey) {
    final query = _search.trim().toLowerCase();
    final list = _items
        .where((item) => item.sectionKey == sectionKey)
        .where((item) {
          if (query.isEmpty) return true;
          final haystack = [
            item.title,
            item.subtitle,
            item.shortDescription,
            item.longDescription,
            item.category,
          ].join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .toList()
      ..sort((a, b) {
        final orderCompare = a.displayOrder.compareTo(b.displayOrder);
        if (orderCompare != 0) return orderCompare;
        return a.title.compareTo(b.title);
      });
    return list;
  }

  _WebsiteBlockDefinition get _selectedWebsiteBlock {
    return _websiteBlocks.firstWhere(
      (block) => block.key == _selectedWebsiteBlockKey,
      orElse: () => _websiteBlocks.first,
    );
  }

  Future<void> _openEditor({
    WebContentItem? item,
    String? sectionKey,
  }) async {
    final targetSection =
        WebContentItem.sectionByKey(sectionKey ?? _selectedSectionKey) ??
            WebContentItem.sections.first;
    final branchId =
        widget.branches.isNotEmpty ? widget.branches.first.id : null;
    final initial = item ??
        WebContentItem.empty(
          branchId: branchId,
          sectionKey: targetSection.key,
          contentType: targetSection.contentType,
        );

    final saved = await showDialog<WebContentItem>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _WebContentEditorSheet(
          item: initial,
          branches: widget.branches,
          catalogOptions: _catalogOptions,
        );
      },
    );

    if (saved == null) return;
    await _repository.saveContent(saved);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Contenido guardado correctamente'),
        backgroundColor: Color(0xFFC6A76A),
      ),
    );
    await _load();
  }

  Future<void> _delete(WebContentItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar contenido'),
        content: Text(
          'Se eliminara "${item.title.isEmpty ? item.sectionLabel : item.title}". Esta accion no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await _repository.deleteContent(item.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contenido eliminado')),
    );
    await _load();
  }

  Future<void> _toggleActive(WebContentItem item, bool value) async {
    await _repository.saveContent(item.copyWith(isActive: value));
    await _load();
  }

  Future<void> _toggleFeatured(WebContentItem item, bool value) async {
    await _repository.saveContent(item.copyWith(isFeatured: value));
    await _load();
  }

  Future<void> _showPreview(WebContentItem item) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _WebContentPreviewDialog(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedBlock = _selectedWebsiteBlock;
    final selectedSection =
        WebContentItem.sectionByKey(_selectedSectionKey) ??
            WebContentItem.sections.first;
    final visibleSections = selectedBlock.mappedSectionKeys.isEmpty
        ? WebContentItem.sections
        : WebContentItem.sections
            .where(
              (section) => selectedBlock.mappedSectionKeys.contains(section.key),
            )
            .toList();
    final activeSection =
        visibleSections.any((section) => section.key == selectedSection.key)
            ? selectedSection
            : (visibleSections.isNotEmpty ? visibleSections.first : selectedSection);
    final selectedItems = _itemsForSection(activeSection.key);

    return Container(
      color: const Color(0xFFF5F3EF),
      child: Column(
        children: [
          _WebContentHeader(
            search: _search,
            onSearchChanged: (value) => setState(() => _search = value),
            onCreate: _loading ? null : () => _openEditor(),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        'Mapa de la pagina',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1F1A15),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cada tarjeta representa una sección de la página web. Desde aquí puedes ver qué contenido existe, cómo se verá y abrir el editor sin salir del panel.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          height: 1.6,
                          color: const Color(0xFF6D655B),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _websiteBlocks.map((block) {
                          final selected = block.key == selectedBlock.key;
                          return selected
                              ? FilledButton(
                                  onPressed: () {},
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFC6A76A),
                                    foregroundColor: const Color(0xFF1F170F),
                                  ),
                                  child: Text(block.title),
                                )
                              : OutlinedButton(
                                  onPressed: () => setState(() {
                                    _selectedWebsiteBlockKey = block.key;
                                    if (block.primarySectionKey != null) {
                                      _selectedSectionKey =
                                          block.primarySectionKey!;
                                    }
                                  }),
                                  child: Text(block.title),
                                );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      _WebsiteMapFocusPanel(
                        block: selectedBlock,
                        itemsCount: _items
                            .where(
                              (item) => selectedBlock.mappedSectionKeys.contains(
                                item.sectionKey,
                              ),
                            )
                            .length,
                        visibleCount: _items
                            .where(
                              (item) =>
                                  selectedBlock.mappedSectionKeys.contains(
                                    item.sectionKey,
                                  ) &&
                                  item.isCurrentlyVisible,
                            )
                            .length,
                        onOpenSection: (sectionKey) => setState(() {
                          _selectedSectionKey = sectionKey;
                        }),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Contenido administrable',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1F1A15),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        selectedBlock.mappedSectionKeys.isEmpty
                            ? 'Este bloque aun no esta conectado al CMS. Aqui dejaremos los botones de edicion cuando cableemos esta parte de la landing.'
                            : 'Estas tarjetas alimentan este bloque de la web. Aqui editas el contenido puntual que se muestra en la zona seleccionada.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          height: 1.6,
                          color: const Color(0xFF6D655B),
                        ),
                      ),
                      const SizedBox(height: 22),
                      if (visibleSections.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE7DECF)),
                          ),
                          child: Text(
                            'Todavia no hay secciones conectadas para este bloque. En la siguiente fase aqui apareceran sus botones y formularios de edicion.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              height: 1.6,
                              color: const Color(0xFF6D655B),
                            ),
                          ),
                        )
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final wide = constraints.maxWidth >= 1120;
                            final crossAxisCount = wide ? 2 : 1;
                            final spacing = 16.0;
                            final cardWidth = (constraints.maxWidth -
                                    (crossAxisCount - 1) * spacing) /
                                crossAxisCount;
                            const cardHeight = 280.0;
                            return Wrap(
                              spacing: spacing,
                              runSpacing: spacing,
                              children: visibleSections.map((section) {
                                final sectionItems = _itemsForSection(section.key);
                                final previewItem = sectionItems
                                        .where((item) => item.isCurrentlyVisible)
                                        .cast<WebContentItem?>()
                                        .firstWhere(
                                          (item) => item != null,
                                          orElse: () => null,
                                        ) ??
                                    (sectionItems.isNotEmpty
                                        ? sectionItems.first
                                        : null);
                                return SizedBox(
                                  width: cardWidth,
                                  height: cardHeight,
                                  child: _SectionOverviewCard(
                                    section: section,
                                    items: sectionItems,
                                    previewItem: previewItem,
                                    selected: section.key == activeSection.key,
                                    onSelect: () => setState(
                                      () => _selectedSectionKey = section.key,
                                    ),
                                    onCreate: () => _openEditor(sectionKey: section.key),
                                    onEditPrimary: previewItem != null
                                        ? () => _openEditor(
                                              item: previewItem,
                                              sectionKey: section.key,
                                            )
                                        : null,
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      const SizedBox(height: 28),
                      if (visibleSections.isNotEmpty)
                        _SectionDetailPanel(
                          section: activeSection,
                          items: selectedItems,
                          onCreate: () => _openEditor(sectionKey: activeSection.key),
                          onEdit: (item) => _openEditor(
                            item: item,
                            sectionKey: activeSection.key,
                          ),
                          onDelete: _canDelete ? _delete : null,
                          onPreview: _showPreview,
                          onToggleActive: _toggleActive,
                          onToggleFeatured: _toggleFeatured,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _WebContentHeader extends StatelessWidget {
  const _WebContentHeader({
    required this.search,
    required this.onSearchChanged,
    required this.onCreate,
  });

  final String search;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
      decoration: const BoxDecoration(
        color: Color(0xFFFCFAF6),
        border: Border(bottom: BorderSide(color: Color(0xFFE9E1D4))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configuraciones pagina web',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Controla lo que el cliente ve en la web: hero, servicios, promociones, destacados y vitrinas de la tienda. Los cambios se reflejan sin tocar código.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.5,
                        color: const Color(0xFF6D655B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              FilledButton.icon(
                onPressed: onCreate,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFC6A76A),
                  foregroundColor: const Color(0xFF1F170F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: Text(
                  'Nueva publicacion',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: onSearchChanged,
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: InputDecoration(
                    hintText:
                        'Buscar por titulo, texto, categoria o tipo de contenido...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionOverviewCard extends StatelessWidget {
  const _SectionOverviewCard({
    required this.section,
    required this.items,
    required this.previewItem,
    required this.selected,
    required this.onSelect,
    required this.onCreate,
    this.onEditPrimary,
  });

  final WebContentSectionDefinition section;
  final List<WebContentItem> items;
  final WebContentItem? previewItem;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onCreate;
  final VoidCallback? onEditPrimary;

  @override
  Widget build(BuildContext context) {
    final activeCount = items.where((item) => item.isCurrentlyVisible).length;
    final featuredCount = items.where((item) => item.isFeatured).length;
    final statusLabel = items.isEmpty
        ? 'Lista para configurar'
        : (activeCount > 0 ? 'Activa' : 'Contenido oculto');
    final statusColor = items.isEmpty
        ? const Color(0xFFEFF2F7)
        : (activeCount > 0
            ? const Color(0xFFE5F4E8)
            : const Color(0xFFF5E8E4));

    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected
                ? const Color(0xFFC6A76A)
                : const Color(0xFFE7DECF),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.label,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E1813),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        section.description.isEmpty
                            ? 'Contenido visible en esta sección de la página web.'
                            : section.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          height: 1.5,
                          color: const Color(0xFF6D655B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _StatusChip(
                  label: statusLabel,
                  color: statusColor,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _MiniStat(label: 'Items', value: '${items.length}'),
                const SizedBox(width: 10),
                _MiniStat(label: 'Activos', value: '$activeCount'),
                const SizedBox(width: 10),
                _MiniStat(label: 'Destacados', value: '$featuredCount'),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F4EC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFEEE4D4)),
                ),
                child: previewItem == null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Text(
                            'Todavía no hay contenido cargado aquí.\nUsa "Crear contenido" para empezar.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              height: 1.5,
                              color: const Color(0xFF83786D),
                            ),
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(18),
                            ),
                            child: SizedBox(
                              width: 148,
                              height: double.infinity,
                              child: _RemoteOrAssetImage(url: previewItem!.imageUrl),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Preview',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      letterSpacing: 1.8,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFC6A76A),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    previewItem!.title.isEmpty
                                        ? 'Sin titulo'
                                        : previewItem!.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1E1813),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: Text(
                                      previewItem!.shortDescription.isNotEmpty
                                          ? previewItem!.shortDescription
                                          : previewItem!.longDescription,
                                      maxLines: 4,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        height: 1.5,
                                        color: const Color(0xFF675D52),
                                      ),
                                    ),
                                  ),
                                  if (previewItem!.priceLabel.isNotEmpty)
                                    Text(
                                      previewItem!.promoPriceLabel.isNotEmpty
                                          ? previewItem!.promoPriceLabel
                                          : previewItem!.priceLabel,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF9E7B33),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton(
                  onPressed: onCreate,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC6A76A),
                    foregroundColor: const Color(0xFF1F170F),
                  ),
                  child: const Text('Crear contenido'),
                ),
                if (items.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: onSelect,
                    child: const Text('Ver listado'),
                  ),
                ],
                if (onEditPrimary != null) ...[
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: onEditPrimary,
                    child: const Text('Editar preview'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WebsiteMapFocusPanel extends StatelessWidget {
  const _WebsiteMapFocusPanel({
    required this.block,
    required this.itemsCount,
    required this.visibleCount,
    required this.onOpenSection,
  });

  final _WebsiteBlockDefinition block;
  final int itemsCount;
  final int visibleCount;
  final ValueChanged<String> onOpenSection;

  @override
  Widget build(BuildContext context) {
    final statusLabel = block.status == _WebsiteBlockStatus.editable
        ? 'Editable hoy'
        : 'Siguiente fase';
    final statusColor = block.status == _WebsiteBlockStatus.editable
        ? const Color(0xFFE5F4E8)
        : const Color(0xFFF3EEDF);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7DECF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  block.title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E1813),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _StatusChip(label: statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            block.description,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.55,
              color: const Color(0xFF6D655B),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F4EC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEEE4D4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vista del bloque',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                    color: const Color(0xFFC6A76A),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _previewSummary(),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.5,
                    color: const Color(0xFF675D52),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MiniStat(label: 'Items', value: '$itemsCount'),
              _MiniStat(label: 'Visibles', value: '$visibleCount'),
              _MiniStat(
                label: 'Estado',
                value: block.status == _WebsiteBlockStatus.editable
                    ? 'Conectado'
                    : 'Pendiente',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (block.mappedSectionKeys.isNotEmpty) ...[
            Text(
              'Secciones de este bloque',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF554B40),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: block.mappedSectionKeys.map((sectionKey) {
                final section = WebContentItem.sectionByKey(sectionKey);
                if (section == null) return const SizedBox.shrink();
                return FilledButton.icon(
                  onPressed: () => onOpenSection(section.key),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC6A76A),
                    foregroundColor: const Color(0xFF1F170F),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(section.label),
                );
              }).toList(),
            ),
          ] else
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.schedule_outlined, size: 16),
              label: const Text('Lo conectamos en la siguiente fase'),
            ),
        ],
      ),
    );
  }

  String _previewSummary() {
    if (block.status == _WebsiteBlockStatus.pending) {
      return 'Este bloque ya esta mapeado visualmente para que ubiques la zona de la web, pero aun no esta conectado al CMS.';
    }
    if (itemsCount == 0) {
      return 'Todavia no hay contenido administrable cargado para este bloque. Puedes entrar y empezar a configurarlo.';
    }
    if (visibleCount == 0) {
      return 'Este bloque ya tiene contenido, pero ahora mismo nada esta visible para el cliente.';
    }
    return 'Este bloque ya tiene contenido visible y puedes administrarlo desde este panel.';
  }
}

class _SectionDetailPanel extends StatelessWidget {
  const _SectionDetailPanel({
    required this.section,
    required this.items,
    required this.onCreate,
    required this.onEdit,
    required this.onPreview,
    required this.onToggleActive,
    required this.onToggleFeatured,
    this.onDelete,
  });

  final WebContentSectionDefinition section;
  final List<WebContentItem> items;
  final VoidCallback onCreate;
  final void Function(WebContentItem item) onEdit;
  final void Function(WebContentItem item) onPreview;
  final void Function(WebContentItem item, bool value) onToggleActive;
  final void Function(WebContentItem item, bool value) onToggleFeatured;
  final Future<void> Function(WebContentItem item)? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7DECF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.label,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1F1A15),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      section.description.isEmpty
                          ? 'Contenido visible en esta parte de la página web.'
                          : section.description,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.6,
                        color: const Color(0xFF6D655B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: onCreate,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFC6A76A),
                  foregroundColor: const Color(0xFF1F170F),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Crear contenido'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F4EC),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                'No hay contenido cargado en ${section.label}. Cuando crees uno, aparecerá aquí con su estado, orden y accesos para editarlo o previsualizarlo.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.6,
                  color: const Color(0xFF6F655A),
                ),
              ),
            )
          else
            ...items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _ContentRowCard(
                  item: item,
                  onEdit: () => onEdit(item),
                  onPreview: () => onPreview(item),
                  onToggleActive: (value) => onToggleActive(item, value),
                  onToggleFeatured: (value) => onToggleFeatured(item, value),
                  onDelete: onDelete == null ? null : () => onDelete!(item),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _ContentRowCard extends StatelessWidget {
  const _ContentRowCard({
    required this.item,
    required this.onEdit,
    required this.onPreview,
    required this.onToggleActive,
    required this.onToggleFeatured,
    this.onDelete,
  });

  final WebContentItem item;
  final VoidCallback onEdit;
  final VoidCallback onPreview;
  final ValueChanged<bool> onToggleActive;
  final ValueChanged<bool> onToggleFeatured;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final dateRange = _dateRangeLabel(item.startDate, item.endDate);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFAF6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEAE1D4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 140,
              height: 112,
              child: _RemoteOrAssetImage(url: item.imageUrl),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusChip(
                      label: item.isCurrentlyVisible ? 'Visible' : 'Oculta',
                      color: item.isCurrentlyVisible
                          ? const Color(0xFFE5F4E8)
                          : const Color(0xFFF5E8E4),
                    ),
                    _StatusChip(
                      label: 'Orden ${item.displayOrder}',
                      color: const Color(0xFFF3EEDF),
                    ),
                    if (item.isFeatured)
                      const _StatusChip(
                        label: 'Destacado',
                        color: Color(0xFFFBE7B2),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item.title.isEmpty ? 'Sin titulo' : item.title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1C1712),
                  ),
                ),
                if (item.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF897B6D),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  item.shortDescription.isNotEmpty
                      ? item.shortDescription
                      : item.longDescription,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.5,
                    color: const Color(0xFF62584D),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  children: [
                    if (item.priceLabel.isNotEmpty)
                      _MetaText(label: 'Precio', value: item.priceLabel),
                    if (item.promoPriceLabel.isNotEmpty)
                      _MetaText(label: 'Promo', value: item.promoPriceLabel),
                    if (item.category.isNotEmpty)
                      _MetaText(label: 'Categoria', value: item.category),
                    if (dateRange.isNotEmpty)
                      _MetaText(label: 'Vigencia', value: dateRange),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 190,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile.adaptive(
                  value: item.isActive,
                  onChanged: onToggleActive,
                  dense: true,
                  activeThumbColor: const Color(0xFFC6A76A),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Activo',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SwitchListTile.adaptive(
                  value: item.isFeatured,
                  onChanged: onToggleFeatured,
                  dense: true,
                  activeThumbColor: const Color(0xFFC6A76A),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Destacado',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: onPreview,
                      child: const Text('Preview'),
                    ),
                    OutlinedButton(
                      onPressed: onEdit,
                      child: const Text('Editar'),
                    ),
                    if (item.ctaUrl.trim().isNotEmpty)
                      OutlinedButton(
                        onPressed: () async {
                          final uri = _resolveCtaUri(item.ctaUrl);
                          if (uri != null) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        child: const Text('Abrir CTA'),
                      ),
                    if (onDelete != null)
                      TextButton(
                        onPressed: onDelete,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                        ),
                        child: const Text('Eliminar'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WebContentEditorSheet extends StatefulWidget {
  const _WebContentEditorSheet({
    required this.item,
    required this.branches,
    required this.catalogOptions,
  });

  final WebContentItem item;
  final List<WebContentBranch> branches;
  final List<WebCatalogLinkOption> catalogOptions;

  @override
  State<_WebContentEditorSheet> createState() => _WebContentEditorSheetState();
}

class _WebContentEditorSheetState extends State<_WebContentEditorSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late String? _branchId =
      widget.item.branchId ??
      (widget.branches.isNotEmpty ? widget.branches.first.id : null);
  late String _sectionKey = widget.item.sectionKey;
  late String _contentType = widget.item.contentType;
  late String? _linkedServiceId = widget.item.linkedServiceId;
  late String? _linkedProductId = widget.item.linkedProductId;
  late bool _isActive = widget.item.isActive;
  late bool _isFeatured = widget.item.isFeatured;
  late DateTime? _startDate = widget.item.startDate;
  late DateTime? _endDate = widget.item.endDate;

  late final TextEditingController _titleCtrl =
      TextEditingController(text: widget.item.title);
  late final TextEditingController _subtitleCtrl =
      TextEditingController(text: widget.item.subtitle);
  late final TextEditingController _shortCtrl =
      TextEditingController(text: widget.item.shortDescription);
  late final TextEditingController _longCtrl =
      TextEditingController(text: widget.item.longDescription);
  late final TextEditingController _priceCtrl =
      TextEditingController(
        text: widget.item.price?.toStringAsFixed(0) ?? '',
      );
  late final TextEditingController _promoPriceCtrl =
      TextEditingController(
        text: widget.item.promoPrice?.toStringAsFixed(0) ?? '',
      );
  late final TextEditingController _imageCtrl =
      TextEditingController(text: widget.item.imageUrl);
  late final TextEditingController _videoCtrl =
      TextEditingController(text: widget.item.videoUrl);
  late final TextEditingController _categoryCtrl =
      TextEditingController(text: widget.item.category);
  late final TextEditingController _ctaTextCtrl =
      TextEditingController(text: widget.item.ctaText);
  late final TextEditingController _ctaUrlCtrl =
      TextEditingController(text: widget.item.ctaUrl);
  late final TextEditingController _orderCtrl =
      TextEditingController(text: widget.item.displayOrder.toString());

  String? _formError;

  List<WebCatalogLinkOption> get _catalogOptionsForSection {
    if (WebContentItem.serviceTypes.contains(_contentType)) {
      return widget.catalogOptions
          .where((option) => option.type == 'service')
          .toList();
    }
    if (WebContentItem.productTypes.contains(_contentType)) {
      return widget.catalogOptions
          .where((option) => option.type == 'product')
          .toList();
    }
    return const <WebCatalogLinkOption>[];
  }

  WebContentItem get _previewItem {
    return widget.item.copyWith(
      branchId: _branchId,
      sectionKey: _sectionKey,
      contentType: _contentType,
      title: _titleCtrl.text.trim(),
      subtitle: _subtitleCtrl.text.trim(),
      shortDescription: _shortCtrl.text.trim(),
      longDescription: _longCtrl.text.trim(),
      price: double.tryParse(_priceCtrl.text.trim()),
      clearPrice: _priceCtrl.text.trim().isEmpty,
      promoPrice: double.tryParse(_promoPriceCtrl.text.trim()),
      clearPromoPrice: _promoPriceCtrl.text.trim().isEmpty,
      imageUrl: _imageCtrl.text.trim(),
      videoUrl: _videoCtrl.text.trim(),
      category: _categoryCtrl.text.trim(),
      ctaText: _ctaTextCtrl.text.trim(),
      ctaUrl: _ctaUrlCtrl.text.trim(),
      displayOrder: int.tryParse(_orderCtrl.text.trim()) ?? 0,
      isActive: _isActive,
      isFeatured: _isFeatured,
      startDate: _startDate,
      clearStartDate: _startDate == null,
      endDate: _endDate,
      clearEndDate: _endDate == null,
      linkedServiceId: _linkedServiceId,
      clearLinkedServiceId: _linkedServiceId == null,
      linkedProductId: _linkedProductId,
      clearLinkedProductId: _linkedProductId == null,
    );
  }

  @override
  void initState() {
    super.initState();
    final controllers = [
      _titleCtrl,
      _subtitleCtrl,
      _shortCtrl,
      _longCtrl,
      _priceCtrl,
      _promoPriceCtrl,
      _imageCtrl,
      _videoCtrl,
      _categoryCtrl,
      _ctaTextCtrl,
      _ctaUrlCtrl,
      _orderCtrl,
    ];
    for (final controller in controllers) {
      controller.addListener(_handleLivePreviewChange);
    }
  }

  void _handleLivePreviewChange() {
    if (mounted) {
      setState(() {
        _formError = null;
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    _shortCtrl.dispose();
    _longCtrl.dispose();
    _priceCtrl.dispose();
    _promoPriceCtrl.dispose();
    _imageCtrl.dispose();
    _videoCtrl.dispose();
    _categoryCtrl.dispose();
    _ctaTextCtrl.dispose();
    _ctaUrlCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  void _applySection(String key) {
    final section = WebContentItem.sectionByKey(key);
    setState(() {
      _sectionKey = key;
      _contentType = section?.contentType ?? _contentType;
      _linkedServiceId = WebContentItem.serviceTypes.contains(_contentType)
          ? _linkedServiceId
          : null;
      _linkedProductId = WebContentItem.productTypes.contains(_contentType)
          ? _linkedProductId
          : null;
    });
  }

  void _applyCatalogSelection(String? id) {
    if (WebContentItem.serviceTypes.contains(_contentType)) {
      _linkedServiceId = id;
      _linkedProductId = null;
    } else if (WebContentItem.productTypes.contains(_contentType)) {
      _linkedProductId = id;
      _linkedServiceId = null;
    }

    WebCatalogLinkOption? selected;
    for (final option in _catalogOptionsForSection) {
      if (option.id == id) {
        selected = option;
        break;
      }
    }
    if (selected != null) {
      if (_titleCtrl.text.trim().isEmpty) _titleCtrl.text = selected.title;
      if (_subtitleCtrl.text.trim().isEmpty) {
        _subtitleCtrl.text = selected.subtitle;
      }
      if (_shortCtrl.text.trim().isEmpty) {
        _shortCtrl.text = selected.description;
      }
      if (_imageCtrl.text.trim().isEmpty && selected.imageUrl.isNotEmpty) {
        _imageCtrl.text = selected.imageUrl;
      }
      if (_categoryCtrl.text.trim().isEmpty && selected.category.isNotEmpty) {
        _categoryCtrl.text = selected.category;
      }
      if (_priceCtrl.text.trim().isEmpty && selected.price != null) {
        _priceCtrl.text = selected.price!.toStringAsFixed(0);
      }
    }
    setState(() => _formError = null);
  }

  Future<void> _pickDate(bool isStart) async {
    final initialDate = (isStart ? _startDate : _endDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      locale: const Locale('es', 'MX'),
    );
    if (picked == null) return;
    setState(() {
      final value = DateTime(picked.year, picked.month, picked.day, 12);
      if (isStart) {
        _startDate = value;
      } else {
        _endDate = value;
      }
    });
  }

  void _save() {
    setState(() => _formError = null);
    if (!_formKey.currentState!.validate()) return;

    final price = double.tryParse(_priceCtrl.text.trim());
    final promoPrice = double.tryParse(_promoPriceCtrl.text.trim());
    if (promoPrice != null && price != null && promoPrice > price) {
      setState(() {
        _formError =
            'El precio promocional no puede ser mayor al precio principal.';
      });
      return;
    }
    if (_ctaTextCtrl.text.trim().isNotEmpty &&
        _ctaUrlCtrl.text.trim().isEmpty) {
      setState(() {
        _formError =
            'Si agregas un botón CTA, también debes capturar su link.';
      });
      return;
    }
    if (_startDate != null &&
        _endDate != null &&
        _endDate!.isBefore(_startDate!)) {
      setState(() {
        _formError =
            'La fecha de fin no puede ser anterior a la fecha de inicio.';
      });
      return;
    }
    Navigator.pop(context, _previewItem);
  }

  @override
  Widget build(BuildContext context) {
    final selectedSection =
        WebContentItem.sectionByKey(_sectionKey) ??
            WebContentItem.sections.first;
    final catalogOptions = _catalogOptionsForSection;
    final linkedValue = _linkedServiceId ?? _linkedProductId;
    final media = MediaQuery.of(context);
    final dateFormat = DateFormat('dd MMM yyyy', 'es_MX');
    final isWide = media.size.width >= 1180;
    final dialogWidth = isWide ? media.size.width * 0.92 : media.size.width * 0.96;
    final dialogHeight = media.size.height * 0.92;

    final formPane = _EditorFormPane(
      formKey: _formKey,
      branchId: _branchId,
      branches: widget.branches,
      sectionKey: _sectionKey,
      selectedSection: selectedSection,
      contentType: _contentType,
      linkedValue: linkedValue,
      catalogOptions: catalogOptions,
      titleCtrl: _titleCtrl,
      subtitleCtrl: _subtitleCtrl,
      shortCtrl: _shortCtrl,
      longCtrl: _longCtrl,
      priceCtrl: _priceCtrl,
      promoPriceCtrl: _promoPriceCtrl,
      imageCtrl: _imageCtrl,
      videoCtrl: _videoCtrl,
      categoryCtrl: _categoryCtrl,
      ctaTextCtrl: _ctaTextCtrl,
      ctaUrlCtrl: _ctaUrlCtrl,
      orderCtrl: _orderCtrl,
      isActive: _isActive,
      isFeatured: _isFeatured,
      startDate: _startDate,
      endDate: _endDate,
      dateFormat: dateFormat,
      formError: _formError,
      onSectionChanged: _applySection,
      onBranchChanged: (value) => setState(() => _branchId = value),
      onCatalogChanged: _applyCatalogSelection,
      onPickStartDate: () => _pickDate(true),
      onPickEndDate: () => _pickDate(false),
      onClearStartDate: () => setState(() => _startDate = null),
      onClearEndDate: () => setState(() => _endDate = null),
      onActiveChanged: (value) => setState(() => _isActive = value),
      onFeaturedChanged: (value) => setState(() => _isFeatured = value),
      onCancel: () => Navigator.pop(context),
      onSave: _save,
      isEditing: widget.item.id != null,
    );

    final previewPane = _LivePreviewPane(item: _previewItem);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: SafeArea(
        child: SizedBox(
          width: dialogWidth,
          height: dialogHeight,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3EF),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFE7DECF)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 32,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                24 + media.viewInsets.bottom,
              ),
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 7,
                          child: SingleChildScrollView(child: formPane),
                        ),
                        const SizedBox(width: 18),
                        Expanded(flex: 5, child: previewPane),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(child: formPane),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 320,
                          width: double.infinity,
                          child: previewPane,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorFormPane extends StatelessWidget {
  const _EditorFormPane({
    required this.formKey,
    required this.branchId,
    required this.branches,
    required this.sectionKey,
    required this.selectedSection,
    required this.contentType,
    required this.linkedValue,
    required this.catalogOptions,
    required this.titleCtrl,
    required this.subtitleCtrl,
    required this.shortCtrl,
    required this.longCtrl,
    required this.priceCtrl,
    required this.promoPriceCtrl,
    required this.imageCtrl,
    required this.videoCtrl,
    required this.categoryCtrl,
    required this.ctaTextCtrl,
    required this.ctaUrlCtrl,
    required this.orderCtrl,
    required this.isActive,
    required this.isFeatured,
    required this.startDate,
    required this.endDate,
    required this.dateFormat,
    required this.formError,
    required this.onSectionChanged,
    required this.onBranchChanged,
    required this.onCatalogChanged,
    required this.onPickStartDate,
    required this.onPickEndDate,
    required this.onClearStartDate,
    required this.onClearEndDate,
    required this.onActiveChanged,
    required this.onFeaturedChanged,
    required this.onCancel,
    required this.onSave,
    required this.isEditing,
  });

  final GlobalKey<FormState> formKey;
  final String? branchId;
  final List<WebContentBranch> branches;
  final String sectionKey;
  final WebContentSectionDefinition selectedSection;
  final String contentType;
  final String? linkedValue;
  final List<WebCatalogLinkOption> catalogOptions;
  final TextEditingController titleCtrl;
  final TextEditingController subtitleCtrl;
  final TextEditingController shortCtrl;
  final TextEditingController longCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController promoPriceCtrl;
  final TextEditingController imageCtrl;
  final TextEditingController videoCtrl;
  final TextEditingController categoryCtrl;
  final TextEditingController ctaTextCtrl;
  final TextEditingController ctaUrlCtrl;
  final TextEditingController orderCtrl;
  final bool isActive;
  final bool isFeatured;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateFormat dateFormat;
  final String? formError;
  final ValueChanged<String> onSectionChanged;
  final ValueChanged<String?> onBranchChanged;
  final ValueChanged<String?> onCatalogChanged;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickEndDate;
  final VoidCallback onClearStartDate;
  final VoidCallback onClearEndDate;
  final ValueChanged<bool> onActiveChanged;
  final ValueChanged<bool> onFeaturedChanged;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7DECF)),
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing
                            ? 'Editar contenido web'
                            : 'Crear contenido web',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Edita los campos y revisa a la derecha cómo se vería el cambio antes de publicarlo.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF6D655B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: 250,
                  child: _FormFieldFrame(
                    label: 'Seccion *',
                    child: DropdownButtonFormField<String>(
                      initialValue: sectionKey,
                      decoration: _editorInputDecoration(),
                      items: WebContentItem.sections.map((section) {
                        return DropdownMenuItem<String>(
                          value: section.key,
                          child: Text(section.label),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) onSectionChanged(value);
                      },
                    ),
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: _FormFieldFrame(
                    label: 'Tipo',
                    child: TextFormField(
                      initialValue: contentType,
                      enabled: false,
                      decoration: _editorInputDecoration(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: _FormFieldFrame(
                    label: 'Sucursal',
                    child: DropdownButtonFormField<String?>(
                      initialValue: branchId,
                      decoration: _editorInputDecoration(),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Global'),
                        ),
                        ...branches.map((branch) {
                          return DropdownMenuItem<String?>(
                            value: branch.id,
                            child: Text(branch.name),
                          );
                        }),
                      ],
                      onChanged: onBranchChanged,
                    ),
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: _FormFieldFrame(
                    label: 'Orden *',
                    child: TextFormField(
                      controller: orderCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _editorInputDecoration(hintText: '0'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Requerido';
                        }
                        if (int.tryParse(value.trim()) == null) {
                          return 'Número inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              selectedSection.description,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF877A6C),
              ),
            ),
            if (catalogOptions.isNotEmpty) ...[
              const SizedBox(height: 20),
              _FormFieldFrame(
                label: WebContentItem.serviceTypes.contains(contentType)
                    ? 'Servicio vinculado'
                    : 'Producto vinculado',
                child: DropdownButtonFormField<String?>(
                  initialValue: linkedValue,
                  decoration: _editorInputDecoration(
                    hintText: 'Selecciona del catálogo real',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Sin vincular'),
                    ),
                    ...catalogOptions.map((option) {
                      return DropdownMenuItem<String?>(
                        value: option.id,
                        child: Text(
                          option.priceLabel.isEmpty
                              ? option.title
                              : '${option.title} · ${option.priceLabel}',
                        ),
                      );
                    }),
                  ],
                  onChanged: onCatalogChanged,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Si este contenido representa algo vendible, conviene vincularlo al catálogo real para no duplicar precios ni productos.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF877A6C),
                ),
              ),
            ],
            const SizedBox(height: 22),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _FormFieldFrame(
                        label: 'Titulo *',
                        child: TextFormField(
                          controller: titleCtrl,
                          decoration: _editorInputDecoration(),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Captura un título';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      _FormFieldFrame(
                        label: 'Subtitulo',
                        child: TextFormField(
                          controller: subtitleCtrl,
                          decoration: _editorInputDecoration(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _FormFieldFrame(
                        label: 'Descripcion corta',
                        child: TextFormField(
                          controller: shortCtrl,
                          maxLines: 3,
                          decoration: _editorInputDecoration(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _FormFieldFrame(
                        label: 'Descripcion larga',
                        child: TextFormField(
                          controller: longCtrl,
                          maxLines: 6,
                          decoration: _editorInputDecoration(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _FormFieldFrame(
                              label: 'Precio',
                              child: TextFormField(
                                controller: priceCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: _editorInputDecoration(
                                  prefixText: '\$',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _FormFieldFrame(
                              label: 'Precio promocional',
                              child: TextFormField(
                                controller: promoPriceCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: _editorInputDecoration(
                                  prefixText: '\$',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _FormFieldFrame(
                        label: 'Categoria',
                        child: TextFormField(
                          controller: categoryCtrl,
                          decoration: _editorInputDecoration(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _FormFieldFrame(
                        label: 'Imagen',
                        child: TextFormField(
                          controller: imageCtrl,
                          decoration: _editorInputDecoration(
                            hintText: 'https://... o assets/images/...',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Agrega una imagen para la preview';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      _FormFieldFrame(
                        label: 'Video opcional',
                        child: TextFormField(
                          controller: videoCtrl,
                          decoration: _editorInputDecoration(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _FormFieldFrame(
                              label: 'Boton CTA',
                              child: TextFormField(
                                controller: ctaTextCtrl,
                                decoration: _editorInputDecoration(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _FormFieldFrame(
                              label: 'Link CTA',
                              child: TextFormField(
                                controller: ctaUrlCtrl,
                                decoration: _editorInputDecoration(
                                  hintText: 'https://... / /tienda / #contacto',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _DateCard(
                    label: 'Fecha de inicio',
                    value: startDate == null
                        ? 'Sin fecha'
                        : dateFormat.format(startDate!),
                    onPick: onPickStartDate,
                    onClear: startDate == null ? null : onClearStartDate,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _DateCard(
                    label: 'Fecha de fin',
                    value: endDate == null
                        ? 'Sin fecha'
                        : dateFormat.format(endDate!),
                    onPick: onPickEndDate,
                    onClear: endDate == null ? null : onClearEndDate,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch.adaptive(
                      value: isActive,
                      activeThumbColor: const Color(0xFFC6A76A),
                      onChanged: onActiveChanged,
                    ),
                    Text(
                      'Activo',
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch.adaptive(
                      value: isFeatured,
                      activeThumbColor: const Color(0xFFC6A76A),
                      onChanged: onFeaturedChanged,
                    ),
                    Text(
                      'Destacado',
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
            if (formError != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF4B8B2)),
                ),
                child: Text(
                  formError!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF9F2D20),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => _WebContentPreviewDialog(
                        item: _buildStaticPreview(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Abrir preview grande'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onCancel,
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: onSave,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC6A76A),
                    foregroundColor: const Color(0xFF1F170F),
                  ),
                  child: const Text('Guardar contenido'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  WebContentItem _buildStaticPreview() {
    return WebContentItem.empty(
      branchId: branchId,
      sectionKey: sectionKey,
      contentType: contentType,
    ).copyWith(
      title: titleCtrl.text.trim(),
      subtitle: subtitleCtrl.text.trim(),
      shortDescription: shortCtrl.text.trim(),
      longDescription: longCtrl.text.trim(),
      price: double.tryParse(priceCtrl.text.trim()),
      clearPrice: priceCtrl.text.trim().isEmpty,
      promoPrice: double.tryParse(promoPriceCtrl.text.trim()),
      clearPromoPrice: promoPriceCtrl.text.trim().isEmpty,
      imageUrl: imageCtrl.text.trim(),
      videoUrl: videoCtrl.text.trim(),
      category: categoryCtrl.text.trim(),
      ctaText: ctaTextCtrl.text.trim(),
      ctaUrl: ctaUrlCtrl.text.trim(),
      displayOrder: int.tryParse(orderCtrl.text.trim()) ?? 0,
      isActive: isActive,
      isFeatured: isFeatured,
      startDate: startDate,
      clearStartDate: startDate == null,
      endDate: endDate,
      clearEndDate: endDate == null,
    );
  }
}

class _LivePreviewPane extends StatelessWidget {
  const _LivePreviewPane({required this.item});

  final WebContentItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFC6A76A).withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vista previa en tiempo real',
            style: GoogleFonts.inter(
              color: const Color(0xFFC6A76A),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            item.sectionLabel,
            style: GoogleFonts.playfairDisplay(
              color: const Color(0xFFF3E6D1),
              fontSize: 30,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                children: [
                  Expanded(
                    flex: 5,
                    child: SizedBox(
                      width: double.infinity,
                      child: _RemoteOrAssetImage(url: item.imageUrl),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Container(
                      width: double.infinity,
                      color: const Color(0xFF181818),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.subtitle.isNotEmpty)
                            Text(
                              item.subtitle.toUpperCase(),
                              style: GoogleFonts.inter(
                                color: const Color(0xFFC6A76A),
                                fontSize: 10,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          if (item.subtitle.isNotEmpty)
                            const SizedBox(height: 8),
                          Text(
                            item.title.isEmpty ? 'Tu titulo aparecerá aquí' : item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.playfairDisplay(
                              color: const Color(0xFFF3E6D1),
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: Text(
                              item.shortDescription.isNotEmpty
                                  ? item.shortDescription
                                  : 'La descripción corta te ayuda a entender cómo se presentará esta pieza en la web.',
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              if (item.promoPriceLabel.isNotEmpty)
                                Text(
                                  item.promoPriceLabel,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFFF4D089),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              else if (item.priceLabel.isNotEmpty)
                                Text(
                                  item.priceLabel,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFFF4D089),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFC6A76A),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  item.ctaText.isEmpty
                                      ? 'CTA'
                                      : item.ctaText,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF1F170F),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(
              'Estado: ${item.isCurrentlyVisible ? 'visible en web' : 'oculto en web'} · Orden: ${item.displayOrder} · Tipo: ${item.contentType}',
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormFieldFrame extends StatelessWidget {
  const _FormFieldFrame({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF554B40),
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _DateCard extends StatelessWidget {
  const _DateCard({
    required this.label,
    required this.value,
    required this.onPick,
    this.onClear,
  });

  final String label;
  final String value;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1D7C8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF554B40),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF3D342B),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onPick,
            icon: const Icon(Icons.event_outlined),
          ),
          if (onClear != null)
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    );
  }
}

class _WebContentPreviewDialog extends StatelessWidget {
  const _WebContentPreviewDialog({required this.item});

  final WebContentItem item;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFC6A76A).withValues(alpha: 0.22),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Previsualización',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFC6A76A),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  height: 280,
                  width: double.infinity,
                  child: _RemoteOrAssetImage(url: item.imageUrl),
                ),
              ),
              const SizedBox(height: 20),
              if (item.subtitle.isNotEmpty)
                Text(
                  item.subtitle.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: const Color(0xFFC6A76A),
                    fontSize: 11,
                    letterSpacing: 2.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (item.subtitle.isNotEmpty) const SizedBox(height: 10),
              Text(
                item.title.isEmpty ? 'Sin titulo' : item.title,
                style: GoogleFonts.playfairDisplay(
                  color: const Color(0xFFF3E6D1),
                  fontSize: 38,
                  fontWeight: FontWeight.w400,
                ),
              ),
              if (item.shortDescription.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  item.shortDescription,
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.7,
                  ),
                ),
              ],
              if (item.longDescription.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  item.longDescription,
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 13,
                    height: 1.7,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  if (item.promoPriceLabel.isNotEmpty)
                    Text(
                      item.promoPriceLabel,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFF4D089),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else if (item.priceLabel.isNotEmpty)
                    Text(
                      item.priceLabel,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFF4D089),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (item.priceLabel.isNotEmpty &&
                      item.promoPriceLabel.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Text(
                      item.priceLabel,
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 14,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (item.ctaText.trim().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC6A76A),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.ctaText,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF1F170F),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.inter(fontSize: 12),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(
              color: Color(0xFF8B7F71),
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Color(0xFF433A31),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F4EC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF7A7065),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF2B2118),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF3A3027),
        ),
      ),
    );
  }
}

class _RemoteOrAssetImage extends StatelessWidget {
  const _RemoteOrAssetImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) {
      return Container(
        color: const Color(0xFF1C1C1C),
        child: const Icon(
          Icons.image_outlined,
          color: Colors.white24,
          size: 38,
        ),
      );
    }

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: const Color(0xFF1C1C1C),
          child: const Icon(
            Icons.broken_image_outlined,
            color: Colors.white24,
            size: 38,
          ),
        ),
      );
    }

    return Image.asset(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: const Color(0xFF1C1C1C),
        child: const Icon(
          Icons.broken_image_outlined,
          color: Colors.white24,
          size: 38,
        ),
      ),
    );
  }
}

InputDecoration _editorInputDecoration({
  String? hintText,
  String? prefixText,
}) {
  return InputDecoration(
    hintText: hintText,
    prefixText: prefixText,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE1D7C8)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE1D7C8)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFC6A76A)),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFCC554B)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFCC554B)),
    ),
  );
}

String _dateRangeLabel(DateTime? start, DateTime? end) {
  if (start == null && end == null) return '';
  final format = DateFormat('dd MMM yyyy', 'es_MX');
  if (start != null && end != null) {
    return '${format.format(start)} - ${format.format(end)}';
  }
  if (start != null) return 'Desde ${format.format(start)}';
  return 'Hasta ${format.format(end!)}';
}

Uri? _resolveCtaUri(String rawUrl) {
  final value = rawUrl.trim();
  if (value.isEmpty) return null;
  if (value.startsWith('/') || value.startsWith('#')) {
    return Uri.base.resolve(value);
  }
  return Uri.tryParse(value.startsWith('http') ? value : 'https://$value');
}
