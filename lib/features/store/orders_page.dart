import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../pages/landing_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final _db = Supabase.instance.client;
  final _emailCtrl = TextEditingController();
  List<_Order> _orders = [];
  bool _loading = false;
  bool _searched = false;
  String? _error;
  String? _searchedEmail;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty) return;
    setState(() { _loading = true; _error = null; _searched = false; });
    try {
      final raw = await _db
          .from('orders')
          .select('id, status, total, currency, created_at, paid_at, customer_name, customer_email, order_items(id, product_name, quantity, unit_price, product_type, image_url, digital_access(access_status, access_url))')
          .eq('customer_email', email)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _searchedEmail = email;
        _orders = (raw as List).map((r) => _Order.fromMap(Map<String, dynamic>.from(r))).toList();
        _searched = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudieron cargar las órdenes.');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0A0A),
      padding: const EdgeInsets.fromLTRB(32, 56, 32, 24),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => const LandingPage()));
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF2A2A2A)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_rounded,
                      color: Color(0xFF888888), size: 16),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mis compras',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 26,
                        color: const Color(0xFFF5F0EB),
                        fontWeight: FontWeight.w300,
                      )),
                  Text('Historial de órdenes',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: const Color(0xFF888888))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(height: 0.5, color: const Color(0xFFE9C176).withValues(alpha: 0.15)),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // ── Buscador por email ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE9C176).withValues(alpha: 0.4)),
                  ),
                  child: TextField(
                    controller: _emailCtrl,
                    style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFFF5F0EB)),
                    keyboardType: TextInputType.emailAddress,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: 'Correo con el que compraste',
                      hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF555555)),
                      prefixIcon: const Icon(Icons.mail_outline_rounded,
                          color: Color(0xFFE9C176), size: 18),
                      filled: true,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _loading ? null : _search,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9C176).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE9C176).withValues(alpha: 0.4)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(
                              color: Color(0xFFE9C176), strokeWidth: 1.5))
                      : Text('Buscar',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFFE9C176),
                              fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(child: _buildResults()),
      ],
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(
              color: Color(0xFFE9C176), strokeWidth: 1.5));
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded, color: Color(0xFF444444), size: 48),
          const SizedBox(height: 16),
          Text(_error!,
              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF888888))),
          const SizedBox(height: 16),
          TextButton(
              onPressed: _search,
              child: Text('Reintentar',
                  style: GoogleFonts.inter(color: const Color(0xFFE9C176)))),
        ]),
      );
    }
    if (!_searched) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFFE9C176).withValues(alpha: 0.06),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE9C176).withValues(alpha: 0.15)),
            ),
            child: const Icon(Icons.search_rounded,
                color: Color(0xFFE9C176), size: 40),
          ),
          const SizedBox(height: 20),
          Text('Consulta tus compras',
              style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  color: const Color(0xFFF5F0EB),
                  fontWeight: FontWeight.w300)),
          const SizedBox(height: 8),
          Text('Ingresa el correo con el que realizaste tu compra.',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF888888)),
              textAlign: TextAlign.center),
        ]),
      );
    }
    if (_orders.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.receipt_long_outlined,
              color: Color(0xFF444444), size: 48),
          const SizedBox(height: 16),
          Text('Sin órdenes para $_searchedEmail',
              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF888888)),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Verifica que el correo sea el mismo con el que compraste.',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF555555)),
              textAlign: TextAlign.center),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 60),
      itemCount: _orders.length,
      itemBuilder: (_, i) => _OrderCard(order: _orders[i]),
    );
  }
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _OrderCard extends StatefulWidget {
  final _Order order;
  const _OrderCard({required this.order});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final color = _statusColor(o.status);
    final fmt = NumberFormat('#,##0.00', 'es_MX');
    final dateFmt = DateFormat("d 'de' MMMM yyyy, HH:mm", 'es');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          // Header row
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_statusIcon(o.status), color: color, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(_statusLabel(o.status),
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: color,
                                      fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(width: 8),
                            Text('#${o.id.substring(0, 8).toUpperCase()}',
                                style: GoogleFonts.inter(
                                    fontSize: 11, color: const Color(0xFF555555))),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(dateFmt.format(o.createdAt.toLocal()),
                            style: GoogleFonts.inter(
                                fontSize: 11, color: const Color(0xFF777777))),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('\$${fmt.format(o.total)} MXN',
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              color: const Color(0xFFE9C176),
                              fontWeight: FontWeight.w700)),
                      Text('${o.items.length} artículo${o.items.length != 1 ? 's' : ''}',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: const Color(0xFF666666))),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF555555),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Expanded items
          if (_expanded) ...[
            Container(
                height: 0.5,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: Colors.white.withValues(alpha: 0.05)),
            ...o.items.map((item) => _ItemRow(item: item)),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  static Color _statusColor(String s) => switch (s) {
        'paid' => const Color(0xFF4CAF50),
        'pending' => const Color(0xFFFFB74D),
        'cancelled' => const Color(0xFFEF5350),
        _ => const Color(0xFF888888),
      };

  static IconData _statusIcon(String s) => switch (s) {
        'paid' => Icons.check_circle_outline_rounded,
        'pending' => Icons.schedule_rounded,
        'cancelled' => Icons.cancel_outlined,
        _ => Icons.info_outline_rounded,
      };

  static String _statusLabel(String s) => switch (s) {
        'paid' => 'Pagada',
        'pending' => 'Pendiente',
        'cancelled' => 'Cancelada',
        _ => s,
      };
}

class _ItemRow extends StatelessWidget {
  final _OrderItem item;
  const _ItemRow({required this.item});

  IconData get _typeIcon => switch (item.productType) {
        'digital' => Icons.graphic_eq_rounded,
        'membership' => Icons.workspace_premium_outlined,
        'gift_card' => Icons.redeem_outlined,
        'physical' => Icons.shopping_bag_outlined,
        _ => Icons.spa_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'es_MX');
    final isDigital = item.productType == 'digital';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: item.imageUrl.startsWith('http')
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(item.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, e, s) =>
                                Icon(_typeIcon, size: 16, color: const Color(0xFFE9C176))),
                      )
                    : Icon(_typeIcon, size: 16, color: const Color(0xFFE9C176)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: GoogleFonts.inter(
                            fontSize: 13, color: const Color(0xFFCCCCCC))),
                    if (isDigital)
                      Text('Producto digital',
                          style: GoogleFonts.inter(
                              fontSize: 10, color: const Color(0xFFE9C176))),
                  ],
                ),
              ),
              Text('x${item.quantity}',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: const Color(0xFF666666))),
              const SizedBox(width: 12),
              Text('\$${fmt.format(item.unitPrice * item.quantity)}',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFFAAAAAA),
                      fontWeight: FontWeight.w500)),
            ],
          ),
          // Download button for digital products
          if (isDigital) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: item.downloadUrl != null
                  ? GestureDetector(
                      onTap: () => launchUrl(Uri.parse(item.downloadUrl!)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9C176).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFE9C176).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.download_rounded,
                                size: 14, color: Color(0xFFE9C176)),
                            const SizedBox(width: 6),
                            Text('Descargar',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFFE9C176),
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.hourglass_empty_rounded,
                            size: 12, color: Color(0xFF666666)),
                        const SizedBox(width: 6),
                        Text('Archivo no disponible aún',
                            style: GoogleFonts.inter(
                                fontSize: 11, color: const Color(0xFF666666))),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Models ────────────────────────────────────────────────────────────────────

class _Order {
  final String id;
  final String status;
  final double total;
  final String currency;
  final DateTime createdAt;
  final DateTime? paidAt;
  final List<_OrderItem> items;

  const _Order({
    required this.id,
    required this.status,
    required this.total,
    required this.currency,
    required this.createdAt,
    this.paidAt,
    required this.items,
  });

  factory _Order.fromMap(Map<String, dynamic> m) {
    final rawItems = m['order_items'] as List? ?? [];
    return _Order(
      id: m['id'] as String,
      status: m['status'] as String? ?? 'pending',
      total: (m['total'] as num?)?.toDouble() ?? 0,
      currency: m['currency'] as String? ?? 'MXN',
      createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
      paidAt: m['paid_at'] != null
          ? DateTime.tryParse(m['paid_at'] as String)
          : null,
      items: rawItems
          .map((i) => _OrderItem.fromMap(Map<String, dynamic>.from(i as Map)))
          .toList(),
    );
  }
}

class _OrderItem {
  final String name;
  final int quantity;
  final double unitPrice;
  final String imageUrl;
  final String productType;
  final String? downloadUrl;

  const _OrderItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.imageUrl,
    required this.productType,
    this.downloadUrl,
  });

  factory _OrderItem.fromMap(Map<String, dynamic> m) {
    // digital_access can come as a List (one-to-many) or Map (one-to-one) depending on the query
    final raw = m['digital_access'];
    Map<String, dynamic>? access;
    if (raw is List && raw.isNotEmpty) {
      access = Map<String, dynamic>.from(raw.first as Map);
    } else if (raw is Map) {
      access = Map<String, dynamic>.from(raw);
    }
    final accessUrl = access?['access_url'] as String?;

    return _OrderItem(
      name: m['product_name'] as String? ?? '—',
      quantity: (m['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (m['unit_price'] as num?)?.toDouble() ?? 0,
      imageUrl: m['image_url'] as String? ?? '',
      productType: m['product_type'] as String? ?? '',
      downloadUrl: (accessUrl != null && accessUrl.isNotEmpty) ? accessUrl : null,
    );
  }
}
