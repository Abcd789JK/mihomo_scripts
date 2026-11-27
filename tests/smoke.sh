# --------------------------------------------------
# name   : tests/smoke.sh
# desc   : 静态自检 —— 语法 / 行尾 / 版本一致性 / 生成物一致性
#          不安装、不改系统、不需要 root，本地与 CI 共用同一份
# usage  : bash tests/smoke.sh
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

FAILED=0
ok()  { printf '  \033[32m[ OK ]\033[0m %s\n' "$*"; }
bad() { printf '  \033[31m[FAIL]\033[0m %s\n' "$*"; FAILED=$((FAILED + 1)); }
warn(){ printf '  \033[33m[WARN]\033[0m %s\n' "$*"; }
title(){ printf '\n%s\n' "$*"; }

# 从文件读取头部版本号与 SCRIPT_VERSION 常量，输出 "<header> <const>"。
read_versions() { # $1=文件
    local header const
    header="$(awk '/^# ver[[:space:]]*:/ { v=$0; sub(/^# ver[[:space:]]*:[[:space:]]*/, "", v); sub(/[[:space:]]+$/, "", v); print v; exit }' "$1")"
    const="$(awk -F'"' '/^readonly SCRIPT_VERSION=/ { print $2; exit }' "$1")"
    printf '%s %s\n' "$header" "$const"
}

# ---------- 1. 文件存在性 ----------
title '1/6 文件完整性'
for f in "${FILES[@]}"; do
    for d in "$BETA_DIR" "$STABLE_DIR"; do
        if [[ -f "${d}/${f}" ]]; then
            ok "存在 ${d#"$ROOT_DIR"/}/${f}"
        else
            bad "缺失 ${d#"$ROOT_DIR"/}/${f}"
        fi
    done
done

# ---------- 2. 语法 ----------
title '2/6 bash 语法'
for f in "${FILES[@]}"; do
    for d in "$BETA_DIR" "$STABLE_DIR"; do
        [[ -f "${d}/${f}" ]] || continue
        if bash -n "${d}/${f}" 2>/dev/null; then
            ok "语法 ${d#"$ROOT_DIR"/}/${f}"
        else
            bad "语法 ${d#"$ROOT_DIR"/}/${f}"
        fi
    done
done

# ---------- 3. 行尾 ----------
title '3/6 行尾必须为 LF'
for f in "${FILES[@]}"; do
    for d in "$BETA_DIR" "$STABLE_DIR"; do
        [[ -f "${d}/${f}" ]] || continue
        # 统计 CR 字节数；非 0 说明混入 CRLF。
        if [[ "$(tr -cd '\r' < "${d}/${f}" | wc -c | tr -d ' ')" -eq 0 ]]; then
            ok "LF ${d#"$ROOT_DIR"/}/${f}"
        else
            bad "含 CRLF ${d#"$ROOT_DIR"/}/${f}（会触发环境报 'bash\\r' 不存在）"
        fi
    done
done

# ---------- 4. 版本号一致性 ----------
title '4/6 版本号一致性'
BETA_VERSION=""
for f in "${FILES[@]}"; do
    [[ -f "${BETA_DIR}/${f}" ]] || continue
    read -r header const <<<"$(read_versions "${BETA_DIR}/${f}")"

    if [[ -z "$header" || -z "$const" ]]; then
        bad "${f} 无法读取版本号（header='${header}' const='${const}'）"
        continue
    fi
    if [[ "$header" != "$const" ]]; then
        bad "${f} 头部 ${header} ≠ 常量 ${const}"
    else
        ok "${f} beta 版本一致：${const}"
    fi
    if [[ "$const" != *-beta ]]; then
        bad "${f} beta 版本 '${const}' 未以 -beta 结尾"
    fi

    # 两个文件的版本号必须相同，避免 install/manage 各带一个版本。
    if [[ -z "$BETA_VERSION" ]]; then
        BETA_VERSION="$const"
    elif [[ "$BETA_VERSION" != "$const" ]]; then
        bad "两个 beta 文件版本不一致：${BETA_VERSION} vs ${const}"
    fi
done

STABLE_VERSION="${BETA_VERSION%-beta}"
if [[ -n "$BETA_VERSION" ]]; then
    for f in "${FILES[@]}"; do
        [[ -f "${STABLE_DIR}/${f}" ]] || continue
        read -r header const <<<"$(read_versions "${STABLE_DIR}/${f}")"
        if [[ "$header" == "$STABLE_VERSION" && "$const" == "$STABLE_VERSION" ]]; then
            ok "${f} 稳定版版本为 ${STABLE_VERSION}"
        else
            bad "${f} 稳定版版本应为 ${STABLE_VERSION}，实际 header='${header}' const='${const}'"
        fi
    done
fi

# ---------- 5. 生成物一致性 ----------
# 用与 sync-mihomo.sh 完全相同的两条转换规则重建稳定版，再与仓库中的实际文件比对。
# 命中即说明有人手改了 mihomo/，或忘了跑 sync。
title '5/6 生成物与 beta 源一致'
if [[ -z "$BETA_VERSION" ]]; then
    bad "无法确定 beta 版本号，跳过生成物比对"
else
    # 用进程替换按生成规则即时渲染，不落临时文件：
    # 既避免 CI/Windows 下清理临时目录的权限问题，也不会污染工作区。
    render_stable() {
        sed -e "s/${BETA_VERSION}/${STABLE_VERSION}/g" \
            -e 's#mihomo_beta#mihomo#g' \
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

        # 稳定版不得残留 beta 路径。
        if grep -q 'mihomo_beta' "${STABLE_DIR}/${f}" 2>/dev/null; then
            bad "${f} 残留 mihomo_beta 路径"
        else
            ok "${f} 无 beta 路径残留"
        fi
    done
fi

# ---------- 6. 可执行位与 shellcheck ----------
title '6/6 可执行位 / shellcheck'
for f in "${FILES[@]}"; do
    for d in "$BETA_DIR" "$STABLE_DIR"; do
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
        for d in "$BETA_DIR" "$STABLE_DIR"; do
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
    printf '\033[32m%s\033[0m\n' "[ PASS ] 全部检查通过（版本 ${STABLE_VERSION:-unknown}）"
    exit 0
fi
printf '\033[31m%s\033[0m\n' "[FAILED] ${FAILED} 项检查未通过"
exit 1
