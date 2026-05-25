import 'dart:ui';
import 'package:flutter/material.dart';
import '../pages/reception_login_page.dart';
import '../features/store/store_page.dart';
import '../features/store/orders_page.dart';
import '../services/whatsapp_link.dart';

class Navbar extends StatefulWidget {
  final bool isScrolled;
  final Function(int) onTap;

  const Navbar({
    super.key,
    required this.isScrolled,
    required this.onTap,
  });

  @override
  State<Navbar> createState() => _NavbarState();
}

class _NavbarState extends State<Navbar> {
  bool _menuOpen = false;

  void _closeMenu() => setState(() => _menuOpen = false);

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBar(context, isMobile),
          if (isMobile && _menuOpen) _buildMobileMenu(context),
        ],
      ),
    );
  }

  Widget _buildBar(BuildContext context, bool isMobile) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 20 : 80,
            vertical: isMobile ? 14 : 20,
          ),
          decoration: BoxDecoration(
            color: widget.isScrolled || (isMobile && _menuOpen)
                ? Colors.black.withValues(alpha: 0.85)
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: widget.isScrolled ? Colors.white10 : Colors.transparent,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "SAHARA CLUB",
                style: TextStyle(
                  color: Color(0xFFC6A76A),
                  fontSize: 18,
                  letterSpacing: 4,
                  fontFamily: 'Playfair',
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isMobile)
                GestureDetector(
                  onTap: () => setState(() => _menuOpen = !_menuOpen),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _menuOpen ? Icons.close : Icons.menu,
                      key: ValueKey(_menuOpen),
                      color: const Color(0xFFC6A76A),
                      size: 24,
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    _navItem("HOME", 0),
                    _navItem("SERVICIOS", 1),
                    _navItem("EXPERIENCIA", 2),
                    _navItem("NOTICIAS", 3),
                    _navItem("CONTACTO", 4),
                    const SizedBox(width: 20),
                    _conciergeButton(),
                    const SizedBox(width: 12),
                    _storeButton(context),
                    const SizedBox(width: 12),
                    _ordersButton(context),
                    const SizedBox(width: 20),
                    _receptionButton(context),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileMenu(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          color: Colors.black.withValues(alpha: 0.93),
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _mobileNavItem("HOME", 0),
              _mobileNavItem("SERVICIOS", 1),
              _mobileNavItem("EXPERIENCIA", 2),
              _mobileNavItem("NOTICIAS", 3),
              _mobileNavItem("CONTACTO", 4),
              const SizedBox(height: 16),
              Container(height: 0.5, color: Colors.white12),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _storeMobileButton(context),
                  ),
                  const SizedBox(width: 12),
                  _ordersMobileButton(context),
                ],
              ),
              const SizedBox(height: 12),
              _conciergeMobileButton(),
              const SizedBox(height: 12),
              _receptionMobileButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileNavItem(String text, int index) {
    return GestureDetector(
      onTap: () {
        widget.onTap(index);
        _closeMenu();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            letterSpacing: 3,
          ),
        ),
      ),
    );
  }

  Widget _navItem(String text, int index) {
    return _NavbarItem(text: text, index: index, onTap: widget.onTap);
  }

  Widget _conciergeButton() {
    return GestureDetector(
      onTap: () => SaharaWhatsApp.openWhatsApp(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF25D366).withValues(alpha: 0.14),
          border: Border.all(color: const Color(0xFF25D366), width: 1),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_outlined, color: Color(0xFF25D366), size: 16),
            SizedBox(width: 8),
            Text(
              'CONCIERGE',
              style: TextStyle(
                color: Color(0xFF25D366),
                fontSize: 11,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conciergeMobileButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF25D366),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 14),
        ),
        onPressed: () {
          _closeMenu();
          SaharaWhatsApp.openWhatsApp();
        },
        icon: const Icon(Icons.chat_outlined, size: 18),
        label: const Text(
          'HABLAR POR WHATSAPP',
          style: TextStyle(fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _receptionButton(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFC6A76A),
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 18),
      ),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ReceptionLoginPage()),
      ),
      child: const Text(
        "RECEPCIÓN",
        style: TextStyle(fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _receptionMobileButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFC6A76A),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 14),
        ),
        onPressed: () {
          _closeMenu();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReceptionLoginPage()),
          );
        },
        child: const Text(
          "RECEPCIÓN",
          style: TextStyle(fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _ordersButton(BuildContext context) {
    return IconButton(
      tooltip: 'Mis compras',
      icon: const Icon(Icons.receipt_long_outlined, color: Color(0xFFC6A76A), size: 20),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const OrdersPage()),
      ),
    );
  }

  Widget _ordersMobileButton(BuildContext context) {
    return IconButton(
      tooltip: 'Mis compras',
      icon: const Icon(Icons.receipt_long_outlined, color: Color(0xFFC6A76A), size: 22),
      onPressed: () {
        _closeMenu();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OrdersPage()),
        );
      },
    );
  }

  Widget _storeButton(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFC6A76A), width: 1),
        foregroundColor: const Color(0xFFC6A76A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 18),
      ),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const StorePage()),
      ),
      child: const Text(
        "TIENDA",
        style: TextStyle(fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _storeMobileButton(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFC6A76A), width: 1),
        foregroundColor: const Color(0xFFC6A76A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      ),
      onPressed: () {
        _closeMenu();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StorePage()),
        );
      },
      child: const Text(
        "TIENDA",
        style: TextStyle(fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _NavbarItem extends StatefulWidget {
  final String text;
  final int index;
  final Function(int) onTap;

  const _NavbarItem({required this.text, required this.index, required this.onTap});

  @override
  State<_NavbarItem> createState() => _NavbarItemState();
}

class _NavbarItemState extends State<_NavbarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => widget.onTap(widget.index),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Text(
            widget.text,
            style: TextStyle(
              color: _isHovered ? const Color(0xFFC6A76A) : Colors.white70,
              fontSize: 11,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}
