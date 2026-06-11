# DESIGN_SPEC.md — FRC Motion Analyser UI v3

> 此文件係UI同功能實作嘅唯一真實來源（source of truth）。
> 配合 `frc-motion-ui-v3.html`（視覺參考，所有數值以此HTML代碼為準）同 `frc-knowledge-base.html`（FRC邏輯來源）使用。
> Claude Code：實作任何screen前必須先讀完本文件相關章節。

-----

## 0. 實作規則

1. 顏色、字體、圓角、間距一律用本文件嘅token，唔可以自創數值
1. 每個screen有「功能需求」同「驗收標準」，兩者都要滿足先算完成
1. 視覺細節有疑問時，打開 `frc-motion-ui-v3.html` 對照HTML/CSS代碼
1. 代償偵測邏輯、ROM參考值，一律以 `frc-knowledge-base.html` 為準
1. 逐個screen實作，完成一個先開下一個

-----

## 1. Design Tokens

### 顏色

|Token       |值                      |用途                        |
|------------|-----------------------|--------------------------|
|`ink`       |`#0A0A0A`              |全局背景                      |
|`surface`   |`#151515`              |卡片背景                      |
|`surface2`  |`#1E1E1E`              |次級表面（avatar等）             |
|`line`      |`rgba(255,255,255,.08)`|邊框、分隔線                    |
|`orange`    |`#FF5C00`              |主色：CTA、AROM弧、骨架、active tab|
|`orangeSoft`|`rgba(255,92,0,.14)`   |橙色底（coach cue背景）          |
|`good`      |`#4ADE80`              |正向數據、進步                   |
|`warn`      |`#FFB020`              |接近臨界、需注意                  |
|`deficit`   |`#FF3B5C`              |passive deficit、代償、退步     |
|`text`      |`#F5F2EE`              |主文字                       |
|`muted`     |`#8A8580`              |次文字、label                 |

顏色語義鐵律：**橙=主動/品牌、綠=好、黃=注意、紅=deficit/代償**。唔可以混用。

### 字體（Flutter: google_fonts package）

|角色     |字體                   |用途              |
|-------|---------------------|----------------|
|Display|Space Grotesk 600/700|頁面標題、greeting   |
|Body   |Inter 400–700        |一般UI文字          |
|Data   |DM Mono 400/500      |所有數字、角度、時間、label|

**規則：任何量化數據（角度、百分比、計數）一律DM Mono。**

### 形狀

- 卡片圓角 18 / 抽屜頂圓角 26 / 按鈕 14 / chip 999（全圓）
- 頁面左右padding 20
- Tab bar 高78，背景 `rgba(10,10,10,.92)` + blur

-----

## 2. 簽名元件：Range Arc

成個app嘅視覺DNA，出現喺Screen 02/04/05。用Flutter `CustomPainter` 實作。

### 結構（由內至外）

1. **底環**：半徑42，stroke 9，色 `rgba(255,255,255,.08)`，完整圓
1. **AROM弧**（橙 `#FF5C00`，stroke 9，round cap）：起點12點，長度 = `AROM / 該關節normative ROM`（normative值查knowledge base ROM表）
1. **Deficit弧**（紅 `rgba(255,59,92,.35)`，stroke 9）：由AROM終點延伸至PROM終點，即 `(PROM − AROM) / normative`
1. **PROM參考線**：半徑49（外圈），stroke 1.5，色 `rgba(255,255,255,.25–.28)`，長度 = `PROM / normative`
1. **中心文字**：主數值（DM Mono 17–19）+ 下方label（DM Mono 8.5–9，letter-spacing寬）

### 行為

- 數值變化時弧長動畫過渡（300ms ease-out）
- Deficit < 5° 時紅弧轉綠色調 `rgba(74,222,128,.3)`（達標狀態）

-----

## 3. Screen 01 — Home（主頁）

### 版面（上至下）

1. Eyebrow日期（DM Mono小字）+ greeting「早晨，{用戶名}」（Space Grotesk 24）
1. **開始評估CTA**：橙色漸變（`#FF5C00 → #FF8A3D`）大卡，黑字，右上裝飾圓環，內有黑底「選擇客戶」pill按鈕
1. **今日客戶**列表卡：每行 = avatar（首字母）+ 姓名 + meta（年齡·重點·週數）+ 右側關鍵joint數值（顏色按狀態：good/warn/deficit）
1. **本週數據**：兩張並排小卡（評估次數、平均AROM增幅）
1. Tab bar：主頁 / 客戶 / 評估 / 進度

### 功能需求

- 客戶列表來自Firestore，按今日排程排序
- 每個客戶顯示「上次評估最差關節」嘅數值，顏色邏輯：deficit較上次收窄→綠；不變→黃；惡化或8週重評到期→紅
- 8週重評到期客戶顯示 `RE-TEST DUE` 紅色標記（日期計算自上次完整評估）
- CTA → 客戶選擇 → 進入Screen 02

### 驗收標準

- [ ] 無客戶時顯示empty state（邀請加入第一位客戶，唔係空白）
- [ ] 重評到期邏輯經單元測試（55/56/57日邊界）

-----

## 4. Screen 02 — Live即時評估

### 版面

- 全屏camera feed，骨架overlay（橙線2.5px，關節點：黑底橙邊圓，活躍關節實心橙）
- 頂部HUD兩個chip：左 `REC 00:42`（紅點閃爍1.2s）、右 `POSE LOCKED · 31/33`（綠點，數字=偵測到嘅landmark數）
- 角度tag：黑底70%透明+blur，DM Mono 11px，跟隨關節位置；正常=橙邊、注意=黃邊、代償=紅邊紅字
- 底部抽屜：三段狀態（收起/peek/全開），peek內容 = Range Arc + 2×2 metrics grid

### 功能需求

- MediaPipe Pose即時推理（on-device），骨架overlay 30fps以上
- 即時計算並顯示：當前關節AROM、passive deficit（PROM由教練手動輸入或上次記錄帶入）、smoothness %（角速度變異係數）、代償計數
- 代償偵測（邏輯見knowledge base）：骨盆側傾>3°、肩胛上提、腰椎代償——觸發時對應tag轉紅+震動feedback
- 偵測到完整人體（landmark≥28）→ 抽屜自動由收起彈到peek（300ms spring）
- 抽屜全開：顯示該session所有已測關節列表
- 錄影記錄完整session，連同時間戳記嘅角度數據存Firestore

### 驗收標準

- [ ] 弱光環境pose lost時HUD chip轉黃「RE-ACQUIRING」，唔crash
- [ ] 抽屜手勢同自動彈出唔衝突
- [ ] 代償觸發延遲<200ms

-----

## 5. Screen 03 — CARs引導模式

### 版面

- 頂部置中：eyebrow「CARs · 第N/3圈」+ 關節名（Space Grotesk 18）+ `SLOW · MAX EFFORT · BREATHE`（DM Mono橙字，letter-spacing寬）
- 中央大圓軌跡（半徑118）：未行=白點線、已行=橙實線5px、代償區段=紅實線
- 目標光點：橙色圓+脈衝動畫（1.6s），沿軌跡移動
- 圓心：完成百分比（DM Mono 30）+ `ROTATION` label
- 底部：coach cue卡（橙底橙邊，`!` icon，具體指令文字）+ 三格stats（速度倍率/圓滑度/代償區段）

### 功能需求

- 軌跡 = 該關節CARs嘅理想路徑，用戶用肢體末端帶光點行圈
- 即時將實際關節軌跡映射到圓上，行過區段著色
- 代償觸發 → 該區段標紅 + coach cue更新（指明鐘面位置，例如「12點至1點」）+ 語音提示（TTS）
- 完成3圈 → 自動計算：平均速度、smoothness、代償區段clock map → 寫入評估記錄
- 速度過快（>1.2×建議速度）→ cue「減慢」

### 驗收標準

- [ ] 代償clock map準確記錄方位（12等分）
- [ ] 語音cue唔重疊（queue管理，最少間隔3秒）

-----

## 6. Screen 04 — 評估報告

### 版面

1. Eyebrow「{客戶} · 評估 #N」+ 標題（Space Grotesk 21）+ 對比日期（DM Mono muted）
1. 圖例行：AROM（橙線）/ PROM（白幼線）/ Deficit（紅）
1. **每關節一張arc card**：左Range Arc（86px，中心主數值+對上次delta），右側關節名+數據行（AROM·PROM·Deficit+對比）+狀態flag（綠✓進步 / 紅⚠代償描述）
1. **AI Summary卡**：左橙邊3px，`AI SUMMARY · 可編輯` label，專業文字
1. 橙色全寬按鈕「出PDF報告 →」

### 功能需求

- 自動對比上次評估，計算每關節delta
- Flag邏輯：deficit收窄→綠；連續2次無進步→黃描述；代償介入→紅+具體代償名
- AI summary：Claude API生成，輸入=本次+上次數據+代償記錄，輸出=書面語專業摘要（150字內，含下階段建議），**教練可編輯先出report**
- PDF：Movement Decoded品牌header、arc圖表、summary、教練簽名位
- 報告存Firestore + 可分享link

### 驗收標準

- [ ] AI summary生成失敗時可手動輸入，唔blocking
- [ ] PDF喺iOS/Android分享sheet正常運作

-----

## 7. Screen 05 — 進度追蹤

### 版面

1. Eyebrow「{客戶} · {關節}」+ 時間範圍pill（4週/8週/12週/全部，active=橙底黑字）
1. 大數字delta：`+13°`（DM Mono 42）+ 綠色`▲ 17%` + label「AROM增幅 · 8週」
1. **趨勢圖**（核心）：AROM橙實線3px+數據點、PROM白點線1.5px、兩線之間紅色填充`rgba(255,59,92,.16)` = deficit zone、zone中央標注「PASSIVE DEFICIT 收窄中」
1. 評估記錄log：日期 + 類型 + sub資訊（CARs次數·代償）+ 右側delta（綠+/灰0/紅−）

### 功能需求

- 圖表用fl_chart或CustomPainter，deficit zone填充係賣點，必須實現
- 時間範圍切換即時更新，動畫過渡
- 點擊數據點 → 跳轉該次評估報告（Screen 04）
- 關節切換器（同一客戶多關節追蹤）

### 驗收標準

- [ ] 只有1次評估時顯示單點+提示「再評估一次即可見趨勢」
- [ ] deficit zone喺AROM>PROM嘅異常數據下唔會反轉畫崩

-----

## 8. Flutter實作指引

```
依賴：
  google_fonts（Space Grotesk / Inter / DM Mono）
  camera + google_mlkit_pose_detection
  fl_chart（或CustomPainter自繪）
  firebase_core / cloud_firestore
  pdf + printing（報告輸出）
  flutter_tts（CARs語音cue）
```

- Range Arc、CARs軌跡圈、趨勢圖deficit zone：全部 `CustomPainter`，參考HTML內SVG嘅 `pathLength`/`stroke-dasharray` 邏輯轉換成 `canvas.drawArc` sweepAngle
- 抽屜：`DraggableScrollableSheet`，snap points `[0.08, 0.28, 0.85]`
- 主題集中喺 `lib/theme/tokens.dart`，所有顏色字體由此引用
- 動畫統一：300ms ease-out（數值變化）、spring（抽屜）

-----

## 9. 實作順序建議

1. `tokens.dart` + Range Arc widget（獨立可測試）
1. Screen 01 Home（靜態→接Firestore）
1. Screen 02 Live（camera+骨架先，metrics後）
1. Screen 04 Report（用mock數據先行）
1. Screen 03 CARs
1. Screen 05 Progress
1. AI summary + PDF最後

-----

*Movement Decoded · UI Design v3 · 2026-06*