// ロビー画面（招待番号・参加者リスト・募集締切）
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';

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
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        title: Text(widget.subjectName, style: const TextStyle(color: Colors.white)),
        automaticallyImplyLeading: false,
      ),
      body: _isCreating
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF4CAF50)),
                  SizedBox(height: 16),
                  Text('ルームを作成中...'),
                ],
              ),
            )
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // 招待番号カード
                    Card(
                      color: Colors.blue[50],
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.share, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                Text(
                                  '招待番号',
                                  style: TextStyle(fontSize: 16, color: Colors.blue[700]),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _roomCode ?? '------',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                                letterSpacing: 8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'この番号を友達に共有しよう！',
                              style: TextStyle(fontSize: 14, color: Colors.blue[600]),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 科目情報
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.school, color: Color(0xFF4CAF50)),
                            const SizedBox(width: 12),
                            Text(
                              '${widget.grade}年 第${widget.term}学期 ${widget.subjectName}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 参加者リスト
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.people, color: Color(0xFF4CAF50)),
                                  const SizedBox(width: 8),
                                  Text(
                                    '参加者 $_participantCount人',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(),
                              Expanded(
                                child: _participants.isEmpty
                                    ? const Center(child: Text('参加者を待っています...'))
                                    : ListView.builder(
                                        itemCount: _participants.length,
                                        itemBuilder: (context, index) {
                                          final p = _participants[index];
                                          return ListTile(
                                            leading: CircleAvatar(
                                              backgroundColor: const Color(0xFF4CAF50),
                                              child: Text(
                                                (p['displayName'] as String? ?? '?').substring(0, 1),
                                                style: const TextStyle(color: Colors.white),
                                              ),
                                            ),
                                            title: Text(p['displayName'] as String? ?? '???'),
                                            trailing: index == 0
                                                ? Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8, vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.orange,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Text(
                                                      'ホスト',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  )
                                                : null,
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 募集締切ボタン（ホストのみ）
                    if (widget.isHost)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _participantCount > 0 && !_isClosing ? _closeLobby : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isClosing
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                )
                              : const Text(
                                  '募集締切 → クイズ開始',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),

                    // 参加者は待機メッセージ
                    if (!widget.isHost)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'ホストが募集を締め切るまでお待ちください',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
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
                      child: Text(
                        'キャンセル',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
