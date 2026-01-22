// ルーム・チャットサービス
import {
  doc,
  getDoc,
  setDoc,
  collection,
  query,
  orderBy,
  limit,
  getDocs,
  onSnapshot,
  addDoc,
  serverTimestamp,
  Timestamp,
  updateDoc,
  arrayUnion,
} from 'firebase/firestore';
import { db, isDemoMode } from '../config/firebase';
import { Room, Message, RoomType, CONFIG, Report } from '../types';
import { v4 as uuidv4 } from 'uuid';

// デモデータストレージ
const demoRooms: Map<string, Room> = new Map();
const demoMessages: Map<string, Message[]> = new Map();

// Firestoreのタイムスタンプを日付に変換
const toDate = (timestamp: Timestamp | Date | undefined): Date => {
  if (!timestamp) return new Date();
  if (timestamp instanceof Timestamp) {
    return timestamp.toDate();
  }
  return timestamp;
};

// ルームを取得
export const getRoom = async (roomId: string): Promise<Room | null> => {
  if (isDemoMode) {
    // デモモードではルームを自動作成
    if (!demoRooms.has(roomId)) {
      const now = new Date();
      const room: Room = {
        roomId,
        sessionId: roomId.split('_')[0],
        type: roomId.includes('correct') ? 'CORRECT_GROUP' : roomId.includes('incorrect') ? 'INCORRECT_GROUP' : 'COMMON',
        memberUserIds: [],
        createdAt: now,
        expiresAt: new Date(now.getTime() + CONFIG.GROUP_ROOM_SECONDS * 1000),
      };
      demoRooms.set(roomId, room);
    }
    return demoRooms.get(roomId) || null;
  }

  try {
    const roomRef = doc(db, 'rooms', roomId);
    const snapshot = await getDoc(roomRef);

    if (!snapshot.exists()) {
      return null;
    }

    const data = snapshot.data();
    return {
      roomId: data.roomId,
      sessionId: data.sessionId,
      type: data.type as RoomType,
      memberUserIds: data.memberUserIds,
      createdAt: toDate(data.createdAt),
      expiresAt: toDate(data.expiresAt),
    };
  } catch (error) {
    console.error('Error getting room:', error);
    return null;
  }
};

// ルームをリアルタイム購読
export const subscribeToRoom = (
  roomId: string,
  callback: (room: Room | null) => void
) => {
  if (isDemoMode) {
    // デモモードでは定期的にルームをチェック
    const checkRoom = async () => {
      const room = await getRoom(roomId);
      callback(room);
    };
    checkRoom();
    const interval = setInterval(checkRoom, 1000);
    return () => clearInterval(interval);
  }

  try {
    const roomRef = doc(db, 'rooms', roomId);

    return onSnapshot(roomRef, (snapshot) => {
      if (!snapshot.exists()) {
        callback(null);
        return;
      }

      const data = snapshot.data();
      callback({
        roomId: data.roomId,
        sessionId: data.sessionId,
        type: data.type as RoomType,
        memberUserIds: data.memberUserIds,
        createdAt: toDate(data.createdAt),
        expiresAt: toDate(data.expiresAt),
      });
    });
  } catch (error) {
    console.error('Error subscribing to room:', error);
    return () => {};
  }
};

// ルームを作成
export const createRoom = async (
  sessionId: string,
  type: RoomType,
  memberUserIds: string[],
  durationSeconds: number
): Promise<Room> => {
  const roomId = uuidv4();
  const now = new Date();
  const expiresAt = new Date(now.getTime() + durationSeconds * 1000);

  const room: Room = {
    roomId,
    sessionId,
    type,
    memberUserIds,
    createdAt: now,
    expiresAt,
  };

  if (isDemoMode) {
    demoRooms.set(roomId, room);
    return room;
  }

  try {
    const roomRef = doc(db, 'rooms', roomId);
    await setDoc(roomRef, {
      ...room,
      createdAt: serverTimestamp(),
      expiresAt: Timestamp.fromDate(expiresAt),
    });
  } catch (error) {
    console.error('Error creating room:', error);
    demoRooms.set(roomId, room);
  }

  return room;
};

// ルームにユーザーを追加
export const joinRoom = async (roomId: string, userId: string): Promise<void> => {
  if (isDemoMode) {
    const room = demoRooms.get(roomId);
    if (room && !room.memberUserIds.includes(userId)) {
      room.memberUserIds.push(userId);
    }
    return;
  }

  try {
    const roomRef = doc(db, 'rooms', roomId);
    await updateDoc(roomRef, {
      memberUserIds: arrayUnion(userId),
    });
  } catch (error) {
    console.error('Error joining room:', error);
    // フォールバック
    const room = demoRooms.get(roomId);
    if (room && !room.memberUserIds.includes(userId)) {
      room.memberUserIds.push(userId);
    }
  }
};

// メッセージを取得（最新N件）
export const getMessages = async (
  roomId: string,
  limitCount: number = 100
): Promise<Message[]> => {
  if (isDemoMode) {
    return demoMessages.get(roomId) || [];
  }

  try {
    const messagesRef = collection(db, 'rooms', roomId, 'messages');
    const q = query(messagesRef, orderBy('createdAt', 'desc'), limit(limitCount));

    const snapshot = await getDocs(q);
    const messages: Message[] = [];

    snapshot.forEach((doc) => {
      const data = doc.data();
      messages.push({
        messageId: doc.id,
        roomId: data.roomId,
        senderUserId: data.senderUserId,
        type: data.type,
        text: data.text,
        createdAt: toDate(data.createdAt),
        moderationFlags: data.moderationFlags,
      });
    });

    return messages.reverse();
  } catch (error) {
    console.error('Error getting messages:', error);
    return demoMessages.get(roomId) || [];
  }
};

// メッセージをリアルタイム購読
export const subscribeToMessages = (
  roomId: string,
  callback: (messages: Message[]) => void
) => {
  if (isDemoMode) {
    // デモモードでは定期的にメッセージをチェック
    const interval = setInterval(() => {
      callback(demoMessages.get(roomId) || []);
    }, 500);
    callback(demoMessages.get(roomId) || []);
    return () => clearInterval(interval);
  }

  try {
    const messagesRef = collection(db, 'rooms', roomId, 'messages');
    const q = query(messagesRef, orderBy('createdAt', 'asc'), limit(200));

    return onSnapshot(q, (snapshot) => {
      const messages: Message[] = [];

      snapshot.forEach((doc) => {
        const data = doc.data();
        messages.push({
          messageId: doc.id,
          roomId: data.roomId,
          senderUserId: data.senderUserId,
          type: data.type,
          text: data.text,
          createdAt: toDate(data.createdAt),
          moderationFlags: data.moderationFlags,
        });
      });

      callback(messages);
    });
  } catch (error) {
    console.error('Error subscribing to messages:', error);
    return () => {};
  }
};

// NGワードリスト（簡易版）
const NG_WORDS: string[] = [
  // 実際の運用では適切なNGワードリストを設定
];

// メッセージのバリデーション
const validateMessage = (text: string): { valid: boolean; flags: string[] } => {
  const flags: string[] = [];

  // 空メッセージチェック
  if (!text || text.trim().length === 0) {
    return { valid: false, flags: ['EMPTY'] };
  }

  // 長さチェック（500文字まで）
  if (text.length > 500) {
    return { valid: false, flags: ['TOO_LONG'] };
  }

  // NGワードチェック
  for (const word of NG_WORDS) {
    if (text.toLowerCase().includes(word.toLowerCase())) {
      flags.push('NG_WORD');
      break;
    }
  }

  return { valid: true, flags };
};

// レート制限チェック用のキャッシュ
const rateLimitCache = new Map<string, number[]>();

// レート制限チェック
const checkRateLimit = (userId: string): boolean => {
  const now = Date.now();
  const windowMs = 1000; // 1秒
  const maxMessages = CONFIG.MESSAGE_RATE_LIMIT;

  const timestamps = rateLimitCache.get(userId) || [];
  const recentTimestamps = timestamps.filter((t) => now - t < windowMs);

  if (recentTimestamps.length >= maxMessages) {
    return false;
  }

  recentTimestamps.push(now);
  rateLimitCache.set(userId, recentTimestamps);
  return true;
};

// メッセージを送信
export const sendMessage = async (
  roomId: string,
  senderUserId: string,
  text: string
): Promise<Message | null> => {
  // レート制限チェック
  if (!checkRateLimit(senderUserId)) {
    throw new Error('Rate limit exceeded');
  }

  // バリデーション
  const validation = validateMessage(text);
  if (!validation.valid) {
    throw new Error('Invalid message');
  }

  const message: Message = {
    messageId: uuidv4(),
    roomId,
    senderUserId,
    type: 'TEXT',
    text: text.trim(),
    createdAt: new Date(),
    moderationFlags: validation.flags.length > 0 ? validation.flags : undefined,
  };

  if (isDemoMode) {
    const messages = demoMessages.get(roomId) || [];
    messages.push(message);
    demoMessages.set(roomId, messages);
    return message;
  }

  try {
    const messagesRef = collection(db, 'rooms', roomId, 'messages');
    const messageData = {
      roomId,
      senderUserId,
      type: 'TEXT' as const,
      text: text.trim(),
      createdAt: serverTimestamp(),
      moderationFlags: validation.flags.length > 0 ? validation.flags : undefined,
    };

    const docRef = await addDoc(messagesRef, messageData);
    message.messageId = docRef.id;
  } catch (error) {
    console.error('Error sending message:', error);
    // フォールバック
    const messages = demoMessages.get(roomId) || [];
    messages.push(message);
    demoMessages.set(roomId, messages);
  }

  return message;
};

// 通報を送信
export const reportMessage = async (
  roomId: string,
  messageId: string | undefined,
  reporterUserId: string,
  targetUserId: string,
  reason: string
): Promise<void> => {
  if (isDemoMode) {
    console.log('Demo mode: Report submitted', { roomId, messageId, targetUserId, reason });
    return;
  }

  try {
    const report: Omit<Report, 'reportId'> = {
      roomId,
      messageId,
      reporterUserId,
      targetUserId,
      reason,
      createdAt: new Date(),
    };

    const reportsRef = collection(db, 'reports');
    await addDoc(reportsRef, {
      ...report,
      createdAt: serverTimestamp(),
    });

    // イベントログにも記録
    const eventsRef = collection(db, 'events');
    await addDoc(eventsRef, {
      eventType: 'REPORT',
      userId: reporterUserId,
      roomId,
      data: { targetUserId, reason, messageId },
      createdAt: serverTimestamp(),
    });
  } catch (error) {
    console.error('Error reporting message:', error);
  }
};

// グループROOMを作成（正解者/不正解者）
export const createGroupRoom = async (
  sessionId: string,
  type: 'CORRECT_GROUP' | 'INCORRECT_GROUP'
): Promise<Room> => {
  return createRoom(sessionId, type, [], CONFIG.GROUP_ROOM_SECONDS);
};

// 1on1 ROOMを作成
export const createOneOnOneRoom = async (
  sessionId: string,
  correctUserId: string,
  incorrectUserId: string
): Promise<Room> => {
  return createRoom(
    sessionId,
    'ONE_ON_ONE',
    [correctUserId, incorrectUserId],
    CONFIG.ONE_ON_ONE_SECONDS
  );
};

// 共同ROOMを作成
export const createCommonRoom = async (sessionId: string): Promise<Room> => {
  return createRoom(sessionId, 'COMMON', [], CONFIG.COMMON_ROOM_SECONDS);
};
