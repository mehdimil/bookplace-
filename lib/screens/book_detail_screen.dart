import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bookplace/models/book_post.dart';
import 'package:bookplace/services/supabase_service.dart';
import 'package:bookplace/screens/comments_sheet.dart';

class BookDetailScreen extends StatefulWidget {
  final BookPost post;
  const BookDetailScreen({super.key, required this.post});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  late BookPost post;
  bool get _isOwnPost => post.userId == svc.currentUser?.id;

  @override
  void initState() { super.initState(); post = widget.post; }

  Future<void> _toggleLike() async {
    final was = post.isLiked;
    setState(() => post.isLiked = !was);
    try {
      if (was) await svc.unlikeBook(post.id);
      else await svc.likeBook(post.id);
    } catch (_) { setState(() => post.isLiked = was); }
  }

  Future<void> _deletePost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Post',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text('Are you sure? This cannot be undone.',
            style: TextStyle(color: Colors.white54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await svc.deletePost(post.id);
      if (!mounted) return;
      // Pop and signal parent to remove the post
      Navigator.pop(context, 'deleted');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  String _fmt(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(children: [
        if (post.coverUrl != null) ...[
          Positioned.fill(
            child: CachedNetworkImage(imageUrl: post.coverUrl!, fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox()),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(color: Colors.black.withOpacity(0.80)),
            ),
          ),
        ],

        SafeArea(child: Column(children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(post.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: post.isLiked ? const Color(0xFFFF6B6B) : Colors.white, size: 22),
                onPressed: _toggleLike,
              ),
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                onPressed: () => showModalBottomSheet(
                  context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
                  builder: (_) => CommentsSheet(bookId: post.id),
                ),
              ),
              // Delete button — only for own posts
              if (_isOwnPost)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
                  onPressed: _deletePost,
                ),
            ]),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Cover + info hero row
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Hero(
                    tag: 'cover_${post.id}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: post.coverUrl != null
                          ? CachedNetworkImage(imageUrl: post.coverUrl!,
                              width: 120, height: 175, fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _FallbackCover(post: post))
                          : _FallbackCover(post: post),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(post.title,
                          style: const TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w900, fontSize: 22, height: 1.2)),
                      const SizedBox(height: 6),
                      Text('by ${post.author}',
                          style: const TextStyle(color: Colors.white60, fontSize: 14)),
                      const SizedBox(height: 10),
                      Row(children: List.generate(5, (i) => Icon(
                          i < post.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: const Color(0xFFFFD700), size: 17))),
                      if (post.genre != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B6B).withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.45)),
                          ),
                          child: Text(post.genre!,
                              style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 12)),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(children: [
                        const Icon(Icons.favorite_rounded, color: Color(0xFFFF6B6B), size: 14),
                        const SizedBox(width: 4),
                        Text(_fmt(post.likesCount),
                            style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        const SizedBox(width: 12),
                        const Icon(Icons.chat_bubble_rounded, color: Colors.white38, size: 14),
                        const SizedBox(width: 4),
                        Text(_fmt(post.commentsCount),
                            style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ]),
                    ]),
                  ),
                ]),
                const SizedBox(height: 20),

                // Author row
                Row(children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: const Color(0xFFFF6B6B),
                    backgroundImage: post.userAvatar != null
                        ? CachedNetworkImageProvider(post.userAvatar!) : null,
                    child: post.userAvatar == null
                        ? Text((post.username ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                                color: Colors.white)) : null,
                  ),
                  const SizedBox(width: 8),
                  Text('@${post.username}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ]),
                const SizedBox(height: 18),

                // Review
                const Text('Review',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(height: 8),
                Text(post.review,
                    style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.65)),

                // Quote
                if (post.quote != null) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(12),
                          border: Border(left: BorderSide(color: const Color(0xFF4ECDC4), width: 3)),
                        ),
                        child: Text('"${post.quote}"',
                            style: const TextStyle(color: Color(0xFF4ECDC4),
                                fontStyle: FontStyle.italic, fontSize: 14, height: 1.5)),
                      ),
                    ),
                  ),
                ],

                // Pages
                if (post.pages.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text('Pages',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                  const SizedBox(height: 12),
                  ...post.pages.map((p) => _PageCard(page: p, totalPages: post.pages.length)),
                ],
              ]),
            ),
          ),
        ])),
      ]),
    );
  }
}

class _PageCard extends StatelessWidget {
  final BookPage page;
  final int totalPages;
  const _PageCard({required this.page, required this.totalPages});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Page ${page.pageNumber} / $totalPages',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ),
        if (page.content.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Text(page.content,
                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.8)),
          ),
        if (page.photoUrl != null)
          ClipRRect(
            borderRadius: page.content.isEmpty
                ? BorderRadius.circular(14)
                : const BorderRadius.vertical(bottom: Radius.circular(14)),
            child: CachedNetworkImage(imageUrl: page.photoUrl!,
                width: double.infinity, fit: BoxFit.cover, height: 200,
                errorWidget: (_, __, ___) => const SizedBox()),
          ),
      ]),
    );
  }
}

class _FallbackCover extends StatelessWidget {
  final BookPost post;
  const _FallbackCover({required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120, height: 175,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFF4ECDC4)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Center(child: Text(
        post.title.substring(0, post.title.length > 2 ? 2 : post.title.length).toUpperCase(),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 28),
      )),
    );
  }
}