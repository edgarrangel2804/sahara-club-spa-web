import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/sahara_theme.dart';

class WhatsAppMetaTemplatesPanel extends StatefulWidget {
  const WhatsAppMetaTemplatesPanel({super.key});

  @override
  State<WhatsAppMetaTemplatesPanel> createState() =>
      _WhatsAppMetaTemplatesPanelState();
}

class _MetaTemplateRow {
  final String id;
  final String templateKey;
  final String? metaTemplateName;
  final String metaTemplateStatus;
  final String metaLanguage;
  final String metaCategory;
  final int metaVariablesCount;
  final List<dynamic> metaComponents;
  final String messageBody;
  final bool isActive;
  final DateTime? approvedAt;
  final String? rejectedReason;
  final DateTime? lastSyncAt;

  _MetaTemplateRow({
    required this.id,
    required this.templateKey,
    required this.metaTemplateName,
    required this.metaTemplateStatus,
    required this.metaLanguage,
    required this.metaCategory,
    required this.metaVariablesCount,
    required this.metaComponents,
    required this.messageBody,
    required this.isActive,
    required this.approvedAt,
    required this.rejectedReason,
    required this.lastSyncAt,
  });

  factory _MetaTemplateRow.fromMap(Map<String, dynamic> m) => _MetaTemplateRow(
        id: m['id'] as String,
        templateKey: (m['template_key'] as String?) ?? '',
        metaTemplateName: m['meta_template_name'] as String?,
        metaTemplateStatus:
            (m['meta_template_status'] as String?) ?? 'pending',
        metaLanguage: (m['meta_language'] as String?) ?? 'es_MX',
        metaCategory: (m['meta_category'] as String?) ?? 'UTILITY',
        metaVariablesCount: (m['meta_variables_count'] as int?) ?? 0,
        metaComponents: (m['meta_components_schema'] as List?) ?? const [],
        messageBody: (m['message_body'] as String?) ?? '',
        isActive: (m['is_active'] as bool?) ?? true,
        approvedAt: m['approved_at'] == null
            ? null
            : DateTime.tryParse(m['approved_at'] as String),
        rejectedReason: m['rejected_reason'] as String?,
        lastSyncAt: m['last_sync_at'] == null
            ? null
            : DateTime.tryParse(m['last_sync_at'] as String),
      );
}

class _WhatsAppMetaTemplatesPanelState
    extends State<WhatsAppMetaTemplatesPanel> {
  bool _loading = true;
  bool _syncing = false;
  String? _syncError;
  String? _syncSummary;
  List<_MetaTemplateRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await Supabase.instance.client
          .from('whatsapp_meta_templates_view')
          .select()
          .order('template_key', ascending: true);
      _rows = (data as List)
          .map((e) => _MetaTemplateRow.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      _syncError = 'No se pudo cargar templates: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sync() async {
    setState(() {
      _syncing = true;
      _syncError = null;
      _syncSummary = null;
    });
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'sync_meta_templates',
        body: const {},
      );
      final payload = Map<String, dynamic>.from(res.data as Map);
      _syncSummary =
          'Fetched: ${payload['fetched']} · Updated: ${payload['updated']} · Deleted: ${payload['marked_deleted']}';
      await _load();
    } catch (e) {
      _syncError = 'Sync falló: $e';
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'approved':
        return const Color(0xFF1A9E65);
      case 'pending':
        return const Color(0xFFC68A17);
      case 'rejected':
      case 'disabled':
      case 'deleted':
        return const Color(0xFFB32D2D);
      case 'paused':
        return const Color(0xFF8757C9);
      default:
        return Colors.black45;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'approved':
        return 'APROBADO';
      case 'pending':
        return 'PENDIENTE';
      case 'rejected':
        return 'RECHAZADO';
      case 'disabled':
        return 'DESACTIVADO';
      case 'deleted':
        return 'ELIMINADO';
      case 'paused':
        return 'EN PAUSA';
      default:
        return s.toUpperCase();
    }
  }

  String _previewFromComponents(_MetaTemplateRow r) {
    for (final c in r.metaComponents) {
      if (c is Map && (c['type']?.toString().toUpperCase() == 'BODY')) {
        return (c['text']?.toString() ?? '').trim();
      }
    }
    return r.messageBody;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Templates Meta',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: SaharaTheme.grisCarbon,
              ),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: _syncing ? null : _sync,
              icon: _syncing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync, size: 18),
              label: const Text('Sincronizar con Meta'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Catálogo oficial de plantillas aprobadas por Meta para WhatsApp Cloud API. '
          'Solo los templates APROBADOS pueden enviarse fuera de la ventana de 24h.',
          style: GoogleFonts.inter(fontSize: 12, color: Colors.black54),
        ),
        if (_syncSummary != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A9E65).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _syncSummary!,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
        if (_syncError != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFB32D2D).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _syncError!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFFB32D2D),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        ..._rows.map(_buildRow),
      ],
    );
  }

  Widget _buildRow(_MetaTemplateRow r) {
    final color = _statusColor(r.metaTemplateStatus);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFECE9E4)),
      ),
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
                      r.metaTemplateName ?? '(sin meta_template_name)',
                      style: GoogleFonts.firaCode(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: SaharaTheme.grisCarbon,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Evento interno: ${r.templateKey}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(r.metaTemplateStatus),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('Idioma', r.metaLanguage),
              _chip('Categoría', r.metaCategory),
              _chip('Vars', '${r.metaVariablesCount}'),
              if (r.approvedAt != null)
                _chip('Aprobado', r.approvedAt!.toIso8601String().split('T').first),
              if (r.lastSyncAt != null)
                _chip('Sync', r.lastSyncAt!.toIso8601String().split('T').first),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F4EF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _previewFromComponents(r),
              style: GoogleFonts.inter(fontSize: 12, color: Colors.black87),
            ),
          ),
          if (r.rejectedReason != null && r.rejectedReason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Motivo de rechazo: ${r.rejectedReason}',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFFB32D2D),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1ECE3),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: SaharaTheme.grisCarbon,
        ),
      ),
    );
  }
}
