import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/sahara_theme.dart';
import 'pages/landing_page.dart';
import 'pages/reception_login_page.dart';
import 'pages/agenda_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url:     'https://fkbyxhwdcsgrrixalzwf.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
             '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZrYnl4aHdkY3NncnJpeGFsendmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc1NzE3MjYsImV4cCI6MjA5MzE0NzcyNn0'
             '.IJ2nDtgBPkbY8CRDmGGJTvE6kELrY0sp3_F9yseZP9Q',
  );

  runApp(const SaharaApp());
}

class SaharaApp extends StatelessWidget {
  const SaharaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sahara Club Spa',
      debugShowCheckedModeBanner: false,
      theme: SaharaTheme.theme,
      home: const _AuthGate(),
      routes: {
        '/recepcion': (_) => const ReceptionLoginPage(),
        '/agenda':    (_) => const AgendaPage(),
      },
    );
  }
}

// Watches auth state: shows AgendaPage when logged in, LandingPage otherwise.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, _) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) return const AgendaPage();
        return const LandingPage();
      },
    );
  }
}
