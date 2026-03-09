import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bookplace/models/book_post.dart';
import 'package:bookplace/services/supabase_service.dart';
import 'package:bookplace/screens/profile_screen.dart';
import 'package:bookplace/screens/search_screen.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUsername;
  final String? otherAvatar;
  const ChatScreen({super.key, required this.conversationId, required this.otherUserId,
      required this.otherUsername, this.otherAvatar});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _loading = true;
  bool _sending = false;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = svc.subscribeToMessages(widget.conversationId, (msg) {
      if (mounted) setState(() => _messages.add(msg));
      _scrollToBottom();
    });
  }

  Future<void> _load() async {
    try {
      final msgs = await svc.getMessages(widget.conversationId);
      if (mounted) setState(() { _messages.addAll(msgs); _loading = false; });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _scrollToBottom() {
    if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    _ctrl.clear();
    setState(() => _sending = true);
    try { await svc.sendMessage(conversationId: widget.conversationId, content: text); }
    catch (_) {}
    if (mounted) setState(() => _sending = false);
  }

  void _openProfile() => Navigator.push(context,
      MaterialPageRoute(builder: (_) => ProfileScreen(userId: widget.otherUserId)));

  @override
  void dispose() { _channel?.unsubscribe(); _ctrl.dispose(); _scroll.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final myId = svc.currentUser?.id ?? '';
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: GestureDetector(
          onTap: _openProfile,
          child: Row(children: [
            // Clickable profile picture
            Hero(
              tag: 'avatar_${widget.otherUserId}',
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFFF6B6B),
                backgroundImage: widget.otherAvatar != null
                    ? CachedNetworkImageProvider(widget.otherAvatar!) : null,
                child: widget.otherAvatar == null
                    ? Text(widget.otherUsername.isNotEmpty
                          ? widget.otherUsername[0].toUpperCase() : '?',
                        style: const TextStyle(fontWeight: FontWeight.bold,
                            fontSize: 13, color: Colors.white))
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('@${widget.otherUsername}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15,
                      color: Colors.white)),
              Text('Tap to view profile',
                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
            ])),
          ]),
        ),
        actions: [
          // Search bar to start new chat
          IconButton(
            icon: const Icon(Icons.person_search_rounded, color: Colors.white54, size: 22),
            tooltip: 'Find another user',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SearchScreen())),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B6B)))
              : _messages.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.waving_hand_rounded, color: Colors.white24, size: 44),
                      const SizedBox(height: 12),
                      Text('Say hello to @${widget.otherUsername}!',
                          style: const TextStyle(color: Colors.white38, fontSize: 14)),
                    ]))
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final msg = _messages[i];
                        final isMe = msg.senderId == myId;
                        final showTime = i == 0 ||
                            msg.createdAt.difference(_messages[i - 1].createdAt).inMinutes > 10;
                        return Column(children: [
                          if (showTime) Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(_fmtTime(msg.createdAt),
                                style: const TextStyle(color: Colors.white24, fontSize: 11)),
                          ),
                          _Bubble(msg: msg, isMe: isMe,
                              otherAvatar: widget.otherAvatar,
                              otherUsername: widget.otherUsername,
                              onAvatarTap: _openProfile),
                        ]);
                      },
                    ),
        ),

        // Input
        Container(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.of(context).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: Color(0xFF111111),
            border: Border(top: BorderSide(color: Colors.white10)),
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 4, minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Message @${widget.otherUsername}…',
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                  filled: true, fillColor: const Color(0xFF1E1E1E),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.5)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _send,
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
                  shape: BoxShape.circle,
                ),
                child: _sending
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  String _fmtTime(DateTime t) {
    final now = DateTime.now();
    if (now.difference(t).inDays == 0)
      return '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';
    return '${t.day}/${t.month}  ${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage msg;
  final bool isMe;
  final String? otherAvatar;
  final String otherUsername;
  final VoidCallback onAvatarTap;
  const _Bubble({required this.msg, required this.isMe, this.otherAvatar,
      required this.otherUsername, required this.onAvatarTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Other user avatar (clickable) on the left
          if (!isMe) ...[
            GestureDetector(
              onTap: onAvatarTap,
              child: CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFFFF6B6B),
                backgroundImage: otherAvatar != null
                    ? CachedNetworkImageProvider(otherAvatar!) : null,
                child: otherAvatar == null
                    ? Text(otherUsername.isNotEmpty ? otherUsername[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 10, color: Colors.white,
                            fontWeight: FontWeight.bold))
                    : null,
              ),
            ),
            const SizedBox(width: 6),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.68),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                gradient: isMe ? const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]) : null,
                color: isMe ? null : const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
              ),
              child: Text(msg.content,
                  style: TextStyle(
                      color: isMe ? Colors.white : Colors.white70,
                      fontSize: 14, height: 1.4)),
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}