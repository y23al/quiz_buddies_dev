# Quiz Buddies

リアルタイムクイズで繋がる学習コミュニティアプリ

## 概要

Quiz Buddiesは、1日2回ランダムな時間に出題されるクイズを通じて、ユーザー同士が「教え合う」体験を提供するアプリです。

### コア体験

- **BeReal的**：通知が届いたその瞬間にクイズに参加するライブ感
- **学び/交流**：間違えた人が、正解した人から教えてもらえる
- **短時間の濃いコミュニケーション**：30秒グループ→1on1→共同ROOM

## 技術スタック

- **Frontend**: React Native (Expo) + TypeScript
- **Backend**: Firebase (Auth, Firestore, Cloud Functions, FCM)
- **State Management**: Zustand

## セットアップ

### 1. 依存関係のインストール

```bash
npm install
```

### 2. Firebase設定

1. [Firebase Console](https://console.firebase.google.com/)で新しいプロジェクトを作成
2. Authentication で「匿名認証」を有効化
3. Firestore Database を作成
4. プロジェクト設定から設定値を取得

### 3. 環境変数の設定

`.env.example`をコピーして`.env`を作成し、Firebase設定値を入力：

```bash
cp .env.example .env
```

```
EXPO_PUBLIC_FIREBASE_API_KEY=your-api-key
EXPO_PUBLIC_FIREBASE_AUTH_DOMAIN=your-project.firebaseapp.com
EXPO_PUBLIC_FIREBASE_PROJECT_ID=your-project-id
EXPO_PUBLIC_FIREBASE_STORAGE_BUCKET=your-project.appspot.com
EXPO_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=your-sender-id
EXPO_PUBLIC_FIREBASE_APP_ID=your-app-id
```

### 4. Firestoreセキュリティルールのデプロイ

```bash
firebase deploy --only firestore:rules
```

### 5. Cloud Functionsのデプロイ

```bash
cd functions
npm install
npm run build
cd ..
firebase deploy --only functions
```

### 6. アプリの起動

```bash
npm start
```

## プロジェクト構成

```
src/
├── components/       # 共通コンポーネント
│   ├── Timer.tsx
│   ├── ChatMessage.tsx
│   ├── ChatInput.tsx
│   ├── QuizChoice.tsx
│   └── LoadingScreen.tsx
├── config/           # 設定ファイル
│   └── firebase.ts
├── hooks/            # カスタムフック
├── navigation/       # ナビゲーション
│   └── AppNavigator.tsx
├── screens/          # 画面コンポーネント
│   ├── auth/
│   │   └── AuthScreen.tsx
│   ├── home/
│   │   ├── HomeScreen.tsx
│   │   └── SettingsScreen.tsx
│   ├── quiz/
│   │   ├── QuizScreen.tsx
│   │   └── ResultScreen.tsx
│   └── room/
│       ├── GroupRoomScreen.tsx
│       ├── OneOnOneRoomScreen.tsx
│       └── CommonRoomScreen.tsx
├── services/         # APIサービス
│   ├── authService.ts
│   ├── sessionService.ts
│   └── roomService.ts
├── store/            # 状態管理
│   ├── authStore.ts
│   └── sessionStore.ts
├── types/            # 型定義
│   └── index.ts
└── utils/            # ユーティリティ
    ├── nickname.ts
    └── time.ts

functions/            # Cloud Functions
└── src/
    └── index.ts
```

## セッションの流れ

1. **通知受信**: ランダムな時刻にプッシュ通知
2. **クイズ参加**: 2分以内にアプリを開いてクイズに回答（60秒）
3. **グループROOM**: 正解者/不正解者に分かれて30秒チャット
4. **1on1 ROOM**: 正解者と不正解者がマッチして教え合い（3分）
5. **共同ROOM**: 全員が合流して雑談・感想共有（5分）

## 設定値（調整可能）

- 参加期限: 2分
- クイズ回答時間: 60秒
- グループROOM時間: 30秒
- 1on1 ROOM時間: 3分
- 共同ROOM時間: 5分
- セッション時間帯: 10:00〜22:00

## 開発用機能

ホーム画面の「[DEV] テストセッション作成」ボタンで、開発用のテストセッションを即座に作成できます（`__DEV__`環境のみ表示）。

## ライセンス

Private
