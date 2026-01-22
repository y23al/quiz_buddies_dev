// クイズ画面
import React, { useEffect, useState, useCallback, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  SafeAreaView,
  Alert,
} from 'react-native';
import { useNavigation, useRoute, RouteProp } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useAuthStore, useSessionStore } from '../../store';
import {
  getSession,
  getQuiz,
  submitAnswer,
  handleTimeout,
  subscribeToSession,
} from '../../services';
import { RootStackParamList, Quiz, CONFIG } from '../../types';
import { Timer, QuizChoice, LoadingScreen } from '../../components';

type NavigationProp = NativeStackNavigationProp<RootStackParamList>;
type QuizRouteProp = RouteProp<RootStackParamList, 'Quiz'>;

export const QuizScreen: React.FC = () => {
  const navigation = useNavigation<NavigationProp>();
  const route = useRoute<QuizRouteProp>();
  const { sessionId } = route.params;
  const { user } = useAuthStore();
  const { setCurrentQuiz } = useSessionStore();

  const [quiz, setQuiz] = useState<Quiz | null>(null);
  const [selectedAnswer, setSelectedAnswer] = useState<number | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [showResult, setShowResult] = useState(false);
  const [isCorrect, setIsCorrect] = useState(false);
  const [remainingTime, setRemainingTime] = useState(CONFIG.QUIZ_TIME_SECONDS);
  const [countdown, setCountdown] = useState(CONFIG.RESULT_DISPLAY_SECONDS);

  const timerRef = useRef<NodeJS.Timeout | null>(null);
  const countdownRef = useRef<NodeJS.Timeout | null>(null);
  const hasSubmittedRef = useRef(false);

  // クイズを読み込み
  useEffect(() => {
    const loadQuiz = async () => {
      try {
        const session = await getSession(sessionId);
        if (!session) {
          Alert.alert('エラー', 'セッションが見つかりません');
          navigation.goBack();
          return;
        }

        const quizData = await getQuiz(session.quizId);
        if (!quizData) {
          Alert.alert('エラー', 'クイズが見つかりません');
          navigation.goBack();
          return;
        }

        setQuiz(quizData);
        setCurrentQuiz(quizData);
      } catch (error) {
        console.error('Error loading quiz:', error);
        Alert.alert('エラー', 'クイズの読み込みに失敗しました');
        navigation.goBack();
      }
    };

    loadQuiz();
  }, [sessionId, navigation, setCurrentQuiz]);

  // セッション状態を監視
  useEffect(() => {
    const unsubscribe = subscribeToSession(sessionId, (session) => {
      if (session && session.phase !== 'JOINABLE' && session.phase !== 'QUIZ' && !showResult) {
        // セッションがクイズフェーズ以外に変わった場合
        if (session.correctRoomId && session.incorrectRoomId) {
          if (!hasSubmittedRef.current) {
            // 未回答の場合はタイムアウト処理
            handleTimeoutSubmit();
          }
        }
      }
    });

    return () => unsubscribe();
  }, [sessionId, showResult]);

  // クイズタイマー
  useEffect(() => {
    if (!quiz || showResult) return;

    timerRef.current = setInterval(() => {
      setRemainingTime((prev) => {
        if (prev <= 1) {
          // タイムアウト
          if (!hasSubmittedRef.current) {
            handleTimeoutSubmit();
          }
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
  }, [quiz, showResult]);

  // 結果表示後のカウントダウン
  useEffect(() => {
    if (!showResult) return;

    countdownRef.current = setInterval(() => {
      setCountdown((prev) => {
        if (prev <= 1) {
          // ルームへ遷移
          navigateToRoom();
          return 0;
        }
        return prev - 1;
      });
    }, 1000);

    return () => {
      if (countdownRef.current) {
        clearInterval(countdownRef.current);
      }
    };
  }, [showResult]);

  const handleTimeoutSubmit = useCallback(async () => {
    if (hasSubmittedRef.current || !user) return;
    hasSubmittedRef.current = true;

    try {
      await handleTimeout(sessionId, user.userId);
      setIsCorrect(false);
      setShowResult(true);
    } catch (error) {
      console.error('Error handling timeout:', error);
    }
  }, [sessionId, user]);

  const handleSubmit = async () => {
    if (selectedAnswer === null || isSubmitting || !user || hasSubmittedRef.current) return;

    hasSubmittedRef.current = true;
    setIsSubmitting(true);

    try {
      const result = await submitAnswer(sessionId, user.userId, selectedAnswer);
      setIsCorrect(result === 'CORRECT');
      setShowResult(true);
    } catch (error) {
      console.error('Error submitting answer:', error);
      hasSubmittedRef.current = false;
      Alert.alert('エラー', '回答の送信に失敗しました');
    } finally {
      setIsSubmitting(false);
    }
  };

  const navigateToRoom = useCallback(async () => {
    try {
      const session = await getSession(sessionId);
      if (!session) return;

      const roomId = isCorrect ? session.correctRoomId : session.incorrectRoomId;
      const roomType = isCorrect ? 'correct' : 'incorrect';

      if (roomId) {
        navigation.replace('GroupRoom', { sessionId, roomId, roomType });
      } else {
        // ルームがまだ作成されていない場合は結果画面へ
        navigation.replace('Result', { sessionId, isCorrect });
      }
    } catch (error) {
      console.error('Error navigating to room:', error);
    }
  }, [sessionId, isCorrect, navigation]);

  const handleChoicePress = (index: number) => {
    if (showResult || isSubmitting) return;
    setSelectedAnswer(index);
    // 選択後すぐに送信
    setTimeout(() => {
      if (!hasSubmittedRef.current) {
        handleSubmit();
      }
    }, 300);
  };

  if (!quiz) {
    return <LoadingScreen message="クイズを読み込み中..." />;
  }

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <Timer
          remainingTime={showResult ? countdown : remainingTime}
          label={showResult ? 'ルームに移動するまで' : '残り時間'}
          showWarning={!showResult}
        />
      </View>

      <View style={styles.content}>
        <View style={styles.questionContainer}>
          <Text style={styles.question}>{quiz.questionText}</Text>
        </View>

        <View style={styles.choicesContainer}>
          {quiz.choices.map((choice, index) => (
            <QuizChoice
              key={index}
              index={index}
              text={choice}
              selected={selectedAnswer === index}
              disabled={showResult || isSubmitting}
              isCorrect={index === quiz.correctChoiceIndex}
              showResult={showResult}
              onPress={() => handleChoicePress(index)}
            />
          ))}
        </View>
      </View>

      {showResult && (
        <View style={styles.resultOverlay}>
          <View style={[styles.resultBadge, isCorrect ? styles.correctBadge : styles.incorrectBadge]}>
            <Text style={styles.resultText}>
              {isCorrect ? '正解！' : '不正解...'}
            </Text>
            <Text style={styles.resultSubtext}>
              {isCorrect
                ? '正解者ルームへ移動します'
                : '不正解者ルームへ移動します'}
            </Text>
          </View>
        </View>
      )}
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
  },
  header: {
    paddingVertical: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#E8E8E8',
  },
  content: {
    flex: 1,
  },
  questionContainer: {
    padding: 24,
    backgroundColor: '#f9f9f9',
  },
  question: {
    fontSize: 20,
    fontWeight: '600',
    color: '#333',
    lineHeight: 30,
    textAlign: 'center',
  },
  choicesContainer: {
    flex: 1,
    paddingVertical: 16,
  },
  resultOverlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(0,0,0,0.5)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  resultBadge: {
    padding: 32,
    borderRadius: 16,
    alignItems: 'center',
  },
  correctBadge: {
    backgroundColor: '#4CAF50',
  },
  incorrectBadge: {
    backgroundColor: '#f44336',
  },
  resultText: {
    fontSize: 32,
    fontWeight: 'bold',
    color: '#fff',
    marginBottom: 8,
  },
  resultSubtext: {
    fontSize: 16,
    color: 'rgba(255,255,255,0.9)',
  },
});
