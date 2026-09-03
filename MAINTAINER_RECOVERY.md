# iSnapNuke 維護者災難復原備忘錄

> **用途：** 在原本的 Mac、Keychain 或本機發布檔案遺失後，協助維護者在新 Mac 重建 iSnapNuke 的建置、簽署、notarization、更新與 GitHub Release 發布環境。
>
> **安全界線：** 此文件可以提交到 GitHub，但它**不是**秘密備份。不要在這裡填入或提交私鑰、`.p12` 密碼、Apple app-specific password、GitHub PAT、OpenAI API key、App Store Connect `.p8` 檔內容，或 Keychain 匯出資料。

本文中的 `<…>` 都是必須由安全備份或新建立的憑證替換的佔位符。執行前請確認終端機不會記錄秘密到 shell history，也不要把秘密檔複製到 repository 內。

## 先讀這一節

不要在確認備份狀態前，直接重新產生所有金鑰或撤銷既有憑證。

| 項目 | 是否可直接重新產生 | 為什麼 |
| --- | --- | --- |
| Sparkle EdDSA 私鑰 | **否** | 已發布 App 信任原本的 Sparkle 公鑰。換新私鑰後，新 appcast 無法被既有 App 驗證。 |
| 更新政策私鑰 | **否** | 已發布 App 信任原本內嵌的更新政策公鑰。換新私鑰後，既有 App 不會接受新政策。 |
| Developer ID Application 憑證與本機私鑰 | 可以重新申請，但先評估 | 遺失時可新建憑證，但要保留既有簽署身分的連續性，應先從加密備份還原 `.p12`。 |
| notarytool 認證 | 可以重建 | 可重新建立 app-specific password 或 App Store Connect API key，並重新存入 Keychain profile。 |
| GitHub PAT | 可以重建 | 撤銷舊 token 後建立有正確 repository 寫入權限的新 token。 |
| `OPENAI_API_KEY` | 可以重建 | 重新建立或從安全的秘密管理工具還原即可。 |
| `.build/`、DMG、dSYM、archive、release notes | 可以重建 | 都是 source code 與發布流程產生的衍生物。 |

## 現行非秘密設定索引

以下是目前發布腳本使用的識別資訊與預設位置。它們不是秘密，但腳本更新後應以 `releae.sh` 為準。

| 項目 | 目前值 |
| --- | --- |
| GitHub repository | `League2EB/iSnapNuke` |
| Git remote | `git@github.com:League2EB/iSnapNuke.git` |
| 預設 branch | `main` |
| App bundle identifier | `com.xuanci.isnapnuke` |
| `notarytool` Keychain profile | `iSnapNuke-notary` |
| Sparkle Keychain account | `com.xuanci.isnapnuke` |
| 更新政策私鑰預設路徑 | `~/.config/iSnapNuke/update-policy.key` |
| GitHub PAT Keychain service | `iSnapNuke-gh-pat` |
| GitHub PAT Keychain account | `League2EB` |
| GitHub CLI 預設路徑 | `/opt/homebrew/bin/gh` |
| 預設 OpenAI model | `gpt-5.6-terra` |
| Sparkle 工具目錄 | `.build/artifacts/sparkle/Sparkle/bin/` |

`OPENAI_API_KEY` 的目前約定是從 `~/.zshrc` 匯出到 shell 環境，而不是寫在 repository 或 Keychain。它供本機 `scripts/generate-release-notes.py` 產生發布摘要使用；一般 source build 不需要它，但 `./releae.sh --check` 與正式發布流程會要求它存在。

## Git 未追蹤檔案與安全備份

### 與發布直接相關的忽略項目

| Git ignore 項目 | 用途 | 新 Mac 的處理方式 |
| --- | --- | --- |
| `/releae.sh` | 本機互動式發布編排器，依序處理 preflight、版本、測試、簽署、notarization、appcast、policy、tag 與 GitHub Release。注意檔名目前拼作 `releae.sh`。 | 從**加密安全備份**還原，不要加入 Git。 |
| `/scripts/generate-release-notes.py` | 用 `OPENAI_API_KEY` 與 `OPENAI_MODEL` 產生雙語發布摘要。 | 從**加密安全備份**還原，不要加入 Git。 |
| `/scripts/package-update.sh` | 建立、notarize、staple 及驗證 Apple Silicon DMG。 | 從**加密安全備份**還原，不要加入 Git。 |
| `*.key`、`*.privatekey`、`.sparkle_private_key` | 更新簽章私鑰或其暫存匯出檔。 | 只從**加密安全備份**還原到 repository 外的位置。 |
| `dist/`、`*.dSYM`、`*.xcarchive` | DMG、App bundle、debug symbols 與 archive 等發布產物。 | 重新建置，無須備份。 |
| `.build/`、`.swiftpm/`、`DerivedData/` | SwiftPM、Xcode 的快取與中間產物。 | 重新建置，無須備份。 |

`.git/info/exclude` 也在本機忽略 `/releae.sh` 與 `/.build`。它本身不會被 clone，因此新 Mac 以 `.gitignore` 為主要保護；若需要相同本機排除規則，可自行補上。

### 已追蹤、可用來重建發布流程的檔案

下列檔案應從 Git clone 取得，不需另行備份：

- `Packaging/Info.plist`：bundle、版本、Sparkle feed 與更新政策 URL。
- `Packaging/appcast.template.xml`、`Packaging/update-policy.template.json`：更新 metadata 的模板。
- `appcast.xml`、`update-policy.json`：目前已發布的更新 metadata。
- `scripts/build-app.sh`：建置 App、注入兩個公開金鑰，並以 hardened runtime 與 timestamp 簽署。
- `scripts/verify-app-bundle.sh`：驗證 App bundle、Sparkle framework、簽章與 timestamp。
- `scripts/set-version.sh`、`scripts/validate-release.sh`：版本、build number、tag 與 HEAD 一致性檢查。

> `.p12`、`.cer`、`.p8` 等敏感檔即使目前沒有全部被 `.gitignore` 模式涵蓋，也絕不可放入 repository。請只把它們保存在加密備份、受存取控制的 secrets manager 或 Keychain。

## 新 Mac 的基本環境

### 1. 取得 source code 與 GitHub 存取權

建立新的 SSH key 或從安全備份還原既有 SSH 設定，將**公開金鑰**加到 GitHub 帳號後，驗證並 clone：

```zsh
ssh -T git@github.com

git clone git@github.com:League2EB/iSnapNuke.git
cd iSnapNuke
git switch main
git remote -v
```

預期 `origin` 的 fetch 與 push URL 都是 `git@github.com:League2EB/iSnapNuke.git`。若 clone 時使用其他 URL，可安全地改回 SSH remote：

```zsh
git remote set-url origin git@github.com:League2EB/iSnapNuke.git
```

SSH key 可重新建立，不影響使用者已安裝 App 的更新驗證。

### 2. 安裝工具

安裝目前 release script 所需的工具：

- Xcode 與 Command Line Tools，提供 `xcrun`、`codesign`、`notarytool`、`stapler`、`hdiutil`、`spctl`、`lipo`、`PlistBuddy`。
- Swift、Git、Python 3。
- Homebrew 與 GitHub CLI，預設位置是 `/opt/homebrew/bin/gh`。

不要把本文件記錄的目前版本視為永久最低要求。請先查看 `releae.sh` 的 `verify_prerequisites`，再用以下指令確認新機實際可用的工具：

```zsh
xcodebuild -version
swift --version
git --version
python3 --version
/opt/homebrew/bin/gh --version
```

先讓 SwiftPM 下載依賴並產生 Sparkle 工具：

```zsh
swift build -c release

SPARKLE_BIN="$PWD/.build/artifacts/sparkle/Sparkle/bin"
test -x "$SPARKLE_BIN/generate_appcast"
test -x "$SPARKLE_BIN/generate_keys"
test -x "$SPARKLE_BIN/sign_update"
```

## Apple Developer 與簽署要求

### 帳號與角色

為了發布網站或 GitHub 下載的 macOS App，需要：

1. 已啟用雙重認證的 Apple Account。
2. 有效的 Apple Developer Program 會員資格。
3. 能管理專案所屬 Apple Developer team 的帳號權限。現行 Developer ID Application 憑證建立流程要求 **Account Holder**；雲端管理的 Developer ID 憑證有另外的角色規則。

如果是組織 enrollment，Apple 可能要求合法實體、D‑U‑N‑S Number、可代表公司的授權、工作用 email 與網站。請依 Apple Developer 後台在當時顯示的最新要求辦理。

### Developer ID Application 憑證

現行流程建立的是 `.dmg`，因此需要 **Developer ID Application** 憑證來簽署 App 與 DMG。它**不**產生 `.pkg`，所以目前不需要 Developer ID Installer 憑證；現行 App 也沒有使用 Developer ID provisioning profile。

優先順序：

1. **先嘗試延續既有身分：** 從安全備份匯入包含憑證與相符私鑰的 `.p12`。單獨下載 `.cer` 不足以簽署。
2. **只有備份確定遺失時才建立新憑證：** 用 Keychain Access 建立新的 CSR，再到 Apple Developer 的 Certificates 頁面建立 Developer ID Application 憑證。
3. 匯入或新建後，列出可用的 code-signing identities，確認其中包含要用於本專案的 Developer ID Application identity：

```zsh
security find-identity -v -p codesigning
```

在 Keychain Access 匯出 `.p12` 時，使用長且獨立的匯出密碼，並把該檔與密碼放在不同的受保護位置。新 Mac 上雙擊 `.p12` 或從 Keychain Access 匯入，再重新執行上面的 identity 檢查。

### Notarization

發布腳本會：

1. 以 Developer ID、hardened runtime 與 secure timestamp 簽署 App 及 Sparkle 的巢狀程式碼。
2. 送出 App archive 給 `notarytool`，staple App。
3. 建立並簽署 DMG，送出 DMG，再 staple 與 Gatekeeper 驗證。

這些步驟要求有效 Developer ID 簽章與可用的 `notarytool` Keychain profile。現行 profile 名稱為 `iSnapNuke-notary`。

選擇**其中一種**認證方式，並只在 Keychain 儲存結果：

```zsh
# 方法 A：Apple ID + app-specific password。
# 不帶 --password，讓 notarytool 在安全提示中詢問，避免把密碼放進 shell history。
xcrun notarytool store-credentials "iSnapNuke-notary" \
  --apple-id "<Apple ID email>" \
  --team-id "<從 Apple Developer 帳號取得的 Team ID>" \
  --validate
```

```zsh
# 方法 B：App Store Connect API key。
# .p8 路徑必須在 repository 外的受保護位置。
xcrun notarytool store-credentials "iSnapNuke-notary" \
  --key "<安全位置>/AuthKey_<KEY_ID>.p8" \
  --key-id "<KEY_ID>" \
  --issuer "<ISSUER_ID>" \
  --validate
```

App Store Connect API `.p8` 私鑰通常只能下載一次。若採用方法 B，務必把它放進加密備份，而不是 Git。建立完成後，安全地驗證 profile：

```zsh
xcrun notarytool history --keychain-profile "iSnapNuke-notary"
```

## 更新簽章私鑰

### Sparkle EdDSA 私鑰，必須還原

Sparkle 的私鑰保存在 macOS Keychain，使用 account `com.xuanci.isnapnuke`。`generate_keys` 的 `-p` 只顯示公開金鑰，`-x` 可把私鑰匯出至檔案，`-f` 可在新 Mac 匯入。

在**仍可使用的舊 Mac**上，將私鑰匯出到 repository 外、由加密備份接手的位置：

```zsh
SPARKLE_BIN="$PWD/.build/artifacts/sparkle/Sparkle/bin"
"$SPARKLE_BIN/generate_keys" \
  --account "com.xuanci.isnapnuke" \
  -x "<安全暫存位置>/iSnapNuke-sparkle.privatekey"
```

從該安全備份還原到**新 Mac**後，匯入 Keychain：

```zsh
SPARKLE_BIN="$PWD/.build/artifacts/sparkle/Sparkle/bin"
"$SPARKLE_BIN/generate_keys" \
  --account "com.xuanci.isnapnuke" \
  -f "<安全備份還原位置>/iSnapNuke-sparkle.privatekey"

"$SPARKLE_BIN/generate_keys" \
  --account "com.xuanci.isnapnuke" \
  -p
```

將最後輸出的公開金鑰與先前已封存的公開金鑰或既有 release build 內的 `SUPublicEDKey` 比對。不要在尚未確認備份遺失前直接執行不帶 `-f` 的 `generate_keys`，否則可能建立不相容的新私鑰。

### 更新政策私鑰，必須還原

現行預設路徑是：

```text
~/.config/iSnapNuke/update-policy.key
```

從加密備份還原時，建立私有目錄並限制檔案權限：

```zsh
install -d -m 700 "$HOME/.config/iSnapNuke"
install -m 600 \
  "<安全備份還原位置>/update-policy.key" \
  "$HOME/.config/iSnapNuke/update-policy.key"
```

只輸出並核對導出的**公開金鑰**：

```zsh
swift run -c release iSnapNukeReleaseTool print-policy-public-key \
  --private-key "$HOME/.config/iSnapNuke/update-policy.key"
```

這個值必須與已發布 App 所信任的更新政策公開金鑰一致。若 Sparkle 或更新政策私鑰真的永久遺失，必須另行設計相容性遷移或接受既有安裝無法透過原更新通道升級，不能把「直接重生金鑰」當成一般復原方式。

## GitHub、OpenAI 與本機發布腳本

### GitHub PAT

建立新的 PAT 時，僅授權 `League2EB/iSnapNuke` 所需的最小權限。現行 preflight 會驗證：

- token 所屬 GitHub 帳號為 `League2EB`；
- 對 `League2EB/iSnapNuke` 具有推送／Contents 寫入能力。

以下模板會讓 `security` 以安全提示取得 PAT，不要把 token 寫在指令列、`~/.zshrc`、shell history 或文件中：

```zsh
security add-generic-password -U \
  -a "League2EB" \
  -s "iSnapNuke-gh-pat" \
  -w
```

檢查項目存在而不讀出值：

```zsh
security find-generic-password \
  -a "League2EB" \
  -s "iSnapNuke-gh-pat" \
  >/dev/null
```

可用下列方式暫時將 token 傳給 GitHub CLI 進行身份與 repository 權限檢查。它不會把 token 印到終端機：

```zsh
GH_TOKEN="$(security find-generic-password \
  -a "League2EB" \
  -s "iSnapNuke-gh-pat" \
  -w)" \
  /opt/homebrew/bin/gh api user --jq .login
unset GH_TOKEN
```

### `OPENAI_API_KEY`

目前的發布摘要產生器從 `~/.zshrc` 的環境變數讀取 API key。請用安全的文字編輯器開啟檔案，加入或更新下列內容：

```zsh
# iSnapNuke 本機發布摘要，絕不可提交到 Git。
export OPENAI_API_KEY="<新的秘密值>"
export OPENAI_MODEL="gpt-5.6-terra"
```

重新開啟 shell 或載入設定後，只檢查它是否存在，不要輸出值：

```zsh
source ~/.zshrc
[[ -n "${OPENAI_API_KEY:-}" ]] && print "OPENAI_API_KEY 已設定"
```

`OPENAI_MODEL` 可覆寫；若沒有特別需要，保留目前預設 `gpt-5.6-terra`。若改用其他秘密管理方式，發布前仍必須讓 `OPENAI_API_KEY` 存在於目前 shell 環境。

### 還原本機發布腳本

從加密安全備份取回下列檔案，複製到對應位置後設定可執行權限。這些檔案被刻意忽略，**不要** `git add -f`：

```zsh
REPO="<iSnapNuke repository 絕對路徑>"

install -m 700 "<安全備份>/releae.sh" \
  "$REPO/releae.sh"
install -m 700 "<安全備份>/generate-release-notes.py" \
  "$REPO/scripts/generate-release-notes.py"
install -m 700 "<安全備份>/package-update.sh" \
  "$REPO/scripts/package-update.sh"
```

還原後先檢查沒有把秘密硬編碼到腳本，且重要的設定仍符合本文件「現行非秘密設定索引」：

```zsh
cd "$REPO"
git check-ignore -v releae.sh scripts/generate-release-notes.py scripts/package-update.sh
```

## 新機復原與發布檢查表

### 一次性復原

- [ ] 取得 repository，確認 branch 是 `main`，remote 指向 `git@github.com:League2EB/iSnapNuke.git`。
- [ ] 安裝 Xcode／Command Line Tools、Swift、Git、Python 3、Homebrew 與 GitHub CLI。
- [ ] 從安全備份還原三個 local-only scripts，且不提交它們。
- [ ] 還原 Developer ID `.p12`，並以 `security find-identity` 驗證 signing identity。
- [ ] 建立或還原 `iSnapNuke-notary` Keychain profile，並用 `notarytool history` 驗證。
- [ ] 匯入原本的 Sparkle 私鑰並核對公開金鑰。
- [ ] 還原 `~/.config/iSnapNuke/update-policy.key` 並核對公開金鑰。
- [ ] 建立新的 GitHub PAT，存入 `iSnapNuke-gh-pat` / `League2EB` Keychain item。
- [ ] 在 `~/.zshrc` 或替代的安全環境注入方式設定 `OPENAI_API_KEY`。
- [ ] 執行 `swift build -c release`，確認 Sparkle 工具存在。

### 每次正式發布前

- [ ] `git status --short --branch` 顯示在 `main`，沒有未提交或未追蹤的工作。
- [ ] `git fetch origin` 後，本機 `main` 與 `origin/main` 已同步。
- [ ] 不帶任何秘密輸出地執行 `./releae.sh --check`。
- [ ] 先修正 preflight 所有錯誤，再執行正式發布。
- [ ] 僅在互動式 Terminal 執行 `./releae.sh`，閱讀版本、build number、最低支援版本與 release notes 的確認提示。

`./releae.sh --check` 不修改檔案、不建立 tag、不建立 GitHub Release。正式模式會在確認後依序：

1. 更新 `Packaging/Info.plist` 的版本與 build number。
2. 執行 `swift test`。
3. 使用 Developer ID 簽署 App，將 Sparkle 與更新政策的**公開金鑰**注入 App。
4. 建立、notarize、staple 並驗證 Apple Silicon DMG。
5. 產生並簽署 Sparkle `appcast.xml`。
6. 產生並簽署 `update-policy.json`。
7. 驗證產物與 metadata，建立 release commit 與 annotated tag。
8. 先推送 tag，建立 GitHub draft Release 並上傳 DMG。
9. 從 GitHub 下載 draft DMG 再驗證，然後發布 Release，最後推送 `main` 與更新 metadata。

這是對 GitHub 有寫入作用的不可逆或高影響操作。發布中斷後，不要盲目重跑，先檢查 `git status`、本機 tag、GitHub Release 狀態與 script 的錯誤訊息。

## 公開提交前的安全檢查

本文件本身應被 Git 追蹤，而不應被忽略：

```zsh
if git check-ignore -q MAINTAINER_RECOVERY.md; then
  print -u2 "錯誤：MAINTAINER_RECOVERY.md 不應被 ignore"
  exit 1
fi

git status --short
```

提交前人工檢查 diff，尤其確認沒有以下內容：

- `-----BEGIN … PRIVATE KEY-----` 區塊；
- 真正的 PAT、API key、app-specific password、`.p8` 或 `.p12`；
- `security find-generic-password ... -w` 的輸出結果；
- 任何可用來直接登入或簽署的秘密值。

## 官方參考

- [Apple Developer Program enrollment](https://developer.apple.com/programs/enroll/)
- [Developer ID certificates](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/)
- [建立 Certificate Signing Request](https://developer.apple.com/help/account/certificates/create-a-certificate-signing-request/)
- [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Sparkle documentation](https://sparkle-project.org/documentation/)
- [Sparkle GitHub repository](https://github.com/sparkle-project/Sparkle)

Apple、GitHub、Sparkle 與 OpenAI 的流程或權限需求可能會改變。若本文件和現行工具／官方文件衝突，優先採用最新的官方文件與 repository 中的 release scripts，並在完成後更新本備忘錄。
