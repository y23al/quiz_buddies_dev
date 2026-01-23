// モデルエクスポート
export 'user.dart';
export 'session.dart';
export 'quiz.dart';
export 'participation.dart';
export 'room.dart';
export 'message.dart';

// 設定定数
class AppConfig {
  static const int quizTimeSeconds = 30;
  static const int groupRoomSeconds = 60;
  static const int oneOnOneSeconds = 180;
  static const int commonRoomSeconds = 120;
  static const int joinDeadlineSeconds = 60;
  static const int messageCooldownMs = 1000;
}
