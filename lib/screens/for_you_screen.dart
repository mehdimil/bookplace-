import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:bookplace/models/book_post.dart';
import 'package:bookplace/services/supabase_service.dart';
import 'package:bookplace/widgets/book_card.dart';
import 'package:bookplace/screens/search_screen.dart';

class ForYouScreen extends StatefulWidget {
  const ForYouScreen({super.key});
  @override
  State<ForYouScreen> createState() => _ForYouScreenState();
}

class _ForYouScreenState extends State<ForYouScreen> {
  final List<BookPost> _posts = [];
  bool _loading = true;
  bool _fetching = false;
  int _offset = 0;
  final _pageController = PageController();

  @override
  void initState() { super.initState(); _loadPosts(); }

  Future<void> _loadPosts({bool refresh = false}) async {
    if (_fetching) return;
    setState(() => _fetching = true);
    if (refresh) { _offset = 0; _posts.clear(); }
    try {
      final newPosts = await svc.getFeed(offset: _offset);
      if (mounted) setState(() {
        _posts.addAll(newPosts);
        _offset += newPosts.length;
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
    finally { if (mounted) setState(() => _fetching = false); }
  }

  void _onPageChanged(int p) { if (p >= _posts.length - 2) _loadPosts(); }

  Future<void> _toggleLike(BookPost post) async {
    final was = post.isLiked;
    setState(() => post.isLiked = !was);
    try { if (was) await svc.unlikeBook(post.id); else await svc.likeBook(post.id); }
    catch (_) { setState(() => post.isLiked = was); }
  }

  @override
  void dispose() { _pageController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D0D),
        body: Center(child: CircularProgressIndicator(
            color: Color(0xFFFF6B6B), strokeWidth: 2)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      extendBodyBehindAppBar: true,
      // ── Frosted search bar centred at top ──────────────────────────────
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: Colors.black.withOpacity(0.28),
              alignment: Alignment.bottomCenter,
              padding: EdgeInsets.only(
                  bottom: 8,
                  top: MediaQuery.of(context).padding.top,
                  left: 16, right: 16),
              child: GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SearchScreen())),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.14)),
                  ),
                  child: Row(children: [
                    const SizedBox(width: 12),
                    Icon(Icons.search_rounded,
                        color: Colors.white.withOpacity(0.5), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Search readers & authors…',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.35),
                              fontSize: 13)),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B6B).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Find',
                          style: TextStyle(color: Color(0xFFFF6B6B),
                              fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _posts.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.menu_book_rounded, size: 52,
                    color: Colors.white.withOpacity(0.1)),
                const SizedBox(height: 14),
                Text('No posts yet',
                    style: TextStyle(color: Colors.white.withOpacity(0.3),
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ]))
          : PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              onPageChanged: _onPageChanged,
              itemCount: _posts.length,
              itemBuilder: (_, i) => BookCard(
                post: _posts[i],
                onLike: () => _toggleLike(_posts[i]),
              ),
            ),
    );
  }
}