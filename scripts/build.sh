#!/bin/bash
# build.sh - 从模板生成 luci-app-xx IPK
# 所有参数通过环境变量传入（由 workflow 设置）

set -e

PKG_NAME="${INPUT_PACKAGE_NAME}"
SERVICE_TITLE="${INPUT_SERVICE_TITLE}"
VERSION="${INPUT_VERSION}"
DESCRIPTION="${INPUT_DESCRIPTION}"
BINARY="${INPUT_BINARY}"
START_ARGS="${INPUT_START_ARGS}"
HAS_WEB="${INPUT_HAS_WEB}"
WEB_ENTRY="${INPUT_WEB_ENTRY}"
EXTRA_OPTIONS="${INPUT_EXTRA_OPTIONS}"

SERVICE_NAME="${PKG_NAME#luci-app-}"
BINARY_NAME="$(basename "${BINARY}")"
WEB_ENTRY_DEFAULT="${WEB_ENTRY:-3001}"

TEMPLATES_DIR="$(dirname "$0")/../templates"
BUILD_DIR="/tmp/luci_build_${PKG_NAME}"
VARS_JSON="${BUILD_DIR}/vars.json"

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

echo ">>> Building ${PKG_NAME} ${VERSION}"
echo "    service_name : ${SERVICE_NAME}"
echo "    binary_name  : ${BINARY_NAME}"
echo "    has_web      : ${HAS_WEB}"
echo "    web_entry    : ${WEB_ENTRY_DEFAULT}"
echo "    extra_options: ${EXTRA_OPTIONS}"

# ── 用 Python 生成所有替换内容，输出到 JSON 文件 ──────────
# 这样完全避免 shell heredoc 里的引号冲突问题
export INPUT_PACKAGE_NAME INPUT_SERVICE_TITLE INPUT_VERSION INPUT_DESCRIPTION
export INPUT_BINARY INPUT_START_ARGS INPUT_HAS_WEB INPUT_WEB_ENTRY INPUT_WORK_DIR INPUT_ENV_VARS INPUT_EXTRA_OPTIONS

python3 "$(dirname "$0")/gen_vars.py" "${VARS_JSON}"

echo "    vars.json written"

# ── 模板替换函数 ──────────────────────────────────────────
render_template() {
    local src="$1"
    local dst="$2"
    python3 "$(dirname "$0")/render.py" "${src}" "${dst}" "${VARS_JSON}"
}

# ── 读取 SERVICE_NAME（从 vars.json）──────────────────────
SERVICE_NAME=$(python3 -c "import json; print(json.load(open('${VARS_JSON}'))['{{SERVICE_NAME}}'])")

# ── 创建目录结构 ──────────────────────────────────────────
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
python3 -c "
import json
d = json.load(open('${VARS_JSON}'))
with open('${PKG_DATA}/etc/config/${SERVICE_NAME}', 'w') as f:
    f.write(d['{{UCI_DEFAULTS}}'])
"

# ── 生成各文件 ────────────────────────────────────────────
render_template "${TEMPLATES_DIR}/init.d.sh"   "${PKG_DATA}/etc/init.d/${SERVICE_NAME}"
render_template "${TEMPLATES_DIR}/uci-defaults.sh" "${PKG_DATA}/etc/uci-defaults/${PKG_NAME}"
render_template "${TEMPLATES_DIR}/menu.json"   "${PKG_DATA}/usr/share/luci/menu.d/${PKG_NAME}.json"
render_template "${TEMPLATES_DIR}/acl.json"    "${PKG_DATA}/usr/share/rpcd/acl.d/${PKG_NAME}.json"
render_template "${TEMPLATES_DIR}/ucode.uc"    "${PKG_DATA}/usr/share/rpcd/ucode/luci.${SERVICE_NAME}"
render_template "${TEMPLATES_DIR}/main.js"     "${PKG_DATA}/www/luci-static/resources/view/${SERVICE_NAME}/main.js"
render_template "${TEMPLATES_DIR}/log.js"      "${PKG_DATA}/www/luci-static/resources/view/${SERVICE_NAME}/log.js"
render_template "${TEMPLATES_DIR}/control"     "${PKG_CTRL}/control"
cp "${TEMPLATES_DIR}/postinst.sh" "${PKG_CTRL}/postinst"
cp "${TEMPLATES_DIR}/prerm.sh"    "${PKG_CTRL}/prerm"

# ── 权限 ──────────────────────────────────────────────────
find "${PKG_DATA}" -type f | xargs chmod 644
find "${PKG_DATA}" -type d | xargs chmod 755
chmod 755 \
    "${PKG_DATA}/etc/init.d/${SERVICE_NAME}" \
    "${PKG_DATA}/etc/uci-defaults/${PKG_NAME}" \
    "${PKG_DATA}/usr/share/rpcd/ucode/luci.${SERVICE_NAME}" \
    "${PKG_CTRL}/postinst" \
    "${PKG_CTRL}/prerm"

# ── 打包 IPK ──────────────────────────────────────────────
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
