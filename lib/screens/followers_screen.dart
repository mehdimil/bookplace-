import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bookplace/services/supabase_service.dart';
import 'package:bookplace/screens/profile_screen.dart';

class FollowersScreen extends StatefulWidget {
  final String userId;
  final bool showFollowers; // true = followers, false = following
  const FollowersScreen({super.key, required this.userId, required this.showFollowers});

  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final users = widget.showFollowers
          ? await svc.getFollowers(widget.userId)
          : await svc.getFollowing(widget.userId);
      if (mounted) setState(() { _users = users; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.showFollowers ? 'Followers' : 'Following',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B6B)))
          : _users.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.people_outline, size: 52, color: Colors.white24),
                  const SizedBox(height: 12),
                  Text(widget.showFollowers ? 'No followers yet' : 'Not following anyone',
                      style: const TextStyle(color: Colors.white38, fontSize: 15)),
                ]))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _users.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1, indent: 70),
                  itemBuilder: (_, i) => _UserTile(user: _users[i]),
                ),
    );
  }
}

class _UserTile extends StatefulWidget {
  final Map<String, dynamic> user;
  const _UserTile({required this.user});

  @override
  State<_UserTile> createState() => _UserTileState();
}

class _UserTileState extends State<_UserTile> {
  bool _isFollowing = false;
  bool _loading = false;
  bool get _isMe => widget.user['id'] == svc.currentUser?.id;

  @override
  void initState() {
    super.initState();
    if (!_isMe) _checkFollow();
  }

  Future<void> _checkFollow() async {
    try {
      final f = await svc.isFollowing(widget.user['id']);
      if (mounted) setState(() => _isFollowing = f);
    } catch (_) {}
  }

  Future<void> _toggle() async {
    setState(() => _loading = true);
    try {
      if (_isFollowing) await svc.unfollow(widget.user['id']);
      else await svc.follow(widget.user['id']);
      if (mounted) setState(() => _isFollowing = !_isFollowing);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final username = widget.user['username'] ?? '';
    final displayName = widget.user['display_name'] ?? username;
    final avatar = widget.user['avatar_url'];
    final userId = widget.user['id'] as String;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId))),
        child: CircleAvatar(
          radius: 24,
          backgroundColor: const Color(0xFFFF6B6B),
          backgroundImage: avatar != null ? CachedNetworkImageProvider(avatar) : null,
          child: avatar == null
              ? Text(username.isNotEmpty ? username[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
              : null,
        ),
      ),
      title: GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId))),
        child: Text(displayName.isNotEmpty ? displayName : username,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
      ),
      subtitle: Text('@$username',
          style: const TextStyle(color: Colors.white38, fontSize: 12)),
      trailing: _isMe
          ? null
          : GestureDetector(
              onTap: _loading ? null : _toggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  gradient: _isFollowing ? null : const LinearGradient(
                      colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
                  color: _isFollowing ? Colors.transparent : null,
                  borderRadius: BorderRadius.circular(20),
                  border: _isFollowing ? Border.all(color: Colors.white30) : null,
                ),
                child: _loading
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        _isFollowing ? 'Following' : 'Follow',
                        style: TextStyle(
                          color: _isFollowing ? Colors.white54 : Colors.white,
                          fontSize: 12, fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId))),
    );
  }
}