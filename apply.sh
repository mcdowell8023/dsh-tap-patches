#!/usr/bin/env bash
# 把 dsh-tap-patches 的补丁应用到指定 DSH profile。
# 幂等：补丁已注册、配置块已存在时不会重复写入。
#
# 用法:
#   ./apply.sh [profile] [--dry-run]
#   profile 默认 desktop
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE="desktop"
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -*) echo "unknown flag: $arg" >&2; exit 2 ;;
    *) PROFILE="$arg" ;;
  esac
done

APP="/Applications/DSH Desktop.app"
DESKTOP_BIN="$APP/Contents/MacOS/DSH Desktop"
PNPM_CJS="$APP/Contents/Resources/app/node_modules/pnpm/bin/pnpm.cjs"
PROFILE_DIR="$HOME/.dsh/profiles/$PROFILE"

say() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[ -d "$PROFILE_DIR" ] || die "profile 不存在: $PROFILE_DIR"
[ -x "$DESKTOP_BIN" ] || die "找不到 DSH Desktop: $DESKTOP_BIN"
[ -f "$PNPM_CJS" ] || die "找不到 app 内置 pnpm: $PNPM_CJS"
[ -f "$PROFILE_DIR/node_modules/dsh-tap/package.json" ] || die "$PROFILE 没装 dsh-tap"

VERSION="$(node -p "require('$PROFILE_DIR/node_modules/dsh-tap/package.json').version" 2>/dev/null || true)"
[ -n "$VERSION" ] || die "读不到 dsh-tap 版本"
PATCH_SRC="$REPO_DIR/patches/dsh-tap@$VERSION.patch"
[ -f "$PATCH_SRC" ] || die "没有 dsh-tap@$VERSION 的补丁（现有: $(ls "$REPO_DIR/patches" | tr '\n' ' '))"

say "==> profile=$PROFILE  dsh-tap=$VERSION"

# 1. 落 patch 文件
PATCH_DST="$PROFILE_DIR/patches"
if [ "$DRY_RUN" = 1 ]; then
  say "[dry-run] 会写入 $PATCH_DST/$(basename "$PATCH_SRC")"
else
  mkdir -p "$PATCH_DST"
  cp -f "$PATCH_SRC" "$PATCH_DST/"
  say "patch 文件: $PATCH_DST/$(basename "$PATCH_SRC")"
fi

# 2. 在 pnpm-workspace.yaml 注册 patchedDependencies（幂等）
WS="$PROFILE_DIR/pnpm-workspace.yaml"
if [ "$DRY_RUN" = 1 ]; then
  say "[dry-run] 会确保 $WS 含 patchedDependencies.$VERSION"
else
  python3 - "$WS" "$VERSION" <<'PY'
import sys, os, re
path, ver = sys.argv[1], sys.argv[2]
key = f"dsh-tap@{ver}"
entry = f"  {key}: patches/dsh-tap@{ver}.patch"
text = open(path, encoding='utf-8').read() if os.path.exists(path) else "packages:\n  - .\n"
if 'patchedDependencies:' in text:
    if re.search(rf'^\s+{re.escape(key)}:', text, re.M):
        print(f"patchedDependencies 已含 {key}")
    else:
        text = text.rstrip('\n') + '\n' + entry + '\n'
        open(path, 'w', encoding='utf-8').write(text)
        print(f"已追加 {key}")
else:
    text = text.rstrip('\n') + f'\npatchedDependencies:\n{entry}\n'
    open(path, 'w', encoding='utf-8').write(text)
    print(f"已创建 patchedDependencies 并加入 {key}")
PY
fi

# 3. 应用补丁
if [ "$DRY_RUN" = 1 ]; then
  say "[dry-run] 会执行 pnpm install 应用补丁"
else
  say "==> pnpm install（app 内置 11.x）"
  ( cd "$PROFILE_DIR" && ELECTRON_RUN_AS_NODE=1 CI=true "$DESKTOP_BIN" "$PNPM_CJS" install 2>&1 | tail -4 )
fi

# 4. 校验包内补丁
if [ "$DRY_RUN" = 0 ]; then
  "$REPO_DIR/verify.sh" "$PROFILE" || die "包内补丁校验失败"
fi

# 5. profile 层 codebuddy 块（仅 desktop 需要）
if [ "$PROFILE" = "desktop" ]; then
  if [ "$DRY_RUN" = 1 ]; then
    say "[dry-run] 会检查 cordis.patch.yml 的 codebuddy provider 块"
  else
    python3 "$REPO_DIR/scripts/ensure-codebuddy-block.py" "$PROFILE_DIR/cordis.patch.yml" "$REPO_DIR/profile/codebuddy-block.yml"
  fi
fi

say "完成。重启 DSH Desktop 生效。"
