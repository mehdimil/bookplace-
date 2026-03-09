import 'package:flutter/material.dart';
import 'package:bookplace/services/supabase_service.dart';
import 'package:bookplace/screens/home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _loading = false;

  final _loginEmail    = TextEditingController();
  final _loginPassword = TextEditingController();

  final _signupEmail    = TextEditingController();
  final _signupPassword = TextEditingController();
  final _signupUsername = TextEditingController();

  bool _obscureLogin  = true;
  bool _obscureSignup = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _loginEmail.dispose(); _loginPassword.dispose();
    _signupEmail.dispose(); _signupPassword.dispose(); _signupUsername.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email    = _loginEmail.text.trim();
    final password = _loginPassword.text;
    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter your email and password');
      return;
    }
    setState(() => _loading = true);
    try {
      // Clear any broken session first
      try { await svc.signOut(); } catch (_) {}
      await svc.signIn(email: email, password: password);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('invalid login') || msg.contains('invalid credentials')) {
        _showError('Wrong email or password. Please try again.');
      } else if (msg.contains('email not confirmed')) {
        _showError('Please confirm your email before logging in.');
      } else if (msg.contains('network') || msg.contains('socket')) {
        _showError('Network error. Check your connection.');
      } else {
        _showError(e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signup() async {
    final username = _signupUsername.text.trim();
    final email    = _signupEmail.text.trim();
    final password = _signupPassword.text;
    if (username.isEmpty) { _showError('Please enter a username'); return; }
    if (email.isEmpty)    { _showError('Please enter your email'); return; }
    if (password.length < 6) { _showError('Password must be at least 6 characters'); return; }
    setState(() => _loading = true);
    try {
      try { await svc.signOut(); } catch (_) {}
      await svc.signUp(email: email, password: password, username: username);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('already registered') || msg.contains('already exists')) {
        _showError('This email is already registered. Try logging in.');
      } else {
        _showError(e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.menu_book_rounded, size: 56, color: Color(0xFFFF6B6B)),
            const SizedBox(height: 12),
            const Text('Bookplace',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 6),
            Text('Your next favourite read awaits',
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
            const SizedBox(height: 32),
            // Tab switcher
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tab,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                tabs: const [Tab(text: 'Log In'), Tab(text: 'Sign Up')],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _LoginForm(
                    email: _loginEmail, password: _loginPassword,
                    obscure: _obscureLogin,
                    onToggleObscure: () => setState(() => _obscureLogin = !_obscureLogin),
                    onSubmit: _login, loading: _loading,
                  ),
                  _SignupForm(
                    email: _signupEmail, password: _signupPassword, username: _signupUsername,
                    obscure: _obscureSignup,
                    onToggleObscure: () => setState(() => _obscureSignup = !_obscureSignup),
                    onSubmit: _signup, loading: _loading,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Login Form ────────────────────────────────────────────────────────────────
class _LoginForm extends StatelessWidget {
  final TextEditingController email, password;
  final bool obscure, loading;
  final VoidCallback onToggleObscure, onSubmit;

  const _LoginForm({
    required this.email, required this.password, required this.obscure,
    required this.onToggleObscure, required this.onSubmit, required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(children: [
        _Field(controller: email, label: 'Email', icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 16),
        _Field(controller: password, label: 'Password', icon: Icons.lock_outline,
            obscure: obscure,
            suffix: IconButton(
              icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white38),
              onPressed: onToggleObscure,
            )),
        const SizedBox(height: 28),
        _SubmitButton(label: 'Log In', loading: loading, onTap: onSubmit),
      ]),
    );
  }
}

// ── Signup Form ───────────────────────────────────────────────────────────────
class _SignupForm extends StatelessWidget {
  final TextEditingController email, password, username;
  final bool obscure, loading;
  final VoidCallback onToggleObscure, onSubmit;

  const _SignupForm({
    required this.email, required this.password, required this.username,
    required this.obscure, required this.onToggleObscure,
    required this.onSubmit, required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(children: [
        _Field(controller: username, label: 'Username', icon: Icons.person_outline),
        const SizedBox(height: 16),
        _Field(controller: email, label: 'Email', icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 16),
        _Field(controller: password, label: 'Password (min 6 chars)', icon: Icons.lock_outline,
            obscure: obscure,
            suffix: IconButton(
              icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white38),
              onPressed: onToggleObscure,
            )),
        const SizedBox(height: 28),
        _SubmitButton(label: 'Create Account', loading: loading, onTap: onSubmit),
      ]),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;

  const _Field({
    required this.controller, required this.label, required this.icon,
    this.obscure = false, this.suffix, this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white38),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFFF6B6B))),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _SubmitButton({required this.label, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
        ),
        child: TextButton(
          onPressed: loading ? null : onTap,
          style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: loading
              ? const SizedBox(height: 22, width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.white)))
              : Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}