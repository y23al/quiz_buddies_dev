// Quiz Buddies 型定義

// ユーザー
export interface User {
  userId: string;
  displayName: string;
  photoUrl?: string;
  createdAt: Date;
  blockedUserIds: string[];
  fcmToken?: string;
}

// セッションフェーズ
export type SessionPhase =
  | 'SCHEDULED'
  | 'JOINABLE'
  | 'QUIZ'
  | 'SPLIT_ROOM'
  | 'MATCHING'
  | 'ONE_ON_ONE'
  | 'COMMON'
  | 'FINISHED';

// セッション
export interface Session {
  sessionId: string;
  scheduledAt: Date;
  joinableUntil: Date;
  phase: SessionPhase;
  quizId: string;
  createdAt: Date;
  // フェーズごとの開始時刻
  phaseStartAt?: Date;
  correctRoomId?: string;
  incorrectRoomId?: string;
  commonRoomId?: string;
}

// クイズ
export interface Quiz {
  quizId: string;
  questionText: string;
  choices: string[];
  correctChoiceIndex: number;
  explanation: string;
  difficulty?: number;
}

// 回答結果
export type AnswerResult = 'CORRECT' | 'INCORRECT' | 'TIMEOUT';

// セッション参加
export interface Participation {
  sessionId: string;
  userId: string;
  joinedAt: Date;
  answer?: number;
  answeredAt?: Date;
  result?: AnswerResult;
  splitRoomAssigned?: 'correct' | 'incorrect';
  oneOnOneRoomId?: string;
  commonRoomJoinedAt?: Date;
}

// ルームタイプ
export type RoomType =
  | 'CORRECT_GROUP'
  | 'INCORRECT_GROUP'
  | 'ONE_ON_ONE'
  | 'COMMON'
  | 'RETEACH_ONE_ON_ONE';

// ルーム
export interface Room {
  roomId: string;
  sessionId: string;
  type: RoomType;
  memberUserIds: string[];
  createdAt: Date;
  expiresAt: Date;
}

// メッセージタイプ
export type MessageType = 'TEXT';

// メッセージ
export interface Message {
  messageId: string;
  roomId: string;
  senderUserId: string;
  type: MessageType;
  text: string;
  createdAt: Date;
  moderationFlags?: string[];
}

// 通報
export interface Report {
  reportId: string;
  roomId: string;
  messageId?: string;
  reporterUserId: string;
  targetUserId: string;
  reason: string;
  createdAt: Date;
}

// イベントログ
export interface EventLog {
  eventId: string;
  eventType: string;
  userId: string;
  sessionId?: string;
  roomId?: string;
  data?: Record<string, unknown>;
  createdAt: Date;
}

// 設定値
export const CONFIG = {
  // 参加期限（秒）
  JOIN_DEADLINE_SECONDS: 120, // 2分
  // クイズ回答時間（秒）
  QUIZ_TIME_SECONDS: 60,
  // 正誤表示後の遷移待機時間（秒）
  RESULT_DISPLAY_SECONDS: 3,
  // グループROOM時間（秒）
  GROUP_ROOM_SECONDS: 30,
  // 1on1 ROOM時間（秒）
  ONE_ON_ONE_SECONDS: 180, // 3分
  // 共同ROOM時間（秒）
  COMMON_ROOM_SECONDS: 300, // 5分
  // 許容時間帯
  SESSION_START_HOUR: 10,
  SESSION_END_HOUR: 22,
  // 1日のセッション数
  SESSIONS_PER_DAY: 2,
  // メッセージレート制限（1秒あたりの最大送信数）
  MESSAGE_RATE_LIMIT: 2,
} as const;

// ナビゲーション型
export type RootStackParamList = {
  Auth: undefined;
  Home: undefined;
  Quiz: { sessionId: string };
  Result: { sessionId: string; isCorrect: boolean };
  GroupRoom: { sessionId: string; roomId: string; roomType: 'correct' | 'incorrect' };
  OneOnOneRoom: { sessionId: string; roomId: string };
  CommonRoom: { sessionId: string; roomId: string };
  Settings: undefined;
};
