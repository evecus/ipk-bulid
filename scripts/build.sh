#!/bin/bash
# build.sh - 从模板生成 luci-app-xx IPK
# 所有参数通过环境变量传入（由 workflow 设置）

set -e

# ── 参数读取 ──────────────────────────────────────────────
PKG_NAME="${INPUT_PACKAGE_NAME}"           # luci-app-sub-store
SERVICE_TITLE="${INPUT_SERVICE_TITLE}"     # Sub-Store
VERSION="${INPUT_VERSION}"                 # 1.0-r1
DESCRIPTION="${INPUT_DESCRIPTION}"         # 简单的订阅管理器
BINARY="${INPUT_BINARY}"                   # /usr/bin/sub-store
START_ARGS="${INPUT_START_ARGS}"           # --port=$port --path=$backend_path
HAS_WEB="${INPUT_HAS_WEB}"                 # true / false
WEB_ENTRY="${INPUT_WEB_ENTRY}"             # 3001 或 3001/ui
EXTRA_OPTIONS="${INPUT_EXTRA_OPTIONS}"     # port:3001:端口 backend_path:/sub-store:后端路径

# ── 自动推导 ──────────────────────────────────────────────
# 服务名：去掉 luci-app- 前缀
SERVICE_NAME="${PKG_NAME#luci-app-}"

# 二进制名：取最后一段
BINARY_NAME="$(basename "${BINARY}")"

TEMPLATES_DIR="$(dirname "$0")/../templates"
BUILD_DIR="/tmp/luci_build_${PKG_NAME}"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

echo ">>> Building ${PKG_NAME} ${VERSION}"
echo "    service_name : ${SERVICE_NAME}"
echo "    binary_name  : ${BINARY_NAME}"
echo "    has_web      : ${HAS_WEB}"
echo "    web_entry    : ${WEB_ENTRY}"
echo "    extra_options: ${EXTRA_OPTIONS}"

# ── 解析 extra_options ────────────────────────────────────
# 格式: 变量名:默认值:显示标签（空格分隔多个）
declare -a VAR_NAMES=()
declare -a VAR_DEFAULTS=()
declare -a VAR_LABELS=()

if [ -n "${EXTRA_OPTIONS}" ]; then
    for item in ${EXTRA_OPTIONS}; do
        IFS=':' read -r vname vdefault vlabel <<< "${item}"
        VAR_NAMES+=("${vname}")
        VAR_DEFAULTS+=("${vdefault}")
        VAR_LABELS+=("${vlabel}")
    done
fi

# ── 生成 CONFIG_GETS 块（init.d 用）──────────────────────
CONFIG_GETS=""
for i in "${!VAR_NAMES[@]}"; do
    vname="${VAR_NAMES[$i]}"
    vdefault="${VAR_DEFAULTS[$i]}"
    # 对齐格式
    CONFIG_GETS="${CONFIG_GETS}    local ${vname}\n"
    CONFIG_GETS="${CONFIG_GETS}    config_get ${vname} main ${vname} '${vdefault}'\n"
done

# ── 生成 START_ARGS_PROCD（init.d procd_append 用）────────
START_ARGS_PROCD=""
if [ -n "${START_ARGS}" ]; then
    # 把 $varname 替换成 shell 引用写法，每个参数一行
    # 先按空格分词，逐个 append
    for arg in ${START_ARGS}; do
        # 展开 $varname 为实际 shell 变量引用（在 heredoc 里已经是字面量）
        START_ARGS_PROCD="${START_ARGS_PROCD} \\\\\n        ${arg}"
    done
fi

# ── 生成 EXTRA_FIELDS（main.js LuCI 输入框）──────────────
EXTRA_FIELDS=""

# has_web=true 时加网页入口输入框
if [ "${HAS_WEB}" = "true" ]; then
    WEB_ENTRY_DEFAULT="${WEB_ENTRY:-3001}"
    EXTRA_FIELDS="${EXTRA_FIELDS}        o = s.option(form.Value, 'web_entry', '网页入口');\n"
    EXTRA_FIELDS="${EXTRA_FIELDS}        o.placeholder = '${WEB_ENTRY_DEFAULT}';\n"
    EXTRA_FIELDS="${EXTRA_FIELDS}        o.default = '${WEB_ENTRY_DEFAULT}';\n"
    EXTRA_FIELDS="${EXTRA_FIELDS}        o.rmempty = false;\n"
    EXTRA_FIELDS="${EXTRA_FIELDS}\n"
fi

# extra_options 对应的输入框
for i in "${!VAR_NAMES[@]}"; do
    vname="${VAR_NAMES[$i]}"
    vdefault="${VAR_DEFAULTS[$i]}"
    vlabel="${VAR_LABELS[$i]}"
    EXTRA_FIELDS="${EXTRA_FIELDS}        o = s.option(form.Value, '${vname}', '${vlabel}');\n"
    EXTRA_FIELDS="${EXTRA_FIELDS}        o.placeholder = '${vdefault}';\n"
    EXTRA_FIELDS="${EXTRA_FIELDS}        o.default = '${vdefault}';\n"
    EXTRA_FIELDS="${EXTRA_FIELDS}        o.rmempty = false;\n"
    EXTRA_FIELDS="${EXTRA_FIELDS}\n"
done

# ── 生成打开 Web 按钮（has_web=true）──────────────────────
WEB_ENTRY_DEFAULT="${WEB_ENTRY:-3001}"
# 分离端口和路径
WEB_PORT="${WEB_ENTRY_DEFAULT%%/*}"
WEB_PATH="${WEB_ENTRY_DEFAULT#*/}"
[ "${WEB_PATH}" = "${WEB_ENTRY_DEFAULT}" ] && WEB_PATH=""  # 没有路径部分

if [ "${HAS_WEB}" = "true" ]; then
    if [ -n "${WEB_PATH}" ]; then
        OPEN_URL="'http://' + window.location.hostname + ':' + entry.split('/')[0] + '/' + entry.split('/').slice(1).join('/')"
    else
        OPEN_URL="'http://' + window.location.hostname + ':' + entry"
    fi
    OPEN_BTN_DEF="            const openBtn = E('button', {\n"
    OPEN_BTN_DEF="${OPEN_BTN_DEF}                'class': 'btn cbi-button',\n"
    OPEN_BTN_DEF="${OPEN_BTN_DEF}                'style': 'margin-left:12px; padding:2px 12px; font-size:13px;',\n"
    OPEN_BTN_DEF="${OPEN_BTN_DEF}                'click': function() {\n"
    OPEN_BTN_DEF="${OPEN_BTN_DEF}                    const entry = uci.get('${SERVICE_NAME}', 'main', 'web_entry') || '${WEB_ENTRY_DEFAULT}';\n"
    OPEN_BTN_DEF="${OPEN_BTN_DEF}                    window.open(${OPEN_URL}, '_blank');\n"
    OPEN_BTN_DEF="${OPEN_BTN_DEF}                }\n"
    OPEN_BTN_DEF="${OPEN_BTN_DEF}            }, '打开 Web 界面');\n"
    OPEN_BTN_REF=",\n                    openBtn"
else
    OPEN_BTN_DEF=""
    OPEN_BTN_REF=""
fi

# ── 生成 UCI 默认配置 ─────────────────────────────────────
UCI_DEFAULTS="config ${SERVICE_NAME} main\n"
UCI_DEFAULTS="${UCI_DEFAULTS}\toption enabled '0'\n"
if [ "${HAS_WEB}" = "true" ]; then
    UCI_DEFAULTS="${UCI_DEFAULTS}\toption web_entry '${WEB_ENTRY_DEFAULT}'\n"
fi
for i in "${!VAR_NAMES[@]}"; do
    UCI_DEFAULTS="${UCI_DEFAULTS}\toption ${VAR_NAMES[$i]} '${VAR_DEFAULTS[$i]}'\n"
done

# ── 模板替换函数 ──────────────────────────────────────────
render_template() {
    local src="$1"
    local dst="$2"
    cp "${src}" "${dst}"

    # 使用 python3 做替换（避免 sed 对特殊字符的问题）
    python3 - "${dst}" << PYEOF
import sys, re

path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()

replacements = {
    '{{PKG_NAME}}':        '${PKG_NAME}',
    '{{SERVICE_NAME}}':    '${SERVICE_NAME}',
    '{{SERVICE_TITLE}}':   '${SERVICE_TITLE}',
    '{{VERSION}}':         '${VERSION}',
    '{{DESCRIPTION}}':     '${DESCRIPTION}',
    '{{BINARY}}':          '${BINARY}',
    '{{BINARY_NAME}}':     '${BINARY_NAME}',
    '{{CONFIG_GETS}}':     '${CONFIG_GETS}'.replace('\\\\n', '\n'),
    '{{START_ARGS_PROCD}}':'${START_ARGS_PROCD}'.replace('\\\\n', '\n'),
    '{{EXTRA_FIELDS}}':    '${EXTRA_FIELDS}'.replace('\\\\n', '\n'),
    '{{OPEN_BTN_DEF}}':    '${OPEN_BTN_DEF}'.replace('\\\\n', '\n'),
    '{{OPEN_BTN_REF}}':    '${OPEN_BTN_REF}'.replace('\\\\n', '\n'),
}

for k, v in replacements.items():
    content = content.replace(k, v)

with open(path, 'w') as f:
    f.write(content)
PYEOF
}

# ── 创建包目录结构 ────────────────────────────────────────
PKG_DATA="${BUILD_DIR}/data"
PKG_CTRL="${BUILD_DIR}/ctrl"

mkdir -p "${PKG_DATA}/etc/config"
mkdir -p "${PKG_DATA}/etc/init.d"
mkdir -p "${PKG_DATA}/etc/uci-defaults"
mkdir -p "${PKG_DATA}/usr/share/luci/menu.d"
mkdir -p "${PKG_DATA}/usr/share/rpcd/acl.d"
mkdir -p "${PKG_DATA}/usr/share/rpcd/ucode"
mkdir -p "${PKG_DATA}/www/luci-static/resources/view/${SERVICE_NAME}"
mkdir -p "${PKG_CTRL}"

# ── etc/config ────────────────────────────────────────────
printf "${UCI_DEFAULTS}" > "${PKG_DATA}/etc/config/${SERVICE_NAME}"

# ── etc/init.d ────────────────────────────────────────────
render_template "${TEMPLATES_DIR}/init.d.sh" \
    "${PKG_DATA}/etc/init.d/${SERVICE_NAME}"
chmod 755 "${PKG_DATA}/etc/init.d/${SERVICE_NAME}"

# ── etc/uci-defaults ──────────────────────────────────────
render_template "${TEMPLATES_DIR}/uci-defaults.sh" \
    "${PKG_DATA}/etc/uci-defaults/${PKG_NAME}"
chmod 755 "${PKG_DATA}/etc/uci-defaults/${PKG_NAME}"

# ── menu.d ────────────────────────────────────────────────
render_template "${TEMPLATES_DIR}/menu.json" \
    "${PKG_DATA}/usr/share/luci/menu.d/${PKG_NAME}.json"

# ── acl.d ─────────────────────────────────────────────────
render_template "${TEMPLATES_DIR}/acl.json" \
    "${PKG_DATA}/usr/share/rpcd/acl.d/${PKG_NAME}.json"

# ── ucode RPC ─────────────────────────────────────────────
render_template "${TEMPLATES_DIR}/ucode.uc" \
    "${PKG_DATA}/usr/share/rpcd/ucode/luci.${SERVICE_NAME}"
chmod 755 "${PKG_DATA}/usr/share/rpcd/ucode/luci.${SERVICE_NAME}"

# ── LuCI views ────────────────────────────────────────────
render_template "${TEMPLATES_DIR}/main.js" \
    "${PKG_DATA}/www/luci-static/resources/view/${SERVICE_NAME}/main.js"
render_template "${TEMPLATES_DIR}/log.js" \
    "${PKG_DATA}/www/luci-static/resources/view/${SERVICE_NAME}/log.js"

# ── control ───────────────────────────────────────────────
render_template "${TEMPLATES_DIR}/control" "${PKG_CTRL}/control"
cp "${TEMPLATES_DIR}/postinst.sh" "${PKG_CTRL}/postinst"
cp "${TEMPLATES_DIR}/prerm.sh"    "${PKG_CTRL}/prerm"
chmod 755 "${PKG_CTRL}/postinst" "${PKG_CTRL}/prerm"

# ── 打包 IPK ──────────────────────────────────────────────
find "${PKG_DATA}" -type f | xargs chmod 644
find "${PKG_DATA}" -type d | xargs chmod 755
chmod 755 \
    "${PKG_DATA}/etc/init.d/${SERVICE_NAME}" \
    "${PKG_DATA}/etc/uci-defaults/${PKG_NAME}" \
    "${PKG_DATA}/usr/share/rpcd/ucode/luci.${SERVICE_NAME}"

cd "${PKG_DATA}"
tar czf "${BUILD_DIR}/data.tar.gz" ./ --owner=0 --group=0

cd "${PKG_CTRL}"
tar czf "${BUILD_DIR}/control.tar.gz" ./ --owner=0 --group=0

echo "2.0" > "${BUILD_DIR}/debian-binary"

IPK_NAME="${PKG_NAME}_${VERSION}_all.ipk"
cd "${BUILD_DIR}"
tar czf "${GITHUB_WORKSPACE}/${IPK_NAME}" \
    ./debian-binary ./control.tar.gz ./data.tar.gz

echo ">>> Built: ${IPK_NAME}"
echo "ipk_name=${IPK_NAME}" >> "${GITHUB_OUTPUT}"
