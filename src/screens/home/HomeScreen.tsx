// ホーム画面
import React, { useEffect, useState, useCallback } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  SafeAreaView,
  RefreshControl,
  ScrollView,
  Alert,
} from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { Ionicons } from '@expo/vector-icons';
import { useAuthStore, useSessionStore } from '../../store';
import { getCurrentSession, joinSession, createSampleQuiz, createSampleSession } from '../../services';
import { RootStackParamList, Session } from '../../types';
import { LoadingScreen } from '../../components';

type NavigationProp = NativeStackNavigationProp<RootStackParamList>;

export const HomeScreen: React.FC = () => {
  const navigation = useNavigation<NavigationProp>();
  const { user } = useAuthStore();
  const { setCurrentSession, setLoading, isLoading } = useSessionStore();
  const [currentSession, setCurrentSessionLocal] = useState<Session | null>(null);
  const [refreshing, setRefreshing] = useState(false);

  const checkForSession = useCallback(async () => {
    try {
      const session = await getCurrentSession();
      setCurrentSessionLocal(session);
    } catch (error) {
      console.error('Error checking session:', error);
    }
  }, []);

  useEffect(() => {
    checkForSession();
  }, [checkForSession]);

  const onRefresh = useCallback(async () => {
    setRefreshing(true);
    await checkForSession();
    setRefreshing(false);
  }, [checkForSession]);

  const handleJoinSession = async () => {
    if (!currentSession || !user) return;

    setLoading(true);
    try {
      await joinSession(currentSession.sessionId, user.userId);
      setCurrentSession(currentSession);
      navigation.navigate('Quiz', { sessionId: currentSession.sessionId });
    } catch (error) {
      console.error('Error joining session:', error);
      Alert.alert('エラー', 'セッションへの参加に失敗しました');
    } finally {
      setLoading(false);
    }
  };

  // 開発用：サンプルセッションを作成
  const handleCreateTestSession = async () => {
    try {
      setLoading(true);
      const quiz = await createSampleQuiz();
      const session = await createSampleSession(quiz.quizId);
      setCurrentSessionLocal(session);
      Alert.alert('成功', 'テストセッションを作成しました');
    } catch (error) {
      console.error('Error creating test session:', error);
      Alert.alert('エラー', 'テストセッションの作成に失敗しました');
    } finally {
      setLoading(false);
    }
  };

  if (isLoading) {
    return <LoadingScreen message="セッションに参加中..." />;
  }

  const isJoinable = currentSession?.phase === 'JOINABLE';

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView
        contentContainerStyle={styles.scrollContent}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
        }
      >
        <View style={styles.header}>
          <Text style={styles.greeting}>
            こんにちは、{user?.displayName || 'ゲスト'}さん
          </Text>
          <TouchableOpacity
            style={styles.settingsButton}
            onPress={() => navigation.navigate('Settings')}
          >
            <Ionicons name="settings-outline" size={24} color="#333" />
          </TouchableOpacity>
        </View>

        <View style={styles.mainContent}>
          {currentSession && isJoinable ? (
            <View style={styles.sessionCard}>
              <View style={styles.sessionBadge}>
                <Text style={styles.sessionBadgeText}>参加可能！</Text>
              </View>
              <Text style={styles.sessionTitle}>クイズが出題されています！</Text>
              <Text style={styles.sessionDescription}>
                今すぐ参加して、みんなと一緒にクイズを解こう
              </Text>
              <TouchableOpacity
                style={styles.joinButton}
                onPress={handleJoinSession}
              >
                <Text style={styles.joinButtonText}>参加する</Text>
                <Ionicons name="arrow-forward" size={20} color="#fff" />
              </TouchableOpacity>
            </View>
          ) : (
            <View style={styles.noSessionCard}>
              <Ionicons name="time-outline" size={64} color="#ccc" />
              <Text style={styles.noSessionTitle}>
                現在進行中のクイズはありません
              </Text>
              <Text style={styles.noSessionDescription}>
                1日2回、ランダムな時間に通知が届きます。{'\n'}
                通知が届いたらすぐに参加しよう！
              </Text>
            </View>
          )}

          {/* 開発用ボタン */}
          {__DEV__ && (
            <TouchableOpacity
              style={styles.devButton}
              onPress={handleCreateTestSession}
            >
              <Text style={styles.devButtonText}>
                [DEV] テストセッション作成
              </Text>
            </TouchableOpacity>
          )}
        </View>

        <View style={styles.infoSection}>
          <Text style={styles.infoTitle}>Quiz Buddiesの遊び方</Text>
          <View style={styles.infoItem}>
            <View style={styles.infoIcon}>
              <Text style={styles.infoIconText}>1</Text>
            </View>
            <Text style={styles.infoText}>
              通知が届いたらアプリを開いてクイズに挑戦
            </Text>
          </View>
          <View style={styles.infoItem}>
            <View style={styles.infoIcon}>
              <Text style={styles.infoIconText}>2</Text>
            </View>
            <Text style={styles.infoText}>
              正解・不正解でそれぞれのルームに振り分け
            </Text>
          </View>
          <View style={styles.infoItem}>
            <View style={styles.infoIcon}>
              <Text style={styles.infoIconText}>3</Text>
            </View>
            <Text style={styles.infoText}>
              正解者と不正解者がマッチして教え合い
            </Text>
          </View>
          <View style={styles.infoItem}>
            <View style={styles.infoIcon}>
              <Text style={styles.infoIconText}>4</Text>
            </View>
            <Text style={styles.infoText}>
              最後は全員で共同ルームに集合！
            </Text>
          </View>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  scrollContent: {
    flexGrow: 1,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
    backgroundColor: '#fff',
    borderBottomWidth: 1,
    borderBottomColor: '#E8E8E8',
  },
  greeting: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
  },
  settingsButton: {
    padding: 8,
  },
  mainContent: {
    padding: 16,
  },
  sessionCard: {
    backgroundColor: '#fff',
    borderRadius: 16,
    padding: 24,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 4,
  },
  sessionBadge: {
    backgroundColor: '#4CAF50',
    paddingHorizontal: 12,
    paddingVertical: 4,
    borderRadius: 12,
    alignSelf: 'flex-start',
    marginBottom: 12,
  },
  sessionBadgeText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: '600',
  },
  sessionTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 8,
  },
  sessionDescription: {
    fontSize: 14,
    color: '#666',
    marginBottom: 20,
  },
  joinButton: {
    backgroundColor: '#4CAF50',
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    paddingVertical: 14,
    borderRadius: 12,
  },
  joinButtonText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '600',
    marginRight: 8,
  },
  noSessionCard: {
    backgroundColor: '#fff',
    borderRadius: 16,
    padding: 32,
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 4,
  },
  noSessionTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
    marginTop: 16,
    marginBottom: 8,
  },
  noSessionDescription: {
    fontSize: 14,
    color: '#666',
    textAlign: 'center',
    lineHeight: 22,
  },
  devButton: {
    marginTop: 16,
    padding: 12,
    backgroundColor: '#FF9800',
    borderRadius: 8,
    alignItems: 'center',
  },
  devButtonText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
  },
  infoSection: {
    padding: 16,
    marginTop: 16,
  },
  infoTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
    marginBottom: 16,
  },
  infoItem: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 12,
    backgroundColor: '#fff',
    padding: 12,
    borderRadius: 8,
  },
  infoIcon: {
    width: 28,
    height: 28,
    borderRadius: 14,
    backgroundColor: '#4CAF50',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  infoIconText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: 'bold',
  },
  infoText: {
    flex: 1,
    fontSize: 14,
    color: '#333',
  },
});
