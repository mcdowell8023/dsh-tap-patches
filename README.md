# dsh-tap-patches

给 `dsh-tap`（DeepSeek Harness 的 CodeBuddy / TraeWork / Qoder 通道插件）打的本地补丁集，用 pnpm patch 机制持久化，重装/升级不会丢。

上游仓库：<https://github.com/taikaikaikai-pixel/dsh-tap>

## 为什么存在

上游 0.20.0 在 dsh 0.2.1-rc.2 / DSH Desktop 2.0.18 上有几处明确缺陷，本机已经验证并修复。补丁直接改 `node_modules` 会在每次重装时丢失，所以转成 `pnpm patch` 并集中管理，多台机器（本机、agent hub 主机）用同一套补丁。

## 补丁内容（dsh-tap@0.20.0）

| # | 文件 | 改动 | 修的问题 |
|---|---|---|---|
| 1 | `providers/codebuddy/index.js` | `IDENTITY_REWRITES` + `scrubIdentityStrings()` | CodeBuddy 网关渠道校验扫到 system prompt 里的 "DeepSeek Harness" 身份串，返回 400/11128 |
| 2 | `index.js` | `openAuthUrl()`（spawn 系统浏览器） | dsh Desktop 的 Electron 层拒绝所有 `window.open`，登录按钮点了没反应 |
| 3 | `index.js` | `readPin()` 兼容读 `config.searchProvider` | dsh 0.2.x 的 WebRuntime 没有 `searchProviderId` 字段，webPin 恒 false，卡片头永远误报「宿主漂移」 |
| 4 | `scripts/trae-model-catalog.mjs` | `PRODUCT_DIRS` 加 `Trae CN`；新增 darwin 分支 | Trae 的 db 发现只支持 Windows/WSL，macOS 上永远「未发现 state.vscdb」，模型列表为空 |
| 5 | `index.js` + `lib/client.js` | 凭据账号簿 `accounts[]` + `activeAccountId`，新增 `account-switch` / `account-remove` action 与账号列表 UI | 原先单账号：换号只能退出登录再登录，无法保留多个账号 |

### 多账号（补丁 5）使用说明

- 凭据文件 `~/.dsh/codebuddy-plugin-auth.json` 升级为 v2：`{schemaVersion:2, machine, activeAccountId, accounts[]}`；旧的单账号结构在首次读取时自动迁移，不会丢登录态。
- **添加账号**：CodeBuddy 卡片里点「添加账号」→ 浏览器授权另一个号 → 登录成功后自动成为新条目并切为当前。
- **切换**：账号多于一个时，卡片上出现账号按钮，点一下即切（只改 `activeAccountId`，下一次请求生效，不需要重启）。
- **删除**：`account-remove`（UI 第二版补按钮），删除当前账号后自动切到剩下的第一个。
- 自动切号（额度耗尽时自动跳到下一个）尚未实现，当前是手动切换。

另外两个不是包内补丁：

| # | 位置 | 内容 |
|---|---|---|
| 5 | `~/.dsh/profiles/<name>/cordis.patch.yml` | `llm-pi-ai.providers.codebuddy` 完整 provider 块（patch 层同 id 条目是整块浅覆盖，用户层会把插件 bundle 层的块顶掉） |
| 6 | `pnpm-workspace.yaml` | `patchedDependencies` 注册（由 apply.sh 自动写） |

## 用法

```bash
git clone <this-repo> ~/projects/tools/dsh-tap-patches
cd ~/projects/tools/dsh-tap-patches
./apply.sh                 # 默认 desktop profile
./apply.sh web             # 指定其它 profile
./apply.sh desktop --dry-run
```

`apply.sh` 是幂等的：补丁已注册就跳过，配置块已存在就不动。

`./verify.sh [profile]` 只读检查六处是否都到位。

## 版本同步

- 补丁按 `dsh-tap@<version>.patch` 命名，`apply.sh` 用当前安装版本自动匹配。
- dsh-tap 升级后如果补丁不再干净应用，pnpm 会直接报错（不会静默半应用）。此时需要按新版本重新做一遍补丁，或先卸掉 patchedDependencies 再升。
- 上游发版频繁时，优先把这些修复提 PR；合并后可以逐个从本仓库删掉。

## 相关记录

- 排障记录：`~/KnowledgeBase/Wiki/entities/pattern/DSH-接入CodeBuddy的三类故障与排查手法.md`
- 上游 issue：<https://github.com/taikaikaikai-pixel/dsh-tap/issues/4>
