// 時間関連ユーティリティ

/**
 * サーバー時刻を基準に残り時間を計算
 */
export const calculateRemainingTime = (
  phaseStartAt: Date,
  durationSeconds: number,
  serverTimeOffset: number = 0
): number => {
  const now = Date.now() + serverTimeOffset;
  const startTime = new Date(phaseStartAt).getTime();
  const endTime = startTime + durationSeconds * 1000;
  const remaining = Math.floor((endTime - now) / 1000);
  return Math.max(0, remaining);
};

/**
 * 時間をMM:SS形式でフォーマット
 */
export const formatTime = (seconds: number): string => {
  const mins = Math.floor(seconds / 60);
  const secs = seconds % 60;
  return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
};

/**
 * 日付をYYYY-MM-DD形式でフォーマット
 */
export const formatDate = (date: Date): string => {
  return date.toISOString().split('T')[0];
};

/**
 * ランダムな時刻を生成（指定時間帯内）
 */
export const generateRandomTime = (
  date: Date,
  startHour: number,
  endHour: number
): Date => {
  const result = new Date(date);
  const hour = startHour + Math.floor(Math.random() * (endHour - startHour));
  const minute = Math.floor(Math.random() * 60);
  result.setHours(hour, minute, 0, 0);
  return result;
};
