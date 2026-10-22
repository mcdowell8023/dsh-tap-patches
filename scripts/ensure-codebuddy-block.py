#!/usr/bin/env python3
"""确保 profile 的 cordis.patch.yml 的 llm-pi-ai.providers 下有完整 codebuddy 块。

背景：dsh 的 patch 合并对同 id 条目是「顶层字段浅覆盖」。desktop profile 的
llm-pi-ai 条目（用户自建 ark / igateway / qoder）会把 dsh-tap bundle 层同 id
条目的 providers 整块顶掉，导致 codebuddy 路由缺席、dsh-tap 镜像写入被 schema
拒绝（needs an api）、界面显示宿主漂移。

用法: ensure-codebuddy-block.py <cordis.patch.yml> <codebuddy-block.yml>
幂等：已有 codebuddy: 键时直接退出。改动前写 .bak-<时间戳>。
"""
import sys
import os
import shutil
import time
import json
import subprocess

TARGET, BLOCK_FILE = sys.argv[1], sys.argv[2]
text = open(TARGET, encoding='utf-8').read()

if '\n      codebuddy:' in text or text.startswith('      codebuddy:'):
    print('codebuddy 块已存在，跳过')
    sys.exit(0)

lines = text.splitlines(keepends=True)
try:
    idx_entry = next(i for i, l in enumerate(lines) if l.rstrip() == '- id: llm-pi-ai')
except StopIteration:
    print('找不到 llm-pi-ai 条目，跳过（该 profile 不用 codebuddy）')
    sys.exit(0)

idx_prov = None
for i in range(idx_entry, len(lines)):
    if lines[i].rstrip() == '    providers:':
        idx_prov = i
        break
if idx_prov is None:
    print('llm-pi-ai 条目下没有 providers:，跳过')
    sys.exit(0)

block = open(BLOCK_FILE, encoding='utf-8').read()
if not block.endswith('\n'):
    block += '\n'

backup = f'{TARGET}.bak-{time.strftime("%Y%m%d-%H%M%S")}-codebuddy-block'
shutil.copy2(TARGET, backup)
out = lines[:idx_prov + 1] + [block] + lines[idx_prov + 1:]
open(TARGET, 'w', encoding='utf-8').write(''.join(out))

# 用 host 同款 yaml 解析器做一次校验
node = '''const YAML=require(%s);const fs=require('fs');
const doc=YAML.parse(fs.readFileSync(%s,'utf8'));
const row=doc.find(r=>r.id==='llm-pi-ai');
const p=row&&row.config&&row.config.providers;
if(!p||!p.codebuddy||!p.codebuddy.api){console.error('codebuddy block invalid');process.exit(1)}
console.log('providers:',Object.keys(p).join(', '))''' % (
    json.dumps('/Applications/DSH Desktop.app/Contents/Resources/app/node_modules/yaml'),
    json.dumps(TARGET))
res = subprocess.run(['node', '-e', node], capture_output=True, text=True)
if res.returncode != 0:
    shutil.copy2(backup, TARGET)
    print('校验失败，已回滚:', res.stderr.strip())
    sys.exit(1)
print('已插入 codebuddy 块；', res.stdout.strip())
print('备份:', backup)
