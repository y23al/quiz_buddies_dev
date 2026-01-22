// 結果画面（フォールバック用）
import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  SafeAreaView,
  ActivityIndicator,
} from 'react-native';
import { useNavigation, useRoute, RouteProp } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { subscribeToSession, getSession } from '../../services';
import { RootStackParamList } from '../../types';

type NavigationProp = NativeStackNavigationProp<RootStackParamList>;
type ResultRouteProp = RouteProp<RootStackParamList, 'Result'>;

export const ResultScreen: React.FC = () => {
  const navigation = useNavigation<NavigationProp>();
  const route = useRoute<ResultRouteProp>();
  const { sessionId, isCorrect } = route.params;
  const [waiting, setWaiting] = useState(true);

  useEffect(() => {
    // セッション状態を監視してルームが作成されたら遷移
    const unsubscribe = subscribeToSession(sessionId, (session) => {
      if (!session) return;

      const roomId = isCorrect ? session.correctRoomId : session.incorrectRoomId;
      if (roomId) {
        setWaiting(false);
        navigation.replace('GroupRoom', {
          sessionId,
          roomId,
          roomType: isCorrect ? 'correct' : 'incorrect',
        });
      }
    });

    // タイムアウト処理（30秒経過してもルームがない場合）
    const timeout = setTimeout(async () => {
      const session = await getSession(sessionId);
      if (session?.commonRoomId) {
        navigation.replace('CommonRoom', {
          sessionId,
          roomId: session.commonRoomId,
        });
      }
    }, 30000);

    return () => {
      unsubscribe();
      clearTimeout(timeout);
    };
  }, [sessionId, isCorrect, navigation]);

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.content}>
        <View style={[styles.badge, isCorrect ? styles.correctBadge : styles.incorrectBadge]}>
          <Text style={styles.badgeText}>
            {isCorrect ? '正解！' : '不正解...'}
          </Text>
        </View>

        {waiting && (
          <View style={styles.waitingContainer}>
            <ActivityIndicator size="large" color="#4CAF50" />
            <Text style={styles.waitingText}>
              ルームを準備しています...
            </Text>
          </View>
        )}
      </View>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
  },
  content: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 24,
  },
  badge: {
    paddingHorizontal: 48,
    paddingVertical: 24,
    borderRadius: 16,
    marginBottom: 32,
  },
  correctBadge: {
    backgroundColor: '#4CAF50',
  },
  incorrectBadge: {
    backgroundColor: '#f44336',
  },
  badgeText: {
    fontSize: 32,
    fontWeight: 'bold',
    color: '#fff',
  },
  waitingContainer: {
    alignItems: 'center',
  },
  waitingText: {
    marginTop: 16,
    fontSize: 16,
    color: '#666',
  },
});
