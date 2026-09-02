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
  <a href="#features">功能</a> · <a href="#why">製作原因</a> · <a href="#screenshots">螢幕截圖</a> · <a href="#safety">安全規則</a> · <a href="#force-mode">管他去死模式</a> · <a href="#how-it-works">運作方式</a> · <a href="#installation">安裝</a> · <a href="#updates">版本更新</a> · <a href="#build-from-source">從原始碼建置</a> · <a href="#release-process">發布流程</a> · <a href="#faq">常見問題</a>
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

- Apple Silicon Mac
- macOS 14 或以上

### 預先建置版本

請從 [GitHub Releases](https://github.com/League2EB/iSnapNuke/releases) 下載 Apple Silicon DMG，打開後將 `iSnapNuke.app` 拖到 Applications 捷徑。

公開建置版本均使用 Developer ID 憑證簽署，並通過 Apple notarization。

<a id="updates"></a>

## 版本更新

iSnapNuke 的直接下載版沒有應用程式後端。它從此 repository 讀取小型且經簽章的更新政策，並使用已簽章的 Sparkle 磁碟映像檔安裝更新。

- 目前 build 落後最新 build、但仍被支援時，App 顯示可關閉的「有可用更新」提示。
- 目前 build 小於 `minimumSupportedBuild` 時，App 會以「必須更新」畫面取代主畫面；只可更新、重新檢查政策或退出。
- App 會快取最後一份有效政策。GitHub 無法連線時，已快取的強制更新政策仍會生效；首次啟動且沒有快取時則放行，不會只因暫時無法取得政策而鎖住離線使用者。
- 政策請求使用 HTTPS 與 ETag 驗證，不會包含 APFS metadata、帳號資訊或遙測資料。

政策和 Sparkle appcast 位於固定 repository 路徑：

- `https://raw.githubusercontent.com/League2EB/iSnapNuke/main/update-policy.json`
- `https://raw.githubusercontent.com/League2EB/iSnapNuke/main/appcast.xml`

### 本機更新流程 Demo

Demo 不會下載封存檔、不會寫入更新政策快取，也不會執行 `diskutil`；它同時使用 App 既有的安全快照 Demo 模式。

```sh
./scripts/demo-update.sh optional  # 顯示「有可用更新」
./scripts/demo-update.sh required  # 顯示「必須更新」阻擋畫面
./scripts/demo-update.sh upToDate  # 顯示一般 Demo App
./scripts/demo-update.sh offline   # 驗證首次離線放行
```

前兩種情境點選「立即更新」可驗證安裝交接；App 會提示這是本機 Demo，不會安裝任何檔案。

<a id="build-from-source"></a>

## 從原始碼建置

在專案的本機 checkout 目錄中執行：

```sh
swift test
./scripts/build-app.sh
open dist/iSnapNuke.app
```

`build-app.sh` 會在 `dist/iSnapNuke.app` 產生 Release App bundle，從 `Assets/AppIcon/iSnapNuke.jpg` 建立 `.icns` 圖示，並以 ad-hoc 方式簽署 bundle 供本機使用。

從原始碼建置需要 Xcode Command Line Tools。

若 Gatekeeper 阻擋首次啟動，請在 Finder 中按住 Control 點擊 App，然後選擇「打開」。關閉主視窗時，App 就會結束。

<a id="release-process"></a>

## 發布流程

不可只發布 bare tag。每個公開版本都必須包含 GitHub Release 資產、已簽章的 Sparkle appcast 項目，以及已簽章的更新政策。

### 一次性金鑰設定

1. 在此 repository 外建立政策簽章金鑰：

   ```sh
   swift run iSnapNukeReleaseTool generate-policy-key \
     --private-key "$HOME/.config/iSnapNuke/update-policy.key"
   ```

   保存輸出的公開金鑰。私鑰必須保密，不能 commit。

2. 使用 Sparkle 官方 [`generate_keys`](https://sparkle-project.org/documentation/publishing/) 工具在 Keychain 建立 Sparkle EdDSA 金鑰組。本專案使用 account `com.xuanci.isnapnuke`，並保存輸出的公開金鑰。

3. 安裝 Developer ID Application 憑證，並將 App Store Connect notarization 憑證存入 `notarytool` Keychain profile。以下命令使用本機 profile `iSnapNuke-notary`。

4. 建立只允許存取 `League2EB/iSnapNuke`、權限為 `Contents: Read and write` 的 fine-grained GitHub PAT，再以 service `iSnapNuke-gh-pat`、account `League2EB` 存入 Keychain。使用隱藏輸入，避免 token 出現在 shell history：

   ```zsh
   read -s "TOKEN?GitHub PAT: "; print
   security add-generic-password -U \
     -a League2EB \
     -s iSnapNuke-gh-pat \
     -w "$TOKEN"
   unset TOKEN
   ```

   Git push 仍使用 SSH；PAT 只供 `gh` 呼叫 Release API。

5. 在安全的 release shell 或 CI secret store 中匯出公開金鑰與簽章 identity：

   ```sh
   export UPDATE_POLICY_PUBLIC_KEY="<policy public key>"
   export SPARKLE_PUBLIC_KEY="<Sparkle public key>"
   export SIGNING_IDENTITY="Developer ID Application: XuanCi Tech. Co., Ltd. (T46J69KN43)"
   export NOTARY_PROFILE="iSnapNuke-notary"
   ```

   本專案刻意不保存憑證、私鑰、token 或 notarization 憑證。

### 每次發布檢查表

1. 更新兩個版本欄位，且 build 必須遞增：

   ```sh
   ./scripts/set-version.sh 1.1.0 2
   ```

2. 在同一個已設定安全 release 環境變數的 shell 中，建置並驗證 Developer ID App，接著建立、簽署、notarize、staple 與驗證 Apple Silicon DMG：

   ```sh
   REQUIRE_UPDATE_KEYS=1 ./scripts/build-app.sh
   ./scripts/verify-app-bundle.sh
   NOTARIZE=1 ./scripts/package-update.sh
   ```

   產物為 `dist/release/iSnapNuke-1.1.0-2-arm64.dmg`，內容包含 `iSnapNuke.app` 與 `/Applications` 捷徑。

3. 使用最終 notarized DMG 產生含 EdDSA 簽章的 Sparkle appcast 項目：

   ```sh
   VERSION=1.1.0
   BUILD=2
   TAG="v$VERSION"
   DMG="dist/release/iSnapNuke-$VERSION-$BUILD-arm64.dmg"
   FEED_DIR=".build/release-feed/$TAG"
   mkdir -p "$FEED_DIR"
   cp "$DMG" "$FEED_DIR/"
   .build/artifacts/sparkle/Sparkle/bin/generate_appcast \
     --account com.xuanci.isnapnuke \
     --download-url-prefix "https://github.com/League2EB/iSnapNuke/releases/download/$TAG/" \
     -o appcast.xml \
     "$FEED_DIR"
   ```

4. 複製 `Packaging/update-policy.template.json`，填入新版號、build、更新說明與 ISO-8601 發布時間，然後簽章：

   ```sh
   swift run iSnapNukeReleaseTool sign-policy \
     --policy /path/to/policy-input.json \
     --private-key "$HOME/.config/iSnapNuke/update-policy.key" \
     --output update-policy.json
   swift run iSnapNukeReleaseTool verify-policy \
     --policy update-policy.json \
     --public-key "<policy public key>"
   ```

5. Commit 所有發布改動，在該 commit 建立對應 tag、執行驗證，再透過 SSH push branch 與 tag：

   ```sh
   git tag -a "$TAG" -m "iSnapNuke $VERSION"
   ./scripts/validate-release.sh "$TAG"
   git push origin main "$TAG"
   ```

6. 使用 Keychain 中的 PAT 建立公開 GitHub Release 並上傳 DMG：

   ```sh
   TOKEN="$(security find-generic-password \
     -a League2EB -s iSnapNuke-gh-pat -w)"
   GH_TOKEN="$TOKEN" /opt/homebrew/bin/gh release create "$TAG" "$DMG" \
     --repo League2EB/iSnapNuke \
     --title "iSnapNuke $VERSION" \
     --notes-file /path/to/release-notes.md
   unset TOKEN
   ```

7. 重新下載公開資產，將 SHA-256 checksum 與本機 DMG 比對，並再次執行 DMG、stapler、code-signing 與 Gatekeeper 驗證後再正式公告。

要發布非強制更新，`minimumSupportedBuild` 要維持在上一個仍支援的 build。只有確定新的 GitHub Release 資產可公開下載並能正常安裝後，才提高此值。不可降低已發布的最低 build，客戶端會拒絕政策回滾。

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

iSnapNuke 在本機運作，不會安裝背景服務、不收集遙測資料，也不上傳快照資料。快照操作不包含網路通訊。直接下載版僅在檢查版本更新時，以 HTTPS 向 GitHub 取得已簽章更新政策；只有你點選「立即更新」後，才會下載已簽章發布磁碟映像檔。

<a id="license"></a>

## 授權

本專案採用 [MIT 授權條款](LICENSE)。
