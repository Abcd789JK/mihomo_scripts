# --------------------------------------------------
# name   : tests/smoke.sh
# desc   : 静态自检 —— 结构 / 语法 / 行尾 / 版本 / 通道机制 / 通道读写
#          不安装、不改系统、不需要 root，本地与 CI 共用同一份
# usage  : bash tests/smoke.sh
# 分支模型：
#   main = 正式版，beta = 测试版；两个分支目录结构、文件名称完全一致，
#   脚本都在仓库根目录，通道只由运行期参数与 channel.txt 决定。
#   因此本脚本不区分分支，同一份检查在两个分支都必须通过。
# --------------------------------------------------

# 必须用 bash 运行：dash/sh 不支持 [[ ]] 与数组。
if [ -z "${BASH_VERSION:-}" ]; then
    printf '%s\n' '错误：请使用 bash 运行本脚本' >&2
    exit 1
fi

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR
readonly -a FILES=(install.sh mihomo.sh)
readonly -a ASSETS=(mihomo.yaml mihomo.service mihomo.openrc)

FAILED=0
ok()  { printf '  \033[32m[ OK ]\033[0m %s\n' "$*"; }
bad() { printf '  \033[31m[FAIL]\033[0m %s\n' "$*"; FAILED=$((FAILED + 1)); }
warn(){ printf '  \033[33m[WARN]\033[0m %s\n' "$*"; }
title(){ printf '\n%s\n' "$*"; }

# 读取头部版本号与 SCRIPT_VERSION 常量，输出 "<header> <const>"。
read_versions() { # $1=文件
    local header const
    header="$(awk '/^# ver[[:space:]]*:/ { v=$0; sub(/^# ver[[:space:]]*:[[:space:]]*/, "", v); sub(/[[:space:]]+$/, "", v); print v; exit }' "$1")"
    const="$(awk -F'"' '/^readonly SCRIPT_VERSION=/ { print $2; exit }' "$1")"
    printf '%s %s\n' "$header" "$const"
}

# ---------- 1. 根目录资源 ----------
# install.sh 通过 CONFIG_URL / SERVICE_URL_* 从仓库根目录下载，缺失即安装失败。
title '1/8 根目录资源'
for a in "${ASSETS[@]}"; do
    if [[ ! -f "${ROOT_DIR}/${a}" ]]; then
        bad "缺少 ${a}"
        continue
    fi
    ok "存在 ${a}"
    if [[ "$(tr -cd '\r' < "${ROOT_DIR}/${a}" | wc -c | tr -d ' ')" -eq 0 ]]; then
        ok "LF ${a}"
    else
        bad "${a} 含 CRLF（mihomo.service 带 \\r 会导致 systemd 启动失败）"
    fi
done

# ---------- 2. 目录结构 ----------
title '2/8 目录结构（根目录单一来源）'
for f in "${FILES[@]}"; do
    if [[ -f "${ROOT_DIR}/${f}" ]]; then
        ok "存在 ${f}"
    else
        bad "缺失 ${f}"
    fi
done
for d in mihomo mihomo_beta tools; do
    if [[ -d "${ROOT_DIR}/${d}" ]]; then
        bad "存在旧目录 ${d}/（通道改由分支承载，不应再出现）"
    else
        ok "无旧目录 ${d}/"
    fi
done

# ---------- 3. 语法 ----------
title '3/8 bash 语法'
for f in "${FILES[@]}"; do
    [[ -f "${ROOT_DIR}/${f}" ]] || continue
    if bash -n "${ROOT_DIR}/${f}" 2>/dev/null; then
        ok "语法 ${f}"
    else
        bad "语法 ${f}"
    fi
done

# ---------- 4. 行尾 ----------
title '4/8 行尾必须为 LF'
for f in "${FILES[@]}"; do
    [[ -f "${ROOT_DIR}/${f}" ]] || continue
    if [[ "$(tr -cd '\r' < "${ROOT_DIR}/${f}" | wc -c | tr -d ' ')" -eq 0 ]]; then
        ok "LF ${f}"
    else
        bad "含 CRLF ${f}（会触发环境报 'bash\\r' 不存在）"
    fi
done

# ---------- 5. 版本号 ----------
title '5/8 版本号一致性'
EXPECT_VERSION=""
for f in "${FILES[@]}"; do
    [[ -f "${ROOT_DIR}/${f}" ]] || continue
    read -r header const <<<"$(read_versions "${ROOT_DIR}/${f}")"
    if [[ -z "$header" || -z "$const" ]]; then
        bad "${f} 无法读取版本号"
        continue
    fi
    if [[ "$header" != "$const" ]]; then
        bad "${f} 头部 ${header} ≠ 常量 ${const}"
        continue
    fi
    # 通道由分支承载，版本号不再带 -beta：合入 main 时无需改代码
    if [[ "$const" == *-beta ]]; then
        bad "${f} 版本 '${const}' 仍带 -beta 后缀（通道已改由分支承载）"
        continue
    fi
    ok "${f} 版本一致：${const}"
    if [[ -z "$EXPECT_VERSION" ]]; then
        EXPECT_VERSION="$const"
    elif [[ "$EXPECT_VERSION" != "$const" ]]; then
        bad "两个脚本版本不一致：${EXPECT_VERSION} vs ${const}"
    fi
done

# ---------- 6. 通道机制 ----------
title '6/8 通道机制（无硬编码分支）'
for f in "${FILES[@]}"; do
    [[ -f "${ROOT_DIR}/${f}" ]] || continue

    if grep -qE '^readonly REPO_URL="https://raw\.githubusercontent\.com/Abcd789JK/mihomo_scripts"$' "${ROOT_DIR}/${f}"; then
        ok "${f} 含仓库基础地址 REPO_URL"
    else
        bad "${f} 缺少 REPO_URL 基础地址"
    fi

    # 分支名不得出现在代码里：一旦写死，beta → main 合并后仍会去取旧分支
    if grep -nE 'REPO_BRANCH|refs/heads/(main|beta)' "${ROOT_DIR}/${f}" >/dev/null 2>&1; then
        bad "${f} 硬编码了分支（REPO_BRANCH 或 refs/heads/<分支>）"
    else
        ok "${f} 无硬编码分支"
    fi

    # 资源地址必须由通道派生，且落在仓库根目录
    if grep -qE '^\s*(SHELL|INSTALL|CONFIG)_URL="\$\{REPO_RAW\}/' "${ROOT_DIR}/${f}"; then
        ok "${f} 资源地址由 REPO_RAW 派生"
    else
        bad "${f} 资源地址未由 REPO_RAW 派生"
    fi
    if grep -qE '\$\{REPO_RAW\}/(mihomo|mihomo_beta)/' "${ROOT_DIR}/${f}"; then
        bad "${f} 资源地址仍指向 mihomo/ 或 mihomo_beta/ 子目录"
    else
        ok "${f} 资源地址无旧子目录"
    fi

    for fn in valid_release_channel release_channel_name apply_release_channel read_release_channel save_release_channel; do
        if grep -q "^${fn}()" "${ROOT_DIR}/${f}"; then
            ok "${f} 含函数 ${fn}"
        else
            bad "${f} 缺少函数 ${fn}"
        fi
    done

    for a in "${ASSETS[@]}"; do
        if [[ "$a" == "mihomo.yaml" ]] || [[ "$f" == "install.sh" ]]; then
            grep -Fq "\${REPO_RAW}/${a}" "${ROOT_DIR}/${f}" || bad "${f} 未引用根目录资源 ${a}"
        fi
    done
done

# install.sh：位置参数即发布通道，且必须严格校验
if grep -q '无效的发布通道' "${ROOT_DIR}/install.sh"; then
    ok 'install.sh 校验发布通道参数'
else
    bad 'install.sh 未校验发布通道参数'
fi
if grep -q 'save_release_channel' "${ROOT_DIR}/install.sh"; then
    ok 'install.sh 安装后保存通道'
else
    bad 'install.sh 未保存通道'
fi
# mihomo.sh：启动读取通道，重装把通道透传给安装脚本
if grep -q 'read_release_channel' "${ROOT_DIR}/mihomo.sh"; then
    ok 'mihomo.sh 启动读取通道'
else
    bad 'mihomo.sh 未读取通道'
fi
if grep -q 'bash "$tmp" "$RELEASE_CHANNEL"' "${ROOT_DIR}/mihomo.sh"; then
    ok 'mihomo.sh 重装透传通道'
else
    bad 'mihomo.sh 重装未透传通道'
fi

# ---------- 7. 通道读写的实际执行 ----------
# 把两份脚本里的通道函数抽出来，在隔离临时目录里真跑一遍：
# 保存 → 读回 → 缺文件回退 main → 非法内容回退 main。
title '7/8 通道读写实际执行'
WORK_DIR="$(mktemp -d 2>/dev/null || true)"
if [[ -z "$WORK_DIR" || ! -d "$WORK_DIR" ]]; then
    warn '无法创建临时目录，跳过通道读写检查'
else
    for f in "${FILES[@]}"; do
        [[ -f "${ROOT_DIR}/${f}" ]] || continue
        block="${WORK_DIR}/block-${f}.sh"
        sed -n '/^# 发布通道（main 正式版/,/^# 发行版识别/p' "${ROOT_DIR}/${f}" | sed '$d' > "$block"
        if [[ ! -s "$block" ]]; then
            bad "${f} 未找到发布通道函数块（注释锚点被改动？）"
            continue
        fi

        # 隔离执行：只加载函数块 + 常量与日志桩，RELEASE_FILE 指向临时目录
        ch_run() {
            bash -c '
                set -Eeuo pipefail
                REPO_URL="https://raw.githubusercontent.com/Abcd789JK/mihomo_scripts"
                RELEASE_DEFAULT="main"
                RELEASE_FILE="$2/channel.txt"
                RELEASE_CHANNEL=""; REPO_RAW=""; CONFIG_URL=""; SHELL_URL=""; INSTALL_URL=""
                SERVICE_URL_SYSTEMD=""; SERVICE_URL_OPENRC=""
                log_warn() { printf "WARN:%s\n" "$*" >&2; }
                log_error() { printf "ERROR:%s\n" "$*" >&2; }
                source "$1"
                shift 2
                eval "$*"
            ' _ "$block" "$WORK_DIR" "$1"
        }

        # 通道 → 地址推导
        if [[ "$(ch_run 'apply_release_channel beta; printf "%s" "$SHELL_URL"' 2>/dev/null)" \
            == "https://raw.githubusercontent.com/Abcd789JK/mihomo_scripts/beta/mihomo.sh" ]]; then
            ok "${f} beta 通道地址推导正确"
        else
            bad "${f} beta 通道地址推导异常"
        fi

        # 保存 → 读回
        ch_run 'apply_release_channel beta; save_release_channel' >/dev/null 2>&1 || bad "${f} 保存通道失败"
        if [[ "$(ch_run 'read_release_channel; printf "%s" "$RELEASE_CHANNEL"' 2>/dev/null)" == "beta" ]]; then
            ok "${f} 通道保存后可读回"
        else
            bad "${f} 通道读回失败"
        fi

        # 缺文件 → main + 告警
        mv -f "${WORK_DIR}/channel.txt" "${WORK_DIR}/channel.bak" 2>/dev/null || true
        out="$(ch_run 'read_release_channel; printf "%s" "$RELEASE_CHANNEL"' 2>&1)"
        case "$out" in
            *WARN*main*) ok "${f} 缺记录时回退 main 并告警" ;;
            *) bad "${f} 缺记录时未正确回退（${out//$'\n'/ }）" ;;
        esac

        # 内容非法 → 拒绝继续（不静默回退到任何通道）
        printf 'weird\n' > "${WORK_DIR}/channel.txt"
        if out="$(ch_run 'read_release_channel' 2>&1)"; then
            bad "${f} 非法记录时仍继续执行（应拒绝，避免静默切通道）"
        elif [[ "$out" == *非法* ]]; then
            ok "${f} 非法记录时拒绝继续并说明原因"
        else
            bad "${f} 非法记录时报错信息不明确（${out//$'\n'/ }）"
        fi

        mv -f "${WORK_DIR}/channel.txt" "${WORK_DIR}/channel.bak2" 2>/dev/null || true
    done
    # 清理由本脚本创建的临时目录：先切进去用相对名删除，避免绝对盘符路径
    ( cd "$WORK_DIR" && rm -f ./* 2>/dev/null || true )
    rmdir "$WORK_DIR" 2>/dev/null || true
fi

# ---------- 8. 可执行位与 shellcheck ----------
title '8/8 可执行位 / shellcheck'
for f in "${FILES[@]}"; do
    [[ -f "${ROOT_DIR}/${f}" ]] || continue
    if [[ -x "${ROOT_DIR}/${f}" ]]; then
        ok "可执行 ${f}"
    else
        warn "不可执行 ${f}（建议 chmod +x）"
    fi
done

if command -v shellcheck >/dev/null 2>&1; then
    for f in "${FILES[@]}"; do
        [[ -f "${ROOT_DIR}/${f}" ]] || continue
        if shellcheck -S error -x "${ROOT_DIR}/${f}" >/dev/null 2>&1; then
            ok "shellcheck ${f}"
        else
            bad "shellcheck 报 error ${f}"
        fi
    done
else
    warn '未安装 shellcheck，跳过该检查（CI 中会执行）'
fi

# ---------- 汇总 ----------
printf '\n'
if (( FAILED == 0 )); then
    printf '\033[32m%s\033[0m\n' "[ PASS ] 全部检查通过（版本 ${EXPECT_VERSION:-unknown}）"
    exit 0
fi
printf '\033[31m%s\033[0m\n' "[FAILED] ${FAILED} 项检查未通过"
exit 1
