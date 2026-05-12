import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:html' as html;
import 'theme/sahara_theme.dart';
import 'pages/landing_page.dart';
import 'pages/reception_login_page.dart';
import 'pages/agenda_page.dart';

class GlobalAudioPlayer {
  static final GlobalAudioPlayer _instance = GlobalAudioPlayer._internal();
  factory GlobalAudioPlayer() => _instance;
  GlobalAudioPlayer._internal();

  html.AudioElement? _audio;
  bool _initialized = false;

  void init() {
    if (_initialized) return;
    _initialized = true;

    // Create audio element
    _audio = html.AudioElement()
      ..src = 'assets/musica/musica.mp3'
      ..loop = true
      ..autoplay = false
      ..preload = 'auto'
      ..volume = 0.3; // Aumentado ligeramente para asegurar que se oiga

    // Listener for errors
    _audio?.onError.listen((event) {
      html.window.console.error('Error cargando audio: ${_audio?.error?.code}');
    });

    // Interaction listener - most robust way
    late void Function(html.Event) playAudio;
    
    playAudio = (html.Event e) {
      if (_audio != null && (_audio!.paused)) {
        _audio!.play().then((_) {
          // Success! Remove listeners to avoid playing multiple times
          html.window.removeEventListener('click', playAudio);
          html.window.removeEventListener('touchstart', playAudio);
          html.window.removeEventListener('keydown', playAudio);
        }).catchError((err) {
          html.window.console.warn('Autoplay bloqueado por el navegador: $err');
        });
      }
    };


    html.window.addEventListener('click', playAudio);
    html.window.addEventListener('touchstart', playAudio);
    html.window.addEventListener('keydown', playAudio);
  }

}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url:     'https://fkbyxhwdcsgrrixalzwf.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
             '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZrYnl4aHdkY3NncnJpeGFsendmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc1NzE3MjYsImV4cCI6MjA5MzE0NzcyNn0'
             '.IJ2nDtgBPkbY8CRDmGGJTvE6kELrY0sp3_F9yseZP9Q',
  );

  GlobalAudioPlayer().init();

  runApp(const SaharaApp());
}

class SaharaApp extends StatelessWidget {
  const SaharaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sahara Club Spa',
      debugShowCheckedModeBanner: false,
      theme: SaharaTheme.lightTheme,
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
