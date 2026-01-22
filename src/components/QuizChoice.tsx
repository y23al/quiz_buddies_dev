// クイズ選択肢コンポーネント
import React from 'react';
import { TouchableOpacity, Text, StyleSheet } from 'react-native';

interface QuizChoiceProps {
  index: number;
  text: string;
  selected: boolean;
  disabled: boolean;
  isCorrect?: boolean;
  showResult?: boolean;
  onPress: () => void;
}

const CHOICE_LABELS = ['A', 'B', 'C', 'D'];

export const QuizChoice: React.FC<QuizChoiceProps> = ({
  index,
  text,
  selected,
  disabled,
  isCorrect,
  showResult,
  onPress,
}) => {
  const getBackgroundColor = () => {
    if (showResult) {
      if (isCorrect) return '#4CAF50';
      if (selected && !isCorrect) return '#f44336';
    }
    if (selected) return '#2196F3';
    return '#fff';
  };

  const getTextColor = () => {
    if (showResult && (isCorrect || selected)) return '#fff';
    if (selected) return '#fff';
    return '#333';
  };

  return (
    <TouchableOpacity
      style={[
        styles.container,
        { backgroundColor: getBackgroundColor() },
        disabled && styles.disabled,
      ]}
      onPress={onPress}
      disabled={disabled}
      activeOpacity={0.7}
    >
      <Text style={[styles.label, { color: getTextColor() }]}>
        {CHOICE_LABELS[index]}
      </Text>
      <Text style={[styles.text, { color: getTextColor() }]}>{text}</Text>
    </TouchableOpacity>
  );
};

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
    marginVertical: 8,
    marginHorizontal: 16,
    borderRadius: 12,
    borderWidth: 2,
    borderColor: '#E8E8E8',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 2,
  },
  disabled: {
    opacity: 0.7,
  },
  label: {
    fontSize: 18,
    fontWeight: 'bold',
    width: 32,
    height: 32,
    textAlign: 'center',
    lineHeight: 32,
    backgroundColor: 'rgba(0,0,0,0.1)',
    borderRadius: 16,
    marginRight: 12,
  },
  text: {
    flex: 1,
    fontSize: 16,
  },
});
