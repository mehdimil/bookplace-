class BookPage {
  final String id;
  final String bookId;
  final int pageNumber;
  final String content;
  final String? photoUrl;

  BookPage({
    required this.id,
    required this.bookId,
    required this.pageNumber,
    required this.content,
    this.photoUrl,
  });

  bool get isPhotoOnly => content.trim().isEmpty && photoUrl != null;

  factory BookPage.fromMap(Map<String, dynamic> map) {
    return BookPage(
      id: map['id'],
      bookId: map['book_id'],
      pageNumber: map['page_number'],
      content: map['content'] ?? '',
      photoUrl: map['photo_url'],
    );
  }
}

class BookPost {
  final String id;
  final String userId;
  final String title;
  final String author;
  final String? coverUrl;
  final String? genre;
  final String review;
  final int rating;
  final String? quote;
  final DateTime createdAt;
  final String username;
  final String? displayName;
  final String? userAvatar;
  final int likesCount;
  final int commentsCount;
  bool isLiked;
  List<BookPage> pages;

  BookPost({
    required this.id,
    required this.userId,
    required this.title,
    required this.author,
    this.coverUrl,
    this.genre,
    required this.review,
    required this.rating,
    this.quote,
    required this.createdAt,
    required this.username,
    this.displayName,
    this.userAvatar,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLiked = false,
    this.pages = const [],
  });

  factory BookPost.fromMap(Map<String, dynamic> map) {
    return BookPost(
      id: map['id'],
      userId: map['user_id'],
      title: map['title'],
      author: map['author'],
      coverUrl: map['cover_url'],
      genre: map['genre'],
      review: map['review'],
      rating: map['rating'] ?? 0,
      quote: map['quote'],
      createdAt: DateTime.parse(map['created_at']),
      username: map['username'] ?? '',
      displayName: map['display_name'],
      userAvatar: map['user_avatar'],
      likesCount: map['likes_count'] ?? 0,
      commentsCount: map['comments_count'] ?? 0,
    );
  }
}

class Comment {
  final String id;
  final String userId;
  final String bookId;
  final String content;
  final DateTime createdAt;
  final String username;
  final String? userAvatar;

  Comment({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.content,
    required this.createdAt,
    required this.username,
    this.userAvatar,
  });

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['id'],
      userId: map['user_id'],
      bookId: map['book_id'],
      content: map['content'],
      createdAt: DateTime.parse(map['created_at']),
      username: map['profiles']?['username'] ?? '',
      userAvatar: map['profiles']?['avatar_url'],
    );
  }
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final bool read;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.read,
    required this.createdAt,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      conversationId: map['conversation_id'],
      senderId: map['sender_id'],
      content: map['content'],
      read: map['read'] ?? false,
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

class Conversation {
  final String id;
  final String user1Id;
  final String user2Id;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  // hydrated
  String? otherUsername;
  String? otherAvatar;
  String? otherUserId;

  Conversation({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    this.lastMessage,
    this.lastMessageAt,
    this.otherUsername,
    this.otherAvatar,
    this.otherUserId,
  });

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'],
      user1Id: map['user1_id'],
      user2Id: map['user2_id'],
      lastMessage: map['last_message'],
      lastMessageAt: map['last_message_at'] != null ? DateTime.parse(map['last_message_at']) : null,
    );
  }
}