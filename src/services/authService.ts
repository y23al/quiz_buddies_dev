// 認証サービス
import {
  signInAnonymously,
  onAuthStateChanged,
  User as FirebaseUser,
  signOut,
} from 'firebase/auth';
import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  serverTimestamp,
} from 'firebase/firestore';
import { auth, db, isDemoMode } from '../config/firebase';
import { User } from '../types';
import { generateNickname } from '../utils';

// デモユーザーのストレージ
let demoUser: User | null = null;

// デモモード用のユーザー作成
const createDemoUser = (): User => {
  const userId = 'demo_user_' + Math.random().toString(36).substr(2, 9);
  return {
    userId,
    displayName: generateNickname(),
    createdAt: new Date(),
    blockedUserIds: [],
  };
};

// Firestoreからユーザーデータを取得
export const getUserData = async (userId: string): Promise<User | null> => {
  if (isDemoMode) {
    // デモモードではデモユーザーを返す
    if (demoUser && demoUser.userId === userId) {
      return demoUser;
    }
    return demoUser;
  }

  try {
    const userRef = doc(db, 'users', userId);
    const userSnap = await getDoc(userRef);

    if (userSnap.exists()) {
      const data = userSnap.data();
      return {
        userId: data.userId,
        displayName: data.displayName,
        photoUrl: data.photoUrl,
        createdAt: data.createdAt?.toDate() || new Date(),
        blockedUserIds: data.blockedUserIds || [],
        fcmToken: data.fcmToken,
      };
    }
  } catch (error) {
    console.error('Error getting user data:', error);
  }
  return null;
};

// 新規ユーザーを作成
export const createUser = async (firebaseUser: FirebaseUser): Promise<User> => {
  const user: User = {
    userId: firebaseUser.uid,
    displayName: generateNickname(),
    createdAt: new Date(),
    blockedUserIds: [],
  };

  if (!isDemoMode) {
    try {
      const userRef = doc(db, 'users', firebaseUser.uid);
      await setDoc(userRef, {
        ...user,
        createdAt: serverTimestamp(),
      });
    } catch (error) {
      console.error('Error creating user:', error);
    }
  }

  return user;
};

// 匿名ログイン
export const signInAnonymouslyAsync = async (): Promise<User> => {
  // デモモードの場合
  if (isDemoMode) {
    console.log('Demo mode: Creating demo user');
    demoUser = createDemoUser();
    return demoUser;
  }

  // 本番モード
  const credential = await signInAnonymously(auth);
  const firebaseUser = credential.user;

  // 既存ユーザーを確認
  let user = await getUserData(firebaseUser.uid);

  // 新規ユーザーの場合は作成
  if (!user) {
    user = await createUser(firebaseUser);
  }

  return user;
};

// ログアウト
export const signOutAsync = async (): Promise<void> => {
  if (isDemoMode) {
    demoUser = null;
    return;
  }
  await signOut(auth);
};

// FCMトークンを更新
export const updateFcmToken = async (userId: string, token: string): Promise<void> => {
  if (isDemoMode) return;

  try {
    const userRef = doc(db, 'users', userId);
    await updateDoc(userRef, { fcmToken: token });
  } catch (error) {
    console.error('Error updating FCM token:', error);
  }
};

// ユーザーをブロック
export const blockUser = async (userId: string, targetUserId: string): Promise<void> => {
  if (isDemoMode) {
    if (demoUser && !demoUser.blockedUserIds.includes(targetUserId)) {
      demoUser.blockedUserIds.push(targetUserId);
    }
    return;
  }

  try {
    const userRef = doc(db, 'users', userId);
    const userSnap = await getDoc(userRef);

    if (userSnap.exists()) {
      const blockedUserIds = userSnap.data().blockedUserIds || [];
      if (!blockedUserIds.includes(targetUserId)) {
        blockedUserIds.push(targetUserId);
        await updateDoc(userRef, { blockedUserIds });
      }
    }
  } catch (error) {
    console.error('Error blocking user:', error);
  }
};

// ブロック解除
export const unblockUser = async (userId: string, targetUserId: string): Promise<void> => {
  if (isDemoMode) {
    if (demoUser) {
      demoUser.blockedUserIds = demoUser.blockedUserIds.filter(id => id !== targetUserId);
    }
    return;
  }

  try {
    const userRef = doc(db, 'users', userId);
    const userSnap = await getDoc(userRef);

    if (userSnap.exists()) {
      const blockedUserIds = (userSnap.data().blockedUserIds || []).filter(
        (id: string) => id !== targetUserId
      );
      await updateDoc(userRef, { blockedUserIds });
    }
  } catch (error) {
    console.error('Error unblocking user:', error);
  }
};

// 認証状態の監視
export const subscribeToAuthState = (
  callback: (user: FirebaseUser | null) => void
) => {
  if (isDemoMode) {
    // デモモードでは即座にnullを返す（初期状態）
    // すでにデモユーザーがログイン済みの場合はそのユーザーを返す
    setTimeout(() => {
      if (demoUser) {
        // デモユーザーがいる場合は、ダミーのFirebaseUserとして返す
        callback({ uid: demoUser.userId } as FirebaseUser);
      } else {
        callback(null);
      }
    }, 100);
    return () => {};
  }

  return onAuthStateChanged(auth, callback);
};

// デモユーザーを取得
export const getDemoUser = (): User | null => demoUser;
