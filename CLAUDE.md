# CLAUDE.md — FRC Motion Analyser

> 呢份文件係Claude Code嘅主要context文件。每次新session開始前必須先讀呢份文件。

-----

## Project Overview

**App名稱：** FRC Motion Analyser（暫定）
**品牌：** Movement Decoded
**負責人：** Ani（FRC certified PT，Animal Flow / FRC / NKT / Stick Mobility / Breathwork）
**開發模式：** Solo founder + AI Agent team
**目標：** 用鏡頭做motion capture，量化FRC關節評估（CARS / PAILs / RAILs），取代眼睇估計

-----

## 商業目標

### 短期

- 建立可用prototype驗證概念
- 搵投資者前準備pitch材料

### 長期

1. 上架Flutter app（iOS + Android）
1. 擴展賣給其他FRC practitioners（SaaS）
1. 整合落ElitePro coaching management platform

### 目標用戶

- 主要：FRC certified PTs（Ani自己先用，再賣俾同行）
- 次要：40–60歲注重longevity嘅客戶自用

-----

## 技術棧決定

### 已確認

|層次            |技術                                                |原因                                                        |
|--------------|--------------------------------------------------|----------------------------------------------------------|
|App框架         |**Flutter**                                       |Google官方支援MediaPipe；一套code出iOS+Android；camera pipeline效能最好|
|Pose Detection|**MediaPipe Pose** (`google_mlkit_pose_detection`)|On-device推理；33個landmarks；Flutter官方package                 |
|AI分析          |**Claude API** (`claude-sonnet-4-20250514`)       |輸入joint angle data → 輸出教練式FRC分析報告                         |
|後端/資料庫        |**Firebase Firestore**                            |Ani有ElitePro經驗；realtime；scalable                          |
|認證            |**Firebase Auth**                                 |同Firestore整合                                              |
|儲存            |**Firebase Storage**                              |評估截圖儲存                                                    |

### 已完成prototype

- `motion-capture-v2.html` — 純Web版本（MediaPipe + 即時骨架 + 關節角度 + 下方抽屜UI）
- 已host或可host喺GitHub Pages測試

### 暫定/待決定

- PDF報告生成方案（Flutter PDF library待選）
- RevenueCat vs Stripe subscription（V3）
- 多語言支援（英文先，廣東話/普通話後）

-----

## FRC Domain Knowledge

### 核心概念（必須理解）

**Mobility定義（FRC）**

- Mobility ≠ Flexibility
- Flexibility = Passive ROM（唔代表有控制）
- Mobility = Active ROM + Strength + Control
- 公式：Mobility = Flexibility + Neurological Control

**Injury Gap**

- PROM（被動）普遍比AROM（主動）多10–15°
- 呢個差距係「受傷風險區」
- PAILs/RAILs目的就係縮窄呢個gap

**CARs（Controlled Articular Rotations）**

- 關節喺最大主動幅度下嘅慢速旋轉
- 執行要求：全身irradiation（全身張力）+ 只動目標關節
- 雙重功能：日常保養 + 評估工具
- 左右對比：不對稱 >15° = 臨床顯著，需優先處理

**PAILs/RAILs Protocol**

```
步驟 1：到達end range → 保持2分鐘
步驟 2：PAILs — 漸進等長收縮（20%→100%）× 10–20秒
步驟 3：放鬆 5–10秒
步驟 4：RAILs — 主動進入新ROM × 10–20秒
步驟 5：喺新ROM重複循環
神經效果：end range等長收縮可釋放額外10–15°
```

### ROM參考數據

**髖關節（MVP優先）**

|動作       |正常範圍  |FRC理想|
|---------|------|-----|
|Flexion  |0–120°|>100°|
|Extension|0–30° |>20° |
|IR       |0–45° |對稱   |
|ER       |0–45° |對稱   |
|Abduction|0–45° |>40° |

**肩關節（MVP優先）**

|動作       |正常範圍  |
|---------|------|
|Flexion  |0–180°|
|Extension|0–60° |
|Abduction|0–180°|
|ER       |0–90° |
|IR       |0–70° |

**脊椎（V2）**

|部位/動作|正常範圍    |
|-----|--------|
|胸椎旋轉 |0–45° 各側|
|頸椎旋轉 |0–60° 各側|
|頸椎屈伸 |各0–45°  |

### 代償偵測邏輯（核心競爭優勢）

|評估關節   |常見代償         |MediaPipe偵測方法          |
|-------|-------------|-----------------------|
|髖CARS  |骨盆側傾         |LEFT/RIGHT HIP高度差 >3cm |
|髖IR/ER |骨盆前/後傾       |HIP-SHOULDER連線角度變化     |
|肩CARS  |肩胛上提 / 軀幹側彎  |SHOULDER landmark上升超基準線|
|頸椎CARS |肩膀跟著動        |SHOULDER angle變化監測     |
|胸椎旋轉   |腰椎代償旋轉       |SHOULDER旋轉量 vs HIP旋轉量比值|
|PAILs保持|End range位置下跌|計時期間angle持續監測，偏離>5°警示  |

### MediaPipe Landmark → FRC計算對照

```dart
// MediaPipe Pose 33個landmarks索引
const landmarks = {
  NOSE: 0,
  LEFT_SHOULDER: 11, RIGHT_SHOULDER: 12,
  LEFT_ELBOW: 13,    RIGHT_ELBOW: 14,
  LEFT_WRIST: 15,    RIGHT_WRIST: 16,
  LEFT_HIP: 23,      RIGHT_HIP: 24,
  LEFT_KNEE: 25,     RIGHT_KNEE: 26,
  LEFT_ANKLE: 27,    RIGHT_ANKLE: 28,
};

// 關節角度計算（3點）
double angle3(Point a, Point b, Point c) {
  // b係頂點（關節本身）
  // 返回0–180°
}

// 傾斜角度計算（2點水平差）
double tiltAngle(Point a, Point b) {
  return atan2(b.y - a.y, b.x - a.x) * 180 / pi;
}

// 主要計算
髖屈曲角：angle3(SHOULDER, HIP, KNEE)
膝屈曲角：angle3(HIP, KNEE, ANKLE)
肩屈曲角：angle3(HIP, SHOULDER, ELBOW)
骨盆傾斜：tiltAngle(LEFT_HIP, RIGHT_HIP)
肩膀水平：tiltAngle(LEFT_SHOULDER, RIGHT_SHOULDER)
軀幹前傾：atan2(midHip.x - midShoulder.x, midHip.y - midShoulder.y)
```

**重要限制：** IR/ER旋轉2D鏡頭難以準確量化，需要Z軸資訊。MVP用近似值，長遠考慮MediaPipe Pose Landmarker v2（3D）。

-----

## App 功能架構

### Phase 01 — MVP（而家做）

- [ ] Flutter project setup（google_mlkit_pose_detection）
- [ ] Camera feed + 即時骨架overlay
- [ ] 關節角度即時計算（髖、膝、肩）
- [ ] 骨盆 / 肩膀 / 軀幹排列指示
- [ ] CARS評估模式（引導 + 記錄）
- [ ] 代償偵測基礎版（骨盆側傾、肩胛上提）
- [ ] 評估結果儲存（Firestore）
- [ ] Claude API分析報告生成

### Phase 02 — Training

- [ ] PAILs/RAILs計時器 + 位置監測
- [ ] End range自動偵測
- [ ] 訓練前後ROM即時對比
- [ ] 語音提示 / 引導

### Phase 03 — Platform

- [ ] 多客戶管理
- [ ] PDF評估報告（帶品牌logo）
- [ ] 歷史記錄 + 進步趨勢圖
- [ ] 8週重新評估提醒

### Phase 04 — Scale

- [ ] 訂閱制（RevenueCat）
- [ ] 賣俾其他FRC practitioners
- [ ] ElitePro整合

-----

## 公司架構

### 現實層面

**法律實體：** Sole Trader（UK）— Bootstrapped，資金來自Ani自己
**團隊規模：** 1人（Ani）+ AI Agent team
**資金狀況：** Bootstrapped，目標係建立prototype後搵投資
**收入來源（現階段）：** PT coaching、私人補習、matched betting / bank switching補充收入

### 決策層

```
CEO / Founder / Domain Expert
└── Ani
    ├── 所有最終決策
    ├── FRC / 運動科學知識輸入
    ├── 用戶測試同驗證
    └── 投資者關係（人對人）
```

### Ani必須親自處理（AI做唔到）

|職能       |原因                               |
|---------|---------------------------------|
|法律文件 / 合約|App Store協議、隱私政策、Terms of Service|
|銀行 / 財務  |Stripe / RevenueCat設置、UK稅務申報     |
|投資者會面    |人對人關係，AI只能準備材料                   |
|真實用戶測試   |需要真實客戶反饋，AI無法替代                  |
|FRC邏輯驗證  |Ani係唯一能判斷分析結果正確性嘅人               |

### 搵投資時嘅對外架構（Pitch用）

```
CEO / Co-founder        — Ani
 └ Product vision · FRC domain expertise · GTM

CTO / Co-founder        — 待搵（Flutter + ML background）
 └ Flutter · MediaPipe · Firebase · infrastructure

Advisors（虛銜）        — 待搵1–2位
 └ Healthtech / FRC industry 有名望人士
```

> **優先行動：** 搵技術Co-founder（以equity換labour）係搵投資前最重要一步。目標：Flutter + ML背景，去London Tech meetups / YC co-founder matching搵。

### AI Agent Team職責邊界

AI可以完全cover：

- Product docs、PRD、roadmap
- Flutter code生成
- UI/UX設計方向
- Pitch deck、financial model
- Marketing copy、App Store文案
- FRC research同文獻搜集

AI做得到但Ani要把關：

- ML/CV pipeline調試（要Ani測試同反饋）
- 代償偵測邏輯（Ani確認FRC正確性）
- Claude API prompt優化（Ani評估輸出質素）

-----

## AI Agent Team

開發過程中唔同任務用唔同Claude Project / session，保持context清晰：

|Agent             |Claude Project名稱|主要職責                              |
|------------------|----------------|----------------------------------|
|Product Strategist|`01_product`    |PRD、user stories、功能優先次序           |
|ML/CV Engineer    |`02_ml_cv`      |MediaPipe整合、角度計算、代償邏輯             |
|Flutter Developer |`03_flutter`    |App UI、camera pipeline、Firebase整合 |
|UI/UX Designer    |`04_design`     |設計系統、wireframes、動畫                |
|Content/Marketing |`05_content`    |App Store文案、Movement Decoded內容    |
|Biz/Investor      |`06_biz`        |Pitch deck、財務模型、investor materials|
|Research/QA       |`07_qa`         |文獻查找、benchmark、測試腳本               |

-----

## Design System

**品牌：** Movement Decoded
**風格：** 活力專業（Energetic Professional）
**主色：** `#FF5C00`（橙）
**背景：** `#0A0A0A`
**字體：** Inter（UI）+ DM Mono（數據）
**UI模式：** 全屏鏡頭 + 下方抽屜式panel（三段：收起/半開/全開）
**骨架顏色：** 橙色overlay on camera

-----

## 重要文件

以下文件已建立，放喺outputs資料夾：

|文件                            |內容                            |
|------------------------------|------------------------------|
|`motion-capture-v2.html`      |Web prototype（可直接瀏覽器跑）        |
|`frc-motion-architecture.html`|完整功能架構（4 Phases）              |
|`frc-knowledge-base.html`     |FRC知識庫（CARs/PAILs/RAILs/ROM數據）|
|`motion-capture-ai-team.html` |AI Agent team架構               |

-----

## 下一步行動

### 即時

1. **Flutter project初始化**
   
   ```bash
   flutter create frc_motion_analyser
   cd frc_motion_analyser
   flutter pub add google_mlkit_pose_detection
   flutter pub add camera
   flutter pub add firebase_core cloud_firestore
   ```
1. **重現Web prototype嘅核心功能落Flutter**
- Camera feed
- MediaPipe骨架overlay
- 關節角度計算（同Web版邏輯一樣，改寫成Dart）
1. **加入CARS評估模式**

### 之後

- Anthropic API key申請
- Firebase project建立
- TestFlight beta測試（iOS先）

-----

## 開發原則

1. **Domain first：** 所有技術決定都要以FRC評估準確性為優先
1. **Mobile first：** 所有UI為手機屏幕設計
1. **On-device first：** ML推理盡量本地跑，保護用戶私隱
1. **Ani validates：** 所有FRC分析邏輯輸出必須由Ani親身測試確認正確性
1. **Prototype → Production：** Web版已驗證概念，Flutter版係同一邏輯

-----

*最後更新：2026 | 由Movement Decoded AI Agent Team維護*
