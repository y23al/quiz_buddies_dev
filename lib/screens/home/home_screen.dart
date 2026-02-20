// ホーム画面（v2: ルーム作成/参加・プロフィール）
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../models/models.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final CsvImportService _csvService = CsvImportService();
  final FirebaseSessionService _sessionService = FirebaseSessionService();
  final TextEditingController _inviteCodeController = TextEditingController();
  bool _isImporting = false;
  bool _isImported = false;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    // CSVインポート（初回のみ）
    if (!_isImported) {
      setState(() => _isImporting = true);
      try {
        await _csvService.importFromAsset('assets/karute_data.csv');
        _isImported = true;
      } catch (e) {
        // インポートエラーは無視（既にインポート済みの可能性）
      }
      if (mounted) setState(() => _isImporting = false);
    }

    // プロフィール読み込み
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final authState = ref.read(authProvider);
    if (authState.user != null) {
      final profile = await _sessionService.getUserProfile(authState.user!.userId);
      if (mounted) {
        setState(() => _profile = profile);
      }
    }
  }

  Future<void> _joinByInviteCode() async {
    final code = _inviteCodeController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('6桁の招待番号を入力してください')),
      );
      return;
    }

    final session = await _sessionService.joinByRoomCode(code);
    if (session != null && mounted) {
      final authState = ref.read(authProvider);
      await _sessionService.joinSession(
        session['sessionId'],
        authState.user!.userId,
        authState.user!.displayName,
      );
      if (mounted) {
        Navigator.pushNamed(context, '/lobby', arguments: {
          'sessionId': session['sessionId'],
          'roomCode': code,
          'grade': session['grade'] ?? 0,
          'term': session['term'] ?? 0,
          'subjectId': session['subjectId'] ?? '',
          'subjectName': session['subjectName'] ?? '',
          'isHost': false,
        });
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('招待番号が無効か、募集が締め切られています')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        title: const Text('Quiz Buddies', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: _isImporting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF4CAF50)),
                  SizedBox(height: 16),
                  Text('問題データを読み込み中...'),
                ],
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // プロフィールカード
                    _buildProfileCard(authState),
                    const SizedBox(height: 24),

                    // ルーム作成ボタン
                    _buildCreateRoomCard(),
                    const SizedBox(height: 16),

                    // ルーム参加カード
                    _buildJoinRoomCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileCard(AuthState authState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF4CAF50),
              radius: 28,
              child: Text(
                authState.user?.displayName.substring(0, 1) ?? '?',
                style: const TextStyle(color: Colors.white, fontSize: 22),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authState.user?.displayName ?? 'ゲスト',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  if (_profile != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildBadge('ランク ${_profile!.rank}', Colors.orange),
                        const SizedBox(width: 8),
                        _buildBadge('${_profile!.totalPoints}pt', Colors.blue),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildCreateRoomCard() {
    return Card(
      color: const Color(0xFF4CAF50),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pushNamed(context, '/select-grade'),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Row(
            children: [
              Icon(Icons.add_circle_outline, color: Colors.white, size: 40),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ルームを作成',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '学年・学期・科目を選んでクイズを始めよう',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJoinRoomCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.group_add, color: Color(0xFF4CAF50), size: 28),
                SizedBox(width: 12),
                Text(
                  'ルームに参加',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _inviteCodeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                hintText: '000000',
                hintStyle: TextStyle(color: Colors.grey[400], letterSpacing: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _joinByInviteCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  '参加する',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
