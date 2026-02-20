// チャット画面（PUBLIC共同チャット）
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../widgets/widgets.dart';
import '../../models/models.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final int correctCount;
  final int totalQuestions;
  final List<Map<String, dynamic>> questions;
  final String subjectName;
  final int lectureNo;

  const ChatScreen({
    super.key,
    required this.sessionId,
    this.correctCount = 0,
    this.totalQuestions = 0,
    this.questions = const [],
    this.subjectName = '',
    this.lectureNo = 0,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final FirebaseRoomService _roomService = FirebaseRoomService();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _messageSubscription;
  List<Message> _messages = [];
  int _remainingSeconds = AppConfig.commonRoomSeconds;
  Timer? _timer;

  bool get _needsRetest => widget.correctCount <= AppConfig.retestThreshold;

  @override
  void initState() {
    super.initState();
    _watchMessages();
    _startTimer();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _scrollController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _watchMessages() {
    _messageSubscription = _roomService
        .watchMessages(widget.sessionId)
        .listen((messages) {
      if (mounted) {
        setState(() => _messages = messages);
        _scrollToBottom();
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _remainingSeconds--);
        if (_remainingSeconds <= 0) {
          timer.cancel();
          _onChatEnd();
        }
      }
    });
  }

  void _onChatEnd() {
    if (!mounted) return;
    if (_needsRetest) {
      Navigator.pushReplacementNamed(context, '/retest', arguments: {
        'sessionId': widget.sessionId,
        'questions': widget.questions,
        'subjectName': widget.subjectName,
        'lectureNo': widget.lectureNo,
      });
    } else {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    final authState = ref.read(authProvider);
    if (authState.user == null) return;

    _roomService.sendMessage(
      widget.sessionId,
      authState.user!.userId,
      text.trim(),
      displayName: authState.user!.displayName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.purple,
        title: const Text('みんなのチャット', style: TextStyle(color: Colors.white)),
        automaticallyImplyLeading: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$_remainingSeconds秒',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 再試験通知バナー
          if (_needsRetest)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.red[50],
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'チャット終了後に再試験があります',
                    style: TextStyle(color: Colors.red[700], fontSize: 13),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: Text('メッセージがありません'))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return ChatMessageWidget(
                        message: msg,
                        isMe: msg.senderUserId == authState.user?.userId,
                      );
                    },
                  ),
          ),
          ChatInputWidget(
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}
