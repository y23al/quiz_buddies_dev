// チャットメッセージウィジェット
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/services.dart';

class ChatMessageWidget extends StatelessWidget {
  final Message message;
  final bool isMe;
  final String? senderName;

  const ChatMessageWidget({
    super.key,
    required this.message,
    required this.isMe,
    this.senderName,
  });

  // senderUserIdからアバター色を決定的に生成
  Color _avatarColor(String userId) {
    final colors = [
      Colors.blue,
      Colors.teal,
      Colors.orange,
      Colors.indigo,
      Colors.pink,
      Colors.cyan,
      Colors.deepPurple,
      Colors.amber,
      Colors.brown,
      Colors.green,
    ];
    return colors[userId.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final displayName = senderName ??
        AiService.getParticipantName(message.senderUserId) ??
        '参加者';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              backgroundColor: _avatarColor(message.senderUserId),
              radius: 16,
              child: Text(
                displayName.isNotEmpty ? displayName.substring(0, 1) : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFF4CAF50) : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text ?? '',
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
