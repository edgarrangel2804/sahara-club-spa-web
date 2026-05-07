import 'package:flutter/material.dart';
import 'theme/sahara_theme.dart';
import 'pages/landing_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase (Use your own keys here)
  // await Supabase.initialize(
  //   url: 'YOUR_SUPABASE_URL',
  //   anonKey: 'YOUR_SUPABASE_ANON_KEY',
  // );

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
      home: const LandingPage(),
    );
  }
}