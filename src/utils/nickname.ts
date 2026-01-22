// 匿名ニックネーム生成
const adjectives = [
  'ふわふわ', 'きらきら', 'もこもこ', 'ぴかぴか', 'にこにこ',
  'わくわく', 'うきうき', 'すやすや', 'のびのび', 'ぽかぽか',
  '元気な', '優しい', '賢い', '勇敢な', '陽気な',
  '穏やかな', '明るい', '爽やかな', '温かい', '楽しい',
];

const animals = [
  'ペンギン', 'うさぎ', 'くま', 'ねこ', 'いぬ',
  'パンダ', 'コアラ', 'キツネ', 'リス', 'ハムスター',
  'カピバラ', 'アルパカ', 'レッサーパンダ', 'フクロウ', 'カワウソ',
  'シロクマ', 'ライオン', 'ゾウ', 'キリン', 'ペリカン',
];

export const generateNickname = (): string => {
  const adjective = adjectives[Math.floor(Math.random() * adjectives.length)];
  const animal = animals[Math.floor(Math.random() * animals.length)];
  const number = Math.floor(Math.random() * 100);
  return `${adjective}${animal}${number}`;
};
