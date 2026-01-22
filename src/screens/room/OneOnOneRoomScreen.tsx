// 1on1ルーム画面（教える/教わる）
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
  TouchableOpacity,
  Modal,
} from 'react-native';
import { useNavigation, useRoute, RouteProp } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { Ionicons } from '@expo/vector-icons';
import { useAuthStore, useSessionStore } from '../../store';
import {
  subscribeToMessages,
  sendMessage,
  subscribeToSession,
  subscribeToRoom,
  reportMessage,
  generateAIMessage,
  isAIPartner,
  AI_USER_ID,
  updateDemoSession,
} from '../../services';
import { blockUser } from '../../services/authService';
import { isDemoMode } from '../../config/firebase';
import { RootStackParamList, Message, Room, CONFIG } from '../../types';
import { Timer, ChatMessage, ChatInput, LoadingScreen } from '../../components';
import { calculateRemainingTime } from '../../utils';

type NavigationProp = NativeStackNavigationProp<RootStackParamList>;
type OneOnOneRoomRouteProp = RouteProp<RootStackParamList, 'OneOnOneRoom'>;

// デモ用メッセージストレージ
const demoMessagesLocal: Map<string, Message[]> = new Map();

export const OneOnOneRoomScreen: React.FC = () => {
  const navigation = useNavigation<NavigationProp>();
  const route = useRoute<OneOnOneRoomRouteProp>();
  const { sessionId, roomId } = route.params;
  const { user } = useAuthStore();
  const { participation, currentQuiz, setMessages } = useSessionStore();

  const [room, setRoom] = useState<Room | null>(null);
  const [messages, setLocalMessages] = useState<Message[]>([]);
  const [remainingTime, setRemainingTime] = useState(CONFIG.ONE_ON_ONE_SECONDS);
  const [isLoading, setIsLoading] = useState(true);
  const [showReportModal, setShowReportModal] = useState(false);
  const [selectedMessage, setSelectedMessage] = useState<Message | null>(null);
  const [isAIMatch, setIsAIMatch] = useState(false);

  const flatListRef = useRef<FlatList>(null);
  const timerRef = useRef<NodeJS.Timeout | null>(null);
  const aiMessageTimerRef = useRef<NodeJS.Timeout | null>(null);

  // 相手のユーザーIDを取得
  const partnerUserId = room?.memberUserIds.find((id) => id !== user?.userId);

  // 自分が正解者かどうか
  const isTeacher = participation?.result === 'CORRECT';

  // ルームを購読
  useEffect(() => {
    const unsubscribe = subscribeToRoom(roomId, (roomData) => {
      setRoom(roomData);
      if (roomData && isLoading) {
        const remaining = calculateRemainingTime(roomData.createdAt, CONFIG.ONE_ON_ONE_SECONDS);
        setRemainingTime(remaining);
        setIsLoading(false);

        // 相手がAIかどうかをチェック
        const partner = roomData.memberUserIds.find((id) => id !== user?.userId);
        if (partner && isAIPartner(partner)) {
          setIsAIMatch(true);
        }
      }
    });

    return () => unsubscribe();
  }, [roomId, isLoading, user]);

  // AI相手の場合、自動でメッセージを送信
  useEffect(() => {
    if (!isDemoMode || isLoading || !isAIMatch) return;

    const sendAIMessage = () => {
      // AIが正解者側か不正解者側かによってメッセージを変える
      const aiMessage = generateAIMessage(
        roomId,
        'one_on_one',
        !isTeacher // ユーザーが教える側なら、AIは学習者側
      );

      setLocalMessages((prev) => {
        const newMessages = [...prev, aiMessage];
        demoMessagesLocal.set(roomId, newMessages);
        return newMessages;
      });
    };

    // 最初のAIメッセージを1秒後に送信
    const initialTimer = setTimeout(sendAIMessage, 1000);

    // その後、5-10秒ごとにランダムでAIメッセージを送信
    aiMessageTimerRef.current = setInterval(() => {
      if (Math.random() > 0.4) {
        sendAIMessage();
      }
    }, 5000 + Math.random() * 5000);

    return () => {
      clearTimeout(initialTimer);
      if (aiMessageTimerRef.current) {
        clearInterval(aiMessageTimerRef.current);
      }
    };
  }, [isDemoMode, isLoading, isAIMatch, roomId, isTeacher]);

  // メッセージをリアルタイム購読
  useEffect(() => {
    const unsubscribe = subscribeToMessages(roomId, (newMessages) => {
      if (isDemoMode) {
        const localMsgs = demoMessagesLocal.get(roomId) || [];
        const merged = [...newMessages];
        for (const localMsg of localMsgs) {
          if (!merged.find((m) => m.messageId === localMsg.messageId)) {
            merged.push(localMsg);
          }
        }
        merged.sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime());
        setLocalMessages(merged);
        setMessages(merged);
      } else {
        setLocalMessages(newMessages);
        setMessages(newMessages);
      }
    });

    return () => unsubscribe();
  }, [roomId, setMessages]);

  // セッション状態を監視
  useEffect(() => {
    const unsubscribe = subscribeToSession(sessionId, (session) => {
      if (!session) return;

      // 共同ルームフェーズに遷移した場合
      if (session.phase === 'COMMON' && session.commonRoomId) {
        navigation.replace('CommonRoom', {
          sessionId,
          roomId: session.commonRoomId,
        });
      }
    });

    return () => unsubscribe();
  }, [sessionId, navigation]);

  // タイマー終了時に共同ルームに遷移
  useEffect(() => {
    if (remainingTime <= 0 && isDemoMode) {
      // セッションを共同ルームフェーズに更新
      updateDemoSession(sessionId, { phase: 'COMMON' });

      // 少し待ってから共同ルームに遷移
      const timer = setTimeout(() => {
        navigation.replace('CommonRoom', {
          sessionId,
          roomId: `${sessionId}_common`,
        });
      }, 2000);

      return () => clearTimeout(timer);
    }
  }, [remainingTime, sessionId, navigation]);

  // タイマー
  useEffect(() => {
    timerRef.current = setInterval(() => {
      setRemainingTime((prev) => {
        if (prev <= 1) {
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
        if (Platform.OS === 'web') {
          window.alert('送信制限\nメッセージの送信が速すぎます。少し待ってから再度お試しください。');
        } else {
          Alert.alert('送信制限', 'メッセージの送信が速すぎます。少し待ってから再度お試しください。');
        }
      } else {
        if (Platform.OS === 'web') {
          window.alert('エラー\nメッセージの送信に失敗しました');
        } else {
          Alert.alert('エラー', 'メッセージの送信に失敗しました');
        }
      }
    }
  }, [roomId, user]);

  const handleMessageLongPress = (message: Message) => {
    if (message.senderUserId === user?.userId) return;
    if (isAIPartner(message.senderUserId)) return; // AI相手は通報不可
    setSelectedMessage(message);
    setShowReportModal(true);
  };

  const handleReport = async (reason: string) => {
    if (!user || !selectedMessage || !partnerUserId) return;

    try {
      await reportMessage(
        roomId,
        selectedMessage.messageId,
        user.userId,
        partnerUserId,
        reason
      );
      if (Platform.OS === 'web') {
        window.alert('報告完了\n通報を受け付けました。ご報告ありがとうございます。');
      } else {
        Alert.alert('報告完了', '通報を受け付けました。ご報告ありがとうございます。');
      }
    } catch (error) {
      if (Platform.OS === 'web') {
        window.alert('エラー\n通報の送信に失敗しました');
      } else {
        Alert.alert('エラー', '通報の送信に失敗しました');
      }
    }

    setShowReportModal(false);
    setSelectedMessage(null);
  };

  const handleBlock = async () => {
    if (!user || !partnerUserId) return;

    const confirmBlock = async () => {
      try {
        await blockUser(user.userId, partnerUserId);
        if (Platform.OS === 'web') {
          window.alert('ブロック完了\nこの相手をブロックしました。');
        } else {
          Alert.alert('ブロック完了', 'この相手をブロックしました。');
        }
      } catch (error) {
        if (Platform.OS === 'web') {
          window.alert('エラー\nブロックに失敗しました');
        } else {
          Alert.alert('エラー', 'ブロックに失敗しました');
        }
      }
    };

    if (Platform.OS === 'web') {
      if (window.confirm('ブロックしますか？\nこの相手とは今後マッチングされなくなります。')) {
        confirmBlock();
      }
    } else {
      Alert.alert(
        'ブロックしますか？',
        'この相手とは今後マッチングされなくなります。',
        [
          { text: 'キャンセル', style: 'cancel' },
          {
            text: 'ブロック',
            style: 'destructive',
            onPress: confirmBlock,
          },
        ]
      );
    }

    setShowReportModal(false);
    setSelectedMessage(null);
  };

  const getSenderName = (senderId: string): string | undefined => {
    if (senderId === user?.userId) return undefined;
    if (isAIPartner(senderId)) {
      return isTeacher ? '学習者（AI）' : '先生（AI）';
    }
    return isTeacher ? '学習者' : '教える人';
  };

  const renderMessage = ({ item }: { item: Message }) => (
    <ChatMessage
      message={item}
      isOwnMessage={item.senderUserId === user?.userId}
      senderName={getSenderName(item.senderUserId)}
      onLongPress={() => handleMessageLongPress(item)}
    />
  );

  if (isLoading) {
    return <LoadingScreen message="ルームに接続中..." />;
  }

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <View style={styles.headerTop}>
          <View style={styles.roleContainer}>
            <View style={[styles.roleBadge, isTeacher ? styles.teacherBadge : styles.learnerBadge]}>
              <Text style={styles.roleBadgeText}>
                {isTeacher ? '教える' : '教わる'}
              </Text>
            </View>
            <Text style={styles.roleDescription}>
              {isAIMatch
                ? isTeacher
                  ? 'AI学習者に問題の解き方を教えてあげましょう'
                  : 'AI先生から教えてもらいましょう'
                : isTeacher
                ? '相手に問題の解き方を教えてあげましょう'
                : '正解した人から教えてもらいましょう'}
            </Text>
          </View>
          <Timer remainingTime={remainingTime} label={remainingTime > 0 ? '残り' : '終了'} />
        </View>

        {currentQuiz && (
          <View style={styles.quizHint}>
            <Text style={styles.quizHintLabel}>問題のヒント</Text>
            <Text style={styles.quizHintText}>
              Q: {currentQuiz.questionText}
            </Text>
          </View>
        )}
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
          ListEmptyComponent={
            <View style={styles.emptyContainer}>
              <Text style={styles.emptyText}>
                {isTeacher
                  ? 'まずは相手に挨拶してみましょう！'
                  : 'わからないことを質問してみましょう！'}
              </Text>
            </View>
          }
        />

        <ChatInput
          onSend={handleSendMessage}
          disabled={remainingTime <= 0}
          placeholder={isTeacher ? '解き方を教えてあげよう...' : 'わからないことを質問しよう...'}
        />
      </KeyboardAvoidingView>

      {/* 通報モーダル */}
      <Modal
        visible={showReportModal}
        transparent
        animationType="fade"
        onRequestClose={() => setShowReportModal(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Text style={styles.modalTitle}>報告・ブロック</Text>

            <TouchableOpacity
              style={styles.modalButton}
              onPress={() => handleReport('不適切な発言')}
            >
              <Ionicons name="warning-outline" size={20} color="#f44336" />
              <Text style={styles.modalButtonText}>不適切な発言として報告</Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={styles.modalButton}
              onPress={() => handleReport('スパム')}
            >
              <Ionicons name="mail-outline" size={20} color="#f44336" />
              <Text style={styles.modalButtonText}>スパムとして報告</Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={styles.modalButton}
              onPress={handleBlock}
            >
              <Ionicons name="ban-outline" size={20} color="#f44336" />
              <Text style={styles.modalButtonText}>この相手をブロック</Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={[styles.modalButton, styles.cancelButton]}
              onPress={() => setShowReportModal(false)}
            >
              <Text style={styles.cancelButtonText}>キャンセル</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
  },
  header: {
    padding: 16,
    backgroundColor: '#fff',
    borderBottomWidth: 1,
    borderBottomColor: '#E8E8E8',
  },
  headerTop: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
  },
  roleContainer: {
    flex: 1,
    marginRight: 16,
  },
  roleBadge: {
    paddingHorizontal: 16,
    paddingVertical: 6,
    borderRadius: 16,
    alignSelf: 'flex-start',
    marginBottom: 8,
  },
  teacherBadge: {
    backgroundColor: '#4CAF50',
  },
  learnerBadge: {
    backgroundColor: '#2196F3',
  },
  roleBadgeText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
  },
  roleDescription: {
    fontSize: 13,
    color: '#666',
  },
  quizHint: {
    marginTop: 12,
    padding: 12,
    backgroundColor: '#f5f5f5',
    borderRadius: 8,
  },
  quizHintLabel: {
    fontSize: 12,
    color: '#999',
    marginBottom: 4,
  },
  quizHintText: {
    fontSize: 14,
    color: '#333',
  },
  chatContainer: {
    flex: 1,
    backgroundColor: '#f9f9f9',
  },
  messagesList: {
    paddingVertical: 16,
    flexGrow: 1,
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 32,
  },
  emptyText: {
    fontSize: 14,
    color: '#999',
    textAlign: 'center',
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.5)',
    justifyContent: 'flex-end',
  },
  modalContent: {
    backgroundColor: '#fff',
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    padding: 24,
    paddingBottom: 40,
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
    marginBottom: 16,
    textAlign: 'center',
  },
  modalButton: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
    borderRadius: 8,
    backgroundColor: '#f5f5f5',
    marginBottom: 8,
  },
  modalButtonText: {
    fontSize: 16,
    color: '#333',
    marginLeft: 12,
  },
  cancelButton: {
    backgroundColor: '#E8E8E8',
    justifyContent: 'center',
    marginTop: 8,
  },
  cancelButtonText: {
    fontSize: 16,
    color: '#666',
    textAlign: 'center',
  },
});
