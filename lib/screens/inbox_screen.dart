import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bookplace/models/book_post.dart';
import 'package:bookplace/services/supabase_service.dart';
import 'package:bookplace/screens/chat_screen.dart';
import 'package:bookplace/screens/search_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});
  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  List<Conversation> _convs = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final convs = await svc.getConversations();
      if (mounted) setState(() { _convs = convs; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        titleSpacing: 16,
        title: const Text('Messages',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
        actions: [
          // Search button to find & start new chat
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person_search_rounded,
                  color: Colors.white70, size: 20),
            ),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SearchScreen())),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(children: [
        // Search bar to filter existing conversations
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
          child: _ConvSearch(convs: _convs, onOpen: (conv) =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
              conversationId: conv.id,
              otherUserId: conv.otherUserId ?? '',
              otherUsername: conv.otherUsername ?? '',
              otherAvatar: conv.otherAvatar,
            ))).then((_) => _load()),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B6B)))
              : _convs.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.chat_bubble_outline_rounded, size: 56, color: Colors.white24),
                      const SizedBox(height: 14),
                      const Text('No messages yet',
                          style: TextStyle(color: Colors.white38, fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text('Tap 🔍 above to find and message someone',
                          style: TextStyle(color: Colors.white24, fontSize: 13)),
                    ]))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: const Color(0xFFFF6B6B),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _convs.length,
                        separatorBuilder: (_, __) =>
                            const Divider(color: Colors.white10, height: 1, indent: 72),
                        itemBuilder: (_, i) => _ConvTile(
                          conv: _convs[i],
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => ChatScreen(
                                conversationId: _convs[i].id,
                                otherUserId: _convs[i].otherUserId ?? '',
                                otherUsername: _convs[i].otherUsername ?? '',
                                otherAvatar: _convs[i].otherAvatar,
                              ))).then((_) => _load()),
                        ),
                      ),
                    ),
        ),
      ]),
    );
  }
}

// ── Inline conversation filter ─────────────────────────────────────────────
class _ConvSearch extends StatefulWidget {
  final List<Conversation> convs;
  final void Function(Conversation) onOpen;
  const _ConvSearch({required this.convs, required this.onOpen});
  @override
  State<_ConvSearch> createState() => _ConvSearchState();
}

class _ConvSearchState extends State<_ConvSearch> {
  final _ctrl = TextEditingController();
  String _q = '';

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.convs.where((c) =>
        (c.otherUsername ?? '').toLowerCase().contains(_q.toLowerCase())).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: _ctrl,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        onChanged: (v) => setState(() => _q = v),
        decoration: InputDecoration(
          hintText: 'Search conversations…',
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
          suffixIcon: _q.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white24, size: 16),
                  onPressed: () { _ctrl.clear(); setState(() => _q = ''); })
              : null,
          filled: true,
          fillColor: const Color(0xFF1A1A1A),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.2)),
        ),
      ),
      if (_q.isNotEmpty && filtered.isNotEmpty) ...[
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: filtered.map((c) => ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFFF6B6B),
                backgroundImage: c.otherAvatar != null
                    ? CachedNetworkImageProvider(c.otherAvatar!) : null,
                child: c.otherAvatar == null
                    ? Text((c.otherUsername ?? '?')[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))
                    : null,
              ),
              title: Text('@${c.otherUsername ?? ''}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: Text(c.lastMessage ?? '',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () { _ctrl.clear(); setState(() => _q = ''); widget.onOpen(c); },
            )).toList(),
          ),
        ),
      ],
    ]);
  }
}

// ── Conversation tile ──────────────────────────────────────────────────────
class _ConvTile extends StatelessWidget {
  final Conversation conv;
  final VoidCallback onTap;
  const _ConvTile({required this.conv, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFFFF6B6B),
            backgroundImage: conv.otherAvatar != null
                ? CachedNetworkImageProvider(conv.otherAvatar!) : null,
            child: conv.otherAvatar == null
                ? Text((conv.otherUsername ?? '?')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 16))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('@${conv.otherUsername ?? '…'}',
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 3),
            Text(conv.lastMessage ?? 'Start a conversation',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          if (conv.lastMessageAt != null)
            Text(timeago.format(conv.lastMessageAt!),
                style: const TextStyle(color: Colors.white24, fontSize: 11)),
        ]),
      ),
    );
  }
}