// AIサービス - 自動メッセージとAIマッチング
import { v4 as uuidv4 } from 'uuid';
import { Message, User } from '../types';
import { generateNickname } from '../utils';

// AI用のユーザーID
export const AI_USER_ID = 'ai_assistant';
export const AI_DISPLAY_NAME = 'クイズBot';

// AIユーザーを作成
export const createAIUser = (): User => ({
  userId: AI_USER_ID,
  displayName: AI_DISPLAY_NAME,
  createdAt: new Date(),
  blockedUserIds: [],
});

// ランダムメッセージのテンプレート
const GROUP_ROOM_MESSAGES = {
  correct: [
    'おめでとうございます！🎉',
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
  incorrect: [
    'ドンマイ！次は頑張りましょう！',
    '惜しかったですね...',
    '私も間違えちゃいました😅',
    '難しい問題でしたよね',
    '次のクイズでリベンジ！',
    '一緒に学びましょう！',
    'この問題、引っかかりやすいですよね',
    'まだチャンスはありますよ！',
    '正解者に教えてもらいましょう！',
    '次は絶対正解しましょう！',
  ],
};

const ONE_ON_ONE_MESSAGES = {
  correct: [
    'こんにちは！何か質問はありますか？',
    '解説しますね！',
    'ポイントは〇〇を覚えておくことです',
    '分かりにくいところはありますか？',
    'この問題のコツは...',
    '実は簡単な覚え方があるんです',
    '他に知りたいことはありますか？',
    '一緒に復習しましょう！',
  ],
  incorrect: [
    'ありがとうございます！',
    'なるほど！そういうことだったんですね',
    '勉強になります！',
    'もう一度説明してもらえますか？',
    '分かりやすいです！',
    'これで次は正解できそう！',
    'メモしておきます📝',
    '他にコツはありますか？',
  ],
};

const COMMON_ROOM_MESSAGES = [
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

// ランダムな要素を取得
const getRandomElement = <T>(array: T[]): T => {
  return array[Math.floor(Math.random() * array.length)];
};

// AIメッセージを生成
export const generateAIMessage = (
  roomId: string,
  roomType: 'correct' | 'incorrect' | 'one_on_one' | 'common',
  isCorrectUser?: boolean // 1on1の場合、このAIが正解者側かどうか
): Message => {
  let text: string;

  switch (roomType) {
    case 'correct':
      text = getRandomElement(GROUP_ROOM_MESSAGES.correct);
      break;
    case 'incorrect':
      text = getRandomElement(GROUP_ROOM_MESSAGES.incorrect);
      break;
    case 'one_on_one':
      text = isCorrectUser
        ? getRandomElement(ONE_ON_ONE_MESSAGES.correct)
        : getRandomElement(ONE_ON_ONE_MESSAGES.incorrect);
      break;
    case 'common':
      text = getRandomElement(COMMON_ROOM_MESSAGES);
      break;
    default:
      text = 'こんにちは！';
  }

  return {
    messageId: uuidv4(),
    roomId,
    senderUserId: AI_USER_ID,
    type: 'TEXT',
    text,
    createdAt: new Date(),
  };
};

// AIパートナーを作成（1on1でマッチング相手がいない場合）
export const createAIPartner = (isCorrectSide: boolean): User => ({
  userId: `ai_partner_${isCorrectSide ? 'correct' : 'incorrect'}_${uuidv4().slice(0, 8)}`,
  displayName: `${generateNickname()}（AI）`,
  createdAt: new Date(),
  blockedUserIds: [],
});

// AIパートナーかどうかを判定
export const isAIPartner = (userId: string): boolean => {
  return userId.startsWith('ai_partner_') || userId === AI_USER_ID;
};

// 会話を活性化するメッセージ
const CONVERSATION_STARTERS = [
  'みなさん、調子はどうですか？',
  '今日のクイズについてどう思いますか？',
  '何か面白い話はありますか？',
  '次のクイズも頑張りましょう！',
];

export const generateConversationStarter = (roomId: string): Message => ({
  messageId: uuidv4(),
  roomId,
  senderUserId: AI_USER_ID,
  type: 'TEXT',
  text: getRandomElement(CONVERSATION_STARTERS),
  createdAt: new Date(),
});
