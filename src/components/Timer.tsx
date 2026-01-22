// タイマーコンポーネント
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { formatTime } from '../utils';

interface TimerProps {
  remainingTime: number;
  label?: string;
  showWarning?: boolean;
  warningThreshold?: number;
}

export const Timer: React.FC<TimerProps> = ({
  remainingTime,
  label,
  showWarning = true,
  warningThreshold = 10,
}) => {
  const isWarning = showWarning && remainingTime <= warningThreshold && remainingTime > 0;
  const isExpired = remainingTime <= 0;

  return (
    <View style={styles.container}>
      {label && <Text style={styles.label}>{label}</Text>}
      <Text
        style={[
          styles.time,
          isWarning && styles.warning,
          isExpired && styles.expired,
        ]}
      >
        {formatTime(remainingTime)}
      </Text>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    padding: 8,
  },
  label: {
    fontSize: 12,
    color: '#666',
    marginBottom: 4,
  },
  time: {
    fontSize: 32,
    fontWeight: 'bold',
    color: '#333',
    fontVariant: ['tabular-nums'],
  },
  warning: {
    color: '#ff6b6b',
  },
  expired: {
    color: '#999',
  },
});
