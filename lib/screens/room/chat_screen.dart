// チャット画面（PUBLIC共同チャット + プライベートAI解説）
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

  // 退出ボタン・AI関連（10秒後に表示）
  bool _showExtras = false;
  Timer? _extrasTimer;

  // LM Studio
  bool _isLmStudioAvailable = false;

  // プライベートAIメッセージ
  final List<Message> _privateMessages = [];
  bool _isReplyingToAi = false;
  bool _isAiThinking = false;
  List<Map<String, String>> _aiConversationHistory = [];
  Question? _currentAiQuestion;

  static const String _aiSenderId = 'ai_explainer';

  // 正解率60%未満で再試験
  bool get _needsRetest =>
      widget.totalQuestions > 0 &&
      widget.correctCount / widget.totalQuestions < 0.6;

  @override
  void initState() {
    super.initState();
    _watchMessages();
    _startTimer();
    _startExtrasTimer();
    _checkLmStudio();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _scrollController.dispose();
    _timer?.cancel();
    _extrasTimer?.cancel();
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

  void _startExtrasTimer() {
    _extrasTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) setState(() => _showExtras = true);
    });
  }

  Future<void> _checkLmStudio() async {
    final available = await AiService.isLmStudioAvailable();
    if (mounted) setState(() => _isLmStudioAvailable = available);
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

  void _exit() {
    _onChatEnd();
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

    if (_isReplyingToAi) {
      _sendPrivateReplyToAi(text.trim());
      return;
    }

    final authState = ref.read(authProvider);
    if (authState.user == null) return;

    _roomService.sendMessage(
      widget.sessionId,
      authState.user!.userId,
      text.trim(),
      displayName: authState.user!.displayName,
    );
  }

  // AI問題選択ダイアログ
  void _showQuestionSelector() {
    if (widget.questions.isEmpty) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '解説してほしい問題を選択',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.4,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.questions.length,
                  itemBuilder: (_, index) {
                    final q = Question.fromMap(widget.questions[index]);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.deepPurple,
                        radius: 16,
                        child: Text(
                          '${q.questionNo}',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                      title: Text(
                        q.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _requestAiExplanation(q);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // AI解説をリクエスト
  Future<void> _requestAiExplanation(Question question) async {
    print('[Chat] Requesting AI explanation for Q${question.questionNo}: ${question.text}');
    print('[Chat] Choices: ${question.choices}, Answers: ${question.answers}');
    setState(() {
      _isAiThinking = true;
      _currentAiQuestion = question;
      _aiConversationHistory = [];
    });
    _scrollToBottom();

    final explanation = await AiService.explainQuestion(question, []);

    if (!mounted) return;

    print('[Chat] AI explanation result: ${explanation != null ? "OK (${explanation.length} chars)" : "NULL"}');
    final text = explanation ?? 'すみません、解説を生成できませんでした。もう一度お試しください。';

    final aiMessage = Message(
      messageId: 'ai_${DateTime.now().millisecondsSinceEpoch}',
      roomId: widget.sessionId,
      senderUserId: _aiSenderId,
      type: MessageType.text,
      text: 'Q${question.questionNo}の解説:\n\n$text',
      createdAt: DateTime.now(),
    );

    _aiConversationHistory.add({'role': 'assistant', 'content': text});

    setState(() {
      _privateMessages.add(aiMessage);
      _isAiThinking = false;
      _isReplyingToAi = true;
    });
    _scrollToBottom();
  }

  // AIへのプライベートリプライ
  Future<void> _sendPrivateReplyToAi(String text) async {
    if (_currentAiQuestion == null) return;

    final authState = ref.read(authProvider);
    final userId = authState.user?.userId ?? 'me';

    // ユーザーのプライベートメッセージを追加
    final userMsg = Message(
      messageId: 'priv_${DateTime.now().millisecondsSinceEpoch}',
      roomId: widget.sessionId,
      senderUserId: userId,
      type: MessageType.text,
      text: text,
      createdAt: DateTime.now(),
    );

    _aiConversationHistory.add({'role': 'user', 'content': text});

    setState(() {
      _privateMessages.add(userMsg);
      _isAiThinking = true;
    });
    _scrollToBottom();

    // AIの返答を取得
    final response = await AiService.explainQuestion(
      _currentAiQuestion!,
      _aiConversationHistory,
    );

    if (!mounted) return;

    final aiText = response ?? 'すみません、回答を生成できませんでした。';

    final aiMsg = Message(
      messageId: 'ai_${DateTime.now().millisecondsSinceEpoch}',
      roomId: widget.sessionId,
      senderUserId: _aiSenderId,
      type: MessageType.text,
      text: aiText,
      createdAt: DateTime.now(),
    );

    _aiConversationHistory.add({'role': 'assistant', 'content': aiText});

    setState(() {
      _privateMessages.add(aiMsg);
      _isAiThinking = false;
    });
    _scrollToBottom();
  }

  void _exitAiMode() {
    setState(() {
      _isReplyingToAi = false;
      _currentAiQuestion = null;
      _aiConversationHistory = [];
    });
  }

  // 全メッセージ（公開 + プライベート）を時系列で結合
  List<_ChatItem> _buildChatItems() {
    final items = <_ChatItem>[];

    for (final msg in _messages) {
      items.add(_ChatItem(message: msg, isPrivate: false));
    }
    for (final msg in _privateMessages) {
      items.add(_ChatItem(message: msg, isPrivate: true));
    }

    items.sort((a, b) => a.message.createdAt.compareTo(b.message.createdAt));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final chatItems = _buildChatItems();

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
      body: Stack(
        children: [
          Column(
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

              // AIリプライモード表示
              if (_isReplyingToAi)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: Colors.deepPurple[50],
                  child: Row(
                    children: [
                      const Icon(Icons.smart_toy, color: Colors.deepPurple, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'AIに質問中 (Q${_currentAiQuestion?.questionNo ?? ""})',
                          style: const TextStyle(color: Colors.deepPurple, fontSize: 13),
                        ),
                      ),
                      GestureDetector(
                        onTap: _exitAiMode,
                        child: const Icon(Icons.close, color: Colors.deepPurple, size: 20),
                      ),
                    ],
                  ),
                ),

              // メッセージ一覧
              Expanded(
                child: chatItems.isEmpty && !_isAiThinking
                    ? const Center(child: Text('メッセージがありません'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: chatItems.length + (_isAiThinking ? 1 : 0),
                        itemBuilder: (context, index) {
                          // AI考え中インジケーター
                          if (_isAiThinking && index == chatItems.length) {
                            return _buildAiThinkingBubble();
                          }

                          final item = chatItems[index];
                          final msg = item.message;
                          final isAiMsg = msg.senderUserId == _aiSenderId;
                          final isMyPrivateReply = item.isPrivate && !isAiMsg;
                          final isMe = msg.senderUserId == authState.user?.userId;

                          if (isAiMsg) {
                            return _buildAiMessageBubble(msg);
                          }

                          if (isMyPrivateReply) {
                            return _buildPrivateReplyBubble(msg);
                          }

                          return ChatMessageWidget(
                            message: msg,
                            isMe: isMe,
                          );
                        },
                      ),
              ),

              // 入力欄
              ChatInputWidget(
                onSend: _sendMessage,
                hintText: _isReplyingToAi ? 'AIに質問...' : null,
              ),
            ],
          ),

          // 右下の退出ボタン + ロボットアイコン
          if (_showExtras)
            Positioned(
              right: 16,
              bottom: 90,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ロボットアイコン（LM Studio利用可能時のみ）
                  if (_isLmStudioAvailable)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FloatingActionButton.small(
                        heroTag: 'ai_btn',
                        backgroundColor: Colors.deepPurple,
                        onPressed: _showQuestionSelector,
                        child: const Icon(Icons.smart_toy, color: Colors.white, size: 22),
                      ),
                    ),
                  // 退出ボタン
                  FloatingActionButton.small(
                    heroTag: 'exit_btn',
                    backgroundColor: Colors.grey[600],
                    onPressed: _exit,
                    child: const Icon(Icons.exit_to_app, color: Colors.white, size: 22),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAiMessageBubble(Message msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            backgroundColor: Colors.deepPurple,
            radius: 16,
            child: Icon(Icons.smart_toy, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI解説',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.deepPurple[400],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple[50],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.text ?? '',
                        style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'あなただけに表示されています',
                        style: TextStyle(fontSize: 10, color: Colors.deepPurple[300]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivateReplyBubble(Message msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.deepPurple[100],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                msg.text ?? '',
                style: const TextStyle(color: Colors.black87, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildAiThinkingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            backgroundColor: Colors.deepPurple,
            radius: 16,
            child: Icon(Icons.smart_toy, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.deepPurple[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.deepPurple[300],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '考え中...',
                  style: TextStyle(fontSize: 13, color: Colors.deepPurple[400]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// チャットアイテム（公開/プライベート区別）
class _ChatItem {
  final Message message;
  final bool isPrivate;

  _ChatItem({required this.message, required this.isPrivate});
}
