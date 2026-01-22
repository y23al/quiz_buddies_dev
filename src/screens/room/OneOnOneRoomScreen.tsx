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
  getRoom,
  reportMessage,
} from '../../services';
import { blockUser } from '../../services/authService';
import { RootStackParamList, Message, Room, CONFIG } from '../../types';
import { Timer, ChatMessage, ChatInput, LoadingScreen } from '../../components';
import { calculateRemainingTime } from '../../utils';

type NavigationProp = NativeStackNavigationProp<RootStackParamList>;
type OneOnOneRoomRouteProp = RouteProp<RootStackParamList, 'OneOnOneRoom'>;

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

  const flatListRef = useRef<FlatList>(null);
  const timerRef = useRef<NodeJS.Timeout | null>(null);

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
      }
    });

    return () => unsubscribe();
  }, [roomId, isLoading]);

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
    if (!user || !selectedMessage || !partnerUserId) return;

    try {
      await reportMessage(
        roomId,
        selectedMessage.messageId,
        user.userId,
        partnerUserId,
        reason
      );
      Alert.alert('報告完了', '通報を受け付けました。ご報告ありがとうございます。');
    } catch (error) {
      Alert.alert('エラー', '通報の送信に失敗しました');
    }

    setShowReportModal(false);
    setSelectedMessage(null);
  };

  const handleBlock = async () => {
    if (!user || !partnerUserId) return;

    Alert.alert(
      'ブロックしますか？',
      'この相手とは今後マッチングされなくなります。',
      [
        { text: 'キャンセル', style: 'cancel' },
        {
          text: 'ブロック',
          style: 'destructive',
          onPress: async () => {
            try {
              await blockUser(user.userId, partnerUserId);
              Alert.alert('ブロック完了', 'この相手をブロックしました。');
            } catch (error) {
              Alert.alert('エラー', 'ブロックに失敗しました');
            }
          },
        },
      ]
    );

    setShowReportModal(false);
    setSelectedMessage(null);
  };

  const renderMessage = ({ item }: { item: Message }) => (
    <ChatMessage
      message={item}
      isOwnMessage={item.senderUserId === user?.userId}
      senderName={
        item.senderUserId === user?.userId
          ? undefined
          : isTeacher
          ? '学習者'
          : '教える人'
      }
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
              {isTeacher
                ? '相手に問題の解き方を教えてあげましょう'
                : '正解した人から教えてもらいましょう'}
            </Text>
          </View>
          <Timer remainingTime={remainingTime} label="残り" />
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
