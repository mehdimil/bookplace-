import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bookplace/main.dart';
import 'package:bookplace/screens/auth_screen.dart';
import 'package:bookplace/screens/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    _redirect();
  }

  Future<void> _redirect() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // Try to recover session — if token is expired or broken, sign out cleanly
    try {
      final session = supabase.auth.currentSession;
      if (session != null) {
        // Verify session is still valid by refreshing it
        await supabase.auth.refreshSession();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        _goToAuth();
      }
    } catch (_) {
      // Session is broken/expired — sign out and go to login
      try { await supabase.auth.signOut(); } catch (_) {}
      if (!mounted) return;
      _goToAuth();
    }
  }

  void _goToAuth() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFF4ECDC4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.menu_book_rounded, size: 48, color: Colors.white),
              ),
              const SizedBox(height: 20),
              const Text('Bookplace',
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800,
                      color: Colors.white, letterSpacing: -1)),
              const SizedBox(height: 6),
              Text('Your next favourite read awaits',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}