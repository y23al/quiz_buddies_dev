// アプリナビゲーション
import React, { useEffect } from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { Platform } from 'react-native';
import { useAuthStore } from '../store';
import { subscribeToAuthState, getUserData, getDemoUser } from '../services';
import { isDemoMode } from '../config/firebase';
import { RootStackParamList } from '../types';
import {
  AuthScreen,
  HomeScreen,
  SettingsScreen,
  QuizScreen,
  ResultScreen,
  GroupRoomScreen,
  OneOnOneRoomScreen,
  CommonRoomScreen,
} from '../screens';
import { LoadingScreen } from '../components';

const Stack = createNativeStackNavigator<RootStackParamList>();

// Web用のリンキング設定
const linking = {
  prefixes: ['quizbuddies://', 'http://localhost:8081'],
  config: {
    screens: {
      Auth: 'auth',
      Home: 'home',
      Settings: 'settings',
      Quiz: 'quiz',
      Result: 'result',
      GroupRoom: 'group-room',
      OneOnOneRoom: 'one-on-one-room',
      CommonRoom: 'common-room',
    },
  },
};

export const AppNavigator: React.FC = () => {
  const { isAuthenticated, isLoading, setUser, setLoading } = useAuthStore();

  useEffect(() => {
    // デモモードの場合は、初期化を即座に完了
    if (isDemoMode) {
      const existingDemoUser = getDemoUser();
      if (existingDemoUser) {
        setUser(existingDemoUser);
      } else {
        setLoading(false);
      }
      return;
    }

    const unsubscribe = subscribeToAuthState(async (firebaseUser) => {
      if (firebaseUser) {
        try {
          const userData = await getUserData(firebaseUser.uid);
          setUser(userData);
        } catch (error) {
          console.error('Error getting user data:', error);
          setUser(null);
        }
      } else {
        setUser(null);
      }
      setLoading(false);
    });

    return () => unsubscribe();
  }, [setUser, setLoading]);

  if (isLoading) {
    return <LoadingScreen message="起動中..." />;
  }

  return (
    <NavigationContainer linking={Platform.OS === 'web' ? linking : undefined}>
      <Stack.Navigator
        screenOptions={{
          headerShown: false,
          animation: 'slide_from_right',
        }}
      >
        {!isAuthenticated ? (
          <Stack.Screen name="Auth" component={AuthScreen} />
        ) : (
          <>
            <Stack.Screen name="Home" component={HomeScreen} />
            <Stack.Screen name="Settings" component={SettingsScreen} />
            <Stack.Screen
              name="Quiz"
              component={QuizScreen}
              options={{
                gestureEnabled: false,
              }}
            />
            <Stack.Screen
              name="Result"
              component={ResultScreen}
              options={{
                gestureEnabled: false,
              }}
            />
            <Stack.Screen
              name="GroupRoom"
              component={GroupRoomScreen}
              options={{
                gestureEnabled: false,
              }}
            />
            <Stack.Screen
              name="OneOnOneRoom"
              component={OneOnOneRoomScreen}
              options={{
                gestureEnabled: false,
              }}
            />
            <Stack.Screen
              name="CommonRoom"
              component={CommonRoomScreen}
              options={{
                gestureEnabled: false,
              }}
            />
          </>
        )}
      </Stack.Navigator>
    </NavigationContainer>
  );
};
