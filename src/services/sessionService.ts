// セッションサービス
import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  collection,
  query,
  where,
  getDocs,
  orderBy,
  limit,
  onSnapshot,
  serverTimestamp,
  Timestamp,
} from 'firebase/firestore';
import { db, isDemoMode } from '../config/firebase';
import { Session, Quiz, Participation, AnswerResult, SessionPhase, CONFIG } from '../types';
import { v4 as uuidv4 } from 'uuid';

// デモデータストレージ
let demoSessions: Map<string, Session> = new Map();
let demoQuizzes: Map<string, Quiz> = new Map();
let demoParticipations: Map<string, Participation> = new Map();

// Firestoreのタイムスタンプを日付に変換
const toDate = (timestamp: Timestamp | Date | undefined): Date => {
  if (!timestamp) return new Date();
  if (timestamp instanceof Timestamp) {
    return timestamp.toDate();
  }
  return timestamp;
};

// 現在参加可能なセッションを取得
export const getCurrentSession = async (): Promise<Session | null> => {
  if (isDemoMode) {
    // デモモードでは作成されたセッションを返す
    for (const session of demoSessions.values()) {
      if (['JOINABLE', 'QUIZ', 'SPLIT_ROOM', 'MATCHING', 'ONE_ON_ONE', 'COMMON'].includes(session.phase)) {
        return session;
      }
    }
    return null;
  }

  try {
    const sessionsRef = collection(db, 'sessions');

    // JOINABLEまたは進行中のセッションを検索
    const q = query(
      sessionsRef,
      where('phase', 'in', ['JOINABLE', 'QUIZ', 'SPLIT_ROOM', 'MATCHING', 'ONE_ON_ONE', 'COMMON']),
      orderBy('scheduledAt', 'desc'),
      limit(1)
    );

    const snapshot = await getDocs(q);

    if (snapshot.empty) {
      return null;
    }

    const data = snapshot.docs[0].data();
    return {
      sessionId: data.sessionId,
      scheduledAt: toDate(data.scheduledAt),
      joinableUntil: toDate(data.joinableUntil),
      phase: data.phase as SessionPhase,
      quizId: data.quizId,
      createdAt: toDate(data.createdAt),
      phaseStartAt: toDate(data.phaseStartAt),
      correctRoomId: data.correctRoomId,
      incorrectRoomId: data.incorrectRoomId,
      commonRoomId: data.commonRoomId,
    };
  } catch (error) {
    console.error('Error getting current session:', error);
    return null;
  }
};

// セッションを取得
export const getSession = async (sessionId: string): Promise<Session | null> => {
  if (isDemoMode) {
    return demoSessions.get(sessionId) || null;
  }

  try {
    const sessionRef = doc(db, 'sessions', sessionId);
    const snapshot = await getDoc(sessionRef);

    if (!snapshot.exists()) {
      return null;
    }

    const data = snapshot.data();
    return {
      sessionId: data.sessionId,
      scheduledAt: toDate(data.scheduledAt),
      joinableUntil: toDate(data.joinableUntil),
      phase: data.phase as SessionPhase,
      quizId: data.quizId,
      createdAt: toDate(data.createdAt),
      phaseStartAt: toDate(data.phaseStartAt),
      correctRoomId: data.correctRoomId,
      incorrectRoomId: data.incorrectRoomId,
      commonRoomId: data.commonRoomId,
    };
  } catch (error) {
    console.error('Error getting session:', error);
    return null;
  }
};

// セッションをリアルタイム購読
export const subscribeToSession = (
  sessionId: string,
  callback: (session: Session | null) => void
) => {
  if (isDemoMode) {
    // デモモードでは定期的にセッションをチェック
    const interval = setInterval(() => {
      callback(demoSessions.get(sessionId) || null);
    }, 1000);
    return () => clearInterval(interval);
  }

  try {
    const sessionRef = doc(db, 'sessions', sessionId);

    return onSnapshot(sessionRef, (snapshot) => {
      if (!snapshot.exists()) {
        callback(null);
        return;
      }

      const data = snapshot.data();
      callback({
        sessionId: data.sessionId,
        scheduledAt: toDate(data.scheduledAt),
        joinableUntil: toDate(data.joinableUntil),
        phase: data.phase as SessionPhase,
        quizId: data.quizId,
        createdAt: toDate(data.createdAt),
        phaseStartAt: toDate(data.phaseStartAt),
        correctRoomId: data.correctRoomId,
        incorrectRoomId: data.incorrectRoomId,
        commonRoomId: data.commonRoomId,
      });
    });
  } catch (error) {
    console.error('Error subscribing to session:', error);
    return () => {};
  }
};

// クイズを取得
export const getQuiz = async (quizId: string): Promise<Quiz | null> => {
  if (isDemoMode) {
    return demoQuizzes.get(quizId) || null;
  }

  try {
    const quizRef = doc(db, 'quizzes', quizId);
    const snapshot = await getDoc(quizRef);

    if (!snapshot.exists()) {
      return null;
    }

    const data = snapshot.data();
    return {
      quizId: data.quizId,
      questionText: data.questionText,
      choices: data.choices,
      correctChoiceIndex: data.correctChoiceIndex,
      explanation: data.explanation,
      difficulty: data.difficulty,
    };
  } catch (error) {
    console.error('Error getting quiz:', error);
    return null;
  }
};

// セッションに参加
export const joinSession = async (
  sessionId: string,
  userId: string
): Promise<Participation> => {
  const participationId = `${sessionId}_${userId}`;

  if (isDemoMode) {
    const existing = demoParticipations.get(participationId);
    if (existing) return existing;

    const participation: Participation = {
      sessionId,
      userId,
      joinedAt: new Date(),
    };
    demoParticipations.set(participationId, participation);
    return participation;
  }

  try {
    const participationRef = doc(db, 'participations', participationId);

    // 既存の参加を確認
    const existing = await getDoc(participationRef);
    if (existing.exists()) {
      const data = existing.data();
      return {
        sessionId: data.sessionId,
        userId: data.userId,
        joinedAt: toDate(data.joinedAt),
        answer: data.answer,
        answeredAt: data.answeredAt ? toDate(data.answeredAt) : undefined,
        result: data.result,
        splitRoomAssigned: data.splitRoomAssigned,
        oneOnOneRoomId: data.oneOnOneRoomId,
        commonRoomJoinedAt: data.commonRoomJoinedAt
          ? toDate(data.commonRoomJoinedAt)
          : undefined,
      };
    }

    // 新規参加を作成
    const participation: Participation = {
      sessionId,
      userId,
      joinedAt: new Date(),
    };

    await setDoc(participationRef, {
      ...participation,
      userId,
      joinedAt: serverTimestamp(),
    });

    return participation;
  } catch (error) {
    console.error('Error joining session:', error);
    // エラー時もデモのように動作
    const participation: Participation = {
      sessionId,
      userId,
      joinedAt: new Date(),
    };
    demoParticipations.set(participationId, participation);
    return participation;
  }
};

// 参加情報を取得
export const getParticipation = async (
  sessionId: string,
  userId: string
): Promise<Participation | null> => {
  const participationId = `${sessionId}_${userId}`;

  if (isDemoMode) {
    return demoParticipations.get(participationId) || null;
  }

  try {
    const participationRef = doc(db, 'participations', participationId);
    const snapshot = await getDoc(participationRef);

    if (!snapshot.exists()) {
      return null;
    }

    const data = snapshot.data();
    return {
      sessionId: data.sessionId,
      userId: data.userId,
      joinedAt: toDate(data.joinedAt),
      answer: data.answer,
      answeredAt: data.answeredAt ? toDate(data.answeredAt) : undefined,
      result: data.result,
      splitRoomAssigned: data.splitRoomAssigned,
      oneOnOneRoomId: data.oneOnOneRoomId,
      commonRoomJoinedAt: data.commonRoomJoinedAt
        ? toDate(data.commonRoomJoinedAt)
        : undefined,
    };
  } catch (error) {
    console.error('Error getting participation:', error);
    return demoParticipations.get(participationId) || null;
  }
};

// 参加情報をリアルタイム購読
export const subscribeToParticipation = (
  sessionId: string,
  userId: string,
  callback: (participation: Participation | null) => void
) => {
  const participationId = `${sessionId}_${userId}`;

  if (isDemoMode) {
    const interval = setInterval(() => {
      callback(demoParticipations.get(participationId) || null);
    }, 1000);
    return () => clearInterval(interval);
  }

  try {
    const participationRef = doc(db, 'participations', participationId);

    return onSnapshot(participationRef, (snapshot) => {
      if (!snapshot.exists()) {
        callback(null);
        return;
      }

      const data = snapshot.data();
      callback({
        sessionId: data.sessionId,
        userId: data.userId,
        joinedAt: toDate(data.joinedAt),
        answer: data.answer,
        answeredAt: data.answeredAt ? toDate(data.answeredAt) : undefined,
        result: data.result,
        splitRoomAssigned: data.splitRoomAssigned,
        oneOnOneRoomId: data.oneOnOneRoomId,
        commonRoomJoinedAt: data.commonRoomJoinedAt
          ? toDate(data.commonRoomJoinedAt)
          : undefined,
      });
    });
  } catch (error) {
    console.error('Error subscribing to participation:', error);
    return () => {};
  }
};

// 回答を送信（サーバーサイドで採点）
export const submitAnswer = async (
  sessionId: string,
  userId: string,
  answerIndex: number
): Promise<AnswerResult> => {
  const participationId = `${sessionId}_${userId}`;

  // クイズを取得して採点
  const session = await getSession(sessionId);
  if (!session) {
    throw new Error('Session not found');
  }

  const quiz = await getQuiz(session.quizId);
  if (!quiz) {
    throw new Error('Quiz not found');
  }

  // 採点
  const isCorrect = answerIndex === quiz.correctChoiceIndex;
  const result: AnswerResult = isCorrect ? 'CORRECT' : 'INCORRECT';
  const splitRoomAssigned = isCorrect ? 'correct' : 'incorrect';

  if (isDemoMode) {
    const participation = demoParticipations.get(participationId);
    if (participation) {
      participation.answer = answerIndex;
      participation.answeredAt = new Date();
      participation.result = result;
      participation.splitRoomAssigned = splitRoomAssigned;
    }
    return result;
  }

  try {
    const participationRef = doc(db, 'participations', participationId);

    // 参加情報を更新
    await updateDoc(participationRef, {
      answer: answerIndex,
      answeredAt: serverTimestamp(),
      result,
      splitRoomAssigned,
    });
  } catch (error) {
    console.error('Error submitting answer:', error);
  }

  return result;
};

// タイムアウト処理
export const handleTimeout = async (
  sessionId: string,
  userId: string
): Promise<void> => {
  const participationId = `${sessionId}_${userId}`;

  if (isDemoMode) {
    const participation = demoParticipations.get(participationId);
    if (participation) {
      participation.result = 'TIMEOUT';
      participation.splitRoomAssigned = 'incorrect';
    }
    return;
  }

  try {
    const participationRef = doc(db, 'participations', participationId);

    await updateDoc(participationRef, {
      result: 'TIMEOUT',
      splitRoomAssigned: 'incorrect',
    });
  } catch (error) {
    console.error('Error handling timeout:', error);
  }
};

// サンプルクイズを作成（開発用）
export const createSampleQuiz = async (): Promise<Quiz> => {
  const quiz: Quiz = {
    quizId: uuidv4(),
    questionText: '日本で一番高い山は？',
    choices: ['富士山', '北岳', '奥穂高岳', '槍ヶ岳'],
    correctChoiceIndex: 0,
    explanation: '富士山は標高3,776mで日本一高い山です。2番目は北岳（3,193m）です。',
  };

  if (isDemoMode) {
    demoQuizzes.set(quiz.quizId, quiz);
    return quiz;
  }

  try {
    const quizRef = doc(db, 'quizzes', quiz.quizId);
    await setDoc(quizRef, quiz);
  } catch (error) {
    console.error('Error creating sample quiz:', error);
    demoQuizzes.set(quiz.quizId, quiz);
  }

  return quiz;
};

// サンプルセッションを作成（開発用）
export const createSampleSession = async (quizId: string): Promise<Session> => {
  const now = new Date();
  const sessionId = uuidv4();

  const session: Session = {
    sessionId,
    scheduledAt: now,
    joinableUntil: new Date(now.getTime() + CONFIG.JOIN_DEADLINE_SECONDS * 1000),
    phase: 'JOINABLE',
    quizId,
    createdAt: now,
    phaseStartAt: now,
    correctRoomId: `${sessionId}_correct`,
    incorrectRoomId: `${sessionId}_incorrect`,
    commonRoomId: `${sessionId}_common`,
  };

  if (isDemoMode) {
    demoSessions.set(sessionId, session);
    return session;
  }

  try {
    const sessionRef = doc(db, 'sessions', sessionId);
    await setDoc(sessionRef, {
      ...session,
      scheduledAt: Timestamp.fromDate(session.scheduledAt),
      joinableUntil: Timestamp.fromDate(session.joinableUntil),
      createdAt: serverTimestamp(),
      phaseStartAt: serverTimestamp(),
    });
  } catch (error) {
    console.error('Error creating sample session:', error);
    demoSessions.set(sessionId, session);
  }

  return session;
};

// デモセッションを更新（フェーズ遷移用）
export const updateDemoSession = (sessionId: string, updates: Partial<Session>) => {
  const session = demoSessions.get(sessionId);
  if (session) {
    Object.assign(session, updates);
  }
};

// デモモード用: 参加情報を更新
export const updateDemoParticipation = (
  sessionId: string,
  userId: string,
  updates: Partial<Participation>
) => {
  const participationId = `${sessionId}_${userId}`;
  const participation = demoParticipations.get(participationId);
  if (participation) {
    Object.assign(participation, updates);
  }
};

// デモモード用: セッションの全参加者を取得
export const getDemoParticipants = (sessionId: string): Participation[] => {
  const participants: Participation[] = [];
  for (const [key, participation] of demoParticipations.entries()) {
    if (key.startsWith(sessionId)) {
      participants.push(participation);
    }
  }
  return participants;
};

// デモモード用: マッチング相手を見つける（または作成する）
export const findOrCreateMatch = async (
  sessionId: string,
  userId: string,
  userResult: AnswerResult
): Promise<{ partnerId: string; roomId: string; isAI: boolean }> => {
  const participationId = `${sessionId}_${userId}`;
  const participation = demoParticipations.get(participationId);

  if (participation?.oneOnOneRoomId) {
    // 既にマッチング済み
    return {
      partnerId: '',
      roomId: participation.oneOnOneRoomId,
      isAI: false,
    };
  }

  // 相手を探す（正解者は不正解者と、不正解者は正解者とマッチング）
  const targetResult: AnswerResult = userResult === 'CORRECT' ? 'INCORRECT' : 'CORRECT';

  for (const [key, p] of demoParticipations.entries()) {
    if (!key.startsWith(sessionId)) continue;
    if (p.userId === userId) continue;
    if (p.result !== targetResult) continue;
    if (p.oneOnOneRoomId) continue; // 既にマッチング済みはスキップ

    // マッチング成功
    const roomId = `${sessionId}_1on1_${uuidv4().slice(0, 8)}`;

    // 両者の参加情報を更新
    if (participation) {
      participation.oneOnOneRoomId = roomId;
    }
    p.oneOnOneRoomId = roomId;

    return {
      partnerId: p.userId,
      roomId,
      isAI: false,
    };
  }

  // 相手が見つからない場合はAIとマッチング
  const { createAIPartner } = await import('./aiService');
  const aiPartner = createAIPartner(userResult !== 'CORRECT');
  const roomId = `${sessionId}_1on1_ai_${uuidv4().slice(0, 8)}`;

  // AI参加者を作成
  const aiParticipationId = `${sessionId}_${aiPartner.userId}`;
  const aiParticipation: Participation = {
    sessionId,
    userId: aiPartner.userId,
    joinedAt: new Date(),
    result: targetResult,
    splitRoomAssigned: targetResult === 'CORRECT' ? 'correct' : 'incorrect',
    oneOnOneRoomId: roomId,
  };
  demoParticipations.set(aiParticipationId, aiParticipation);

  // ユーザーの参加情報を更新
  if (participation) {
    participation.oneOnOneRoomId = roomId;
  }

  return {
    partnerId: aiPartner.userId,
    roomId,
    isAI: true,
  };
};
