// セッションサービス
import 'dart:math';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'ai_service.dart';

// デモデータストレージ
final Map<String, Session> _demoSessions = {};
final Map<String, Quiz> _demoQuizzes = {};
final Map<String, Participation> _demoParticipations = {};

class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  // 現在のセッションを取得
  Future<Session?> getCurrentSession() async {
    for (final session in _demoSessions.values) {
      if ([
        SessionPhase.joinable,
        SessionPhase.quiz,
        SessionPhase.splitRoom,
        SessionPhase.matching,
        SessionPhase.oneOnOne,
        SessionPhase.common,
      ].contains(session.phase)) {
        return session;
      }
    }
    return null;
  }

  // セッションを取得
  Session? getSession(String sessionId) {
    return _demoSessions[sessionId];
  }

  // クイズを取得
  Quiz? getQuiz(String quizId) {
    return _demoQuizzes[quizId];
  }

  // セッションに参加
  Future<Participation> joinSession(String sessionId, String userId) async {
    final participationId = '${sessionId}_$userId';

    if (_demoParticipations.containsKey(participationId)) {
      return _demoParticipations[participationId]!;
    }

    final participation = Participation(
      sessionId: sessionId,
      userId: userId,
      joinedAt: DateTime.now(),
    );
    _demoParticipations[participationId] = participation;
    return participation;
  }

  // 参加情報を取得
  Participation? getParticipation(String sessionId, String userId) {
    return _demoParticipations['${sessionId}_$userId'];
  }

  // 回答を送信
  Future<AnswerResult> submitAnswer(
    String sessionId,
    String userId,
    int answerIndex,
  ) async {
    final participationId = '${sessionId}_$userId';
    final session = _demoSessions[sessionId];
    if (session == null) throw Exception('Session not found');

    final quiz = _demoQuizzes[session.quizId];
    if (quiz == null) throw Exception('Quiz not found');

    final isCorrect = answerIndex == quiz.correctChoiceIndex;
    final result = isCorrect ? AnswerResult.correct : AnswerResult.incorrect;
    final splitRoomAssigned = isCorrect ? 'correct' : 'incorrect';

    final participation = _demoParticipations[participationId];
    if (participation != null) {
      _demoParticipations[participationId] = participation.copyWith(
        answer: answerIndex,
        answeredAt: DateTime.now(),
        result: result,
        splitRoomAssigned: splitRoomAssigned,
      );
    }

    return result;
  }

  // タイムアウト処理
  Future<void> handleTimeout(String sessionId, String userId) async {
    final participationId = '${sessionId}_$userId';
    final participation = _demoParticipations[participationId];
    if (participation != null) {
      _demoParticipations[participationId] = participation.copyWith(
        result: AnswerResult.timeout,
        splitRoomAssigned: 'incorrect',
      );
    }
  }

  static final Random _random = Random();

  // 出題済みクイズのインデックスを記録（重複防止）
  static final List<int> _usedQuizIndices = [];

  // クイズプール
  static final List<Map<String, dynamic>> _quizPool = [
    // ── 地理 ──
    {
      'questionText': '日本で一番高い山は？',
      'choices': ['富士山', '北岳', '奥穂高岳', '槍ヶ岳'],
      'correctChoiceIndex': 0,
      'explanation': '富士山は標高3,776mで日本一高い山です。2番目は北岳（3,193m）です。',
      'difficulty': 'easy',
    },
    {
      'questionText': '世界で一番大きい大陸は？',
      'choices': ['アフリカ', 'ユーラシア', '北アメリカ', '南アメリカ'],
      'correctChoiceIndex': 1,
      'explanation': 'ユーラシア大陸は約5,490万km²で世界最大の大陸です。',
      'difficulty': 'easy',
    },
    {
      'questionText': '日本で一番長い川は？',
      'choices': ['利根川', '信濃川', '石狩川', '天竜川'],
      'correctChoiceIndex': 1,
      'explanation': '信濃川は全長367kmで日本一長い川です。新潟県と長野県を流れています。',
      'difficulty': 'easy',
    },
    {
      'questionText': '世界で一番深い湖は？',
      'choices': ['カスピ海', 'バイカル湖', 'タンガニーカ湖', '琵琶湖'],
      'correctChoiceIndex': 1,
      'explanation': 'バイカル湖はロシアにあり、最大深度1,642mで世界一深い湖です。',
      'difficulty': 'medium',
    },
    {
      'questionText': '日本で一番面積が大きい都道府県は？',
      'choices': ['岩手県', '北海道', '長野県', '新潟県'],
      'correctChoiceIndex': 1,
      'explanation': '北海道は面積約83,424km²で日本最大の都道府県です。',
      'difficulty': 'easy',
    },
    {
      'questionText': '世界で一番小さい国は？',
      'choices': ['モナコ', 'バチカン市国', 'サンマリノ', 'ナウル'],
      'correctChoiceIndex': 1,
      'explanation': 'バチカン市国は面積約0.44km²で世界最小の独立国です。',
      'difficulty': 'easy',
    },
    {
      'questionText': 'アマゾン川が流れ込む海は？',
      'choices': ['太平洋', 'インド洋', '大西洋', '北極海'],
      'correctChoiceIndex': 2,
      'explanation': 'アマゾン川は南アメリカ大陸を東に流れ、大西洋に注ぎます。',
      'difficulty': 'medium',
    },
    {
      'questionText': 'オーストラリアの首都は？',
      'choices': ['シドニー', 'メルボルン', 'キャンベラ', 'ブリスベン'],
      'correctChoiceIndex': 2,
      'explanation': 'キャンベラはオーストラリアの首都です。シドニーやメルボルンの方が有名ですが、首都ではありません。',
      'difficulty': 'medium',
    },
    // ── 科学 ──
    {
      'questionText': '水の化学式は？',
      'choices': ['CO2', 'H2O', 'NaCl', 'O2'],
      'correctChoiceIndex': 1,
      'explanation': '水の化学式はH2O（水素2原子と酸素1原子）です。',
      'difficulty': 'easy',
    },
    {
      'questionText': '人間の体で一番大きい臓器は？',
      'choices': ['心臓', '肝臓', '皮膚', '肺'],
      'correctChoiceIndex': 2,
      'explanation': '皮膚は体表面積約1.6〜1.8m²、重さ約3kgで最大の臓器です。',
      'difficulty': 'medium',
    },
    {
      'questionText': '光の三原色に含まれないのは？',
      'choices': ['赤', '緑', '黄', '青'],
      'correctChoiceIndex': 2,
      'explanation': '光の三原色は赤(R)・緑(G)・青(B)です。黄は色の三原色に含まれます。',
      'difficulty': 'medium',
    },
    {
      'questionText': '太陽系で一番大きい惑星は？',
      'choices': ['土星', '木星', '天王星', '海王星'],
      'correctChoiceIndex': 1,
      'explanation': '木星は直径約14万kmで太陽系最大の惑星です。地球の約11倍の大きさです。',
      'difficulty': 'easy',
    },
    {
      'questionText': 'ダイヤモンドの主成分は？',
      'choices': ['鉄', '炭素', 'ケイ素', 'アルミニウム'],
      'correctChoiceIndex': 1,
      'explanation': 'ダイヤモンドは炭素原子が正四面体構造で結合した結晶です。',
      'difficulty': 'medium',
    },
    {
      'questionText': '音が伝わらない場所は？',
      'choices': ['水中', '鉄の中', '真空', '空気中'],
      'correctChoiceIndex': 2,
      'explanation': '音は媒質の振動で伝わるため、媒質がない真空中では伝わりません。',
      'difficulty': 'easy',
    },
    {
      'questionText': '地球の大気に最も多く含まれる気体は？',
      'choices': ['酸素', '窒素', '二酸化炭素', 'アルゴン'],
      'correctChoiceIndex': 1,
      'explanation': '大気の約78%が窒素、約21%が酸素です。',
      'difficulty': 'easy',
    },
    {
      'questionText': 'DNAの二重らせん構造を発見した科学者は？',
      'choices': ['アインシュタイン', 'ニュートン', 'ワトソンとクリック', 'ダーウィン'],
      'correctChoiceIndex': 2,
      'explanation': '1953年にジェームズ・ワトソンとフランシス・クリックがDNAの二重らせん構造を解明しました。',
      'difficulty': 'hard',
    },
    // ── 歴史 ──
    {
      'questionText': '日本の初代内閣総理大臣は？',
      'choices': ['大隈重信', '伊藤博文', '山県有朋', '西郷隆盛'],
      'correctChoiceIndex': 1,
      'explanation': '伊藤博文は1885年に日本初の内閣総理大臣に就任しました。',
      'difficulty': 'medium',
    },
    {
      'questionText': '鎌倉幕府を開いたのは誰？',
      'choices': ['源頼朝', '源義経', '平清盛', '北条時宗'],
      'correctChoiceIndex': 0,
      'explanation': '源頼朝が1185年（諸説あり）に鎌倉幕府を開きました。',
      'difficulty': 'easy',
    },
    {
      'questionText': '関ヶ原の戦いが起きた年は？',
      'choices': ['1500年', '1600年', '1700年', '1800年'],
      'correctChoiceIndex': 1,
      'explanation': '関ヶ原の戦いは1600年に起き、徳川家康が勝利して天下統一への道を開きました。',
      'difficulty': 'medium',
    },
    {
      'questionText': 'フランス革命が始まった年は？',
      'choices': ['1776年', '1789年', '1804年', '1815年'],
      'correctChoiceIndex': 1,
      'explanation': '1789年にバスティーユ牢獄襲撃をきっかけにフランス革命が始まりました。',
      'difficulty': 'medium',
    },
    {
      'questionText': '日本で最初の元号は？',
      'choices': ['大化', '白雉', '天平', '和銅'],
      'correctChoiceIndex': 0,
      'explanation': '大化は645年に制定された日本最初の元号です。大化の改新で知られています。',
      'difficulty': 'hard',
    },
    // ── 文化・文学 ──
    {
      'questionText': '「源氏物語」の作者は？',
      'choices': ['清少納言', '紫式部', '和泉式部', '小野小町'],
      'correctChoiceIndex': 1,
      'explanation': '「源氏物語」は紫式部によって11世紀初頭に書かれた長編物語です。',
      'difficulty': 'easy',
    },
    {
      'questionText': '「吾輩は猫である」の作者は？',
      'choices': ['芥川龍之介', '太宰治', '夏目漱石', '森鷗外'],
      'correctChoiceIndex': 2,
      'explanation': '夏目漱石が1905年に発表したデビュー作です。',
      'difficulty': 'easy',
    },
    {
      'questionText': '「モナ・リザ」を描いた画家は？',
      'choices': ['ミケランジェロ', 'レオナルド・ダ・ヴィンチ', 'ラファエロ', 'ピカソ'],
      'correctChoiceIndex': 1,
      'explanation': 'レオナルド・ダ・ヴィンチが16世紀初頭に描いた肖像画で、パリのルーヴル美術館に所蔵されています。',
      'difficulty': 'easy',
    },
    {
      'questionText': '俳句の季節を表す言葉を何という？',
      'choices': ['季語', '枕詞', '掛詞', '序詞'],
      'correctChoiceIndex': 0,
      'explanation': '季語は俳句において季節を表す言葉で、一句に一つ入れるのが基本です。',
      'difficulty': 'easy',
    },
    // ── スポーツ ──
    {
      'questionText': 'オリンピックの五輪マークの輪の数は？',
      'choices': ['3つ', '4つ', '5つ', '6つ'],
      'correctChoiceIndex': 2,
      'explanation': '五輪マークは5つの輪で5大陸（ヨーロッパ、アジア、アフリカ、オセアニア、アメリカ）を象徴しています。',
      'difficulty': 'easy',
    },
    {
      'questionText': 'サッカーで1チームのフィールドプレーヤーの人数は？',
      'choices': ['9人', '10人', '11人', '12人'],
      'correctChoiceIndex': 1,
      'explanation': 'サッカーは1チーム11人（GK1人＋フィールドプレーヤー10人）で行います。',
      'difficulty': 'easy',
    },
    {
      'questionText': 'テニスで得点が0の時の呼び方は？',
      'choices': ['ゼロ', 'ナッシング', 'ラブ', 'ブランク'],
      'correctChoiceIndex': 2,
      'explanation': 'テニスでは0点を「ラブ（love）」と呼びます。フランス語の「卵（l\'oeuf）」が語源とされています。',
      'difficulty': 'medium',
    },
    {
      'questionText': 'バスケットボールの3ポイントラインの外からシュートを決めると何点？',
      'choices': ['1点', '2点', '3点', '4点'],
      'correctChoiceIndex': 2,
      'explanation': '3ポイントラインの外から決めたシュートは3点です。通常のシュートは2点、フリースローは1点です。',
      'difficulty': 'easy',
    },
    // ── 数学・論理 ──
    {
      'questionText': '円周率（π）の小数点以下2桁目までの値は？',
      'choices': ['3.12', '3.14', '3.16', '3.18'],
      'correctChoiceIndex': 1,
      'explanation': '円周率πは3.14159...で、小数点以下2桁まで表すと3.14です。',
      'difficulty': 'easy',
    },
    {
      'questionText': '1から10までの整数をすべて足すといくつ？',
      'choices': ['45', '50', '55', '60'],
      'correctChoiceIndex': 2,
      'explanation': '1+2+3+...+10 = 10×11÷2 = 55 です。ガウスの公式 n(n+1)/2 で計算できます。',
      'difficulty': 'medium',
    },
    {
      'questionText': '三角形の内角の和は？',
      'choices': ['90度', '180度', '270度', '360度'],
      'correctChoiceIndex': 1,
      'explanation': '平面上の三角形の内角の和は常に180度です。',
      'difficulty': 'easy',
    },
    {
      'questionText': '2の10乗はいくつ？',
      'choices': ['512', '1024', '2048', '4096'],
      'correctChoiceIndex': 1,
      'explanation': '2^10 = 1024 です。コンピュータの世界では1KB = 1024バイトとしてよく使われます。',
      'difficulty': 'medium',
    },
    // ── 食べ物・生活 ──
    {
      'questionText': '寿司のネタで「トロ」はどの魚の部位？',
      'choices': ['サーモン', 'マグロ', 'ブリ', 'タイ'],
      'correctChoiceIndex': 1,
      'explanation': 'トロはマグロの腹部の脂身が多い部位で、大トロ・中トロがあります。',
      'difficulty': 'easy',
    },
    {
      'questionText': 'カレーの辛さの原因となるスパイスは？',
      'choices': ['ターメリック', 'クミン', 'チリペッパー', 'コリアンダー'],
      'correctChoiceIndex': 2,
      'explanation': 'チリペッパー（唐辛子）に含まれるカプサイシンが辛さの主な原因です。',
      'difficulty': 'medium',
    },
    {
      'questionText': '日本で「和牛」として認められている品種はいくつ？',
      'choices': ['2品種', '3品種', '4品種', '5品種'],
      'correctChoiceIndex': 2,
      'explanation': '和牛は黒毛和種、褐毛和種、日本短角種、無角和種の4品種です。',
      'difficulty': 'hard',
    },
    // ── IT・テクノロジー ──
    {
      'questionText': 'HTMLは何の略称？',
      'choices': [
        'Hyper Text Markup Language',
        'High Tech Modern Language',
        'Home Tool Markup Language',
        'Hyper Transfer Mail Language'
      ],
      'correctChoiceIndex': 0,
      'explanation': 'HTMLはHyper Text Markup Languageの略で、Webページの構造を記述するための言語です。',
      'difficulty': 'easy',
    },
    {
      'questionText': '1バイトは何ビット？',
      'choices': ['4ビット', '8ビット', '16ビット', '32ビット'],
      'correctChoiceIndex': 1,
      'explanation': '1バイト = 8ビットです。1ビットは0か1の2値を表します。',
      'difficulty': 'easy',
    },
    {
      'questionText': 'プログラミング言語「Python」の名前の由来は？',
      'choices': ['ヘビのニシキヘビ', 'イギリスのコメディ番組', 'ギリシャ神話', '開発者の苗字'],
      'correctChoiceIndex': 1,
      'explanation': 'Pythonはイギリスのコメディ番組「Monty Python\'s Flying Circus」に由来しています。',
      'difficulty': 'hard',
    },
    // ── 音楽 ──
    {
      'questionText': 'ピアノの鍵盤数（標準）は？',
      'choices': ['76鍵', '85鍵', '88鍵', '92鍵'],
      'correctChoiceIndex': 2,
      'explanation': '標準的なピアノの鍵盤数は88鍵（白鍵52、黒鍵36）です。',
      'difficulty': 'medium',
    },
    {
      'questionText': '「ド・レ・ミ・ファ・ソ・ラ・シ」はどこの国の言葉？',
      'choices': ['ドイツ', 'フランス', 'イタリア', 'スペイン'],
      'correctChoiceIndex': 2,
      'explanation': 'ドレミはイタリア語で、中世の賛美歌の各節の頭文字に由来します。',
      'difficulty': 'medium',
    },
    // ── 自然・動物 ──
    {
      'questionText': '世界で一番速い動物は？',
      'choices': ['チーター', 'ハヤブサ', 'カジキ', 'トンボ'],
      'correctChoiceIndex': 1,
      'explanation': 'ハヤブサは急降下時に時速390kmに達し、地球上で最も速い動物です。チーターは陸上最速（時速120km）です。',
      'difficulty': 'hard',
    },
    {
      'questionText': 'パンダの主食は？',
      'choices': ['笹（竹）', '果物', '昆虫', '木の実'],
      'correctChoiceIndex': 0,
      'explanation': 'ジャイアントパンダは1日に12〜38kgもの竹や笹を食べます。',
      'difficulty': 'easy',
    },
    {
      'questionText': 'タコの心臓はいくつ？',
      'choices': ['1つ', '2つ', '3つ', '4つ'],
      'correctChoiceIndex': 2,
      'explanation': 'タコには3つの心臓があります。1つは全身に血液を送り、残り2つはエラに血液を送ります。',
      'difficulty': 'hard',
    },
    {
      'questionText': '桜の花びらは通常何枚？',
      'choices': ['3枚', '4枚', '5枚', '6枚'],
      'correctChoiceIndex': 2,
      'explanation': 'ソメイヨシノなど一般的な桜の花びらは5枚です。八重桜は品種改良で多くの花びらを持ちます。',
      'difficulty': 'medium',
    },
    // ── 言葉・漢字 ──
    {
      'questionText': '「矛盾」という言葉の由来となった国は？',
      'choices': ['日本', '中国', 'インド', 'ギリシャ'],
      'correctChoiceIndex': 1,
      'explanation': '中国の古典「韓非子」に登場する、何でも突き通す矛と何でも防ぐ盾を売る商人の話が由来です。',
      'difficulty': 'medium',
    },
    {
      'questionText': '日本語の「五十音」は実際には何文字？',
      'choices': ['45文字', '46文字', '48文字', '50文字'],
      'correctChoiceIndex': 1,
      'explanation': '「ゐ」「ゑ」が現代では使われず、「ん」を加えて46文字です。',
      'difficulty': 'hard',
    },
  ];

  // サンプルクイズを作成（ランダムに選択）
  Future<Quiz> createSampleQuiz() async {
    // 全問出題済みならリセット
    if (_usedQuizIndices.length >= _quizPool.length) {
      _usedQuizIndices.clear();
    }

    // 未出題の中からランダム選択
    int index;
    do {
      index = _random.nextInt(_quizPool.length);
    } while (_usedQuizIndices.contains(index));
    _usedQuizIndices.add(index);

    final data = _quizPool[index];
    final quiz = Quiz(
      quizId: const Uuid().v4(),
      questionText: data['questionText'] as String,
      choices: List<String>.from(data['choices'] as List),
      correctChoiceIndex: data['correctChoiceIndex'] as int,
      explanation: data['explanation'] as String?,
      difficulty: data['difficulty'] as String?,
    );
    _demoQuizzes[quiz.quizId] = quiz;
    return quiz;
  }

  // サンプルセッションを作成
  Future<Session> createSampleSession(String quizId) async {
    final now = DateTime.now();
    final sessionId = const Uuid().v4();

    final session = Session(
      sessionId: sessionId,
      scheduledAt: now,
      joinableUntil: now.add(Duration(seconds: AppConfig.joinDeadlineSeconds)),
      phase: SessionPhase.joinable,
      quizId: quizId,
      createdAt: now,
      phaseStartAt: now,
      correctRoomId: '${sessionId}_correct',
      incorrectRoomId: '${sessionId}_incorrect',
      commonRoomId: '${sessionId}_common',
    );

    _demoSessions[sessionId] = session;
    return session;
  }

  // セッションを更新
  void updateSession(String sessionId, Session Function(Session) update) {
    final session = _demoSessions[sessionId];
    if (session != null) {
      _demoSessions[sessionId] = update(session);
    }
  }

  // マッチング相手を見つける
  Future<({String partnerId, String roomId, bool isAI})> findOrCreateMatch(
    String sessionId,
    String userId,
    AnswerResult userResult,
  ) async {
    final participationId = '${sessionId}_$userId';
    final participation = _demoParticipations[participationId];

    if (participation?.oneOnOneRoomId != null) {
      return (
        partnerId: '',
        roomId: participation!.oneOnOneRoomId!,
        isAI: false,
      );
    }

    // 相手を探す
    final targetResult =
        userResult == AnswerResult.correct ? AnswerResult.incorrect : AnswerResult.correct;

    for (final entry in _demoParticipations.entries) {
      if (!entry.key.startsWith(sessionId)) continue;
      if (entry.value.userId == userId) continue;
      if (entry.value.result != targetResult) continue;
      if (entry.value.oneOnOneRoomId != null) continue;

      // マッチング成功
      final roomId = '${sessionId}_1on1_${const Uuid().v4().substring(0, 8)}';

      if (participation != null) {
        _demoParticipations[participationId] = participation.copyWith(
          oneOnOneRoomId: roomId,
        );
      }
      _demoParticipations[entry.key] = entry.value.copyWith(
        oneOnOneRoomId: roomId,
      );

      return (partnerId: entry.value.userId, roomId: roomId, isAI: false);
    }

    // AIとマッチング
    final aiPartner = AiService.createAIPartner(userResult != AnswerResult.correct);
    final roomId = '${sessionId}_1on1_ai_${const Uuid().v4().substring(0, 8)}';

    final aiParticipationId = '${sessionId}_${aiPartner.userId}';
    _demoParticipations[aiParticipationId] = Participation(
      sessionId: sessionId,
      userId: aiPartner.userId,
      joinedAt: DateTime.now(),
      result: targetResult,
      splitRoomAssigned: targetResult == AnswerResult.correct ? 'correct' : 'incorrect',
      oneOnOneRoomId: roomId,
    );

    if (participation != null) {
      _demoParticipations[participationId] = participation.copyWith(
        oneOnOneRoomId: roomId,
      );
    }

    return (partnerId: aiPartner.userId, roomId: roomId, isAI: true);
  }
}
