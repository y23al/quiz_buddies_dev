// ルーレット画面（マルチユーザー対応 + Firebase同期）
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';

class RouletteScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final String roomCode;
  final int grade;
  final int term;
  final String subjectId;
  final String subjectName;
  final int? selectedLecture;

  const RouletteScreen({
    super.key,
    required this.sessionId,
    required this.roomCode,
    required this.grade,
    required this.term,
    required this.subjectId,
    required this.subjectName,
    this.selectedLecture,
  });

  @override
  ConsumerState<RouletteScreen> createState() => _RouletteScreenState();
}

class _RouletteScreenState extends ConsumerState<RouletteScreen>
    with SingleTickerProviderStateMixin {
  final CsvImportService _csvService = CsvImportService();
  final FirebaseSessionService _sessionService = FirebaseSessionService();

  List<int> _lectureNos = [];
  bool _isLoading = true;
  int _displayLecture = 1;
  int? _selectedLecture;
  bool _decided = false;

  // アニメーション用
  Timer? _spinTimer;
  int _spinStep = 0;
  int _totalSpinSteps = 0;
  late List<int> _spinSequence;

  // マルチユーザー
  String? _myUserId;
  List<Map<String, dynamic>> _otherParticipants = [];
  StreamSubscription? _participantSubscription;
  int _writeThrottle = 0;

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authProvider);
    _myUserId = authState.user?.userId;
    _watchOtherParticipants();
    _loadAndSpin();
  }

  @override
  void dispose() {
    _spinTimer?.cancel();
    _participantSubscription?.cancel();
    super.dispose();
  }

  void _watchOtherParticipants() {
    _participantSubscription = _sessionService
        .watchParticipants(widget.sessionId)
        .listen((participants) {
      if (mounted) {
        setState(() {
          _otherParticipants =
              participants.where((p) => p['odId'] != _myUserId).toList();
        });
      }
    });
  }

  Future<void> _loadAndSpin() async {
    int? selected = widget.selectedLecture;
    if (selected == null && widget.roomCode.isNotEmpty) {
      try {
        final snap = await FirebaseDatabase.instance
            .ref('active_sessions/code_${widget.roomCode}/selectedLecture')
            .get();
        if (snap.exists && snap.value is num) {
          selected = (snap.value as num).toInt();
        }
      } catch (_) {}
    }

    List<int> lectureNos;
    try {
      lectureNos = await _csvService.getLectureNos(widget.subjectId);
    } catch (_) {
      lectureNos = [];
    }
    if (!mounted) return;

    if (lectureNos.isEmpty || selected == null) {
      setState(() => _isLoading = false);
      return;
    }

    final random = Random();
    final sequence = _buildSpinSequence(lectureNos, selected, random);

    setState(() {
      _lectureNos = lectureNos;
      _selectedLecture = selected;
      _spinSequence = sequence;
      _totalSpinSteps = sequence.length;
      _isLoading = false;
      _displayLecture = sequence.first;
    });

    _startSpin();
  }

  List<int> _buildSpinSequence(
      List<int> lectures, int target, Random random) {
    final seq = <int>[];
    for (int i = 0; i < 30; i++) {
      seq.add(lectures[random.nextInt(lectures.length)]);
    }
    final targetIdx = lectures.indexOf(target);
    final safeTargetIdx = targetIdx >= 0 ? targetIdx : 0;
    final slowCount = lectures.length * 2 + safeTargetIdx + 1;
    for (int i = 0; i < slowCount; i++) {
      seq.add(lectures[i % lectures.length]);
    }
    return seq;
  }

  void _startSpin() {
    _spinStep = 0;
    _advanceSpin();
  }

  void _advanceSpin() {
    if (_spinStep >= _totalSpinSteps) {
      setState(() {
        _displayLecture = _selectedLecture!;
        _decided = true;
      });
      _writeRouletteState(_selectedLecture!, true);
      Future.delayed(const Duration(seconds: 2), _navigateToQuiz);
      return;
    }

    setState(() {
      _displayLecture = _spinSequence[_spinStep];
    });

    // 5ステップごとにFirebaseへ書き込み
    _writeThrottle++;
    if (_writeThrottle >= 5) {
      _writeThrottle = 0;
      _writeRouletteState(_spinSequence[_spinStep], false);
    }

    final progress = _spinStep / _totalSpinSteps;
    int intervalMs;
    if (progress < 0.5) {
      intervalMs = 60 + (progress * 40).round();
    } else if (progress < 0.8) {
      final t = (progress - 0.5) / 0.3;
      intervalMs = 80 + (t * 170).round();
    } else {
      final t = (progress - 0.8) / 0.2;
      intervalMs = 250 + (t * 350).round();
    }

    _spinStep++;
    _spinTimer = Timer(Duration(milliseconds: intervalMs), _advanceSpin);
  }

  void _writeRouletteState(int display, bool done) {
    if (_myUserId != null) {
      _sessionService.updateRouletteState(
        widget.sessionId,
        _myUserId!,
        display,
        done,
      );
    }
  }

  void _navigateToQuiz() {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/quiz', arguments: {
      'sessionId': widget.sessionId,
      'roomCode': widget.roomCode,
      'grade': widget.grade,
      'term': widget.term,
      'subjectId': widget.subjectId,
      'subjectName': widget.subjectName,
      'lectureNo': _selectedLecture,
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress =
        _totalSpinSteps > 0 ? _spinStep / _totalSpinSteps : 0.0;
    final isSlowing = progress > 0.7;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(widget.subjectName,
            style: const TextStyle(color: Colors.white)),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white))
          : _lectureNos.isEmpty
              ? _buildEmptyState()
              : SafeArea(
                  child: Column(
                    children: [
                      const Spacer(flex: 1),

                      // ステータステキスト
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        style: TextStyle(
                          color: _decided
                              ? const Color(0xFF4CAF50)
                              : Colors.white70,
                          fontSize: _decided ? 22 : 18,
                          fontWeight:
                              _decided ? FontWeight.bold : FontWeight.normal,
                        ),
                        child: Text(_decided ? '決定！' : 'ルーレット'),
                      ),
                      const SizedBox(height: 24),

                      // ルーレットエリア（中央メイン + 周囲に他ユーザー）
                      SizedBox(
                        height: 320,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ..._buildOtherUserRoulettes(),
                            _buildMainRoulette(isSlowing),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      if (_decided)
                        const Text(
                          'クイズを開始します...',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 16),
                        )
                      else
                        Text(
                          isSlowing
                              ? 'もうすぐ止まります...'
                              : '授業回を選んでいます...',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 16),
                        ),

                      const Spacer(flex: 2),
                    ],
                  ),
                ),
    );
  }

  Widget _buildMainRoulette(bool isSlowing) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: _decided ? 200 : 180,
      height: _decided ? 200 : 180,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _decided ? const Color(0xFF4CAF50) : Colors.grey[800],
        border: Border.all(
          color: _decided
              ? const Color(0xFF4CAF50)
              : isSlowing
                  ? Colors.yellow
                  : Colors.orange,
          width: _decided ? 6 : 4,
        ),
        boxShadow: [
          BoxShadow(
            color: (_decided
                    ? const Color(0xFF4CAF50)
                    : isSlowing
                        ? Colors.yellow
                        : Colors.orange)
                .withValues(alpha: _decided ? 0.5 : 0.3),
            blurRadius: _decided ? 30 : 20,
            spreadRadius: _decided ? 8 : 5,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('第',
              style: TextStyle(color: Colors.white70, fontSize: 20)),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: TextStyle(
              color: Colors.white,
              fontSize: _decided ? 72 : 64,
              fontWeight: FontWeight.bold,
            ),
            child: Text('$_displayLecture'),
          ),
          const Text('回',
              style: TextStyle(color: Colors.white70, fontSize: 20)),
        ],
      ),
    );
  }

  List<Widget> _buildOtherUserRoulettes() {
    final count = _otherParticipants.length;
    if (count == 0) return [];

    final widgets = <Widget>[];
    for (int i = 0; i < count; i++) {
      final p = _otherParticipants[i];
      final displayName = p['displayName'] as String? ?? '?';
      final rouletteDisplay = p['rouletteDisplay'];
      final displayVal =
          rouletteDisplay is num ? rouletteDisplay.toInt() : null;
      final rouletteDone = p['rouletteDone'] as bool? ?? false;

      // 極座標で円形配置（上から時計回り）
      final angle = (2 * pi * i / count) - pi / 2;
      const radius = 135.0;
      final dx = radius * cos(angle);
      final dy = radius * sin(angle);

      widgets.add(
        Transform.translate(
          offset: Offset(dx, dy),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: rouletteDone
                      ? const Color(0xFF4CAF50).withValues(alpha: 0.7)
                      : Colors.grey[700],
                  border: Border.all(
                    color: rouletteDone
                        ? const Color(0xFF4CAF50)
                        : Colors.orange.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    displayVal != null ? '$displayVal' : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                displayName.length > 6
                    ? '${displayName.substring(0, 6)}...'
                    : displayName,
                style:
                    const TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning_amber, size: 64, color: Colors.orange[300]),
          const SizedBox(height: 16),
          const Text(
            '授業回が見つかりません',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('戻る'),
          ),
        ],
      ),
    );
  }
}
