// 共通ルーム画面
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../widgets/chat_message_widget.dart';
import '../../widgets/chat_input_widget.dart';

class CommonRoomScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const CommonRoomScreen({
    super.key,
    required this.sessionId,
  });

  @override
  ConsumerState<CommonRoomScreen> createState() => _CommonRoomScreenState();
}

class _CommonRoomScreenState extends ConsumerState<CommonRoomScreen> {
  Timer? _timer;
  Timer? _aiMessageTimer;
  int _remainingSeconds = AppConfig.commonRoomSeconds;
  final List<Message> _messages = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _startTimer();
    _startAIMessages();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _aiMessageTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer?.cancel();
        _finishSession();
      }
    });
  }

  void _startAIMessages() {
    _scheduleNextAIMessage();
  }

  void _scheduleNextAIMessage() {
    final delay = 6 + (DateTime.now().millisecondsSinceEpoch % 8);
    _aiMessageTimer = Timer(Duration(seconds: delay), () async {
      if (mounted) {
        final quiz = ref.read(sessionProvider).currentQuiz;
        final aiMessage = await AiService.generateAIMessageAsync(
          'common_${widget.sessionId}',
          'common',
          chatHistory: _messages,
          quiz: quiz,
        );
        if (mounted) {
          setState(() {
            _messages.add(aiMessage);
          });
          _scrollToBottom();
          _scheduleNextAIMessage();
        }
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _finishSession() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home',
      (route) => false,
    );
  }

  void _sendMessage(String text) {
    final authState = ref.read(authProvider);
    if (authState.user == null) return;

    final message = Message(
      messageId: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      roomId: 'common_${widget.sessionId}',
      senderUserId: authState.user!.userId,
      type: MessageType.text,
      text: text,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(message);
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.purple,
        title: const Text(
          'みんなの部屋',
          style: TextStyle(color: Colors.white),
        ),
        automaticallyImplyLeading: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer, color: Colors.white, size: 18),
                const SizedBox(width: 4),
                Text(
                  '$_remainingSeconds秒',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // インフォバー
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.purple[50],
            child: Text(
              '全員集合！今回のクイズについて話し合おう',
              style: TextStyle(color: Colors.purple[700]),
              textAlign: TextAlign.center,
            ),
          ),

          // チャットエリア
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isMe = message.senderUserId == authState.user?.userId;
                final senderName = isMe
                    ? authState.user?.displayName
                    : AiService.getParticipantName(message.senderUserId);
                return ChatMessageWidget(
                  message: message,
                  isMe: isMe,
                  senderName: senderName,
                );
              },
            ),
          ),

          // 入力エリア
          ChatInputWidget(onSend: _sendMessage),
        ],
      ),
    );
  }
}
