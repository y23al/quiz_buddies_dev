// チャットメッセージウィジェット
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/design_tokens.dart';

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
    // 表示名: パラメータ → Message.displayName → フォールバック
    final displayName = senderName ??
        (message.displayName != null && message.displayName!.isNotEmpty
            ? message.displayName!
            : null) ??
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
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
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
                    color: isMe
                        ? AppColors.goldPrimary
                        : AppColors.surfaceCard,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    border: isMe
                        ? null
                        : Border.all(color: AppColors.lineGold, width: 0.5),
                  ),
                  child: Text(
                    message.text ?? '',
                    style: TextStyle(
                      color: isMe ? AppColors.textOnCard : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.createdAt),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
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
