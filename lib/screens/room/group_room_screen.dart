// グループルーム画面（正解者/不正解者ルーム）
// 人間 + AI が参加
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../widgets/chat_message_widget.dart';
import '../../widgets/chat_input_widget.dart';

class GroupRoomScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final bool isCorrect;

  const GroupRoomScreen({
    super.key,
    required this.sessionId,
    required this.isCorrect,
  });

  @override
  ConsumerState<GroupRoomScreen> createState() => _GroupRoomScreenState();
}

class _GroupRoomScreenState extends ConsumerState<GroupRoomScreen> {
  Timer? _timer;
  Timer? _aiMessageTimer;
  int _remainingSeconds = AppConfig.groupRoomSeconds;
  List<Message> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final FirebaseRoomService _firebaseService = FirebaseRoomService();
  StreamSubscription<List<Message>>? _messageSubscription;
  String get _roomId => 'group_${widget.sessionId}_${widget.isCorrect ? "correct" : "incorrect"}';

  @override
  void initState() {
    super.initState();
    _joinRoom();
    _startTimer();
    _startAIMessages();
  }

  void _joinRoom() {
    final authState = ref.read(authProvider);
    if (authState.user == null) return;

    // Firebaseルームに参加
    _firebaseService.joinRoom(_roomId, authState.user!.userId, authState.user!.displayName);

    // メッセージをリアルタイムで監視
    _messageSubscription = _firebaseService.watchMessages(_roomId).listen((messages) {
      if (mounted) {
        setState(() {
          _messages = messages;
        });
        _scrollToBottom();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _aiMessageTimer?.cancel();
    _messageSubscription?.cancel();
    _scrollController.dispose();
    final authState = ref.read(authProvider);
    if (authState.user != null) {
      _firebaseService.leaveRoom(_roomId, authState.user!.userId);
    }
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
        _startMatching();
      }
    });
  }

  void _startAIMessages() {
    _scheduleNextAIMessage();
  }

  void _scheduleNextAIMessage() {
    final delay = 5 + (DateTime.now().millisecondsSinceEpoch % 10);
    _aiMessageTimer = Timer(Duration(seconds: delay), () async {
      if (mounted) {
        final roomType = widget.isCorrect ? 'correct' : 'incorrect';
        final quiz = ref.read(sessionProvider).currentQuiz;
        final aiMessage = await AiService.generateAIMessageAsync(
          _roomId,
          roomType,
          isCorrectUser: widget.isCorrect,
          chatHistory: _messages,
          quiz: quiz,
        );
        if (mounted) {
          // AIメッセージをFirebaseに送信
          await _firebaseService.sendMessage(
            _roomId,
            aiMessage.senderUserId,
            aiMessage.text ?? '',
            displayName: AiService.getParticipantName(aiMessage.senderUserId),
          );
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

  Future<void> _startMatching() async {
    final authState = ref.read(authProvider);
    if (authState.user == null) return;

    final match = await ref.read(sessionProvider.notifier).findMatch(
      widget.isCorrect,
    );

    if (mounted) {
      Navigator.pushReplacementNamed(
        context,
        '/one-on-one',
        arguments: {
          'sessionId': widget.sessionId,
          'isCorrect': widget.isCorrect,
          'partnerId': match?.userId,
          'isAIPartner': match?.isAI ?? true,
        },
      );
    }
  }

  void _sendMessage(String text) async {
    final authState = ref.read(authProvider);
    if (authState.user == null) return;

    // Firebaseにメッセージを送信
    await _firebaseService.sendMessage(
      _roomId,
      authState.user!.userId,
      text,
      displayName: authState.user!.displayName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: widget.isCorrect ? const Color(0xFF4CAF50) : Colors.orange,
        title: Text(
          widget.isCorrect ? '正解者ルーム' : '不正解者ルーム',
          style: const TextStyle(color: Colors.white),
        ),
        automaticallyImplyLeading: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
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
            color: widget.isCorrect ? Colors.green[50] : Colors.orange[50],
            child: Text(
              widget.isCorrect
                  ? '正解おめでとう！同じ正解者とチャットしよう'
                  : '次は頑張ろう！一緒に学び合おう',
              style: TextStyle(
                color: widget.isCorrect ? Colors.green[700] : Colors.orange[700],
              ),
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
