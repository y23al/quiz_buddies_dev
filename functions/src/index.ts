/**
 * Quiz Buddies Cloud Functions
 *
 * - セッション生成（毎日2回）
 * - 通知送信
 * - マッチング実行
 * - フェーズ遷移管理
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// 設定値
const CONFIG = {
  JOIN_DEADLINE_SECONDS: 120,
  QUIZ_TIME_SECONDS: 60,
  RESULT_DISPLAY_SECONDS: 3,
  GROUP_ROOM_SECONDS: 30,
  ONE_ON_ONE_SECONDS: 180,
  COMMON_ROOM_SECONDS: 300,
  SESSION_START_HOUR: 10,
  SESSION_END_HOUR: 22,
};

// セッションフェーズ
type SessionPhase =
  | 'SCHEDULED'
  | 'JOINABLE'
  | 'QUIZ'
  | 'SPLIT_ROOM'
  | 'MATCHING'
  | 'ONE_ON_ONE'
  | 'COMMON'
  | 'FINISHED';

/**
 * 毎日0時5分にその日のセッションを生成
 */
export const generateDailySessions = functions
  .runWith({ timeoutSeconds: 60 })
  .pubsub
  .schedule('5 0 * * *')
  .timeZone('Asia/Tokyo')
  .onRun(async () => {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    // ランダムな時刻を2つ生成（10時〜22時の間）
    const times: Date[] = [];
    for (let i = 0; i < 2; i++) {
      const hour = CONFIG.SESSION_START_HOUR +
        Math.floor(Math.random() * (CONFIG.SESSION_END_HOUR - CONFIG.SESSION_START_HOUR));
      const minute = Math.floor(Math.random() * 60);
      const sessionTime = new Date(today);
      sessionTime.setHours(hour, minute, 0, 0);
      times.push(sessionTime);
    }

    // 時間順にソート
    times.sort((a, b) => a.getTime() - b.getTime());

    // サンプルクイズを用意（実際の運用ではクイズDBから取得）
    const sampleQuizzes = [
      {
        quizId: `quiz_${Date.now()}_1`,
        questionText: '日本で一番長い川は？',
        choices: ['信濃川', '利根川', '石狩川', '天塩川'],
        correctChoiceIndex: 0,
        explanation: '信濃川は全長367kmで日本最長の川です。',
      },
      {
        quizId: `quiz_${Date.now()}_2`,
        questionText: '太陽系で一番大きい惑星は？',
        choices: ['土星', '木星', '天王星', '海王星'],
        correctChoiceIndex: 1,
        explanation: '木星は太陽系最大の惑星で、地球の約11倍の直径があります。',
      },
    ];

    // セッションを作成
    const batch = db.batch();

    for (let i = 0; i < 2; i++) {
      const sessionId = `session_${today.getTime()}_${i + 1}`;
      const quiz = sampleQuizzes[i];

      // クイズを保存
      const quizRef = db.collection('quizzes').doc(quiz.quizId);
      batch.set(quizRef, quiz);

      // セッションを保存
      const sessionRef = db.collection('sessions').doc(sessionId);
      batch.set(sessionRef, {
        sessionId,
        scheduledAt: admin.firestore.Timestamp.fromDate(times[i]),
        joinableUntil: admin.firestore.Timestamp.fromDate(
          new Date(times[i].getTime() + CONFIG.JOIN_DEADLINE_SECONDS * 1000)
        ),
        phase: 'SCHEDULED' as SessionPhase,
        quizId: quiz.quizId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    console.log(`Generated 2 sessions for ${today.toISOString()}`);
    return null;
  });

/**
 * セッション開始時に通知を送信
 * (scheduledAtの時刻にセッションをJOINABLEに変更し通知)
 */
export const onSessionScheduled = functions
  .runWith({ timeoutSeconds: 60 })
  .firestore
  .document('sessions/{sessionId}')
  .onWrite(async (change, context) => {
    const session = change.after.data();
    if (!session) return;

    const previousSession = change.before.data();

    // SCHEDULEDからJOINABLEへの変更を検知
    if (previousSession?.phase === 'SCHEDULED' && session.phase === 'JOINABLE') {
      // 全ユーザーに通知を送信
      const usersSnapshot = await db.collection('users').get();
      const tokens: string[] = [];

      usersSnapshot.forEach((doc) => {
        const userData = doc.data();
        if (userData.fcmToken) {
          tokens.push(userData.fcmToken);
        }
      });

      if (tokens.length > 0) {
        const message = {
          notification: {
            title: 'クイズが出題されました！',
            body: '今すぐ参加してクイズを解こう！',
          },
          data: {
            sessionId: context.params.sessionId,
            type: 'SESSION_START',
          },
          tokens,
        };

        try {
          const response = await messaging.sendEachForMulticast(message);
          console.log(`Sent notifications: ${response.successCount} success, ${response.failureCount} failed`);
        } catch (error) {
          console.error('Error sending notifications:', error);
        }
      }
    }
  });

/**
 * 参加締切後にルームを作成
 */
export const createRoomsAfterDeadline = functions
  .runWith({ timeoutSeconds: 120 })
  .firestore
  .document('sessions/{sessionId}')
  .onUpdate(async (change, context) => {
    const session = change.after.data();
    const previousSession = change.before.data();

    // JOINABLEからQUIZへの変更を検知
    if (previousSession.phase === 'JOINABLE' && session.phase === 'QUIZ') {
      // QUIZフェーズ開始時刻を記録
      await change.after.ref.update({
        phaseStartAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    // QUIZからSPLIT_ROOMへの変更を検知
    if (previousSession.phase === 'QUIZ' && session.phase === 'SPLIT_ROOM') {
      const sessionId = context.params.sessionId;
      const now = new Date();

      // 正解者ルームを作成
      const correctRoomId = `${sessionId}_correct`;
      const correctRoomRef = db.collection('rooms').doc(correctRoomId);
      await correctRoomRef.set({
        roomId: correctRoomId,
        sessionId,
        type: 'CORRECT_GROUP',
        memberUserIds: [],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromDate(
          new Date(now.getTime() + CONFIG.GROUP_ROOM_SECONDS * 1000)
        ),
      });

      // 不正解者ルームを作成
      const incorrectRoomId = `${sessionId}_incorrect`;
      const incorrectRoomRef = db.collection('rooms').doc(incorrectRoomId);
      await incorrectRoomRef.set({
        roomId: incorrectRoomId,
        sessionId,
        type: 'INCORRECT_GROUP',
        memberUserIds: [],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromDate(
          new Date(now.getTime() + CONFIG.GROUP_ROOM_SECONDS * 1000)
        ),
      });

      // セッションを更新
      await change.after.ref.update({
        correctRoomId,
        incorrectRoomId,
        phaseStartAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

/**
 * グループルーム終了後にマッチング実行
 */
export const executeMatching = functions
  .runWith({ timeoutSeconds: 120 })
  .firestore
  .document('sessions/{sessionId}')
  .onUpdate(async (change, context) => {
    const session = change.after.data();
    const previousSession = change.before.data();

    // SPLIT_ROOMからMATCHINGへの変更を検知
    if (previousSession.phase === 'SPLIT_ROOM' && session.phase === 'MATCHING') {
      const sessionId = context.params.sessionId;

      // 参加者を取得
      const participationsSnapshot = await db
        .collection('participations')
        .where('sessionId', '==', sessionId)
        .get();

      const correctUsers: string[] = [];
      const incorrectUsers: string[] = [];

      participationsSnapshot.forEach((doc) => {
        const data = doc.data();
        if (data.result === 'CORRECT') {
          correctUsers.push(data.userId);
        } else {
          incorrectUsers.push(data.userId);
        }
      });

      // ブロック情報を取得
      const blockMap = new Map<string, string[]>();
      for (const userId of [...correctUsers, ...incorrectUsers]) {
        const userDoc = await db.collection('users').doc(userId).get();
        if (userDoc.exists) {
          blockMap.set(userId, userDoc.data()?.blockedUserIds || []);
        }
      }

      // マッチング実行
      const matches: Array<{ correctUserId: string; incorrectUserId: string }> = [];
      const matchedCorrect = new Set<string>();
      const matchedIncorrect = new Set<string>();

      // シャッフル
      const shuffledCorrect = [...correctUsers].sort(() => Math.random() - 0.5);
      const shuffledIncorrect = [...incorrectUsers].sort(() => Math.random() - 0.5);

      for (const correctUserId of shuffledCorrect) {
        if (matchedCorrect.has(correctUserId)) continue;

        const blockedByCorrect = blockMap.get(correctUserId) || [];

        for (const incorrectUserId of shuffledIncorrect) {
          if (matchedIncorrect.has(incorrectUserId)) continue;

          const blockedByIncorrect = blockMap.get(incorrectUserId) || [];

          // ブロック関係をチェック
          if (
            !blockedByCorrect.includes(incorrectUserId) &&
            !blockedByIncorrect.includes(correctUserId)
          ) {
            matches.push({ correctUserId, incorrectUserId });
            matchedCorrect.add(correctUserId);
            matchedIncorrect.add(incorrectUserId);
            break;
          }
        }
      }

      // 1on1ルームを作成
      const batch = db.batch();
      const now = new Date();

      for (const match of matches) {
        const roomId = `${sessionId}_1on1_${match.correctUserId}_${match.incorrectUserId}`;
        const roomRef = db.collection('rooms').doc(roomId);

        batch.set(roomRef, {
          roomId,
          sessionId,
          type: 'ONE_ON_ONE',
          memberUserIds: [match.correctUserId, match.incorrectUserId],
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          expiresAt: admin.firestore.Timestamp.fromDate(
            new Date(now.getTime() + CONFIG.ONE_ON_ONE_SECONDS * 1000)
          ),
        });

        // 参加情報を更新
        const correctParticipationRef = db
          .collection('participations')
          .doc(`${sessionId}_${match.correctUserId}`);
        batch.update(correctParticipationRef, { oneOnOneRoomId: roomId });

        const incorrectParticipationRef = db
          .collection('participations')
          .doc(`${sessionId}_${match.incorrectUserId}`);
        batch.update(incorrectParticipationRef, { oneOnOneRoomId: roomId });
      }

      await batch.commit();

      // セッションをONE_ON_ONEフェーズに更新
      await change.after.ref.update({
        phase: 'ONE_ON_ONE',
        phaseStartAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

/**
 * 1on1終了後に共同ルームを作成
 */
export const createCommonRoom = functions
  .runWith({ timeoutSeconds: 60 })
  .firestore
  .document('sessions/{sessionId}')
  .onUpdate(async (change, context) => {
    const session = change.after.data();
    const previousSession = change.before.data();

    // ONE_ON_ONEからCOMMONへの変更を検知
    if (previousSession.phase === 'ONE_ON_ONE' && session.phase === 'COMMON') {
      const sessionId = context.params.sessionId;
      const now = new Date();

      // 共同ルームを作成
      const commonRoomId = `${sessionId}_common`;
      const commonRoomRef = db.collection('rooms').doc(commonRoomId);

      await commonRoomRef.set({
        roomId: commonRoomId,
        sessionId,
        type: 'COMMON',
        memberUserIds: [],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromDate(
          new Date(now.getTime() + CONFIG.COMMON_ROOM_SECONDS * 1000)
        ),
      });

      // セッションを更新
      await change.after.ref.update({
        commonRoomId,
        phaseStartAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

/**
 * セッションフェーズを自動遷移させるスケジューラ
 * 1分ごとに実行してフェーズ遷移を管理
 */
export const manageSessionPhases = functions
  .runWith({ timeoutSeconds: 120 })
  .pubsub
  .schedule('every 1 minutes')
  .onRun(async () => {
    const now = new Date();

    // アクティブなセッションを取得
    const sessionsSnapshot = await db
      .collection('sessions')
      .where('phase', 'not-in', ['SCHEDULED', 'FINISHED'])
      .get();

    for (const doc of sessionsSnapshot.docs) {
      const session = doc.data();
      const phaseStartAt = session.phaseStartAt?.toDate() || now;
      const elapsed = (now.getTime() - phaseStartAt.getTime()) / 1000;

      let newPhase: SessionPhase | null = null;

      switch (session.phase) {
        case 'JOINABLE':
          if (elapsed >= CONFIG.JOIN_DEADLINE_SECONDS) {
            newPhase = 'QUIZ';
          }
          break;
        case 'QUIZ':
          if (elapsed >= CONFIG.QUIZ_TIME_SECONDS) {
            newPhase = 'SPLIT_ROOM';
          }
          break;
        case 'SPLIT_ROOM':
          if (elapsed >= CONFIG.GROUP_ROOM_SECONDS) {
            newPhase = 'MATCHING';
          }
          break;
        case 'ONE_ON_ONE':
          if (elapsed >= CONFIG.ONE_ON_ONE_SECONDS) {
            newPhase = 'COMMON';
          }
          break;
        case 'COMMON':
          if (elapsed >= CONFIG.COMMON_ROOM_SECONDS) {
            newPhase = 'FINISHED';
          }
          break;
      }

      if (newPhase) {
        await doc.ref.update({
          phase: newPhase,
          phaseStartAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`Session ${doc.id} transitioned from ${session.phase} to ${newPhase}`);
      }
    }

    // SCHEDULEDセッションをJOINABLEに変更
    const scheduledSnapshot = await db
      .collection('sessions')
      .where('phase', '==', 'SCHEDULED')
      .get();

    for (const doc of scheduledSnapshot.docs) {
      const session = doc.data();
      const scheduledAt = session.scheduledAt?.toDate();

      if (scheduledAt && now >= scheduledAt) {
        await doc.ref.update({
          phase: 'JOINABLE',
          phaseStartAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`Session ${doc.id} is now JOINABLE`);
      }
    }

    return null;
  });

/**
 * イベントログを記録
 */
export const logEvent = functions
  .firestore
  .document('events/{eventId}')
  .onCreate(async (snap) => {
    // イベントログの追加処理
    // 必要に応じて分析用のログを出力
    const event = snap.data();
    console.log(`Event logged: ${event.eventType} by ${event.userId}`);
  });
