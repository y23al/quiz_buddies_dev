// AIサービス（LM Studio ローカルLLM統合 - 人間を装う複数AI参加者）
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../utils/nickname_generator.dart';

// AI参加者
class AiParticipant {
  final String userId;
  final String displayName;

  AiParticipant({required this.userId, required this.displayName});
}

class AiService {
  static const String aiUserId = 'ai_assistant';
  static const String aiDisplayName = 'クイズBot';

  static const String _lmStudioBaseUrl = 'http://127.0.0.1:1234/v1';
  static const Duration _timeout = Duration(seconds: 15);

  static final Random _random = Random();

  // ルームごとのAI参加者プール
  static final Map<String, List<AiParticipant>> _roomParticipants = {};

  // AI参加者名の逆引き用キャッシュ
  static final Map<String, String> _participantNames = {};

  // ルームのAI参加者を取得（なければ生成）
  static List<AiParticipant> getOrCreateParticipants(String roomId, {int count = 4}) {
    if (!_roomParticipants.containsKey(roomId)) {
      final participants = List.generate(count, (i) {
        final name = generateNickname();
        final id = 'ai_participant_${roomId}_${i}_${const Uuid().v4().substring(0, 6)}';
        _participantNames[id] = name;
        return AiParticipant(userId: id, displayName: name);
      });
      _roomParticipants[roomId] = participants;
    }
    return _roomParticipants[roomId]!;
  }

  // AI参加者名を取得
  static String? getParticipantName(String userId) {
    return _participantNames[userId];
  }

  // ランダムにAI参加者を1人選ぶ
  static AiParticipant _pickRandomParticipant(String roomId) {
    final participants = getOrCreateParticipants(roomId);
    return participants[_random.nextInt(participants.length)];
  }

  // クイズ情報を含む動的システムプロンプトを構築
  static String _buildSystemPrompt({
    required String participantName,
    required String roomType,
    bool? isCorrectUser,
    Quiz? quiz,
  }) {
    final buffer = StringBuffer();

    // 基本キャラクター設定
    buffer.writeln('あなたは「$participantName」という名前のクイズアプリの参加者（人間）です。');
    buffer.writeln('あなたはAIではなく、普通の人間の参加者として自然に振る舞ってください。');
    buffer.writeln('「私はAIです」「AIとして」などの発言は絶対にしないでください。');
    buffer.writeln();

    // クイズ情報
    if (quiz != null) {
      buffer.writeln('【今回のクイズ】');
      buffer.writeln('問題: ${quiz.questionText}');
      if (quiz.choices.isNotEmpty) {
        buffer.writeln('選択肢:');
        for (var i = 0; i < quiz.choices.length; i++) {
          buffer.writeln('  ${String.fromCharCode(65 + i)}. ${quiz.choices[i]}');
        }
        buffer.writeln('正解: ${String.fromCharCode(65 + quiz.correctChoiceIndex)}. ${quiz.choices[quiz.correctChoiceIndex]}');
      }
      if (quiz.explanation != null && quiz.explanation!.isNotEmpty) {
        buffer.writeln('解説: ${quiz.explanation}');
      }
      buffer.writeln();
    }

    // ルーム状況と立場
    switch (roomType) {
      case 'correct':
        buffer.writeln('【あなたの状況】');
        buffer.writeln('あなたはこのクイズに正解した参加者です。');
        buffer.writeln('現在「正解者ルーム」にいて、同じく正解した他の参加者とチャットしています。');
        buffer.writeln('嬉しさを共有したり、どう解いたか話し合ったり、自然な会話をしてください。');
        break;
      case 'incorrect':
        buffer.writeln('【あなたの状況】');
        buffer.writeln('あなたはこのクイズに不正解だった参加者です。');
        buffer.writeln('現在「不正解者ルーム」にいて、同じく間違えた他の参加者とチャットしています。');
        buffer.writeln('お互いを励まし合ったり、どこが難しかったか話し合ったりしてください。');
        break;
      case 'one_on_one':
        if (isCorrectUser == true) {
          buffer.writeln('【あなたの状況】');
          buffer.writeln('あなたはこのクイズに正解した参加者です。');
          buffer.writeln('現在、不正解だった相手と1対1でチャットしています。');
          buffer.writeln('相手に分かりやすく教えてあげてください。上から目線にならず、優しく丁寧に。');
        } else {
          buffer.writeln('【あなたの状況】');
          buffer.writeln('あなたはこのクイズに不正解だった参加者です。');
          buffer.writeln('現在、正解した相手と1対1でチャットしています。');
          buffer.writeln('分からなかったことを質問したり、教えてもらった内容に反応してください。');
        }
        break;
      case 'common':
        buffer.writeln('【あなたの状況】');
        buffer.writeln('全員（正解者も不正解者も）が集まる共通ルームにいます。');
        buffer.writeln('今回のクイズの感想を共有したり、他の参加者と雑談してください。');
        break;
    }

    buffer.writeln();
    buffer.writeln('日本語で1〜2文の短い返答をしてください。長すぎる返答はしないでください。');
    buffer.writeln('絵文字は使わないか、使っても1つまでにしてください。');

    return buffer.toString();
  }

  // フォールバック用の定型メッセージ
  static const Map<String, List<String>> _fallbackMessages = {
    'correct': [
      'おめでとうございます！',
      'さすがです！',
      'すごい！どうやって分かったんですか？',
      'やりましたね！',
      'ナイス正解！',
    ],
    'incorrect': [
      'ドンマイ！次は頑張りましょう！',
      '惜しかったですね...',
      '難しい問題でしたよね',
      '次のクイズでリベンジ！',
      '一緒に学びましょう！',
    ],
    'one_on_one_correct': [
      'こんにちは！何か質問はありますか？',
      '解説しますね！',
      '分かりにくいところはありますか？',
    ],
    'one_on_one_incorrect': [
      'ありがとうございます！',
      'なるほど！そういうことだったんですね',
      '勉強になります！',
    ],
    'common': [
      'みなさんお疲れ様でした！',
      '今日のクイズ、難しかったですね',
      '楽しかったです！',
      'いい勉強になりました',
    ],
  };

  static T _getRandomElement<T>(List<T> list) {
    return list[_random.nextInt(list.length)];
  }

  static String _getFallbackKey(String roomType, {bool? isCorrectUser}) {
    if (roomType == 'one_on_one') {
      return isCorrectUser == true ? 'one_on_one_correct' : 'one_on_one_incorrect';
    }
    return roomType;
  }

  static String _getFallbackMessage(String roomType, {bool? isCorrectUser}) {
    final key = _getFallbackKey(roomType, isCorrectUser: isCorrectUser);
    final messages = _fallbackMessages[key] ?? _fallbackMessages['common']!;
    return _getRandomElement(messages);
  }

  // LM Studio APIを呼び出し
  static Future<String?> _callLmStudio(
    String systemPrompt,
    List<Map<String, String>> chatHistory,
  ) async {
    try {
      final messages = <Map<String, String>>[
        {'role': 'system', 'content': systemPrompt},
        ...chatHistory,
      ];

      if (chatHistory.isEmpty) {
        messages.add({
          'role': 'user',
          'content': 'チャットルームに参加しました。挨拶や話題を振ってください。',
        });
      }

      final response = await http
          .post(
            Uri.parse('$_lmStudioBaseUrl/chat/completions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'messages': messages,
              'max_tokens': 150,
              'temperature': 0.9,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'] as String?;
        return content?.trim();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // 非同期AIメッセージ生成（複数AI参加者 + クイズコンテキスト）
  static Future<Message> generateAIMessageAsync(
    String roomId,
    String roomType, {
    bool? isCorrectUser,
    List<Message> chatHistory = const [],
    Quiz? quiz,
  }) async {
    // ランダムなAI参加者を選択
    final participant = _pickRandomParticipant(roomId);

    // 動的システムプロンプトを構築
    final systemPrompt = _buildSystemPrompt(
      participantName: participant.displayName,
      roomType: roomType,
      isCorrectUser: isCorrectUser,
      quiz: quiz,
    );

    // チャット履歴をLLM用フォーマットに変換
    final history = chatHistory.map((msg) {
      final role = isAIPartner(msg.senderUserId) ? 'assistant' : 'user';
      return {'role': role, 'content': msg.text ?? ''};
    }).toList();

    final aiText = await _callLmStudio(systemPrompt, history);
    final text = (aiText != null && aiText.trim().isNotEmpty)
        ? aiText
        : _getFallbackMessage(roomType, isCorrectUser: isCorrectUser);

    return Message(
      messageId: const Uuid().v4(),
      roomId: roomId,
      senderUserId: participant.userId,
      type: MessageType.text,
      text: text,
      createdAt: DateTime.now(),
    );
  }

  // 同期版（フォールバック用）
  static Message generateAIMessage(
    String roomId,
    String roomType, {
    bool? isCorrectUser,
  }) {
    final participant = _pickRandomParticipant(roomId);
    final text = _getFallbackMessage(roomType, isCorrectUser: isCorrectUser);

    return Message(
      messageId: const Uuid().v4(),
      roomId: roomId,
      senderUserId: participant.userId,
      type: MessageType.text,
      text: text,
      createdAt: DateTime.now(),
    );
  }

  // AIパートナーを作成（人間を装う）
  static AppUser createAIPartner(bool isCorrectSide) {
    final name = generateNickname();
    final id = 'ai_partner_${isCorrectSide ? 'correct' : 'incorrect'}_${const Uuid().v4().substring(0, 8)}';
    _participantNames[id] = name;
    return AppUser(
      userId: id,
      displayName: name,
      createdAt: DateTime.now(),
      blockedUserIds: [],
    );
  }

  // AIかどうか判定（内部用）
  static bool isAIPartner(String userId) {
    return userId.startsWith('ai_partner_') ||
        userId.startsWith('ai_participant_') ||
        userId == aiUserId;
  }
}
