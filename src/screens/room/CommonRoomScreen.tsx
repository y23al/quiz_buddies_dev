// 共同ルーム画面
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
  getRoom,
  joinRoom,
  reportMessage,
} from '../../services';
import { RootStackParamList, Message, CONFIG, Session, Quiz } from '../../types';
import { Timer, ChatMessage, ChatInput, LoadingScreen } from '../../components';
import { calculateRemainingTime } from '../../utils';

type NavigationProp = NativeStackNavigationProp<RootStackParamList>;
type CommonRoomRouteProp = RouteProp<RootStackParamList, 'CommonRoom'>;

export const CommonRoomScreen: React.FC = () => {
  const navigation = useNavigation<NavigationProp>();
  const route = useRoute<CommonRoomRouteProp>();
  const { sessionId, roomId } = route.params;
  const { user } = useAuthStore();
  const { currentQuiz, setMessages, reset } = useSessionStore();

  const [messages, setLocalMessages] = useState<Message[]>([]);
  const [remainingTime, setRemainingTime] = useState(CONFIG.COMMON_ROOM_SECONDS);
  const [isLoading, setIsLoading] = useState(true);
  const [showReportModal, setShowReportModal] = useState(false);
  const [selectedMessage, setSelectedMessage] = useState<Message | null>(null);
  const [sessionEnded, setSessionEnded] = useState(false);

  const flatListRef = useRef<FlatList>(null);
  const timerRef = useRef<NodeJS.Timeout | null>(null);

  // ルームに参加
  useEffect(() => {
    const setup = async () => {
      if (!user) return;

      try {
        await joinRoom(roomId, user.userId);

        const room = await getRoom(roomId);
        if (room) {
          const remaining = calculateRemainingTime(room.createdAt, CONFIG.COMMON_ROOM_SECONDS);
          setRemainingTime(remaining);
        }

        setIsLoading(false);
      } catch (error) {
        console.error('Error joining room:', error);
        setIsLoading(false);
      }
    };

    setup();
  }, [roomId, user]);

  // メッセージをリアルタイム購読
  useEffect(() => {
    const unsubscribe = subscribeToMessages(roomId, (newMessages) => {
      setLocalMessages(newMessages);
      setMessages(newMessages);
    });

    return () => unsubscribe();
  }, [roomId, setMessages]);

  // セッション状態を監視
  useEffect(() => {
    const unsubscribe = subscribeToSession(sessionId, (session) => {
      if (!session) return;

      if (session.phase === 'FINISHED') {
        setSessionEnded(true);
      }
    });

    return () => unsubscribe();
  }, [sessionId]);

  // タイマー
  useEffect(() => {
    timerRef.current = setInterval(() => {
      setRemainingTime((prev) => {
        if (prev <= 1) {
          setSessionEnded(true);
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

  const handleMessageLongPress = (message: Message) => {
    if (message.senderUserId === user?.userId) return;
    setSelectedMessage(message);
    setShowReportModal(true);
  };

  const handleReport = async (reason: string) => {
    if (!user || !selectedMessage) return;

    try {
      await reportMessage(
        roomId,
        selectedMessage.messageId,
        user.userId,
        selectedMessage.senderUserId,
        reason
      );
      Alert.alert('報告完了', '通報を受け付けました。ご報告ありがとうございます。');
    } catch (error) {
      Alert.alert('エラー', '通報の送信に失敗しました');
    }

    setShowReportModal(false);
    setSelectedMessage(null);
  };

  const handleGoHome = () => {
    reset();
    navigation.reset({
      index: 0,
      routes: [{ name: 'Home' }],
    });
  };

  const renderMessage = ({ item }: { item: Message }) => (
    <ChatMessage
      message={item}
      isOwnMessage={item.senderUserId === user?.userId}
      senderName={item.senderUserId === user?.userId ? undefined : '参加者'}
      onLongPress={() => handleMessageLongPress(item)}
    />
  );

  if (isLoading) {
    return <LoadingScreen message="共同ルームに参加中..." />;
  }

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <View style={styles.headerTop}>
          <View style={styles.headerInfo}>
            <Text style={styles.headerTitle}>みんなの部屋</Text>
            <Text style={styles.headerDescription}>
              クイズに参加した全員で雑談しよう
            </Text>
          </View>
          {!sessionEnded && <Timer remainingTime={remainingTime} label="残り" />}
        </View>

        {currentQuiz && (
          <View style={styles.answerSection}>
            <Text style={styles.answerLabel}>今回の問題の答え</Text>
            <Text style={styles.answerText}>
              Q: {currentQuiz.questionText}
            </Text>
            <View style={styles.answerBadge}>
              <Text style={styles.answerBadgeText}>
                A: {currentQuiz.choices[currentQuiz.correctChoiceIndex]}
              </Text>
            </View>
            {currentQuiz.explanation && (
              <Text style={styles.explanation}>{currentQuiz.explanation}</Text>
            )}
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
                感想や質問を共有しましょう！
              </Text>
            </View>
          }
        />

        {!sessionEnded ? (
          <ChatInput
            onSend={handleSendMessage}
            placeholder="感想を共有しよう..."
          />
        ) : (
          <View style={styles.endedContainer}>
            <Text style={styles.endedText}>セッションが終了しました</Text>
            <TouchableOpacity style={styles.homeButton} onPress={handleGoHome}>
              <Text style={styles.homeButtonText}>ホームに戻る</Text>
            </TouchableOpacity>
          </View>
        )}
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
            <Text style={styles.modalTitle}>報告</Text>

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
  headerInfo: {
    flex: 1,
    marginRight: 16,
  },
  headerTitle: {
    fontSize: 20,
    fontWeight: '600',
    color: '#333',
    marginBottom: 4,
  },
  headerDescription: {
    fontSize: 13,
    color: '#666',
  },
  answerSection: {
    marginTop: 16,
    padding: 12,
    backgroundColor: '#E8F5E9',
    borderRadius: 8,
  },
  answerLabel: {
    fontSize: 12,
    color: '#4CAF50',
    fontWeight: '600',
    marginBottom: 4,
  },
  answerText: {
    fontSize: 14,
    color: '#333',
    marginBottom: 8,
  },
  answerBadge: {
    backgroundColor: '#4CAF50',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 4,
    alignSelf: 'flex-start',
    marginBottom: 8,
  },
  answerBadgeText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
  },
  explanation: {
    fontSize: 13,
    color: '#666',
    lineHeight: 20,
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
  endedContainer: {
    padding: 16,
    backgroundColor: '#fff',
    alignItems: 'center',
    borderTopWidth: 1,
    borderTopColor: '#E8E8E8',
  },
  endedText: {
    fontSize: 16,
    color: '#666',
    marginBottom: 12,
  },
  homeButton: {
    backgroundColor: '#4CAF50',
    paddingHorizontal: 32,
    paddingVertical: 12,
    borderRadius: 24,
  },
  homeButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
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
