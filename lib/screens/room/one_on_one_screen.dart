// 1対1ルーム画面
// 人間同士のみ（AIなし）
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
  final bool isAIPartner; // 後方互換性のために残すが、常にfalse扱い

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
  int _remainingSeconds = AppConfig.oneOnOneSeconds;
  List<Message> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final FirebaseRoomService _firebaseService = FirebaseRoomService();
  StreamSubscription<List<Message>>? _messageSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _memberSubscription;
  String? _partnerDisplayName;
  String get _roomId => 'oneOnOne_${widget.sessionId}_${widget.partnerId ?? "waiting"}';

  @override
  void initState() {
    super.initState();
    _joinRoom();
    _startTimer();
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

    // メンバーを監視してパートナー名を取得
    _memberSubscription = _firebaseService.watchMembers(_roomId).listen((members) {
      if (mounted) {
        final partner = members.where((m) => m['userId'] != authState.user!.userId).toList();
        if (partner.isNotEmpty) {
          setState(() {
            _partnerDisplayName = partner.first['displayName'] as String?;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _messageSubscription?.cancel();
    _memberSubscription?.cancel();
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
        _navigateToCommonRoom();
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
    final partnerName = _partnerDisplayName ?? 'パートナー';

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
                partnerName.isNotEmpty ? partnerName.substring(0, 1) : '?',
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
                    partnerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    !widget.isCorrect ? '正解者' : '不正解者',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
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
            color: Colors.blue[50],
            child: Text(
              widget.isCorrect
                  ? '$partnerNameさんに教えてあげよう！'
                  : '$partnerNameさんに質問してみよう！',
              style: TextStyle(color: Colors.blue[700]),
              textAlign: TextAlign.center,
            ),
          ),

          // チャットエリア
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      'パートナーを待っています...\nメッセージを送って会話を始めましょう！',
                      style: TextStyle(color: Colors.grey[500]),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMe = message.senderUserId == authState.user?.userId;
                      return ChatMessageWidget(
                        message: message,
                        isMe: isMe,
                        senderName: isMe ? authState.user?.displayName : partnerName,
                      );
                    },
                  ),
          ),

          // 完了ボタン
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _goToHome,
                icon: const Icon(Icons.check_circle, color: Colors.white),
                label: const Text(
                  '完了',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

          // 入力エリア
          ChatInputWidget(onSend: _sendMessage),
        ],
      ),
    );
  }

  void _goToHome() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home',
      (route) => false,
    );
  }
}
