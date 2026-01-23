// AIサービス
import 'dart:math';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../utils/nickname_generator.dart';

class AiService {
  static const String aiUserId = 'ai_assistant';
  static const String aiDisplayName = 'クイズBot';

  // グループルームメッセージ
  static const Map<String, List<String>> groupRoomMessages = {
    'correct': [
      'おめでとうございます！',
      'さすがです！',
      '正解率高いですね！',
      'すごい！どうやって分かったんですか？',
      '次のクイズも楽しみですね！',
      'このクイズ、難しかったけど解けましたね！',
      'やりましたね！',
      '勉強になりました！',
      'ナイス正解！',
      '一緒に正解できて嬉しいです！',
    ],
    'incorrect': [
      'ドンマイ！次は頑張りましょう！',
      '惜しかったですね...',
      '私も間違えちゃいました',
      '難しい問題でしたよね',
      '次のクイズでリベンジ！',
      '一緒に学びましょう！',
      'この問題、引っかかりやすいですよね',
      'まだチャンスはありますよ！',
      '正解者に教えてもらいましょう！',
      '次は絶対正解しましょう！',
    ],
  };

  // 1on1メッセージ
  static const Map<String, List<String>> oneOnOneMessages = {
    'correct': [
      'こんにちは！何か質問はありますか？',
      '解説しますね！',
      'ポイントは覚えておくことです',
      '分かりにくいところはありますか？',
      'この問題のコツは...',
      '実は簡単な覚え方があるんです',
      '他に知りたいことはありますか？',
      '一緒に復習しましょう！',
    ],
    'incorrect': [
      'ありがとうございます！',
      'なるほど！そういうことだったんですね',
      '勉強になります！',
      'もう一度説明してもらえますか？',
      '分かりやすいです！',
      'これで次は正解できそう！',
      'メモしておきます',
      '他にコツはありますか？',
    ],
  };

  // 共同ルームメッセージ
  static const List<String> commonRoomMessages = [
    'みなさんお疲れ様でした！',
    '今日のクイズ、難しかったですね',
    '楽しかったです！',
    'また参加したいです！',
    '次のセッションも頑張りましょう！',
    '正解者の方、教えてくれてありがとう！',
    'いい勉強になりました',
    '明日も参加する人いますか？',
    'このアプリ楽しいですね！',
    'みんなで学ぶって良いですね',
  ];

  static final Random _random = Random();

  // ランダムな要素を取得
  static T _getRandomElement<T>(List<T> list) {
    return list[_random.nextInt(list.length)];
  }

  // AIメッセージを生成
  static Message generateAIMessage(
    String roomId,
    String roomType, {
    bool? isCorrectUser,
  }) {
    String text;

    switch (roomType) {
      case 'correct':
        text = _getRandomElement(groupRoomMessages['correct']!);
        break;
      case 'incorrect':
        text = _getRandomElement(groupRoomMessages['incorrect']!);
        break;
      case 'one_on_one':
        text = isCorrectUser == true
            ? _getRandomElement(oneOnOneMessages['correct']!)
            : _getRandomElement(oneOnOneMessages['incorrect']!);
        break;
      case 'common':
        text = _getRandomElement(commonRoomMessages);
        break;
      default:
        text = 'こんにちは！';
    }

    return Message(
      messageId: const Uuid().v4(),
      roomId: roomId,
      senderUserId: aiUserId,
      type: MessageType.text,
      text: text,
      createdAt: DateTime.now(),
    );
  }

  // AIパートナーを作成
  static AppUser createAIPartner(bool isCorrectSide) {
    return AppUser(
      userId: 'ai_partner_${isCorrectSide ? 'correct' : 'incorrect'}_${const Uuid().v4().substring(0, 8)}',
      displayName: '${generateNickname()}（AI）',
      createdAt: DateTime.now(),
      blockedUserIds: [],
    );
  }

  // AIパートナーかどうか判定
  static bool isAIPartner(String userId) {
    return userId.startsWith('ai_partner_') || userId == aiUserId;
  }
}
