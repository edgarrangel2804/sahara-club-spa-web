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

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        // Redirigir a la Agenda (Simulado por ahora con un SnackBar)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Acceso concedido. Entrando a la Agenda...')),
        );
        // Navigator.pushReplacementNamed(context, '/agenda');
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
                      : const Text("ENTER COMMAND CENTER", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}