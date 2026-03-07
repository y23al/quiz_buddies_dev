// チャット画面（PUBLIC共同チャット + プライベートAI解説 + 参加者/フレンド申請）
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../widgets/widgets.dart';
import '../../models/models.dart';
import '../../theme/design_tokens.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final int correctCount;
  final int totalQuestions;
  final List<Map<String, dynamic>> questions;
  final Map<int, String?> userAnswers;
  final String subjectName;
  final int lectureNo;

  const ChatScreen({
    super.key,
    required this.sessionId,
    this.correctCount = 0,
    this.totalQuestions = 0,
    this.questions = const [],
    this.userAnswers = const {},
    this.subjectName = '',
    this.lectureNo = 0,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final FirebaseRoomService _roomService = FirebaseRoomService();
  final FirebaseSessionService _sessionService = FirebaseSessionService();
  final FriendService _friendService = FriendService();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _messageSubscription;
  StreamSubscription? _participantSubscription;
  List<Message> _messages = [];
  int _remainingSeconds = AppConfig.commonRoomSeconds;
  Timer? _timer;

  // 退出ボタン・AI関連（10秒後に表示）
  bool _showExtras = false;
  Timer? _extrasTimer;

  // プライベートAIメッセージ
  final List<Message> _privateMessages = [];
  bool _isReplyingToAi = false;
  bool _isAiThinking = false;
  List<Map<String, String>> _aiConversationHistory = [];
  Question? _currentAiQuestion;

  static const String _aiSenderId = 'ai_explainer';

  // 参加者一覧 + フレンド申請
  List<Map<String, dynamic>> _participants = [];
  final Map<String, String> _friendStates = {};
  bool _showParticipants = false;

  // 問題一覧パネル
  bool _showQuestions = false;
  Set<int> _wrongQuestionIndices = {};

  // 正解率60%未満で再試験
  bool get _needsRetest =>
      widget.totalQuestions > 0 &&
      widget.correctCount / widget.totalQuestions < 0.6;

  @override
  void initState() {
    super.initState();
    _watchMessages();
    _watchParticipants();
    _startTimer();
    _startExtrasTimer();
    _buildWrongQuestions();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _participantSubscription?.cancel();
    _scrollController.dispose();
    _timer?.cancel();
    _extrasTimer?.cancel();
    super.dispose();
  }

  void _buildWrongQuestions() {
    final wrongs = <int>{};
    for (int i = 0; i < widget.questions.length; i++) {
      final q = Question.fromMap(widget.questions[i]);
      final userAnswer = widget.userAnswers[i];
      if (userAnswer == null || !q.isCorrect(userAnswer)) {
        wrongs.add(i);
      }
    }
    _wrongQuestionIndices = wrongs;
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

  void _watchParticipants() {
    _participantSubscription = _sessionService
        .watchParticipants(widget.sessionId)
        .listen((participants) {
      if (mounted) {
        setState(() => _participants = participants);
        _checkFriendStates(participants);
      }
    });
  }

  Future<void> _checkFriendStates(List<Map<String, dynamic>> participants) async {
    final myUserId = ref.read(authProvider).user?.userId;
    if (myUserId == null) return;
    for (final p in participants) {
      final otherId = p['odId'] as String?;
      if (otherId == null || otherId == myUserId) continue;
      if (_friendStates.containsKey(otherId)) continue;
      if (await _friendService.areFriends(myUserId, otherId)) {
        _friendStates[otherId] = 'friend';
      } else if (await _friendService.hasExistingRequest(myUserId, otherId)) {
        _friendStates[otherId] = 'sent';
      } else {
        _friendStates[otherId] = 'send';
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _sendFriendRequest(String otherId, String otherName) async {
    debugPrint('[FriendRequest] _sendFriendRequest called: otherId=$otherId, otherName=$otherName');
    final authState = ref.read(authProvider);
    debugPrint('[FriendRequest] user=${authState.user?.userId}, isGuest=${authState.user?.isGuest}');

    if (authState.user == null || authState.user!.isGuest) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('ゲストユーザーはフレンド申請できません。ログインしてください。'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }
    try {
      debugPrint('[FriendRequest] calling friendService.sendFriendRequest...');
      await _friendService.sendFriendRequest(
        fromUserId: authState.user!.userId,
        toUserId: otherId,
        fromDisplayName: authState.user!.displayName,
        toDisplayName: otherName,
        sessionId: widget.sessionId,
      );
      debugPrint('[FriendRequest] sendFriendRequest succeeded');
      if (mounted) {
        setState(() => _friendStates[otherId] = 'sent');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$otherName にフレンド申請を送りました！'),
            backgroundColor: AppColors.goldDeep,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      debugPrint('[FriendRequest] ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('フレンド申請に失敗しました: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
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
  Future<void> _showQuestionSelector() async {
    if (widget.questions.isEmpty) return;

    // LM Studio の接続をその場で確認
    final available = await AiService.isLmStudioAvailable();
    if (!mounted) return;
    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('LM Studio が起動していません。\nAI解説を使うには localhost:1234 でLM Studioを起動してください。'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '解説してほしい問題を選択',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Divider(height: 1, color: AppColors.lineGold.withValues(alpha: 0.3)),
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
                        backgroundColor: AppColors.accentBlue,
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
                        style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
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
    setState(() {
      _isAiThinking = true;
      _currentAiQuestion = question;
      _aiConversationHistory = [];
    });
    _scrollToBottom();

    final explanation = await AiService.explainQuestion(question, []);

    if (!mounted) return;

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
    final myUserId = authState.user?.userId;
    final isGuest = authState.user?.isGuest ?? true;

    // Premium header (戻るボタンなし)
    final header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.lineGold, width: 0.5)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'みんなのチャット',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ),
          // 問題一覧ボタン
          if (widget.questions.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() {
                _showQuestions = !_showQuestions;
                if (_showQuestions) _showParticipants = false;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _showQuestions ? AppColors.goldPrimary.withValues(alpha: 0.15) : AppColors.surfaceCard2,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _showQuestions ? AppColors.goldPrimary : AppColors.lineGold, width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.quiz, color: AppColors.goldPrimary, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.questions.length}問',
                      style: const TextStyle(color: AppColors.goldPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          if (widget.questions.isNotEmpty)
            const SizedBox(width: 8),
          // 参加者ボタン
          GestureDetector(
            onTap: () => setState(() {
              _showParticipants = !_showParticipants;
              if (_showParticipants) _showQuestions = false;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _showParticipants ? AppColors.goldPrimary.withValues(alpha: 0.15) : AppColors.surfaceCard2,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _showParticipants ? AppColors.goldPrimary : AppColors.lineGold, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people, color: AppColors.goldPrimary, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${_participants.length}',
                    style: const TextStyle(color: AppColors.goldPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Timer badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard2,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.lineGold, width: 0.5),
            ),
            child: Text(
              '$_remainingSeconds秒',
              style: const TextStyle(
                color: AppColors.goldPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      body: StarryBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  header,

                  // 再試験通知バナー
                  if (_needsRetest)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: AppColors.danger.withValues(alpha: 0.15),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: AppColors.danger, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'チャット終了後に再試験があります',
                            style: TextStyle(color: AppColors.danger, fontSize: 13),
                          ),
                        ],
                      ),
                    ),

                  // 問題一覧パネル（トグル）
                  if (_showQuestions)
                    _buildQuestionsPanel(),

                  // AIリプライモード表示
                  if (_isReplyingToAi)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      color: AppColors.accentBlue.withValues(alpha: 0.15),
                      child: Row(
                        children: [
                          const Icon(Icons.smart_toy, color: AppColors.accentBlue, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'AIに質問中 (Q${_currentAiQuestion?.questionNo ?? ""})',
                              style: const TextStyle(color: AppColors.accentBlue, fontSize: 13),
                            ),
                          ),
                          GestureDetector(
                            onTap: _exitAiMode,
                            child: const Icon(Icons.close, color: AppColors.accentBlue, size: 20),
                          ),
                        ],
                      ),
                    ),

                  // 参加者パネル（トグル）
                  if (_showParticipants)
                    _buildParticipantsPanel(myUserId, isGuest),

                  // メッセージ一覧
                  Expanded(
                    child: chatItems.isEmpty && !_isAiThinking
                        ? Center(
                            child: Text(
                              'メッセージがありません',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: chatItems.length + (_isAiThinking ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (_isAiThinking && index == chatItems.length) {
                                return _buildAiThinkingBubble();
                              }

                              final item = chatItems[index];
                              final msg = item.message;
                              final isAiMsg = msg.senderUserId == _aiSenderId;
                              final isMyPrivateReply = item.isPrivate && !isAiMsg;
                              final isMe = msg.senderUserId == myUserId;

                              if (isAiMsg) {
                                return _buildAiMessageBubble(msg);
                              }

                              if (isMyPrivateReply) {
                                return _buildPrivateReplyBubble(msg);
                              }

                              // 送信者のアバターURLを参加者データから取得
                              final senderAvatar = _participants
                                  .where((p) => p['odId'] == msg.senderUserId)
                                  .map((p) => p['avatarUrl'] as String?)
                                  .firstOrNull;

                              return ChatMessageWidget(
                                message: msg,
                                isMe: isMe,
                                avatarUrl: isMe
                                    ? ref.read(authProvider).user?.avatarUrl
                                    : senderAvatar,
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
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: FloatingActionButton.small(
                          heroTag: 'ai_btn',
                          backgroundColor: AppColors.accentBlue,
                          onPressed: _showQuestionSelector,
                          child: const Icon(Icons.smart_toy, color: Colors.white, size: 22),
                        ),
                      ),
                      FloatingActionButton.small(
                        heroTag: 'exit_btn',
                        backgroundColor: AppColors.surfaceCard2,
                        onPressed: _exit,
                        child: const Icon(Icons.exit_to_app, color: AppColors.textPrimary, size: 22),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 問題一覧パネル
  Widget _buildQuestionsPanel() {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.4,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard2.withValues(alpha: 0.5),
        border: const Border(
          bottom: BorderSide(color: AppColors.lineGold, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                const Text(
                  '問題一覧',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.goldPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                if (_wrongQuestionIndices.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '不正解 ${_wrongQuestionIndices.length}問',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.danger,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: widget.questions.length,
              itemBuilder: (context, index) {
                final q = Question.fromMap(widget.questions[index]);
                final isWrong = _wrongQuestionIndices.contains(index);
                final userAnswer = widget.userAnswers[index];

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isWrong
                        ? AppColors.danger.withValues(alpha: 0.08)
                        : AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isWrong
                          ? AppColors.danger.withValues(alpha: 0.4)
                          : AppColors.lineGold.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: isWrong ? AppColors.danger : AppColors.goldPrimary,
                            child: Text(
                              '${q.questionNo}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isWrong ? Icons.close : Icons.check_circle,
                            color: isWrong ? AppColors.danger : AppColors.goldPrimary,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isWrong ? '不正解' : '正解',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isWrong ? AppColors.danger : AppColors.goldPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        q.text,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: isWrong ? AppColors.danger : AppColors.textPrimary,
                          fontWeight: isWrong ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '正解: ${q.answers.join(', ')}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.goldPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isWrong && userAnswer != null)
                        Text(
                          'あなたの回答: $userAnswer',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.danger,
                          ),
                        ),
                      if (isWrong && userAnswer == null)
                        const Text(
                          '時間切れ',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.danger,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 参加者パネル
  Widget _buildParticipantsPanel(String? myUserId, bool isGuest) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard2.withValues(alpha: 0.5),
        border: const Border(
          bottom: BorderSide(color: AppColors.lineGold, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '参加者',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.goldPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ..._participants.map((p) {
            final otherId = p['odId'] as String?;
            final name = p['displayName'] as String? ?? '???';
            final avatarUrl = p['avatarUrl'] as String?;
            final isMe = otherId == myUserId;
            final state = _friendStates[otherId] ?? 'send';

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  UserAvatarWidget(
                    avatarUrl: isMe ? ref.read(authProvider).user?.avatarUrl : avatarUrl,
                    displayName: name,
                    size: 28,
                    borderColor: isMe ? AppColors.goldPrimary : null,
                    borderWidth: 1.5,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isMe ? '$name (あなた)' : name,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  // フレンド申請ボタン（自分以外・ゲスト以外）
                  if (!isMe && !isGuest && otherId != null)
                    _buildFriendChip(state, otherId, name),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFriendChip(String state, String otherId, String name) {
    switch (state) {
      case 'friend':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.goldPrimary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text('フレンド', style: TextStyle(fontSize: 12, color: AppColors.goldPrimary, fontWeight: FontWeight.bold)),
        );
      case 'sent':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard2,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text('申請済み', style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
        );
      default:
        return Material(
          color: AppColors.goldPrimary,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () {
              debugPrint('[FriendChip] tapped! otherId=$otherId, name=$name');
              _sendFriendRequest(otherId, name);
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: const Text('フレンド申請', style: TextStyle(fontSize: 12, color: AppColors.textOnCard, fontWeight: FontWeight.bold)),
            ),
          ),
        );
    }
  }

  Widget _buildAiMessageBubble(Message msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.accentBlue,
            radius: 16,
            child: Icon(Icons.smart_toy, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI解説',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.accentBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.accentBlue.withValues(alpha: 0.12),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.text ?? '',
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'あなただけに表示されています',
                        style: TextStyle(fontSize: 10, color: AppColors.accentBlue.withValues(alpha: 0.6)),
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
                color: AppColors.accentBlue.withValues(alpha: 0.2),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                msg.text ?? '',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
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
            backgroundColor: AppColors.accentBlue,
            radius: 16,
            child: Icon(Icons.smart_toy, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.accentBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accentBlue,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '考え中...',
                  style: TextStyle(fontSize: 13, color: AppColors.accentBlue.withValues(alpha: 0.8)),
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
