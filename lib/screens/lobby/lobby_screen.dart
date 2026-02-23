// ロビー画面（招待番号・参加者リスト・募集締切）
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/premium_components.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  final String? sessionId;
  final String? roomCode;
  final int grade;
  final int term;
  final String subjectId;
  final String subjectName;
  final bool isHost;

  const LobbyScreen({
    super.key,
    this.sessionId,
    this.roomCode,
    required this.grade,
    required this.term,
    required this.subjectId,
    required this.subjectName,
    required this.isHost,
  });

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  final FirebaseSessionService _sessionService = FirebaseSessionService();
  final CsvImportService _csvService = CsvImportService();
  String? _sessionId;
  String? _roomCode;
  int _participantCount = 0;
  List<Map<String, dynamic>> _participants = [];
  StreamSubscription? _sessionSubscription;
  StreamSubscription? _participantSubscription;
  StreamSubscription? _phaseSubscription;
  bool _isCreating = true;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    if (widget.isHost) {
      _createRoom();
    } else {
      _sessionId = widget.sessionId;
      _roomCode = widget.roomCode;
      _isCreating = false;
      _watchParticipants();
    }
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _participantSubscription?.cancel();
    _phaseSubscription?.cancel();
    super.dispose();
  }

  Future<void> _createRoom() async {
    final authState = ref.read(authProvider);
    if (authState.user == null) return;

    try {
      // 新しいルームを作成
      final session = await _sessionService.createRoomSession(
        grade: widget.grade,
        term: widget.term,
        subjectId: widget.subjectId,
        subjectName: widget.subjectName,
      );

      if (session != null && mounted) {
        _sessionId = session['sessionId'] as String;
        _roomCode = session['roomCode'] as String;

        // ホストがセッションに参加
        await _sessionService.joinSession(
          _sessionId!,
          authState.user!.userId,
          authState.user!.displayName,
        );

        setState(() => _isCreating = false);
        _watchParticipants();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ルーム作成に失敗しました')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  void _watchParticipants() {
    if (_sessionId == null) return;
    _participantSubscription = _sessionService
        .watchParticipants(_sessionId!)
        .listen((participants) {
      if (mounted) {
        setState(() {
          _participants = participants;
          _participantCount = participants.length;
        });
      }
    });

    // 非ホスト: フェーズ変更を監視してルーレットに自動遷移
    if (!widget.isHost && _roomCode != null) {
      _phaseSubscription = FirebaseDatabase.instance
          .ref('active_sessions/code_$_roomCode')
          .onValue
          .listen((event) async {
        if (!mounted) return;
        if (!event.snapshot.exists) return;
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        final phase = data['phase'] as String?;
        if (phase == 'roulette') {
          _phaseSubscription?.cancel();
          final rawLecture = data['selectedLecture'];
          final selectedLecture = rawLecture is num ? rawLecture.toInt() : null;
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/roulette', arguments: {
            'sessionId': _sessionId,
            'roomCode': _roomCode,
            'grade': widget.grade,
            'term': widget.term,
            'subjectId': widget.subjectId,
            'subjectName': widget.subjectName,
            'selectedLecture': selectedLecture,
          });
        }
      });
    }
  }

  Future<void> _closeLobby() async {
    if (_sessionId == null || _roomCode == null || _isClosing) return;
    setState(() => _isClosing = true);

    // 授業回をランダムに決定
    List<int> lectureNos;
    try {
      lectureNos = await _csvService.getLectureNos(widget.subjectId);
    } catch (_) {
      lectureNos = [];
    }
    if (!mounted) return;

    if (lectureNos.isEmpty) {
      setState(() => _isClosing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('授業回が見つかりません')),
      );
      return;
    }

    final selectedLecture = lectureNos[Random().nextInt(lectureNos.length)];

    // Firebaseに選択された授業回を保存（全員が同じ回を使う）
    await FirebaseDatabase.instance
        .ref('active_sessions/code_$_roomCode/selectedLecture')
        .set(selectedLecture);

    // フェーズ更新
    await _sessionService.updatePhase(_sessionId!, 'roulette', roomCode: _roomCode!);
    if (!mounted) return;

    Navigator.pushReplacementNamed(context, '/roulette', arguments: {
      'sessionId': _sessionId,
      'roomCode': _roomCode,
      'grade': widget.grade,
      'term': widget.term,
      'subjectId': widget.subjectId,
      'subjectName': widget.subjectName,
      'selectedLecture': selectedLecture,
    });
  }

  @override
  Widget build(BuildContext context) {
    // Premium header with gold line
    final header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.lineGold, width: 0.5)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pushNamedAndRemoveUntil(
            context, '/home', (route) => false,
          ),
          child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary, size: 24),
        ),
        const SizedBox(width: 12),
        Text(
          widget.subjectName,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ]),
    );

    return Scaffold(
      body: StarryBackground(
        child: SafeArea(
          child: _isCreating
              ? Column(
                  children: [
                    header,
                    const Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: AppColors.goldPrimary),
                            SizedBox(height: 16),
                            Text(
                              'ルームを作成中...',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    header,
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // 招待番号カード
                            PremiumCard(
                              type: PremiumCardType.dark,
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.share, color: AppColors.goldPrimary),
                                      const SizedBox(width: 8),
                                      Text(
                                        '招待番号',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.goldPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _roomCode ?? '------',
                                    style: const TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.goldPrimary,
                                      letterSpacing: 8,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'この番号を友達に共有しよう！',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: _roomCode == null
                                          ? null
                                          : () {
                                              final url =
                                                  'https://quiz-buddies-3a96c.web.app/join?code=$_roomCode';
                                              Clipboard.setData(
                                                  ClipboardData(text: url));
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: const Text(
                                                      '招待URLをコピーしました'),
                                                  backgroundColor:
                                                      AppColors.goldDeep,
                                                  behavior: SnackBarBehavior
                                                      .floating,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                ),
                                              );
                                            },
                                      icon: const Icon(Icons.link, size: 18),
                                      label: const Text('招待URLをコピー'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.goldPrimary,
                                        side: const BorderSide(
                                            color: AppColors.goldPrimary),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // 科目情報
                            PremiumCard(
                              type: PremiumCardType.light,
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  const GoldIconCircle(icon: Icons.school, size: 36),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '${widget.grade}年 第${widget.term}学期 ${widget.subjectName}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textOnCard,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // 参加者リスト
                            Expanded(
                              child: PremiumCard(
                                type: PremiumCardType.dark,
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.people, color: AppColors.goldPrimary),
                                        const SizedBox(width: 8),
                                        Text(
                                          '参加者 $_participantCount人',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      height: 0.5,
                                      color: AppColors.lineGold,
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: _participants.isEmpty
                                          ? const Center(
                                              child: Text(
                                                '参加者を待っています...',
                                                style: TextStyle(
                                                  color: AppColors.textMuted,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            )
                                          : ListView.builder(
                                              itemCount: _participants.length,
                                              itemBuilder: (context, index) {
                                                final p = _participants[index];
                                                final displayName =
                                                    p['displayName'] as String? ?? '?';
                                                return Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                                  child: Row(
                                                    children: [
                                                      // Gold border avatar
                                                      Container(
                                                        width: 40,
                                                        height: 40,
                                                        decoration: BoxDecoration(
                                                          shape: BoxShape.circle,
                                                          color: AppColors.surfaceCard2,
                                                          border: Border.all(
                                                            color: AppColors.goldPrimary,
                                                            width: 2,
                                                          ),
                                                        ),
                                                        alignment: Alignment.center,
                                                        child: Text(
                                                          displayName.substring(0, 1),
                                                          style: const TextStyle(
                                                            color: AppColors.goldPrimary,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Text(
                                                          displayName,
                                                          style: const TextStyle(
                                                            color: AppColors.textPrimary,
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                      ),
                                                      if (index == 0)
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(
                                                            horizontal: 10,
                                                            vertical: 4,
                                                          ),
                                                          decoration: BoxDecoration(
                                                            gradient: kGoldGradient,
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: const Text(
                                                            'ホスト',
                                                            style: TextStyle(
                                                              color: AppColors.textOnCard,
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w700,
                                                            ),
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
                              ),
                            ),

                            const SizedBox(height: 16),

                            // 募集締切ボタン（ホストのみ）
                            if (widget.isHost)
                              _isClosing
                                  ? Container(
                                      width: double.infinity,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        gradient: kGoldGradient,
                                        borderRadius: BorderRadius.circular(AppRadius.button),
                                        boxShadow: AppShadows.button,
                                      ),
                                      alignment: Alignment.center,
                                      child: const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          color: AppColors.textOnCard,
                                          strokeWidth: 3,
                                        ),
                                      ),
                                    )
                                  : PremiumButton(
                                      label: '募集締切 → クイズ開始',
                                      onPressed: _participantCount > 0 ? _closeLobby : null,
                                    ),

                            // 参加者は待機メッセージ
                            if (!widget.isHost)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'ホストが募集を締め切るまでお待ちください',
                                  style: TextStyle(fontSize: 16, color: AppColors.textMuted),
                                  textAlign: TextAlign.center,
                                ),
                              ),

                            // キャンセルボタン
                            TextButton(
                              onPressed: () {
                                Navigator.pushNamedAndRemoveUntil(
                                  context, '/home', (route) => false,
                                );
                              },
                              child: const Text(
                                'キャンセル',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
