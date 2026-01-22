// セッション状態管理
import { create } from 'zustand';
import { Session, Quiz, Participation, Room, Message, SessionPhase, CONFIG } from '../types';

interface SessionState {
  // 現在のセッション
  currentSession: Session | null;
  // 現在のクイズ
  currentQuiz: Quiz | null;
  // 自分の参加情報
  participation: Participation | null;
  // 現在のルーム
  currentRoom: Room | null;
  // メッセージ一覧
  messages: Message[];
  // 残り時間（秒）
  remainingTime: number;
  // ローディング状態
  isLoading: boolean;
  // エラー
  error: string | null;

  // アクション
  setCurrentSession: (session: Session | null) => void;
  setCurrentQuiz: (quiz: Quiz | null) => void;
  setParticipation: (participation: Participation | null) => void;
  setCurrentRoom: (room: Room | null) => void;
  setMessages: (messages: Message[]) => void;
  addMessage: (message: Message) => void;
  setRemainingTime: (time: number) => void;
  decrementRemainingTime: () => void;
  setLoading: (loading: boolean) => void;
  setError: (error: string | null) => void;
  reset: () => void;
}

// フェーズごとの制限時間を取得
export const getPhaseTimeLimit = (phase: SessionPhase): number => {
  switch (phase) {
    case 'QUIZ':
      return CONFIG.QUIZ_TIME_SECONDS;
    case 'SPLIT_ROOM':
      return CONFIG.GROUP_ROOM_SECONDS;
    case 'ONE_ON_ONE':
      return CONFIG.ONE_ON_ONE_SECONDS;
    case 'COMMON':
      return CONFIG.COMMON_ROOM_SECONDS;
    default:
      return 0;
  }
};

export const useSessionStore = create<SessionState>((set) => ({
  currentSession: null,
  currentQuiz: null,
  participation: null,
  currentRoom: null,
  messages: [],
  remainingTime: 0,
  isLoading: false,
  error: null,

  setCurrentSession: (session) => set({ currentSession: session }),
  setCurrentQuiz: (quiz) => set({ currentQuiz: quiz }),
  setParticipation: (participation) => set({ participation }),
  setCurrentRoom: (room) => set({ currentRoom: room }),
  setMessages: (messages) => set({ messages }),
  addMessage: (message) =>
    set((state) => ({
      messages: [...state.messages, message].sort(
        (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime()
      ),
    })),
  setRemainingTime: (time) => set({ remainingTime: Math.max(0, time) }),
  decrementRemainingTime: () =>
    set((state) => ({ remainingTime: Math.max(0, state.remainingTime - 1) })),
  setLoading: (isLoading) => set({ isLoading }),
  setError: (error) => set({ error }),
  reset: () =>
    set({
      currentSession: null,
      currentQuiz: null,
      participation: null,
      currentRoom: null,
      messages: [],
      remainingTime: 0,
      isLoading: false,
      error: null,
    }),
}));
