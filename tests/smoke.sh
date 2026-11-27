# --------------------------------------------------
# name   : tests/smoke.sh
# desc   : 静态自检 —— 资源 / 语法 / 行尾 / 版本 / 通道分支 / 生成物一致性
#          不安装、不改系统、不需要 root，本地与 CI 共用同一份
# usage  : bash tests/smoke.sh
# 分支模型：
#   main = 正式版（只有 mihomo/，无 mihomo_beta/）
#   beta = 测试版（mihomo_beta/ 为源，mihomo/ 为同步预览）
#   脚本按目录是否存在自动切换检查项，两个分支都能跑同一份 smoke。
# --------------------------------------------------

# 必须用 bash 运行：dash/sh 不支持 [[ ]] 与数组。
if [ -z "${BASH_VERSION:-}" ]; then
    printf '%s\n' '错误：请使用 bash 运行本脚本' >&2
    exit 1
fi

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR
readonly BETA_DIR="${ROOT_DIR}/mihomo_beta"
readonly STABLE_DIR="${ROOT_DIR}/mihomo"
readonly -a FILES=(install.sh mihomo.sh)
readonly -a ASSETS=(mihomo.yaml mihomo.service mihomo.openrc)

# beta 目录存在 → beta 分支；否则视为 main（正式版）分支。
if [[ -d "$BETA_DIR" ]]; then
    BRANCH="beta"
else
    BRANCH="main"
fi
readonly BRANCH

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

# 断言某目录下的脚本绑定到指定分支，且不残留另一分支的地址。
assert_channel() { # $1=目录 $2=期望分支 $3=禁止分支
    local dir=$1 want=$2 forbid=$3 f
    for f in "${FILES[@]}"; do
        [[ -f "${dir}/${f}" ]] || continue
        if grep -Fq "readonly REPO_BRANCH=\"${want}\"" "${dir}/${f}"; then
            ok "${f} 绑定 ${want} 分支"
        else
            bad "${f} 未绑定 ${want} 分支（应为 readonly REPO_BRANCH=\"${want}\"）"
        fi
        if grep -q "refs/heads/${forbid}" "${dir}/${f}"; then
            bad "${f} 残留 refs/heads/${forbid} 地址"
        else
            ok "${f} 无 ${forbid} 分支地址残留"
        fi
    done
}

printf '\n分支：%s\n' "$BRANCH"

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

# ---------- 2. 文件完整性 ----------
title '2/8 文件完整性'
for f in "${FILES[@]}"; do
    if [[ -f "${STABLE_DIR}/${f}" ]]; then
        ok "存在 mihomo/${f}"
    else
        bad "缺失 mihomo/${f}"
    fi
    if [[ "$BRANCH" == "beta" ]]; then
        if [[ -f "${BETA_DIR}/${f}" ]]; then
            ok "存在 mihomo_beta/${f}"
        else
            bad "缺失 mihomo_beta/${f}"
        fi
    fi
done

# ---------- 3. 语法 ----------
title '3/8 bash 语法'
for f in "${FILES[@]}"; do
    for d in "$STABLE_DIR" "$BETA_DIR"; do
        [[ -f "${d}/${f}" ]] || continue
        if bash -n "${d}/${f}" 2>/dev/null; then
            ok "语法 ${d#"$ROOT_DIR"/}/${f}"
        else
            bad "语法 ${d#"$ROOT_DIR"/}/${f}"
        fi
    done
done

# ---------- 4. 行尾 ----------
title '4/8 行尾必须为 LF'
for f in "${FILES[@]}"; do
    for d in "$STABLE_DIR" "$BETA_DIR"; do
        [[ -f "${d}/${f}" ]] || continue
        if [[ "$(tr -cd '\r' < "${d}/${f}" | wc -c | tr -d ' ')" -eq 0 ]]; then
            ok "LF ${d#"$ROOT_DIR"/}/${f}"
        else
            bad "含 CRLF ${d#"$ROOT_DIR"/}/${f}（会触发环境报 'bash\\r' 不存在）"
        fi
    done
done

# ---------- 5. 版本号 ----------
title '5/8 版本号一致性'
if [[ "$BRANCH" == "beta" ]]; then
    BETA_VERSION=""
    for f in "${FILES[@]}"; do
        [[ -f "${BETA_DIR}/${f}" ]] || continue
        read -r header const <<<"$(read_versions "${BETA_DIR}/${f}")"
        if [[ -z "$header" || -z "$const" ]]; then
            bad "${f} 无法读取版本号"
            continue
        fi
        if [[ "$header" == "$const" ]]; then
            ok "${f} beta 版本一致：${const}"
        else
            bad "${f} 头部 ${header} ≠ 常量 ${const}"
        fi
        if [[ "$const" != *-beta ]]; then
            bad "${f} beta 版本 '${const}' 未以 -beta 结尾"
        fi
        if [[ -z "$BETA_VERSION" ]]; then
            BETA_VERSION="$const"
        elif [[ "$BETA_VERSION" != "$const" ]]; then
            bad "两个 beta 文件版本不一致：${BETA_VERSION} vs ${const}"
        fi
    done
    EXPECT_STABLE="${BETA_VERSION%-beta}"
else
    # main 上无 beta 源，直接以正式版自身为基准。
    EXPECT_STABLE=""
    for f in "${FILES[@]}"; do
        [[ -f "${STABLE_DIR}/${f}" ]] || continue
        read -r header const <<<"$(read_versions "${STABLE_DIR}/${f}")"
        if [[ -n "$header" && "$header" == "$const" && "$const" != *-beta ]]; then
            ok "${f} 正式版版本一致：${const}"
        else
            bad "${f} 版本应一致且不含 -beta，实际 header='${header}' const='${const}'"
        fi
        if [[ -z "$EXPECT_STABLE" ]]; then
            EXPECT_STABLE="$const"
        elif [[ "$EXPECT_STABLE" != "$const" ]]; then
            bad "两个正式版文件版本不一致：${EXPECT_STABLE} vs ${const}"
        fi
    done
fi

if [[ "$BRANCH" == "beta" && -n "$EXPECT_STABLE" ]]; then
    for f in "${FILES[@]}"; do
        [[ -f "${STABLE_DIR}/${f}" ]] || continue
        read -r header const <<<"$(read_versions "${STABLE_DIR}/${f}")"
        if [[ "$header" == "$EXPECT_STABLE" && "$const" == "$EXPECT_STABLE" ]]; then
            ok "${f} 稳定版版本为 ${EXPECT_STABLE}"
        else
            bad "${f} 稳定版版本应为 ${EXPECT_STABLE}，实际 header='${header}' const='${const}'"
        fi
    done
fi

# ---------- 6. 通道分支绑定 ----------
title '6/8 通道分支绑定'
assert_channel "$STABLE_DIR" "main" "beta"
if [[ "$BRANCH" == "beta" ]]; then
    assert_channel "$BETA_DIR" "beta" "main"
fi

# 正式版必须能从根目录取到三份资源，且不得引用 mihomo_beta/（main 上不存在）。
for f in "${FILES[@]}"; do
    [[ -f "${STABLE_DIR}/${f}" ]] || continue
    if grep -q 'mihomo_beta' "${STABLE_DIR}/${f}"; then
        bad "${f} 残留 mihomo_beta 路径（main 上不存在该目录）"
    else
        ok "${f} 无 beta 路径残留"
    fi
    # 资源地址必须在仓库根目录；只对真正出现该地址的文件做正向断言，
    # 避免把 "systemctl status mihomo.service" 这类似是而非的字符串误判。
    for a in "${ASSETS[@]}"; do
        if grep -Fq "\${REPO_RAW}/${a}" "${STABLE_DIR}/${f}"; then
            ok "${f} 资源地址 ${a} 指向根目录"
        fi
    done
    if grep -Fq '${REPO_RAW}/Config/' "${STABLE_DIR}/${f}" \
        || grep -Fq '${REPO_RAW}/Service/' "${STABLE_DIR}/${f}"; then
        bad "${f} 资源地址仍指向 Config/ 或 Service/ 子目录"
    else
        ok "${f} 无旧子目录资源地址"
    fi
done

# ---------- 7. 生成物一致性（仅 beta 分支）----------
title '7/8 生成物与 beta 源一致'
if [[ "$BRANCH" != "beta" ]]; then
    ok "main 分支不含 mihomo_beta/，跳过（正式版为发布产物）"
elif [[ -z "${EXPECT_STABLE:-}" ]]; then
    bad "无法确定版本号，跳过生成物比对"
else
    # 按生成规则即时渲染，不落临时文件：三条规则必须与 sync-mihomo.sh 完全一致。
    render_stable() {
        sed -e "s/${BETA_VERSION}/${EXPECT_STABLE}/g" \
            -e 's#mihomo_beta#mihomo#g' \
            -e 's#REPO_BRANCH="beta"#REPO_BRANCH="main"#g' \
            "${BETA_DIR}/$1"
    }
    for f in "${FILES[@]}"; do
        if [[ ! -f "${STABLE_DIR}/${f}" ]]; then
            bad "缺少稳定版 ${f}"
        elif diff -q <(render_stable "$f") "${STABLE_DIR}/${f}" >/dev/null 2>&1; then
            ok "${f} 与 beta 源一致"
        else
            bad "${f} 与实际生成结果不一致 —— 请运行 bash tools/sync-mihomo.sh"
            diff -u <(render_stable "$f") "${STABLE_DIR}/${f}" | head -20 >&2 || true
        fi
    done
fi

# ---------- 8. 可执行位与 shellcheck ----------
title '8/8 可执行位 / shellcheck'
for f in "${FILES[@]}"; do
    for d in "$STABLE_DIR" "$BETA_DIR"; do
        [[ -f "${d}/${f}" ]] || continue
        if [[ -x "${d}/${f}" ]]; then
            ok "可执行 ${d#"$ROOT_DIR"/}/${f}"
        else
            warn "不可执行 ${d#"$ROOT_DIR"/}/${f}（建议 chmod +x）"
        fi
    done
done

if command -v shellcheck >/dev/null 2>&1; then
    for f in "${FILES[@]}"; do
        for d in "$STABLE_DIR" "$BETA_DIR"; do
            [[ -f "${d}/${f}" ]] || continue
            if shellcheck -S error -x "${d}/${f}" >/dev/null 2>&1; then
                ok "shellcheck ${d#"$ROOT_DIR"/}/${f}"
            else
                bad "shellcheck 报 error ${d#"$ROOT_DIR"/}/${f}"
            fi
        done
    done
else
    warn "未安装 shellcheck，跳过该检查（CI 中会执行）"
fi

# ---------- 汇总 ----------
printf '\n'
if (( FAILED == 0 )); then
    printf '\033[32m%s\033[0m\n' "[ PASS ] 全部检查通过（${BRANCH} 分支，版本 ${EXPECT_STABLE:-unknown}）"
    exit 0
fi
printf '\033[31m%s\033[0m\n' "[FAILED] ${FAILED} 项检查未通过"
exit 1
