// 認証画面
import React, { useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  SafeAreaView,
  ActivityIndicator,
  Alert,
  Platform,
} from 'react-native';
import { signInAnonymouslyAsync } from '../../services';
import { useAuthStore } from '../../store';

// Web対応のアラート
const showAlert = (title: string, message: string) => {
  if (Platform.OS === 'web') {
    window.alert(`${title}\n${message}`);
  } else {
    Alert.alert(title, message);
  }
};

export const AuthScreen: React.FC = () => {
  const [isLoading, setIsLoading] = useState(false);
  const { setUser } = useAuthStore();

  const handleAnonymousLogin = async () => {
    console.log('Login button pressed');
    setIsLoading(true);
    try {
      console.log('Calling signInAnonymouslyAsync...');
      const user = await signInAnonymouslyAsync();
      console.log('User created:', user);
      setUser(user);
      console.log('User set in store');
    } catch (error) {
      console.error('Login error:', error);
      showAlert('エラー', 'ログインに失敗しました。もう一度お試しください。');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.content}>
        <View style={styles.header}>
          <Text style={styles.title}>Quiz Buddies</Text>
          <Text style={styles.subtitle}>みんなで学ぶ、教え合う</Text>
        </View>

        <View style={styles.features}>
          <Text style={styles.featureTitle}>クイズで繋がる新しい学び</Text>
          <Text style={styles.featureText}>
            1日2回のクイズタイムに参加して{'\n'}
            正解した人から教えてもらおう！
          </Text>
        </View>

        <View style={styles.buttonContainer}>
          <TouchableOpacity
            style={[styles.button, styles.anonymousButton]}
            onPress={handleAnonymousLogin}
            disabled={isLoading}
          >
            {isLoading ? (
              <ActivityIndicator color="#fff" />
            ) : (
              <Text style={styles.buttonText}>ゲストとして始める</Text>
            )}
          </TouchableOpacity>

          <Text style={styles.termsText}>
            利用を開始することで、利用規約に同意したものとみなされます
          </Text>
        </View>
      </View>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#4CAF50',
  },
  content: {
    flex: 1,
    justifyContent: 'space-between',
    padding: 24,
  },
  header: {
    alignItems: 'center',
    marginTop: 60,
  },
  title: {
    fontSize: 42,
    fontWeight: 'bold',
    color: '#fff',
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 18,
    color: 'rgba(255,255,255,0.9)',
  },
  features: {
    alignItems: 'center',
    paddingHorizontal: 20,
  },
  featureTitle: {
    fontSize: 24,
    fontWeight: '600',
    color: '#fff',
    marginBottom: 16,
    textAlign: 'center',
  },
  featureText: {
    fontSize: 16,
    color: 'rgba(255,255,255,0.9)',
    textAlign: 'center',
    lineHeight: 24,
  },
  buttonContainer: {
    marginBottom: 40,
  },
  button: {
    height: 56,
    borderRadius: 28,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 16,
  },
  anonymousButton: {
    backgroundColor: '#fff',
  },
  buttonText: {
    fontSize: 18,
    fontWeight: '600',
    color: '#4CAF50',
  },
  termsText: {
    fontSize: 12,
    color: 'rgba(255,255,255,0.7)',
    textAlign: 'center',
  },
});
