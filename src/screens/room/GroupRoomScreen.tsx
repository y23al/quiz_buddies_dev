// グループルーム画面（正解者ROOM / 不正解者ROOM）
import React, { useEffect, useState, useRef, useCallback } from 'react';
import {
  View,
  Text,
  FlatList,
  StyleSheet,
  SafeAreaView,
  Alert,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import { useNavigation, useRoute, RouteProp } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useAuthStore, useSessionStore } from '../../store';
import {
  subscribeToMessages,
  sendMessage,
  subscribeToSession,
  joinRoom,
  getRoom,
  subscribeToParticipation,
} from '../../services';
import { RootStackParamList, Message, CONFIG } from '../../types';
import { Timer, ChatMessage, ChatInput, LoadingScreen } from '../../components';
import { calculateRemainingTime } from '../../utils';

type NavigationProp = NativeStackNavigationProp<RootStackParamList>;
type GroupRoomRouteProp = RouteProp<RootStackParamList, 'GroupRoom'>;

export const GroupRoomScreen: React.FC = () => {
  const navigation = useNavigation<NavigationProp>();
  const route = useRoute<GroupRoomRouteProp>();
  const { sessionId, roomId, roomType } = route.params;
  const { user } = useAuthStore();
  const { setMessages } = useSessionStore();

  const [messages, setLocalMessages] = useState<Message[]>([]);
  const [remainingTime, setRemainingTime] = useState(CONFIG.GROUP_ROOM_SECONDS);
  const [isLoading, setIsLoading] = useState(true);
  const flatListRef = useRef<FlatList>(null);
  const timerRef = useRef<NodeJS.Timeout | null>(null);

  // ルームに参加
  useEffect(() => {
    const joinAndSetup = async () => {
      if (!user) return;

      try {
        await joinRoom(roomId, user.userId);

        // ルーム情報を取得して残り時間を計算
        const room = await getRoom(roomId);
        if (room) {
          const remaining = calculateRemainingTime(room.createdAt, CONFIG.GROUP_ROOM_SECONDS);
          setRemainingTime(remaining);
        }

        setIsLoading(false);
      } catch (error) {
        console.error('Error joining room:', error);
        setIsLoading(false);
      }
    };

    joinAndSetup();
  }, [roomId, user]);

  // メッセージをリアルタイム購読
  useEffect(() => {
    const unsubscribe = subscribeToMessages(roomId, (newMessages) => {
      setLocalMessages(newMessages);
      setMessages(newMessages);
    });

    return () => unsubscribe();
  }, [roomId, setMessages]);

  // 参加情報を監視して1on1ルームへの遷移を検知
  useEffect(() => {
    if (!user) return;

    const unsubscribe = subscribeToParticipation(sessionId, user.userId, (participation) => {
      if (participation?.oneOnOneRoomId) {
        navigation.replace('OneOnOneRoom', {
          sessionId,
          roomId: participation.oneOnOneRoomId,
        });
      }
    });

    return () => unsubscribe();
  }, [sessionId, user, navigation]);

  // セッション状態を監視
  useEffect(() => {
    const unsubscribe = subscribeToSession(sessionId, (session) => {
      if (!session) return;

      // マッチングフェーズまたは共同ルームフェーズに遷移した場合
      if (session.phase === 'COMMON' && session.commonRoomId) {
        navigation.replace('CommonRoom', {
          sessionId,
          roomId: session.commonRoomId,
        });
      }
    });

    return () => unsubscribe();
  }, [sessionId, navigation]);

  // タイマー
  useEffect(() => {
    timerRef.current = setInterval(() => {
      setRemainingTime((prev) => {
        if (prev <= 1) {
          // タイマー終了
          return 0;
        }
        return prev - 1;
      });
    }, 1000);

    return () => {
      if (timerRef.current) {
        clearInterval(timerRef.current);
      }
    };
  }, []);

  const handleSendMessage = useCallback(async (text: string) => {
    if (!user) return;

    try {
      await sendMessage(roomId, user.userId, text);
    } catch (error: any) {
      if (error.message === 'Rate limit exceeded') {
        Alert.alert('送信制限', 'メッセージの送信が速すぎます。少し待ってから再度お試しください。');
      } else {
        Alert.alert('エラー', 'メッセージの送信に失敗しました');
      }
    }
  }, [roomId, user]);

  const renderMessage = ({ item }: { item: Message }) => (
    <ChatMessage
      message={item}
      isOwnMessage={item.senderUserId === user?.userId}
      senderName={item.senderUserId === user?.userId ? undefined : '参加者'}
    />
  );

  if (isLoading) {
    return <LoadingScreen message="ルームに参加中..." />;
  }

  const isCorrectRoom = roomType === 'correct';

  return (
    <SafeAreaView style={[styles.container, isCorrectRoom ? styles.correctRoom : styles.incorrectRoom]}>
      <View style={styles.header}>
        <View style={[styles.badge, isCorrectRoom ? styles.correctBadge : styles.incorrectBadge]}>
          <Text style={styles.badgeText}>
            {isCorrectRoom ? '正解者ルーム' : '不正解者ルーム'}
          </Text>
        </View>
        <Timer remainingTime={remainingTime} label="残り時間" />
        <Text style={styles.headerDescription}>
          {isCorrectRoom
            ? 'おめでとうございます！正解者同士で交流しましょう'
            : 'ドンマイ！同じ仲間と励まし合いましょう'}
        </Text>
      </View>

      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        style={styles.chatContainer}
        keyboardVerticalOffset={90}
      >
        <FlatList
          ref={flatListRef}
          data={messages}
          renderItem={renderMessage}
          keyExtractor={(item) => item.messageId}
          contentContainerStyle={styles.messagesList}
          onContentSizeChange={() => flatListRef.current?.scrollToEnd()}
          onLayout={() => flatListRef.current?.scrollToEnd()}
        />

        <ChatInput
          onSend={handleSendMessage}
          disabled={remainingTime <= 0}
          placeholder="メッセージを入力..."
        />
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  correctRoom: {
    backgroundColor: '#E8F5E9',
  },
  incorrectRoom: {
    backgroundColor: '#FFEBEE',
  },
  header: {
    padding: 16,
    alignItems: 'center',
    backgroundColor: '#fff',
    borderBottomWidth: 1,
    borderBottomColor: '#E8E8E8',
  },
  badge: {
    paddingHorizontal: 16,
    paddingVertical: 6,
    borderRadius: 16,
    marginBottom: 8,
  },
  correctBadge: {
    backgroundColor: '#4CAF50',
  },
  incorrectBadge: {
    backgroundColor: '#f44336',
  },
  badgeText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
  },
  headerDescription: {
    fontSize: 13,
    color: '#666',
    textAlign: 'center',
    marginTop: 8,
  },
  chatContainer: {
    flex: 1,
    backgroundColor: '#fff',
  },
  messagesList: {
    paddingVertical: 16,
  },
});
