// Quiz Buddies - メインエントリーポイント
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/screens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyByY7rvnzRdp3eqD8vOoHxyTWfFP9rlOWA',
      authDomain: 'quiz-buddies-3a96c.firebaseapp.com',
      databaseURL: 'https://quiz-buddies-3a96c-default-rtdb.asia-southeast1.firebasedatabase.app',
      projectId: 'quiz-buddies-3a96c',
      storageBucket: 'quiz-buddies-3a96c.firebasestorage.app',
      messagingSenderId: '570689950826',
      appId: '1:570689950826:web:e1284ebf9176fc5fe32613',
      measurementId: 'G-Q851WNPVM8',
    ),
  );
  runApp(const ProviderScope(child: QuizBuddiesApp()));
}

class QuizBuddiesApp extends StatelessWidget {
  const QuizBuddiesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quiz Buddies',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50),
        ),
        useMaterial3: true,
        fontFamily: 'NotoSansJP',
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      initialRoute: '/auth',
      onGenerateRoute: _generateRoute,
    );
  }

  Route<dynamic>? _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/auth':
        return MaterialPageRoute(
          builder: (_) => const AuthScreen(),
        );

      case '/home':
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        );

      case '/quiz':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => QuizScreen(
            sessionId: args['sessionId'] as String,
            sharedSession: args['sharedSession'] as Map<String, dynamic>?,
          ),
        );

      case '/result':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => ResultScreen(
            sessionId: args['sessionId'] as String,
            isCorrect: args['isCorrect'] as bool,
          ),
        );

      case '/group-room':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => GroupRoomScreen(
            sessionId: args['sessionId'] as String,
            isCorrect: args['isCorrect'] as bool,
          ),
        );

      case '/one-on-one':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => OneOnOneScreen(
            sessionId: args['sessionId'] as String,
            isCorrect: args['isCorrect'] as bool,
            partnerId: args['partnerId'] as String?,
            isAIPartner: args['isAIPartner'] as bool? ?? false,
          ),
        );

      case '/common-room':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => CommonRoomScreen(
            sessionId: args['sessionId'] as String,
          ),
        );

      case '/settings':
        return MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => const AuthScreen(),
        );
    }
  }
}
