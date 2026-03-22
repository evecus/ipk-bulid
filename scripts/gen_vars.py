#!/usr/bin/env python3
"""
gen_vars.py - 从环境变量生成模板替换字典，写入 JSON 文件
用法: python3 gen_vars.py <output_vars.json>
"""
import json, os, sys

out_path = sys.argv[1]

pkg_name      = os.environ['INPUT_PACKAGE_NAME']
service_title = os.environ['INPUT_SERVICE_TITLE']
version       = os.environ['INPUT_VERSION']
description   = os.environ['INPUT_DESCRIPTION']
binary        = os.environ['INPUT_BINARY']
start_args    = os.environ.get('INPUT_START_ARGS', '').strip()
has_web       = os.environ.get('INPUT_HAS_WEB', 'false').lower() == 'true'
web_entry     = os.environ.get('INPUT_WEB_ENTRY', '3001').strip() or '3001'
extra_options = os.environ.get('INPUT_EXTRA_OPTIONS', '').strip()
work_dir      = os.environ.get('INPUT_WORK_DIR', '').strip()

service_name = pkg_name.replace('luci-app-', '', 1)
binary_name  = binary.split('/')[-1]

# ── 解析 extra_options ────────────────────────────────────
var_names, var_defaults, var_labels = [], [], []
if extra_options:
    for item in extra_options.split():
        parts = item.split(':', 2)
        if len(parts) == 3:
            var_names.append(parts[0])
            var_defaults.append(parts[1])
            var_labels.append(parts[2])

# ── WORK_DIR_PROCD（init.d 用）──────────────────────────
work_dir_procd = ("    procd_set_param chdir '" + work_dir + "'\n") if work_dir else ""

# ── CONFIG_GETS（init.d 用）──────────────────────────────
config_gets = ''
for i, vname in enumerate(var_names):
    config_gets += f'    local {vname}\n'
    config_gets += f"    config_get {vname} main {vname} '{var_defaults[i]}'\n"

# ── START_ARGS_PROCD（init.d procd_set_param 用）──────────
start_args_procd = ''
if start_args:
    for arg in start_args.split():
        start_args_procd += f' \\\n        {arg}'

# ── UCI 默认配置 ──────────────────────────────────────────
uci_defaults = f'config {service_name} main\n'
uci_defaults += "\toption enabled '0'\n"
if has_web:
    uci_defaults += f"\toption web_entry '{web_entry}'\n"
for i, vname in enumerate(var_names):
    uci_defaults += f"\toption {vname} '{var_defaults[i]}'\n"

# ── EXTRA_FIELDS（main.js 输入框）────────────────────────
extra_fields = ''
if has_web:
    extra_fields += f"        o = s.option(form.Value, 'web_entry', '网页入口');\n"
    extra_fields += f"        o.placeholder = '{web_entry}';\n"
    extra_fields += f"        o.default = '{web_entry}';\n"
    extra_fields += f"        o.rmempty = false;\n\n"
for i, vname in enumerate(var_names):
    extra_fields += f"        o = s.option(form.Value, '{vname}', '{var_labels[i]}');\n"
    extra_fields += f"        o.placeholder = '{var_defaults[i]}';\n"
    extra_fields += f"        o.default = '{var_defaults[i]}';\n"
    extra_fields += f"        o.rmempty = false;\n\n"

# ── 打开 Web 按钮 ─────────────────────────────────────────
open_btn_def = ''
open_btn_ref = ''
if has_web:
    if '/' in web_entry:
        port_part = web_entry.split('/')[0]
        path_part = '/' + '/'.join(web_entry.split('/')[1:])
        open_url = f"'http://' + window.location.hostname + ':{port_part}{path_part}'"
    else:
        open_url = "'http://' + window.location.hostname + ':' + entry"

    open_btn_def  = "            const openBtn = E('button', {\n"
    open_btn_def += "                'class': 'btn cbi-button',\n"
    open_btn_def += "                'style': 'margin-left:12px; padding:2px 12px; font-size:13px;',\n"
    open_btn_def += "                'click': function() {\n"
    open_btn_def += f"                    const entry = uci.get('{service_name}', 'main', 'web_entry') || '{web_entry}';\n"
    open_btn_def += f"                    window.open({open_url}, '_blank');\n"
    open_btn_def += "                }\n"
    open_btn_def += "            }, '打开 Web 界面');\n"
    open_btn_ref  = ",\n                    openBtn"

# ── 写出 JSON ─────────────────────────────────────────────
replacements = {
    '{{PKG_NAME}}':         pkg_name,
    '{{SERVICE_NAME}}':     service_name,
    '{{SERVICE_TITLE}}':    service_title,
    '{{VERSION}}':          version,
    '{{DESCRIPTION}}':      description,
    '{{BINARY}}':           binary,
    '{{BINARY_NAME}}':      binary_name,
    '{{CONFIG_GETS}}':      config_gets,
    '{{START_ARGS_PROCD}}': start_args_procd,
    '{{WORK_DIR_PROCD}}':   work_dir_procd,
    '{{EXTRA_FIELDS}}':     extra_fields,
    '{{OPEN_BTN_DEF}}':     open_btn_def,
    '{{OPEN_BTN_REF}}':     open_btn_ref,
    '{{UCI_DEFAULTS}}':     uci_defaults,
}

with open(out_path, 'w', encoding='utf-8') as f:
    json.dump(replacements, f, ensure_ascii=False, indent=2)

print(f'    wrote {len(replacements)} vars to {out_path}')
