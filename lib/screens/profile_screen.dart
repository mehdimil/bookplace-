import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bookplace/models/book_post.dart';
import 'package:bookplace/services/supabase_service.dart';
import 'package:bookplace/screens/auth_screen.dart';
import 'package:bookplace/screens/book_detail_screen.dart';
import 'package:bookplace/screens/chat_screen.dart';
import 'package:bookplace/screens/followers_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  List<BookPost> _posts = [];
  bool _loading = true;
  bool _isFollowing = false;
  bool _followLoading = false;
  final _picker = ImagePicker();

  String get _targetId => widget.userId ?? svc.currentUser?.id ?? '';
  bool get _isOwnProfile =>
      widget.userId == null || widget.userId == svc.currentUser?.id;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profile = await svc.getProfile(_targetId);
      final posts = await svc.getUserPosts(_targetId);
      bool following = false;
      if (!_isOwnProfile) following = await svc.isFollowing(_targetId);
      if (mounted) setState(() {
        _profile = profile; _posts = posts;
        _isFollowing = following; _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _toggleFollow() async {
    setState(() => _followLoading = true);
    try {
      if (_isFollowing) await svc.unfollow(_targetId);
      else await svc.follow(_targetId);
      if (mounted) setState(() => _isFollowing = !_isFollowing);
    } catch (_) {}
    if (mounted) setState(() => _followLoading = false);
  }

  Future<void> _openChat() async {
    try {
      final convId = await svc.getOrCreateConversation(_targetId);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
        conversationId: convId,
        otherUserId: _targetId,
        otherUsername: _profile?['username'] ?? '',
        otherAvatar: _profile?['avatar_url'],
      )));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _changeAvatar() async {
    final f = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 600);
    if (f == null) return;
    try {
      final url = await svc.uploadAvatar(fileBytes: await f.readAsBytes(), fileName: f.name);
      await svc.updateProfile(avatarUrl: url);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  void _showEditDialog() {
    final nameCtrl = TextEditingController(text: _profile?['display_name'] ?? '');
    final bioCtrl  = TextEditingController(text: _profile?['bio'] ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Edit Profile',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _dlgField(nameCtrl, 'Display name'),
          const SizedBox(height: 12),
          _dlgField(bioCtrl, 'Bio', maxLines: 3),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await svc.updateProfile(
                  displayName: nameCtrl.text.trim(), bio: bioCtrl.text.trim());
              await _load();
            },
            child: const Text('Save',
                style: TextStyle(color: Color(0xFFFF6B6B), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  TextField _dlgField(TextEditingController c, String hint, {int maxLines = 1}) =>
      TextField(
        controller: c, maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint, hintStyle: const TextStyle(color: Colors.white24),
          filled: true, fillColor: const Color(0xFF0A0A0A),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFFF6B6B))),
        ),
      );

  Future<void> _deletePost(BookPost post) async {
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
      setState(() => _posts.removeWhere((p) => p.id == post.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          backgroundColor: Color(0xFF0A0A0A),
          body: Center(child: CircularProgressIndicator(color: Color(0xFFFF6B6B))));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: RefreshIndicator(
        onRefresh: _load,
        color: const Color(0xFFFF6B6B),
        child: CustomScrollView(slivers: [
          SliverAppBar(
            backgroundColor: const Color(0xFF0A0A0A),
            pinned: true,
            leading: !_isOwnProfile
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    onPressed: () => Navigator.pop(context))
                : null,
            title: Text(
              _profile?['username'] != null ? '@${_profile!['username']}' : 'Profile',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            centerTitle: true,
            actions: [
              if (_isOwnProfile) ...[
                IconButton(icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: _showEditDialog),
                IconButton(
                  icon: const Icon(Icons.logout, size: 20, color: Colors.white54),
                  onPressed: () async {
                    await svc.signOut();
                    if (!mounted) return;
                    Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const AuthScreen()));
                  },
                ),
              ],
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(children: [
                // Avatar
                GestureDetector(
                  onTap: _isOwnProfile ? _changeAvatar : null,
                  child: Stack(children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: const Color(0xFFFF6B6B),
                      backgroundImage: _profile?['avatar_url'] != null
                          ? CachedNetworkImageProvider(_profile!['avatar_url']) : null,
                      child: _profile?['avatar_url'] == null
                          ? Text((_profile?['username'] ?? 'U')[0].toUpperCase(),
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold,
                                  color: Colors.white))
                          : null,
                    ),
                    if (_isOwnProfile)
                      Positioned(bottom: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                              color: Color(0xFFFF6B6B), shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, size: 13, color: Colors.white),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 10),
                Text(_profile?['display_name'] ?? _profile?['username'] ?? '',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: 2),
                Text('@${_profile?['username'] ?? ''}',
                    style: const TextStyle(color: Colors.white54, fontSize: 13)),
                if ((_profile?['bio'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(_profile!['bio'],
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                      textAlign: TextAlign.center),
                ],
                const SizedBox(height: 16),

                // Stats — followers/following are tappable
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _StatBox(value: '${_posts.length}', label: 'Posts'),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => FollowersScreen(userId: _targetId, showFollowers: true))),
                    child: _StatBox(value: '${_profile?['followers_count'] ?? 0}', label: 'Followers'),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => FollowersScreen(userId: _targetId, showFollowers: false))),
                    child: _StatBox(value: '${_profile?['following_count'] ?? 0}', label: 'Following'),
                  ),
                ]),
                const SizedBox(height: 14),

                // Follow + Message buttons for other profiles
                if (!_isOwnProfile) Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _followLoading ? null : _toggleFollow,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: _isFollowing ? null : const LinearGradient(
                              colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
                          color: _isFollowing ? const Color(0xFF1E1E1E) : null,
                          borderRadius: BorderRadius.circular(12),
                          border: _isFollowing ? Border.all(color: Colors.white24) : null,
                        ),
                        alignment: Alignment.center,
                        child: _followLoading
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(
                                _isFollowing ? 'Following ✓' : '+ Subscribe',
                                style: TextStyle(
                                  color: _isFollowing ? Colors.white54 : Colors.white,
                                  fontWeight: FontWeight.w700, fontSize: 14,
                                )),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _openChat,
                    child: Container(
                      height: 40, width: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.chat_bubble_outline_rounded,
                          color: Colors.white70, size: 18),
                    ),
                  ),
                ]),

                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                const SizedBox(height: 6),
                Text(_isOwnProfile ? 'My Reviews' : 'Reviews',
                    style: const TextStyle(color: Colors.white38,
                        fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 10),
              ]),
            ),
          ),

          _posts.isEmpty
              ? const SliverFillRemaining(
                  child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.menu_book_outlined, size: 48, color: Colors.white24),
                    SizedBox(height: 10),
                    Text('No reviews yet', style: TextStyle(color: Colors.white38, fontSize: 14)),
                  ])))
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, mainAxisSpacing: 10,
                        crossAxisSpacing: 10, childAspectRatio: 0.72),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _PostGridItem(
                        post: _posts[i],
                        isOwn: _isOwnProfile,
                        onDelete: () => _deletePost(_posts[i]),
                      ),
                      childCount: _posts.length,
                    ),
                  ),
                ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ]),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value, label;
  const _StatBox({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12)),
    child: Column(children: [
      Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
      const SizedBox(height: 1),
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
    ]),
  );
}

class _PostGridItem extends StatelessWidget {
  final BookPost post;
  final bool isOwn;
  final VoidCallback onDelete;
  const _PostGridItem({required this.post, required this.isOwn, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(context,
            MaterialPageRoute(builder: (_) => BookDetailScreen(post: post)));
        // BookDetailScreen returns 'deleted' if user deleted the post
        // parent _ProfileScreenState handles refresh via _load on pop
      },
      child: Stack(children: [
        // Card
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFF1A1A1A),
            image: post.coverUrl != null
                ? DecorationImage(
                    image: CachedNetworkImageProvider(post.coverUrl!),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                        Colors.black.withOpacity(0.38), BlendMode.darken))
                : null,
            gradient: post.coverUrl == null
                ? const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFF4ECDC4)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight)
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end, children: [
              Text(post.title,
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w700, fontSize: 13),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(post.author,
                  style: const TextStyle(color: Colors.white60, fontSize: 11)),
              const SizedBox(height: 5),
              Row(children: [
                const Icon(Icons.favorite_rounded, color: Color(0xFFFF6B6B), size: 11),
                const SizedBox(width: 3),
                Text('${post.likesCount}',
                    style: const TextStyle(color: Colors.white60, fontSize: 10)),
                const SizedBox(width: 7),
                const Icon(Icons.chat_bubble_rounded, color: Colors.white38, size: 11),
                const SizedBox(width: 3),
                Text('${post.commentsCount}',
                    style: const TextStyle(color: Colors.white60, fontSize: 10)),
              ]),
            ]),
          ),
        ),
        // Delete button — top right, only on own profile
        if (isOwn)
          Positioned(
            top: 6, right: 6,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red.withOpacity(0.6)),
                ),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 14),
              ),
            ),
          ),
      ]),
    );
  }
}