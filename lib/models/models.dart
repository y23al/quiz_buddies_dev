// モデルエクスポート
export 'user.dart';
export 'session.dart';
export 'quiz.dart';
export 'question.dart';
export 'subject.dart';
export 'user_profile.dart';
export 'participation.dart';
export 'room.dart';
export 'message.dart';

// 設定定数
class AppConfig {
  static const int quizTimeSeconds = 30;
  static const int quizQuestionCount = 10;
  static const int pointsPerCorrect = 10;
  static const int retestThreshold = 5; // 正解数5以下で再試験
  static const int exitButtonDelaySeconds = 10; // 退出ボタン表示までの秒数
  static const int commonRoomSeconds = 120;
  static const int groupRoomSeconds = 120;
  static const int oneOnOneSeconds = 120;
  static const int joinDeadlineSeconds = 60;
  static const int messageCooldownMs = 1000;
}
