import 'package:flutter/material.dart';
import 'package:bookplace/screens/for_you_screen.dart';
import 'package:bookplace/screens/add_post_screen.dart';
import 'package:bookplace/screens/profile_screen.dart';
import 'package:bookplace/screens/inbox_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  final _pages = [
    const ForYouScreen(),
    const AddPostScreen(),
    const InboxScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Theme(
      // Kill every background the NavigationBar widget tries to paint
      data: Theme.of(context).copyWith(
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.transparent,
          indicatorColor: Colors.transparent,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,

          elevation: 0,
        ),
        colorScheme: Theme.of(context).colorScheme.copyWith(
          surface: Colors.transparent,
          surfaceContainer: Colors.transparent,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // extendBody lets page content draw behind the nav bar area
        extendBody: true,
        body: IndexedStack(index: _index, children: _pages),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF111111).withOpacity(0.96),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.55),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: NavigationBar(
                backgroundColor: Colors.transparent,
                indicatorColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.transparent,
                elevation: 0,
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                height: 60,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: [
                  _dest(Icons.home_outlined, Icons.home, 'Home', 0),
                  NavigationDestination(
                    icon: _addIcon(),
                    selectedIcon: _addIcon(),
                    label: 'Post',
                  ),
                  _dest(Icons.chat_bubble_outline, Icons.chat_bubble, 'Messages', 2),
                  _dest(Icons.person_outline, Icons.person, 'Profile', 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _addIcon() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Icon(Icons.add, size: 18, color: Colors.white),
  );

  NavigationDestination _dest(IconData off, IconData on, String label, int i) {
    return NavigationDestination(
      icon: Icon(off, size: 22, color: Colors.white38),
      selectedIcon: Icon(on, size: 22, color: const Color(0xFFFF6B6B)),
      label: label,
    );
  }
}