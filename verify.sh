#!/usr/bin/env bash
# 只读校验：确认补丁已应用到指定 profile。
# 用法: ./verify.sh [profile]（默认 desktop）
set -euo pipefail

PROFILE="${1:-desktop}"
PROFILE_DIR="$HOME/.dsh/profiles/$PROFILE"
TAP="$PROFILE_DIR/node_modules/dsh-tap"
fail=0
ok() { printf '  OK   %s\n' "$*"; }
bad() { printf '  FAIL %s\n' "$*"; fail=1; }

echo "==> $PROFILE"

grep -q "IDENTITY_REWRITES" "$TAP/providers/codebuddy/index.js" 2>/dev/null \
  && ok "codebuddy 身份串脱敏" || bad "codebuddy 身份串脱敏缺失"

grep -q "openAuthUrl" "$TAP/index.js" 2>/dev/null \
  && ok "登录走系统浏览器" || bad "登录走系统浏览器缺失"

grep -q "readPin" "$TAP/index.js" 2>/dev/null \
  && ok "webPin 兼容读取" || bad "webPin 兼容读取缺失"

grep -q "Trae CN" "$TAP/scripts/trae-model-catalog.mjs" 2>/dev/null \
  && ok "Trae macOS db 发现" || bad "Trae macOS db 发现缺失"

grep -q "account-switch" "$TAP/index.js" 2>/dev/null \
  && grep -q "account-switch" "$TAP/lib/client.js" 2>/dev/null \
  && ok "多账号账号簿与切换 UI" || bad "多账号改动缺失"

VERSION="$(node -p "require('$TAP/package.json').version" 2>/dev/null || true)"
grep -q "dsh-tap@$VERSION" "$PROFILE_DIR/pnpm-workspace.yaml" 2>/dev/null \
  && ok "patchedDependencies 已注册 ($VERSION)" || bad "patchedDependencies 未注册"

[ -f "$PROFILE_DIR/patches/dsh-tap@$VERSION.patch" ] \
  && ok "patch 文件在位" || bad "patch 文件缺失"

if [ "$PROFILE" = "desktop" ]; then
  grep -q "codebuddy:" "$PROFILE_DIR/cordis.patch.yml" 2>/dev/null \
    && ok "cordis.patch.yml 含 codebuddy 块" || bad "cordis.patch.yml 缺 codebuddy 块"
fi

[ "$fail" = 0 ] && echo "全部通过" || { echo "存在缺失，跑 ./apply.sh $PROFILE"; exit 1; }
