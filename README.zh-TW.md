<p align="center">
  <img src="Assets/AppIcon/iSnapNuke.jpg" width="120" alt="iSnapNuke 圖示">
</p>

<h1 align="center">iSnapNuke</h1>

<p align="center">用於檢視 APFS 快照，並只刪除符合保守安全條件之快照的 macOS App。</p>

<p align="center"><a href="README.md">English</a></p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2014%2B-000000?style=for-the-badge&amp;logo=apple&amp;logoColor=white" alt="平台：macOS 14 或以上">
  <img src="https://img.shields.io/badge/Swift-6-F05138?style=for-the-badge&amp;logo=swift&amp;logoColor=white" alt="Swift 6">
  <img src="https://img.shields.io/badge/License-MIT-80C342?style=for-the-badge" alt="授權：MIT">
</p>

<p align="center">
  <a href="#features">功能</a> · <a href="#why">製作原因</a> · <a href="#screenshots">螢幕截圖</a> · <a href="#safety">安全規則</a> · <a href="#force-mode">管他去死模式</a> · <a href="#how-it-works">運作方式</a> · <a href="#installation">安裝</a> · <a href="#build-from-source">從原始碼建置</a> · <a href="#faq">常見問題</a>
</p>

---

> 刪除 APFS 快照不可復原，也可能移除系統或備份還原點。刪除任何項目前，請先閱讀安全規則。

<a id="about"></a>

## 關於本專案

iSnapNuke 是在本機運作的 macOS 工具，用於檢視目前 System 與 Data 卷宗上的 APFS 快照。它會在一般 macOS 視窗中顯示快照 metadata，依保守刪除規則區分符合條件與受保護的快照，並且只會在你明確確認後執行刪除命令。

App 會顯示在 Dock，不會安裝背景服務，也不會自動刪除快照。

<a id="why"></a>

## 製作原因

<!-- 在此填寫 iSnapNuke 的製作原因。 -->

<a id="features"></a>

## 功能

- 讀取目前 System 與 Data 卷宗上的 APFS 快照。
- 顯示每個快照的名稱、UUID、XID、來源推斷、APFS metadata，以及可取得時的 APFS Private Size。
- 依快照名稱推斷已知來源，包括 macOS 更新、Time Machine 與 Synology Active Backup。
- 以保守安全規則區分「符合刪除條件」與「受保護」快照。
- 支援多選、不可復原操作確認對話框、每次刪除前的重新安全掃描、處理進度與逐筆結果摘要。
- 先以一般權限嘗試刪除，若 macOS 因可能的權限問題拒絕操作，可提供要求管理員授權的重試。
- 提供僅限本次啟動的「管他去死模式」，用於以管理員權限刻意嘗試刪除受保護快照。
- 支援英文與繁體中文介面。

<a id="screenshots"></a>

## 螢幕截圖

螢幕截圖即將提供。

<a id="safety"></a>

## 安全規則

一般模式下，只有同時符合以下所有條件的快照才能被選取：

1. 位於 Data 卷宗。
2. APFS 將 `Purgeable` 標記為 `Yes`。
3. 不是 `RevertTo` 快照。
4. 不是 `RootTo` 快照。
5. 名稱並非以 `com.apple.os.update` 開頭。
6. 名稱與所需 APFS metadata 均存在且有效。
7. UUID 與卷宗 device identifier 均符合預期格式。

只要 metadata 缺漏或未知，快照一律會被視為受保護。即使快照符合上述規則，它仍是還原點，刪除後將失去回復該卷宗至對應時間點的能力。

Time Machine 與第三方備份快照的來源名稱只用於辨識與顯示，不會因名稱自動受到保留。若它符合一般刪除條件，刪除後仍可能失去該本機還原點。請仔細確認每個選取項目。

> **預估可騰出空間：** iSnapNuke 以 APFS Private Size 顯示僅由該快照引用資料量的預估值。多個 APFS 快照可能共用 block，因此刪除一個或多個快照後實際釋放的空間可能不同。無法讀取數值時，App 會顯示為無法取得，不會猜測數字。

<a id="force-mode"></a>

## 管他去死模式

「管他去死模式」預設關閉，開啟時會先顯示獨立警告對話框，且只在本次 App 啟動期間有效，不會被儲存。

開啟後，只要 UUID 與 device identifier 通過命令輸入格式檢查，任何受保護快照都可以被選取。App 會要求 macOS 管理員授權，並逐筆嘗試刪除選取的快照，範圍包含 macOS 更新快照、System 卷宗快照、Time Machine 快照、第三方備份快照與未知來源快照。

此模式仍會保留刪除前重新掃描與輸入格式檢查，但會繞過 iSnapNuke 的保護分類。刪除不可復原，可能移除系統或備份還原點，macOS 也可能拒絕個別操作。不同於一般批次刪除，強制刪除批次會在發生失敗後繼續處理其他項目，並完整列出成功、略過與失敗結果。

<a id="how-it-works"></a>

## 運作方式

iSnapNuke 使用以下命令讀取卷宗與快照資訊：

```sh
diskutil info -plist /
diskutil info -plist /System/Volumes/Data
diskutil apfs listSnapshots <device> -plist
```

它會依前述安全規則評估回傳的 APFS metadata，並在作業系統可提供資訊時讀取 APFS Private Size。

在你選取快照並確認對話框後，iSnapNuke 會再次掃描，並在每個快照刪除前立即重新評估其安全狀態。一般刪除使用：

```sh
diskutil apfs deleteSnapshot <device> -uuid <uuid> -wait
```

若一般刪除因權限問題失敗，結果畫面可提供一個要求 macOS 管理員授權的重試操作。「管他去死模式」一律使用管理員授權。一般批次刪除在第一個失敗或略過項目停止；強制刪除批次則逐筆繼續處理。

<a id="installation"></a>

## 安裝

### 系統需求

- macOS 14 或以上
- Xcode Command Line Tools

### 預先建置版本

<!-- TODO: 發布正式版本後，在此加入公開下載網址與安裝說明。 -->

目前尚未提供已記錄的預先建置版本。請從原始碼建置本機 App bundle。

<a id="build-from-source"></a>

## 從原始碼建置

在專案的本機 checkout 目錄中執行：

```sh
swift test
./scripts/build-app.sh
open dist/iSnapNuke.app
```

`build-app.sh` 會在 `dist/iSnapNuke.app` 產生 Release App bundle，從 `Assets/AppIcon/iSnapNuke.jpg` 建立 `.icns` 圖示，並以 ad-hoc 方式簽署 bundle 供本機使用。

若 Gatekeeper 阻擋首次啟動，請在 Finder 中按住 Control 點擊 App，然後選擇「打開」。關閉主視窗時，App 就會結束。

<a id="language-support"></a>

## 語言支援

- 偏好的系統語言為 `zh-Hant`、`zh-TW`、`zh-HK` 或 `zh-MO` 時，使用繁體中文。
- 所有其他系統語言，包括簡體中文與日文，皆使用英文作為預設與 fallback。

<a id="faq"></a>

## 常見問題

### iSnapNuke 會修改 macOS 或自動刪除快照嗎？

不會。它只在本機讀取 APFS metadata，且只有在你明確選取快照並確認不可復原操作對話框後，才會執行刪除命令。它不會修改 macOS 系統檔案或快照內容。

### 為什麼某個快照受到保護？

它可能位於 System 卷宗、未被標記為可清除、是目前的回復或根快照、屬於 macOS 更新快照，或具有不完整、無效的 metadata。缺漏資訊一律會被視為不安全。

### 如果 macOS 拒絕刪除，會怎樣？

一般模式的結果畫面會標示失敗項目。若屬於可能的權限失敗，App 可提供要求 macOS 管理員授權的重試操作。一般批次刪除會在該項目停止，讓你先確認結果。

### 我可以刪除 Time Machine 或 Synology Active Backup 快照嗎？

App 會將它們的名稱辨識為來源推斷，但一般模式的刪除資格仍依 APFS metadata 與安全規則判定。刪除符合條件的備份快照仍可能移除本機還原點；「管他去死模式」也可以嘗試刪除受保護的備份快照，風險更高。

### APFS Private Size 是否等於我一定能回收的空間？

不完全是。它表示只由該快照引用的資料量，是實用的預估值，但快照可能共用 APFS block。最後實際釋放的磁碟空間可能更高或更低。

<a id="privacy"></a>

## 隱私

iSnapNuke 在本機運作，不會安裝背景服務、不收集遙測資料、不上傳快照資料，且快照操作不包含網路通訊。

<a id="license"></a>

## 授權

本專案採用 [MIT 授權條款](LICENSE)。
