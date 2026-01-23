// ニックネーム生成
import 'dart:math';

const List<String> _adjectives = [
  'ふわふわ', 'きらきら', 'もこもこ', 'ぴかぴか', 'にこにこ',
  'わくわく', 'うきうき', 'すやすや', 'のびのび', 'ぽかぽか',
  '元気な', '優しい', '賢い', '勇敢な', '陽気な',
  '穏やかな', '明るい', '爽やかな', '温かい', '楽しい',
];

const List<String> _animals = [
  'ペンギン', 'うさぎ', 'くま', 'ねこ', 'いぬ',
  'パンダ', 'コアラ', 'キツネ', 'リス', 'ハムスター',
  'カピバラ', 'アルパカ', 'レッサーパンダ', 'フクロウ', 'カワウソ',
  'シロクマ', 'ライオン', 'ゾウ', 'キリン', 'ペリカン',
];

final Random _random = Random();

String generateNickname() {
  final adjective = _adjectives[_random.nextInt(_adjectives.length)];
  final animal = _animals[_random.nextInt(_animals.length)];
  final number = _random.nextInt(100);
  return '$adjective$animal$number';
}
