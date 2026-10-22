# 兼容性对照

| 补丁集 | dsh-tap | dsh | DSH Desktop | 验证日期 | 结果 |
|---|---|---|---|---|---|
| `dsh-tap@0.20.0.patch` | 0.20.0 | 0.2.1-rc.2 | 2.0.18 | 2026-10-22 | 六项校验全通过（`./verify.sh desktop`） |

## 升级步骤（dsh-tap 有新版本时）

1. 先卸掉旧的 patchedDependencies：

   ```bash
   cd ~/.dsh/profiles/desktop
   # 从 pnpm-workspace.yaml 删除对应 patchedDependencies 条目，删掉 patches/ 下的旧 patch
   ```

2. 用插件管理器升级 dsh-tap，记录新版本号。
3. `cd dsh-tap-patches && ./apply.sh`：
   - 有对应版本的 patch → 直接应用
   - 没有 → 脚本报错退出，需要重做补丁（见下）

## 重做补丁（版本变化时）

```bash
cd ~/.dsh/profiles/desktop
ELECTRON_RUN_AS_NODE=1 CI=true \
  "/Applications/DSH Desktop.app/Contents/MacOS/DSH Desktop" \
  "/Applications/DSH Desktop.app/Contents/Resources/app/node_modules/pnpm/bin/pnpm.cjs" \
  patch dsh-tap@<new-version> --edit-dir /tmp/dtp

# 在 /tmp/dtp 里重新应用四处改动（参考本仓库 patch 文件的内容）
ELECTRON_RUN_AS_NODE=1 CI=true ... patch-commit /tmp/dtp
cp patches/dsh-tap@<new-version>.patch <本仓库>/patches/
./verify.sh
```

## 已知边界

- 补丁只针对 `dsh-tap@0.20.0` 的源码结构；上游重构（文件迁移/函数改名）后 patch 会应用失败——pnpm 会报错而不是静默半应用，属于可接受失败。
- `profile/codebuddy-block.yml` 的 models 是 23 条静态基线，运行时会被插件镜像成实际可用列表（当前 15 条），不需要手工维护。
- 如果上游合并了这些修复，对应补丁应从本仓库移除，避免与新版本冲突。
