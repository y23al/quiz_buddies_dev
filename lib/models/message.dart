// メッセージモデル

enum MessageType { text, image, system }

class Message {
  final String messageId;
  final String roomId;
  final String senderUserId;
  final MessageType type;
  final String? text;
  final String? imageUrl;
  final DateTime createdAt;

  Message({
    required this.messageId,
    required this.roomId,
    required this.senderUserId,
    required this.type,
    this.text,
    this.imageUrl,
    required this.createdAt,
  });

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      messageId: map['messageId'] ?? '',
      roomId: map['roomId'] ?? '',
      senderUserId: map['senderUserId'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.name.toUpperCase() == map['type'],
        orElse: () => MessageType.text,
      ),
      text: map['text'],
      imageUrl: map['imageUrl'],
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'roomId': roomId,
      'senderUserId': senderUserId,
      'type': type.name.toUpperCase(),
      'text': text,
      'imageUrl': imageUrl,
      'createdAt': createdAt,
    };
  }
}
