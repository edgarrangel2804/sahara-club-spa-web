import 'dart:ui';
import 'package:flutter/material.dart';
import '../pages/reception_login_page.dart';
import '../pages/wellness_platform_page.dart';

class Navbar extends StatelessWidget {
  final bool isScrolled;
  final Function(int) onTap;

  const Navbar({
    super.key,
    required this.isScrolled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 20),
            decoration: BoxDecoration(
              color: isScrolled
                  ? Colors.black.withValues(alpha: 0.6)
                  : Colors.transparent,
              border: Border(
                bottom: BorderSide(
                  color: isScrolled ? Colors.white10 : Colors.transparent,
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
                    fontSize: 20,
                    letterSpacing: 4,
                    fontFamily: 'Playfair',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    _navItem("HOME", 0),
                    _navItem("SERVICIOS", 1),
                    _navItem("EXPERIENCIA", 2),
                    _navItem("NOTICIAS", 3),
                    _navItem("CONTACTO", 4),
                    const SizedBox(width: 20),
                    _wellnessButton(context),
                    const SizedBox(width: 20),
                    _receptionButton(context),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(String text, int index) {
    return _NavbarItem(text: text, index: index, onTap: onTap);
  }

  Widget _receptionButton(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFC6A76A),
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 18),
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ReceptionLoginPage()),
        );
      },
      child: const Text("RECEPCIÓN", style: TextStyle(fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.bold)),
    );
  }

  Widget _wellnessButton(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFC6A76A), width: 1),
        foregroundColor: const Color(0xFFC6A76A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 18),
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WellnessPlatformPage()),
        );
      },
      child: const Text("WELLNESS", style: TextStyle(fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.bold)),
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