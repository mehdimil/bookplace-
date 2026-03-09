import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bookplace/models/book_post.dart';
import 'package:bookplace/screens/comments_sheet.dart';
import 'package:bookplace/screens/book_detail_screen.dart';
import 'package:bookplace/screens/profile_screen.dart';
import 'package:bookplace/services/supabase_service.dart';

class BookCard extends StatefulWidget {
  final BookPost post;
  final VoidCallback onLike;
  const BookCard({super.key, required this.post, required this.onLike});
  @override
  State<BookCard> createState() => _BookCardState();
}

class _BookCardState extends State<BookCard> with SingleTickerProviderStateMixin {
  int _tab = 0;
  late final PageController _hCtrl;
  bool _isFollowing = false;
  bool _followLoading = false;
  late AnimationController _heartAnim;
  late Animation<double> _heartScale;

  int get _totalTabs => 1 + widget.post.pages.length;
  bool get _isOwn => widget.post.userId == svc.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _hCtrl = PageController();
    if (!_isOwn) _checkFollow();
    _heartAnim = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 160));
    _heartScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _heartAnim, curve: Curves.easeInOut));
  }

  Future<void> _checkFollow() async {
    try {
      final f = await svc.isFollowing(widget.post.userId);
      if (mounted) setState(() => _isFollowing = f);
    } catch (_) {}
  }

  Future<void> _toggleFollow() async {
    if (_followLoading) return;
    setState(() => _followLoading = true);
    try {
      if (_isFollowing) await svc.unfollow(widget.post.userId);
      else await svc.follow(widget.post.userId);
      if (mounted) setState(() => _isFollowing = !_isFollowing);
    } catch (_) {}
    if (mounted) setState(() => _followLoading = false);
  }

  void _like() { _heartAnim.forward(from: 0); widget.onLike(); }
  void _openProfile() => Navigator.push(context,
      MaterialPageRoute(builder: (_) => ProfileScreen(userId: widget.post.userId)));
  void _goTo(int i) => _hCtrl.animateToPage(i,
      duration: const Duration(milliseconds: 280), curve: Curves.easeInOut);

  @override
  void dispose() { _hCtrl.dispose(); _heartAnim.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Exact offset to sit above floating nav bar
    final navOffset = mq.padding.bottom + 80.0;

    return Stack(fit: StackFit.expand, children: [

      // ── 1. Full-bleed background (book cover blurred) ──────────────────
      _Bg(coverUrl: widget.post.coverUrl),

      // ── 2. Cinematic dark vignette ─────────────────────────────────────
      DecoratedBox(decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.08),
            Colors.transparent,
            Colors.black.withOpacity(0.55),
            Colors.black.withOpacity(0.92),
          ],
          stops: const [0.0, 0.35, 0.65, 1.0],
        ),
      )),

      // ── 3. Horizontal swiper ───────────────────────────────────────────
      PageView.builder(
        controller: _hCtrl,
        onPageChanged: (i) => setState(() => _tab = i),
        itemCount: _totalTabs,
        itemBuilder: (_, i) => i == 0
            ? _MainOverlay(
                post: widget.post,
                isOwn: _isOwn,
                isFollowing: _isFollowing,
                followLoading: _followLoading,
                heartScale: _heartScale,
                navOffset: navOffset,
                onFollow: _toggleFollow,
                onProfile: _openProfile,
                onLike: _like,
                hasPages: widget.post.pages.isNotEmpty,
                onPages: () => _goTo(1),
              )
            : _PageOverlay(
                page: widget.post.pages[i - 1],
                post: widget.post,
                total: widget.post.pages.length,
                navOffset: navOffset,
              ),
      ),

      // ── 4. Page dots ───────────────────────────────────────────────────
      if (_totalTabs > 1)
        Positioned(
          top: mq.padding.top + 58,
          left: 0, right: 0,
          child: Row(mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_totalTabs, (i) {
              final on = i == _tab;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: on ? 18 : 4, height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: on ? Colors.white : Colors.white38,
                ),
              );
            }),
          ),
        ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Background
// ─────────────────────────────────────────────────────────────────────────────
class _Bg extends StatelessWidget {
  final String? coverUrl;
  const _Bg({required this.coverUrl});

  @override
  Widget build(BuildContext context) {
    if (coverUrl == null) {
      return Container(color: const Color(0xFF0D0D0D));
    }
    return Stack(fit: StackFit.expand, children: [
      CachedNetworkImage(imageUrl: coverUrl!, fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Container(color: const Color(0xFF111111))),
      BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
        child: Container(color: Colors.black.withOpacity(0.18)),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main overlay — exact TikTok/Reels layout
//   · Right column  = action buttons (fixed position)
//   · Bottom-left   = user info + content
// ─────────────────────────────────────────────────────────────────────────────
class _MainOverlay extends StatelessWidget {
  final BookPost post;
  final bool isOwn, isFollowing, followLoading, hasPages;
  final Animation<double> heartScale;
  final double navOffset;
  final VoidCallback onFollow, onProfile, onLike, onPages;

  const _MainOverlay({
    required this.post, required this.isOwn, required this.isFollowing,
    required this.followLoading, required this.heartScale, required this.navOffset,
    required this.onFollow, required this.onProfile, required this.onLike,
    required this.hasPages, required this.onPages,
  });

  String _n(int n) => n >= 1000 ? '${(n/1000).toStringAsFixed(1)}k' : '$n';

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    // Right column width
    const rw = 64.0;

    return Stack(children: [

      // ── RIGHT ACTION COLUMN ──────────────────────────────────────────
      Positioned(
        right: 8,
        bottom: navOffset + 16,
        width: rw,
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // Avatar (tappable → profile)
          GestureDetector(
            onTap: onProfile,
            child: Stack(alignment: Alignment.bottomCenter, children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF222222),
                  backgroundImage: post.userAvatar != null
                      ? CachedNetworkImageProvider(post.userAvatar!) : null,
                  child: post.userAvatar == null
                      ? Text((post.displayName ?? post.username ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white,
                              fontWeight: FontWeight.bold, fontSize: 16))
                      : null,
                ),
              ),
              // Follow "+" badge — only on other users
              if (!isOwn)
                Positioned(
                  bottom: -6,
                  child: GestureDetector(
                    onTap: onFollow,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        color: _isFollowing(isFollowing),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: followLoading
                          ? const Padding(
                              padding: EdgeInsets.all(3),
                              child: CircularProgressIndicator(
                                  strokeWidth: 1.5, color: Colors.white))
                          : Icon(
                              isFollowing ? Icons.check : Icons.add,
                              color: Colors.white, size: 11),
                    ),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 22),

          // Like
          ScaleTransition(
            scale: heartScale,
            child: _Btn(
              icon: post.isLiked
                  ? Icons.favorite_rounded
                  : Icons.favorite_outline_rounded,
              color: post.isLiked ? const Color(0xFFFF3B5C) : Colors.white,
              label: _n(post.likesCount + (post.isLiked ? 1 : 0)),
              onTap: onLike,
            ),
          ),
          const SizedBox(height: 20),

          // Comment
          _Btn(
            icon: Icons.chat_bubble_outline_rounded,
            label: _n(post.commentsCount),
            onTap: () => showModalBottomSheet(
              context: context, isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => CommentsSheet(bookId: post.id),
            ),
          ),
          const SizedBox(height: 20),

          // Share
          _Btn(icon: Icons.share_rounded, label: 'Share', onTap: () {}),
        ]),
      ),

      // ── BOTTOM-LEFT CONTENT ──────────────────────────────────────────
      Positioned(
        left: 0,
        right: rw + 14,
        bottom: navOffset,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, children: [

            // Username + following label
            GestureDetector(
              onTap: onProfile,
              child: Row(children: [
                Text('@${post.username ?? ''}',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w700, fontSize: 14,
                        shadows: [Shadow(blurRadius: 8, color: Colors.black87)])),
                if (!isOwn) ...[
                  const SizedBox(width: 8),
                  if (isFollowing)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white38),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Following',
                          style: TextStyle(color: Colors.white70, fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ]),
            ),
            const SizedBox(height: 8),

            // Big cover + book meta
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => BookDetailScreen(post: post))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                // ── Large cover ──
                Hero(
                  tag: 'cover_${post.id}',
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.6),
                            blurRadius: 20, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: post.coverUrl != null
                          ? CachedNetworkImage(
                              imageUrl: post.coverUrl!,
                              width: screenW * 0.28,
                              height: screenW * 0.42,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _FallCover(post: post,
                                  w: screenW * 0.28, h: screenW * 0.42))
                          : _FallCover(post: post,
                              w: screenW * 0.28, h: screenW * 0.42),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // ── Title / author / stars / genre ──
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text(post.title,
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w900, fontSize: 18,
                            height: 1.2, letterSpacing: -0.2,
                            shadows: [Shadow(blurRadius: 10, color: Colors.black87)]),
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(post.author,
                        style: TextStyle(color: Colors.white.withOpacity(0.6),
                            fontSize: 12, fontWeight: FontWeight.w500),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(children: List.generate(5, (i) => Icon(
                        i < post.rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: const Color(0xFFFFD700), size: 12))),
                    if (post.genre != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(post.genre!,
                            style: const TextStyle(color: Colors.white,
                                fontSize: 10, fontWeight: FontWeight.w600,
                                letterSpacing: 0.4)),
                      ),
                    ],
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 10),

            // Review snippet
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => BookDetailScreen(post: post))),
              child: Text(post.review,
                  style: TextStyle(color: Colors.white.withOpacity(0.82),
                      fontSize: 13, height: 1.5,
                      shadows: const [Shadow(blurRadius: 6, color: Colors.black87)]),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ),

            // Quote
            if (post.quote != null) ...[
              const SizedBox(height: 5),
              Text('"${post.quote}"',
                  style: TextStyle(color: Colors.white.withOpacity(0.45),
                      fontStyle: FontStyle.italic, fontSize: 12, height: 1.3),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],

            // Read pages
            if (hasPages) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: onPages,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.auto_stories_rounded,
                          color: Colors.white, size: 13),
                      SizedBox(width: 5),
                      Text('Read pages',
                          style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w700, fontSize: 12)),
                    ]),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 6),
          ]),
        ),
      ),
    ]);
  }

  Color _isFollowing(bool f) => f ? Colors.white38 : const Color(0xFFFF3B5C);
}

// ─────────────────────────────────────────────────────────────────────────────
// TikTok-style side button — small icon, count below, no container
// ─────────────────────────────────────────────────────────────────────────────
class _Btn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _Btn({required this.icon, this.color = Colors.white,
      required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 28,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 6)]),
        const SizedBox(height: 3),
        Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 11,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Book-pages overlay
// ─────────────────────────────────────────────────────────────────────────────
class _PageOverlay extends StatelessWidget {
  final BookPage page;
  final BookPost post;
  final int total;
  final double navOffset;
  const _PageOverlay(
      {required this.page, required this.post,
       required this.total, required this.navOffset});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + 72.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, top, 14, navOffset + 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Page \${page.pageNumber} / \$total',
                style: const TextStyle(color: Colors.white,
                    fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(post.title,
              style: TextStyle(color: Colors.white.withOpacity(0.4),
                  fontSize: 11, fontStyle: FontStyle.italic),
              overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 10),
        Expanded(
          child: page.isPhotoOnly
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: CachedNetworkImage(
                      imageUrl: page.photoUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Center(
                          child: Icon(Icons.broken_image,
                              color: Colors.white.withOpacity(0.3), size: 48))),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Stack(children: [
                        Positioned.fill(
                          bottom: 36,
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (page.content.isNotEmpty)
                                  Text(page.content,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          height: 1.9)),
                                if (page.photoUrl != null) ...[
                                  const SizedBox(height: 14),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: CachedNetworkImage(
                                        imageUrl: page.photoUrl!,
                                        width: double.infinity,
                                        fit: BoxFit.cover),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0, left: 0, right: 0,
                          child: Container(
                            height: 36,
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(18)),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.65),
                                ],
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text('scroll  ·  swipe for next',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.25),
                                    fontSize: 10)),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fallback cover when no image
// ─────────────────────────────────────────────────────────────────────────────
class _FallCover extends StatelessWidget {
  final BookPost post;
  final double w, h;
  const _FallCover({required this.post, required this.w, required this.h});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: w, height: h,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: Center(child: Text(
        post.title.substring(0,
            post.title.length > 2 ? 2 : post.title.length).toUpperCase(),
        style: const TextStyle(color: Colors.white70,
            fontWeight: FontWeight.w900, fontSize: 22),
      )),
    );
  }
}