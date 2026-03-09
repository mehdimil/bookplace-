import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bookplace/main.dart';
import 'package:bookplace/models/book_post.dart';

class SupabaseService {
  User? get currentUser => supabase.auth.currentUser;

  // ── Auth ──────────────────────────────────────────────
  Future<AuthResponse> signUp({required String email, required String password, required String username}) async {
    return await supabase.auth.signUp(email: email, password: password, data: {'username': username, 'display_name': username});
  }
  Future<AuthResponse> signIn({required String email, required String password}) async {
    return await supabase.auth.signInWithPassword(email: email, password: password);
  }
  Future<void> signOut() async => await supabase.auth.signOut();

  // ── Upload ────────────────────────────────────────────
  Future<String> uploadCoverPhoto({required Uint8List fileBytes, required String fileName}) async {
    final uid = currentUser!.id;
    final ext = fileName.split('.').last.toLowerCase();
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await supabase.storage.from('book-covers').uploadBinary(path, fileBytes,
        fileOptions: FileOptions(contentType: 'image/$ext', upsert: true));
    return supabase.storage.from('book-covers').getPublicUrl(path);
  }
  Future<String> uploadAvatar({required Uint8List fileBytes, required String fileName}) async {
    final uid = currentUser!.id;
    final ext = fileName.split('.').last.toLowerCase();
    final path = '$uid/avatar.$ext';
    await supabase.storage.from('book-covers').uploadBinary(path, fileBytes,
        fileOptions: FileOptions(contentType: 'image/$ext', upsert: true));
    return supabase.storage.from('book-covers').getPublicUrl(path);
  }

  // ── Profile ───────────────────────────────────────────
  Future<Map<String, dynamic>> getProfile(String userId) async =>
      await supabase.from('profile_with_counts').select().eq('id', userId).single();

  Future<void> updateProfile({String? displayName, String? bio, String? avatarUrl}) async {
    final data = <String, dynamic>{};
    if (displayName != null) data['display_name'] = displayName;
    if (bio != null) data['bio'] = bio;
    if (avatarUrl != null) data['avatar_url'] = avatarUrl;
    await supabase.from('profiles').update(data).eq('id', currentUser!.id);
  }

  // ── Follows ───────────────────────────────────────────
  Future<bool> isFollowing(String targetId) async {
    final r = await supabase.from('follows').select('id')
        .eq('follower_id', currentUser!.id).eq('following_id', targetId).maybeSingle();
    return r != null;
  }
  Future<void> follow(String targetId) async {
    await supabase.from('follows').insert({'follower_id': currentUser!.id, 'following_id': targetId});
  }
  Future<void> unfollow(String targetId) async {
    await supabase.from('follows').delete()
        .eq('follower_id', currentUser!.id).eq('following_id', targetId);
  }

  // ── Feed ─────────────────────────────────────────────
  Future<List<BookPost>> getFeed({int limit = 10, int offset = 0}) async {
    final data = await supabase.from('books_with_counts').select()
        .order('created_at', ascending: false).range(offset, offset + limit - 1);
    final posts = (data as List).map((e) => BookPost.fromMap(e)).toList();
    if (currentUser != null) await _hydrateLikes(posts);
    await _hydratePages(posts);
    return posts;
  }
  Future<List<BookPost>> getUserPosts(String userId) async {
    final data = await supabase.from('books_with_counts').select()
        .eq('user_id', userId).order('created_at', ascending: false);
    final posts = (data as List).map((e) => BookPost.fromMap(e)).toList();
    if (currentUser != null) await _hydrateLikes(posts);
    await _hydratePages(posts);
    return posts;
  }
  Future<void> _hydrateLikes(List<BookPost> posts) async {
    if (posts.isEmpty) return;
    final ids = posts.map((p) => p.id).toList();
    final liked = await supabase.from('likes').select('book_id')
        .eq('user_id', currentUser!.id).inFilter('book_id', ids);
    final likedIds = (liked as List).map((e) => e['book_id'] as String).toSet();
    for (final p in posts) p.isLiked = likedIds.contains(p.id);
  }
  Future<void> _hydratePages(List<BookPost> posts) async {
    if (posts.isEmpty) return;
    final ids = posts.map((p) => p.id).toList();
    final pages = await supabase.from('book_pages').select()
        .inFilter('book_id', ids).order('page_number', ascending: true);
    final map = <String, List<BookPage>>{};
    for (final p in (pages as List)) {
      final page = BookPage.fromMap(p);
      map.putIfAbsent(page.bookId, () => []).add(page);
    }
    for (final p in posts) p.pages = map[p.id] ?? [];
  }

  // ── Delete Post ───────────────────────────────────────
  Future<void> deletePost(String bookId) async {
    await supabase.from('book_pages').delete().eq('book_id', bookId);
    await supabase.from('likes').delete().eq('book_id', bookId);
    await supabase.from('comments').delete().eq('book_id', bookId);
    await supabase.from('books').delete().eq('id', bookId).eq('user_id', currentUser!.id);
  }

  // ── Likes ─────────────────────────────────────────────
  Future<void> likeBook(String bookId) async =>
      await supabase.from('likes').insert({'user_id': currentUser!.id, 'book_id': bookId});
  Future<void> unlikeBook(String bookId) async =>
      await supabase.from('likes').delete().eq('user_id', currentUser!.id).eq('book_id', bookId);

  // ── Comments ──────────────────────────────────────────
  Future<List<Comment>> getComments(String bookId) async {
    final data = await supabase.from('comments').select('*, profiles(username, avatar_url)')
        .eq('book_id', bookId).order('created_at', ascending: true);
    return (data as List).map((e) => Comment.fromMap(e)).toList();
  }
  Future<void> addComment({required String bookId, required String content}) async =>
      await supabase.from('comments').insert({'user_id': currentUser!.id, 'book_id': bookId, 'content': content});
  Future<void> deleteComment(String commentId) async =>
      await supabase.from('comments').delete().eq('id', commentId);

  // ── Posts ─────────────────────────────────────────────
  Future<void> createBookPost({
    required String title, required String author, required String review,
    required int rating, required List<String> pages,
    List<String?> pagePhotoUrls = const [],
    String? coverUrl, String? genre, String? quote,
  }) async {
    final result = await supabase.from('books').insert({
      'user_id': currentUser!.id, 'title': title, 'author': author,
      'review': review, 'rating': rating, 'cover_url': coverUrl, 'genre': genre, 'quote': quote,
    }).select('id').single();
    final bookId = result['id'] as String;
    final inserts = <Map<String, dynamic>>[];
    for (int i = 0; i < pages.length; i++) {
      final text = pages[i].trim();
      final photo = i < pagePhotoUrls.length ? pagePhotoUrls[i] : null;
      if (text.isEmpty && photo == null) continue;
      inserts.add({'book_id': bookId, 'page_number': i + 1, 'content': text, 'photo_url': photo});
    }
    if (inserts.isNotEmpty) await supabase.from('book_pages').insert(inserts);
  }

  // ── Conversations ─────────────────────────────────────
  Future<List<Conversation>> getConversations() async {
    final uid = currentUser!.id;
    final data = await supabase.from('conversations').select()
        .or('user1_id.eq.$uid,user2_id.eq.$uid')
        .order('last_message_at', ascending: false);
    final convs = (data as List).map((e) => Conversation.fromMap(e)).toList();
    // hydrate other user info
    for (final c in convs) {
      final otherId = c.user1Id == uid ? c.user2Id : c.user1Id;
      c.otherUserId = otherId;
      try {
        final p = await supabase.from('profiles').select('username, avatar_url').eq('id', otherId).single();
        c.otherUsername = p['username'];
        c.otherAvatar = p['avatar_url'];
      } catch (_) {}
    }
    return convs;
  }

  Future<String> getOrCreateConversation(String otherUserId) async {
    final uid = currentUser!.id;
    final ids = [uid, otherUserId]..sort();
    final u1 = ids[0]; final u2 = ids[1];
    try {
      final existing = await supabase.from('conversations').select('id')
          .eq('user1_id', u1).eq('user2_id', u2).single();
      return existing['id'];
    } catch (_) {
      final result = await supabase.from('conversations')
          .insert({'user1_id': u1, 'user2_id': u2}).select('id').single();
      return result['id'];
    }
  }

  Future<List<ChatMessage>> getMessages(String conversationId) async {
    final data = await supabase.from('messages').select()
        .eq('conversation_id', conversationId).order('created_at', ascending: true);
    return (data as List).map((e) => ChatMessage.fromMap(e)).toList();
  }

  Future<void> sendMessage({required String conversationId, required String content}) async {
    await supabase.from('messages').insert({
      'conversation_id': conversationId, 'sender_id': currentUser!.id, 'content': content,
    });
    await supabase.from('conversations').update({
      'last_message': content, 'last_message_at': DateTime.now().toIso8601String(),
    }).eq('id', conversationId);
  }

  // ── Search &amp; Follows List ──────────────────────────────────
  Future<List<Map<String,dynamic>>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    final data = await supabase.from('profiles').select('id, username, display_name, avatar_url')
        .ilike('username', '%$query%').limit(20);
    return (data as List).cast<Map<String,dynamic>>();
  }

  Future<List<Map<String,dynamic>>> getFollowers(String userId) async {
    // Get follower IDs first, then fetch their profiles
    final rows = await supabase.from('follows')
        .select('follower_id').eq('following_id', userId);
    final ids = (rows as List).map((e) => e['follower_id'] as String).toList();
    if (ids.isEmpty) return [];
    final profiles = await supabase.from('profiles')
        .select('id, username, display_name, avatar_url').inFilter('id', ids);
    return (profiles as List).cast<Map<String,dynamic>>();
  }

  Future<List<Map<String,dynamic>>> getFollowing(String userId) async {
    // Get following IDs first, then fetch their profiles
    final rows = await supabase.from('follows')
        .select('following_id').eq('follower_id', userId);
    final ids = (rows as List).map((e) => e['following_id'] as String).toList();
    if (ids.isEmpty) return [];
    final profiles = await supabase.from('profiles')
        .select('id, username, display_name, avatar_url').inFilter('id', ids);
    return (profiles as List).cast<Map<String,dynamic>>();
  }

  RealtimeChannel subscribeToMessages(String conversationId, void Function(ChatMessage) onMessage) {
    return supabase.channel('messages:$conversationId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public', table: 'messages',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'conversation_id', value: conversationId),
        callback: (payload) => onMessage(ChatMessage.fromMap(payload.newRecord)),
      ).subscribe();
  }
}

final svc = SupabaseService();