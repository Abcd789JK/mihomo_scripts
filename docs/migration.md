# 迁移到独立仓库：路径替换清单

本仓库从 `Abcd789JK/Tools` 拆分而来。脚本内部硬编码了上游仓库地址与目录前缀，**首次推送前必须完成本页的替换**，否则安装器会把用户拉回旧仓库。

只需改 `mihomo_beta/`，`mihomo/` 由生成器重写。

---

## 一、需要替换的内容

| 位置 | 旧值 | 新值 | 说明 |
|---|---|---|---|
| `REPO_RAW` | `https://raw.githubusercontent.com/Abcd789JK/Tools/refs/heads/main` | `https://raw.githubusercontent.com/<GITHUB_USER>/<REPO_NAME>/refs/heads/main` | 所有原始文件地址的前缀 |
| `SHELL_REPO` | `Abcd789JK/Tools` | `<GITHUB_USER>/<REPO_NAME>` | 用于查询 `commits/main` 取 pin 住的 commit |
| 路径前缀 | `/Script/mihomo_beta` | `/mihomo_beta` | 目录从 `Tools/Script/` 提到了仓库根 |
| jsDelivr 镜像 | `gh/Abcd789JK/Tools@main/Script/mihomo_beta` | `gh/<GITHUB_USER>/<REPO_NAME>@main/mihomo_beta` | 由上面两条规则联动得到 |

**匹配处数**（已按 2.5.3-beta 实测）：

```bash
grep -c 'Abcd789JK/Tools'     mihomo_beta/install.sh mihomo_beta/mihomo.sh   # 2 / 2
grep -c 'Script/mihomo_beta'  mihomo_beta/install.sh mihomo_beta/mihomo.sh   # 5 / 3
```

即 4 行含旧仓库归属、8 行含旧路径前缀；jsDelivr 那一行两者皆有，去重后实际改动 **11 行**。

实际行号（方便逐条 review）：

- `mihomo_beta/mihomo.sh`：`REPO_RAW`、`SHELL_REPO`、`SHELL_URL`、`INSTALL_URL`，以及 `update_shell` 中拼接 pinned commit 的地址。
- `mihomo_beta/install.sh`：`REPO_RAW`、`SHELL_URL`、`usage` 文本示例，以及重装流程里的 curl / wget / jsDelivr 三条分支。

---

## 二、执行替换

```bash
cd mihomo-scripts

# 0. 先备份（sed -i 不可撤销）
cp -a mihomo_beta /tmp/mihomo_beta.bak.$(date +%Y%m%d%H%M%S)

# 1. 替换仓库归属（沿用原 owner 时只改 <REPO_NAME>）
sed -i 's#Abcd789JK/Tools#<GITHUB_USER>/<REPO_NAME>#g' mihomo_beta/install.sh mihomo_beta/mihomo.sh

# 2. 去掉 Script/ 前缀（mihomo_beta 前多一个斜杠，替换后不产生双斜杠）
sed -i 's#/Script/mihomo_beta#/mihomo_beta#g' mihomo_beta/install.sh mihomo_beta/mihomo.sh
```

> 第二条规则同时覆盖 `...@main/Script/mihomo_beta` 这种镜像地址，无需单独处理。

---

## 三、验证

```bash
# 1. 旧仓库与旧路径必须彻底消失，两条命令都应无输出
grep -rn 'Abcd789JK' mihomo_beta/ || echo "OK: 无旧仓库引用"
grep -rn 'Script/'   mihomo_beta/ || echo "OK: 无旧路径引用"

# 2. 重新生成稳定版（会自动同步新地址并做五重校验）
bash tools/sync-mihomo.sh

# 3. 静态自检
bash tests/smoke.sh

# 4. 抽查生成结果中的地址是否指向新仓库
grep -n 'REPO_RAW=\|SHELL_REPO=' mihomo/install.sh mihomo/mihomo.sh
```

预期：4 条 `grep` 全部指向 `<GITHUB_USER>/<REPO_NAME>`，`sync` 输出 `[ OK ] 已同步正式版 2.5.3`，`smoke` 输出 `[ PASS ] 全部检查通过`。

---

## 四、同步替换文档占位符

以下文件中的 `<GITHUB_USER>` / `<REPO_NAME>` 需要替换为真实值（不涉及逻辑，仅影响可读性）：

- `README.md`（安装地址、徽章、License 行）
- `LICENSE`（版权署名）
- `CHANGELOG.md`（如引用仓库地址）

```bash
sed -i 's#<GITHUB_USER>#your-name#g; s#<REPO_NAME>#your-repo#g' README.md LICENSE
```

---

## 五、注意事项

1. **不要手改 `mihomo/`**：替换后必须跑 `sync-mihomo.sh` 重新生成。手改会让 `smoke.sh` 第 5 项报"与实际生成结果不一致"。
2. **旧仓库不要立刻删**：先让新仓库跑通安装，再在旧仓库 README 顶部放迁移公告并归档，避免已发布链接瞬间失效。
3. **`switch 正式版/测试版` 功能依赖两个地址都可达**：迁移期间如果只推了 `mihomo_beta/` 而没推 `mihomo/`，切换会 404。
4. **jsDelivr 有缓存**：镜像地址首次访问可能仍返回旧内容，验证时以 `raw.githubusercontent.com` 为准。
5. **pinned commit 逻辑**：`update_shell` 会查 `api.github.com/repos/<SHELL_REPO>/commits/main`。新仓库若无任何提交，该接口 404，第 12 项菜单会退化到直接下载 `main`——先推首版再测这个功能。
