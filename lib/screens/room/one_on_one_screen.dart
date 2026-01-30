// 1対1ルーム画面
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../widgets/chat_message_widget.dart';
import '../../widgets/chat_input_widget.dart';

class OneOnOneScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final bool isCorrect;
  final String? partnerId;
  final bool isAIPartner;

  const OneOnOneScreen({
    super.key,
    required this.sessionId,
    required this.isCorrect,
    this.partnerId,
    this.isAIPartner = false,
  });

  @override
  ConsumerState<OneOnOneScreen> createState() => _OneOnOneScreenState();
}

class _OneOnOneScreenState extends ConsumerState<OneOnOneScreen> {
  Timer? _timer;
  Timer? _aiMessageTimer;
  int _remainingSeconds = AppConfig.oneOnOneSeconds;
  final List<Message> _messages = [];
  final ScrollController _scrollController = ScrollController();
  late AppUser _partner;

  @override
  void initState() {
    super.initState();
    _initPartner();
    _startTimer();
    if (widget.isAIPartner) {
      _startAIMessages();
    }
  }

  void _initPartner() {
    if (widget.isAIPartner || widget.partnerId == null) {
      _partner = AiService.createAIPartner(!widget.isCorrect);
    } else {
      // 実際のパートナー情報を取得（デモでは仮のデータ）
      _partner = AppUser(
        userId: widget.partnerId!,
        displayName: 'パートナー',
        createdAt: DateTime.now(),
      );
    }
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
        _navigateToCommonRoom();
      }
    });
  }

  void _startAIMessages() {
    _scheduleNextAIMessage();
  }

  void _scheduleNextAIMessage() {
    final delay = 8 + (DateTime.now().millisecondsSinceEpoch % 12);
    _aiMessageTimer = Timer(Duration(seconds: delay), () async {
      if (mounted) {
        final quiz = ref.read(sessionProvider).currentQuiz;
        final aiMessage = await AiService.generateAIMessageAsync(
          'oneOnOne_${widget.sessionId}',
          'one_on_one',
          isCorrectUser: !widget.isCorrect,
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

  void _navigateToCommonRoom() {
    Navigator.pushReplacementNamed(
      context,
      '/common-room',
      arguments: {
        'sessionId': widget.sessionId,
      },
    );
  }

  void _sendMessage(String text) {
    final authState = ref.read(authProvider);
    if (authState.user == null) return;

    final message = Message(
      messageId: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      roomId: 'oneOnOne_${widget.sessionId}',
      senderUserId: authState.user!.userId,
      type: MessageType.text,
      text: text,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(message);
    });
    _scrollToBottom();

    // AIパートナーの場合、返信をシミュレート
    if (widget.isAIPartner) {
      _scheduleAIReply();
    }
  }

  void _scheduleAIReply() {
    Timer(const Duration(seconds: 1), () async {
      if (mounted) {
        final quiz = ref.read(sessionProvider).currentQuiz;
        final aiMessage = await AiService.generateAIMessageAsync(
          'oneOnOne_${widget.sessionId}',
          'one_on_one',
          isCorrectUser: !widget.isCorrect,
          chatHistory: _messages,
          quiz: quiz,
        );
        if (mounted) {
          setState(() {
            _messages.add(aiMessage);
          });
          _scrollToBottom();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              radius: 16,
              child: Text(
                _partner.displayName.isNotEmpty
                    ? _partner.displayName.substring(0, 1)
                    : '?',
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _partner.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    widget.isAIPartner ? 'AIパートナー' : (!widget.isCorrect ? '正解者' : '不正解者'),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
            color: Colors.blue[50],
            child: Text(
              widget.isCorrect
                  ? '${_partner.displayName}さんに教えてあげよう！'
                  : '${_partner.displayName}さんに質問してみよう！',
              style: TextStyle(color: Colors.blue[700]),
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
                return ChatMessageWidget(
                  message: message,
                  isMe: isMe,
                  senderName: isMe ? authState.user?.displayName : _partner.displayName,
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
