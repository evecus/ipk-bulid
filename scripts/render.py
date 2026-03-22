#!/usr/bin/env python3
"""
render.py - 用 vars.json 里的键值对替换模板文件里的占位符
用法: python3 render.py <src> <dst> <vars.json>
"""
import json, sys

src, dst, vars_file = sys.argv[1], sys.argv[2], sys.argv[3]

with open(src, 'r', encoding='utf-8') as f:
    content = f.read()

with open(vars_file, 'r', encoding='utf-8') as f:
    replacements = json.load(f)

for k, v in replacements.items():
    content = content.replace(k, v)

with open(dst, 'w', encoding='utf-8') as f:
    f.write(content)
