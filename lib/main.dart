import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bookplace/screens/splash_screen.dart';

// ⚠️  Replace with your Supabase project URL and anon key
const supabaseUrl = 'https://lwinvdylthisbhgnxojx.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx3aW52ZHlsdGhpc2JoZ254b2p4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI3NDAwNjIsImV4cCI6MjA4ODMxNjA2Mn0.Wmr8pOeka2FetaCWhQ6DnikU7HVRo38DNPyvqmLu43o';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const BookplaceApp());
}

final supabase = Supabase.instance.client;

class BookplaceApp extends StatelessWidget {
  const BookplaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bookplace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF6B6B),
          secondary: Color(0xFF4ECDC4),
          surface: Colors.transparent,
          surfaceContainer: Colors.transparent,
          surfaceContainerHighest: Colors.transparent,
        ),
        // ← This kills the grey slab behind NavigationBar globally
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.transparent,
          indicatorColor: Colors.transparent,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}