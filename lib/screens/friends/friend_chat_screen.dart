// フレンド1対1チャット画面
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/firebase_room_service.dart';
import '../../services/friend_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/premium_components.dart';
import '../../widgets/chat_message_widget.dart';
import '../../widgets/chat_input_widget.dart';

class FriendChatScreen extends ConsumerStatefulWidget {
  final String friendUserId;
  final String friendDisplayName;

  const FriendChatScreen({
    super.key,
    required this.friendUserId,
    required this.friendDisplayName,
  });

  @override
  ConsumerState<FriendChatScreen> createState() => _FriendChatScreenState();
}

class _FriendChatScreenState extends ConsumerState<FriendChatScreen> {
  final FirebaseRoomService _roomService = FirebaseRoomService();
  final ScrollController _scrollController = ScrollController();

  late final String _roomId;
  late final String _myUserId;
  late final String _myDisplayName;

  List<Message> _messages = [];
  StreamSubscription? _messagesSub;

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authProvider);
    _myUserId = authState.user?.userId ?? '';
    _myDisplayName = authState.user?.displayName ?? 'ゲスト';
    _roomId = FriendService.friendRoomId(_myUserId, widget.friendUserId);
    _watchMessages();
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _watchMessages() {
    _messagesSub = _roomService.watchMessages(_roomId).listen((messages) {
      if (mounted) {
        setState(() => _messages = messages);
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    await _roomService.sendMessage(
      _roomId,
      _myUserId,
      text.trim(),
      displayName: _myDisplayName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StarryBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _messages.isEmpty
                    ? _buildEmptyChat()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          return ChatMessageWidget(
                            message: msg,
                            isMe: msg.senderUserId == _myUserId,
                            senderName:
                                msg.senderUserId == _myUserId
                                    ? _myDisplayName
                                    : widget.friendDisplayName,
                          );
                        },
                      ),
              ),
              // 入力欄
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.navBg,
                  border: Border(
                    top: BorderSide(color: AppColors.lineGold, width: 0.5),
                  ),
                ),
                child: ChatInputWidget(
                  onSend: _sendMessage,
                  hintText: 'メッセージを入力...',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final initial = widget.friendDisplayName.isNotEmpty
        ? widget.friendDisplayName.substring(0, 1)
        : '?';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.lineGold, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          // フレンドアバター
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceCard2,
              border: Border.all(color: AppColors.goldPrimary, width: 2),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.friendDisplayName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 56,
            color: AppColors.textPrimary.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 12),
          Text(
            'メッセージを送ってみよう！',
            style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
