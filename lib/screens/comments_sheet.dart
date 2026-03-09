import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:bookplace/models/book_post.dart';
import 'package:bookplace/services/supabase_service.dart';
import 'package:bookplace/screens/profile_screen.dart';

class CommentsSheet extends StatefulWidget {
  final String bookId;
  const CommentsSheet({super.key, required this.bookId});
  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  List<Comment> _comments = [];
  bool _loading = true;
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final c = await svc.getComments(widget.bookId);
      if (mounted) setState(() { _comments = c; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try { await svc.addComment(bookId: widget.bookId, content: text); _ctrl.clear(); await _load(); }
    catch (_) {}
    if (mounted) setState(() => _sending = false);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.75 + bottom,
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white54, size: 15),
          const SizedBox(width: 6),
          const Text('Comments',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
        ]),
        const Divider(color: Colors.white12, height: 20),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B6B)))
              : _comments.isEmpty
                  ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.chat_bubble_outline, size: 36, color: Colors.white12),
                      SizedBox(height: 10),
                      Text('No comments yet. Be the first!',
                          style: TextStyle(color: Colors.white38, fontSize: 13)),
                    ]))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                      itemCount: _comments.length,
                      separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (_, i) => _CommentTile(comment: _comments[i]),
                    ),
        ),

        if (svc.currentUser != null)
          Container(
            padding: EdgeInsets.fromLTRB(14, 10, 14, 10 + bottom),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Add a comment…',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true, fillColor: const Color(0xFF2A2A2A),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _send,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
                    shape: BoxShape.circle,
                  ),
                  child: _sending
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Comment comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Clickable avatar → opens profile
        GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => ProfileScreen(userId: comment.userId))),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFFF6B6B),
            backgroundImage: comment.userAvatar != null
                ? CachedNetworkImageProvider(comment.userAvatar!) : null,
            child: comment.userAvatar == null
                ? Text(comment.username.isNotEmpty ? comment.username[0].toUpperCase() : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white))
                : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              // Clickable username → opens profile
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ProfileScreen(userId: comment.userId))),
                child: Text('@${comment.username}',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              const SizedBox(width: 8),
              Text(timeago.format(comment.createdAt),
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ]),
            const SizedBox(height: 4),
            Text(comment.content,
                style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
          ]),
        ),
      ]),
    );
  }
}