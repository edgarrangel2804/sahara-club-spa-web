import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReceptionLoginPage extends StatefulWidget {
  const ReceptionLoginPage({super.key});

  @override
  State<ReceptionLoginPage> createState() => _ReceptionLoginPageState();
}

class _ReceptionLoginPageState extends State<ReceptionLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _goHome() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    final supa = Supabase.instance.client;
    try {
      final res = await supa.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final user = res.user;
      if (user == null) {
        throw Exception('Credenciales inválidas.');
      }

      // Verificar que el auth user esté vinculado a un staff activo con login habilitado.
      // Esto bloquea: clientes, admins de IA, usuarios huérfanos y staff desactivado.
      final staff = await supa
          .from('staff')
          .select('id, role, active, can_login')
          .eq('auth_user_id', user.id)
          .maybeSingle();

      final isActive = staff != null && (staff['active'] == true);
      final canLogin = staff != null && (staff['can_login'] == true);
      final role = staff?['role']?.toString();
      const allowedRoles = {'admin', 'reception', 'therapist'};

      if (staff == null || !isActive || !canLogin || !allowedRoles.contains(role)) {
        await supa.auth.signOut();
        throw Exception(
          'Tu cuenta no tiene acceso al portal de staff. Contacta al administrador.',
        );
      }

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/agenda');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      appBar: AppBar(backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(
        child: Container(
          width: 450,
          padding: const EdgeInsets.all(50),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(0),
            border: Border.all(color: const Color(0xFFC6A76A).withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "RECEPTION ACCESS",
                style: TextStyle(
                  color: Color(0xFFC6A76A),
                  fontSize: 24,
                  letterSpacing: 4,
                  fontFamily: 'Playfair',
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Ingrese sus credenciales de staff para gestionar el spa.",
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  filled: false, // Forzamos a que no use el fondo blanco del tema
                  labelText: "EMAIL",
                  labelStyle: TextStyle(color: Colors.white38, fontSize: 12, letterSpacing: 2),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFC6A76A))),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  filled: false, // Forzamos a que no use el fondo blanco del tema
                  labelText: "PASSWORD",
                  labelStyle: TextStyle(color: Colors.white38, fontSize: 12, letterSpacing: 2),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFC6A76A))),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC6A76A),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text("ENTRAR", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: TextButton.icon(
                  onPressed: _isLoading ? null : _goHome,
                  icon: const Icon(Icons.arrow_back, size: 16, color: Colors.white54),
                  label: const Text(
                    "Volver a la página principal",
                    style: TextStyle(color: Colors.white54, fontSize: 13, letterSpacing: 1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}