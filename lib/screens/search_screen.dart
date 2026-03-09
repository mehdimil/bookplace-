import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bookplace/services/supabase_service.dart';
import 'package:bookplace/screens/profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  bool _searched = false;

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) { setState(() { _results = []; _searched = false; }); return; }
    setState(() => _loading = true);
    try {
      final r = await svc.searchUsers(q.trim());
      if (mounted) setState(() { _results = r; _loading = false; _searched = true; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

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
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Search users…',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true, fillColor: const Color(0xFF1E1E1E),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
            suffixIcon: _ctrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                    onPressed: () { _ctrl.clear(); _search(''); })
                : null,
          ),
          onChanged: _search,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B6B)))
          : !_searched
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.search, size: 56, color: Colors.white12),
                  const SizedBox(height: 12),
                  const Text('Search for users by username',
                      style: TextStyle(color: Colors.white24, fontSize: 14)),
                ]))
              : _results.isEmpty
                  ? Center(child: Text('No users found for "${_ctrl.text}"',
                      style: const TextStyle(color: Colors.white38, fontSize: 14)))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _results.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: Colors.white10, height: 1, indent: 70),
                      itemBuilder: (_, i) => _SearchUserTile(user: _results[i]),
                    ),
    );
  }
}

class _SearchUserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  const _SearchUserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    final username = user['username'] ?? '';
    final displayName = user['display_name'] ?? username;
    final avatar = user['avatar_url'];
    final userId = user['id'] as String;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: const Color(0xFFFF6B6B),
        backgroundImage: avatar != null ? CachedNetworkImageProvider(avatar) : null,
        child: avatar == null
            ? Text(username.isNotEmpty ? username[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
            : null,
      ),
      title: Text(displayName.isNotEmpty ? displayName : username,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text('@$username', style: const TextStyle(color: Colors.white38, fontSize: 12)),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId))),
    );
  }
}