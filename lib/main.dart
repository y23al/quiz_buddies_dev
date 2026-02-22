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

      case '/select-grade':
        return MaterialPageRoute(
          builder: (_) => const GradeSelectScreen(),
        );

      case '/select-term':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => TermSelectScreen(
            grade: args['grade'] as int,
          ),
        );

      case '/select-subject':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => SubjectSelectScreen(
            grade: args['grade'] as int,
            term: args['term'] as int,
          ),
        );

      case '/lobby':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => LobbyScreen(
            sessionId: args['sessionId'] as String?,
            roomCode: args['roomCode'] as String?,
            grade: args['grade'] as int? ?? 0,
            term: args['term'] as int? ?? 0,
            subjectId: args['subjectId'] as String? ?? '',
            subjectName: args['subjectName'] as String? ?? '',
            isHost: args['isHost'] as bool? ?? false,
          ),
        );

      case '/roulette':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => RouletteScreen(
            sessionId: args['sessionId'] as String,
            roomCode: args['roomCode'] as String? ?? '',
            grade: args['grade'] as int? ?? 0,
            term: args['term'] as int? ?? 0,
            subjectId: args['subjectId'] as String? ?? '',
            subjectName: args['subjectName'] as String? ?? '',
            selectedLecture: args['selectedLecture'] is num
                ? (args['selectedLecture'] as num).toInt()
                : null,
          ),
        );

      case '/quiz':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => QuizScreen(
            sessionId: args['sessionId'] as String,
            roomCode: args['roomCode'] as String?,
            grade: args['grade'] as int? ?? 0,
            term: args['term'] as int? ?? 0,
            subjectId: args['subjectId'] as String? ?? '',
            subjectName: args['subjectName'] as String? ?? '',
            lectureNo: args['lectureNo'] as int? ?? 0,
          ),
        );

      case '/result':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => ResultScreen(
            sessionId: args['sessionId'] as String,
            roomCode: args['roomCode'] as String?,
            subjectName: args['subjectName'] as String? ?? '',
            lectureNo: args['lectureNo'] as int? ?? 0,
            correctCount: args['correctCount'] as int? ?? 0,
            totalQuestions: args['totalQuestions'] as int? ?? 0,
            totalPoints: args['totalPoints'] as int? ?? 0,
            questions: args['questions'] as List<Map<String, dynamic>>? ?? [],
          ),
        );

      case '/review':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => ReviewScreen(
            sessionId: args['sessionId'] as String,
            questions: args['questions'] as List<Map<String, dynamic>>,
          ),
        );

      case '/chat':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => ChatScreen(
            sessionId: args['sessionId'] as String,
            correctCount: args['correctCount'] as int? ?? 0,
            totalQuestions: args['totalQuestions'] as int? ?? 0,
            questions: args['questions'] as List<Map<String, dynamic>>? ?? [],
            subjectName: args['subjectName'] as String? ?? '',
            lectureNo: args['lectureNo'] as int? ?? 0,
          ),
        );

      case '/retest':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => RetestScreen(
            sessionId: args['sessionId'] as String,
            questions: args['questions'] as List<Map<String, dynamic>>,
            subjectName: args['subjectName'] as String? ?? '',
            lectureNo: args['lectureNo'] as int? ?? 0,
          ),
        );

      case '/ranking':
        return MaterialPageRoute(
          builder: (_) => const RankingScreen(),
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
