# mihomo 一键安装与管理脚本

> 仓库地址：`https://github.com/Abcd789JK/mihomo_scripts`
> 当前版本：`2.5.3-beta`（稳定版 `2.5.3` 由工具生成）
> CI 状态：![CI](https://github.com/Abcd789JK/mihomo_scripts/actions/workflows/ci.yml/badge.svg)

面向 Linux 服务器、软路由与容器环境的 mihomo（Clash.Meta）内核一键安装与交互式管理脚本。

脚本采用**双通道**发布：`mihomo_beta/` 为唯一手工维护的源，`mihomo/` 由工具生成并对外提供稳定版。两条线不会漂移，因为生成器在覆盖前会做五重校验。

---

## 一、特性

| 能力 | 说明 |
|---|---|
| 一键安装 | 自动识别发行版与架构、补齐依赖、下载内核、写入 systemd/OpenRC 服务、生成订阅配置与 zashboard 面板 |
| 交互式管理 | `mihomo` 命令进入菜单，覆盖重装、更新、卸载、启停、自启、版本切换、配置管理、日志、脚本自更新 |
| 双通道 | 测试版（`-beta` 后缀）先验证，再生成稳定版；支持装机时用 `--channel` 选择内核通道 |
| 生成式发布 | 只维护一份源码，稳定版由 `tools/sync-mihomo.sh` 生成，避免两套代码各改一半 |
| 静态自检 | `tests/smoke.sh` 与 CI 同源：语法、行尾、版本一致性、生成物一致性 |
| 国内可用 | 内置 jsDelivr 镜像回退，GitHub API 限流时改用重定向获取版本号 |

---

## 二、目录结构

两个分支各放自己那一份，**不共用目录**：

```text
# beta 分支（测试版，日常开发在这里）
mihomo_scripts/
├── mihomo_beta/            # ★ 唯一手工维护的源
│   ├── install.sh          #   安装器（版本号含 -beta 后缀）
│   └── mihomo.sh           #   管理菜单
├── mihomo/                 # 由 tools/sync-mihomo.sh 生成，供发布前预览
├── mihomo.yaml             # 默认配置（脚本从仓库根目录下载）
├── mihomo.service          # systemd 单元
├── mihomo.openrc           # OpenRC 服务脚本
├── tools/sync-mihomo.sh    # beta → 正式版的生成器（五重校验）
├── tests/smoke.sh          # 静态自检，按分支自动切换检查项
├── docs/migration.md
└── .github/  CHANGELOG.md  LICENSE  README.md  .gitattributes  .gitignore

# main 分支（正式版，只放发布产物）
mihomo_scripts/
├── mihomo/                 # 正式版脚本（由 beta 晋升，勿手改）
├── mihomo.yaml  mihomo.service  mihomo.openrc
├── tools/  tests/  docs/  .github/
└── 没有 mihomo_beta/
```

**`main` 上不存在 `mihomo_beta/`**，所以：

- 生成动作只在 `beta` 分支执行（`sync-mihomo.sh` 需要同时看到源与目标目录）；
- `main` 只接收生成结果，`tools/sync-mihomo.sh` 在 `main` 上会主动拒绝运行；
- `tests/smoke.sh` 靠 `mihomo_beta/` 是否存在判断当前分支，自动切换检查项，两个分支跑同一份脚本。

---

## 三、一键安装

需要 **root 权限**，支持 x86_64 / i686 / aarch64 / armv7l / s390x。

**稳定版（推荐）**

```bash
curl -fsSL https://raw.githubusercontent.com/Abcd789JK/mihomo_scripts/main/mihomo/install.sh | bash
```

**测试版（尝鲜 / 协助验证）**

```bash
curl -fsSL https://raw.githubusercontent.com/Abcd789JK/mihomo_scripts/beta/mihomo_beta/install.sh | bash
```

> 测试版走 `beta` 分支，它的 HEAD 就是最新测试源，不必等合并到 `main`。
> 若 `beta` 分支尚未推送，可临时用 `main/mihomo_beta/install.sh`（即最近一次晋升的快照）。

**国内网络（jsDelivr 镜像）**

```bash
curl -fsSL https://cdn.jsdelivr.net/gh/Abcd789JK/mihomo_scripts@main/mihomo/install.sh | bash
```

**钉住版本（生产环境推荐）**

```bash
curl -fsSL https://raw.githubusercontent.com/Abcd789JK/mihomo_scripts/v2.5.3/mihomo/install.sh | bash
```

> 用 tag 而不是 `main`，可避免"上游刚合并、你正好装到中间态"。生产节点请优先使用版本化地址。

**非交互安装**

```bash
bash install.sh --channel stable    # 内核走正式版
bash install.sh --channel alpha     # 内核走测试版（alpha-<哈希>）
```

> 注意区分两个概念：
> - `--channel stable|alpha` 选的是**mihomo 内核**的版本通道；
> - `mihomo_beta/` 与 `mihomo/` 是**脚本自身**的两条发布线。
>
> 用稳定版脚本 + alpha 内核是完全合法的组合，二者互不约束。

**安装结果**

| 项目 | 路径 |
|---|---|
| 安装目录 / 配置 | `/root/mihomo/`（配置为 `/root/mihomo/config.yaml`） |
| 命令入口 | `/usr/bin/mihomo` |
| 服务 | `/etc/systemd/system/mihomo.service` 或 `/etc/init.d/mihomo` |
| 转发参数 | `/etc/sysctl.d/99-ip-forward.conf` |

支持的发行版：Debian/Ubuntu 系（含 Mint、Kali、Armbian）、Fedora/RHEL/CentOS/Rocky/Alma/Amazon Linux、Arch/Manjaro/EndeavourOS、Alpine、openSUSE/SLES。其他发行版会跳过依赖安装，工具齐全时仍可继续。

---

## 四、管理与使用

安装完成后执行 `mihomo` 进入交互菜单（**脚本不提供命令行子命令**，直接运行即可）：

```bash
mihomo
```

| 菜单项 | 功能 |
|---|---|
| 1 | 重新安装 mihomo |
| 2 | 更新内核版本 |
| 3 | 卸载 mihomo |
| 4 / 5 / 6 | 启动 / 停止 / 重启服务 |
| 7 / 8 | 开启 / 关闭开机自启 |
| 9 | 切换正式版 / 测试版内核 |
| 10 | 配置管理（订阅、端口、规则等） |
| 11 | 查看实时日志 |
| 12 | 更新管理脚本自身 |
| 0 或 q | 退出 |

---

## 五、双通道维护流程

这是本仓库最重要的一条纪律：**永远只改 `mihomo_beta/`，且只在 `beta` 分支改**。

```bash
# 0. 确认在 beta 分支
git switch beta

# 1. 修改源码（版本号必须带 -beta 后缀）
vim mihomo_beta/mihomo.sh

# 2. 生成正式版：去掉 -beta 后缀、替换通道目录、把自更新锁定到 main
bash tools/sync-mihomo.sh

# 3. 静态自检（CI 同款，无需 root）
bash tests/smoke.sh

# 4. 实机验证：安装 → 启动 → 切换节点 → 查看日志 → 卸载

# 5. 推送到 beta 分支（发布时再晋升到 main，见下节）
git add -A && git commit -m "feat(mihomo): ..."
git push origin beta
```

`sync-mihomo.sh` 在覆盖正式版之前会依次校验：

1. 根目录三份资源存在（`mihomo.yaml` / `mihomo.service` / `mihomo.openrc`）；
2. `bash -n` 语法正确；
3. 文件为 LF 行尾（无 `\r`）；
4. 文件头 `# ver` 与 `readonly SCRIPT_VERSION` 完全一致；
5. 正式版无 `mihomo_beta` 路径残留，且 `REPO_BRANCH` 已改写为 `main`；
6. 归一化版本号、目录与分支后，与 beta 源**逐字节一致**（防止夹带手工改动）。

任一项失败即中止，正式版保持原样，不会出现"生成了一半"的状态。

**版本号规则**

| 位置 | beta 通道 | 稳定版 |
|---|---|---|
| 文件头 `# ver` | `2.5.3-beta` | `2.5.3` |
| `readonly SCRIPT_VERSION` | `2.5.3-beta` | `2.5.3` |

两处必须同时改、且完全一致，否则生成器直接拒绝运行。

---

## 六、分支与发布

**`main` = 正式版，`beta` = 测试版。** 两条长期分支各自持有本通道的脚本，不共用目录：

| 分支 | 通道 | 持有内容 | 规则 |
|---|---|---|---|
| `main` | 正式版 | `mihomo/` + 三份根目录资源；**无 `mihomo_beta/`** | 禁止直推，只接受发布提交与 `hotfix` PR |
| `beta` | 测试版 | `mihomo_beta/`（源）+ `mihomo/`（生成预览）+ 资源 | 允许直推；提交前跑 `smoke.sh` |
| `feature/<slug>` `fix/<slug>` | 实验 | 从 `beta` 拉出 | 合并后自动删除 |
| `hotfix/<slug>` | 应急 | 仍从 `beta` 改源，走同一条晋升路径 | 合并后自动删除 |

**通道地址由 `REPO_BRANCH` 常量决定**

```bash
# beta 分支上的源文件
readonly REPO_BRANCH="beta"
readonly REPO_RAW="https://raw.githubusercontent.com/Abcd789JK/mihomo_scripts/refs/heads/${REPO_BRANCH}"

# main 分支上的正式版（sync 自动改写，无需手改）
readonly REPO_BRANCH="main"
```

自更新、重装、pinned commit 查询都跟着这个常量走，因此 `main` 不必为了自更新而保留 `mihomo_beta/`——这是"main 上不放 beta 目录"能成立的前提。

**发布流程：把 `mihomo/` 晋升到 main**

```bash
# 1. beta 上验证通过并推送
git switch beta && bash tests/smoke.sh && git push origin beta

# 2. main 只取生成结果
git switch main && git pull
git checkout origin/beta -- mihomo/
bash tests/smoke.sh            # release 模式：只校验正式版

# 3. 更新 CHANGELOG 后提交并打 tag
git add -A && git commit -m "release: v2.5.3"
git tag -a v2.5.3 -m "release: v2.5.3"
git push origin main && git push origin v2.5.3
```

**为什么不能直接 `git merge beta`**：`beta` 上有 `mihomo_beta/`，整分支合并会把它带回 `main`，之后每个发布 PR 都要重新删除同一批文件。只取 `mihomo/` 一个目录，职责最清晰。

- 一个发布提交对应一次发版，回滚只需 revert 一个 SHA。
- 紧急修复也走同一条路径（在 `beta` 改源 → 生成 → 晋升），**不要直接在 `main` 上改 `mihomo/`**，否则下次晋升会被覆盖。
- tag 一旦发布即不可变；需要改动就发新版本号，不要重推同名 tag。
- 紧急回滚：`git revert <发布提交SHA>` → 打 `v2.5.4`。**不要 force push `main`**。

---

## 七、开发约定

- 提交信息遵循 `type(scope): subject`，例如 `fix(install): 修正 Alpine 下 apk 判断`。
- 提交前必须本地跑通 `bash tests/smoke.sh`。
- 所有 `.sh` 必须 LF 行尾，`.gitattributes` 已强制；Windows 端请勿用记事本保存。
- 新增脚本时同步更新：`README` 目录结构、`tests/smoke.sh` 检查列表、`.gitattributes` 行尾规则。
- 不要在脚本里硬编码订阅链接、节点信息、API Token；这些属于运行期配置，不进版本库。

---

## 八、安全与免责

- 本仓库不含任何订阅地址、节点信息或凭据；`.env`、`config*.yaml`、证书私钥均已在 `.gitignore` 中排除。
- 脚本会修改系统服务与 `sysctl` 参数，**执行前请阅读源码**，尤其是 `install.sh` 的依赖安装与服务写入部分。
- 安装器成功后会删除自身 `install.sh`，这是预期行为，不是异常。
- 本项目仅用于学习与自建网络环境，请遵守所在地区的法律法规。

---

## 九、License

[MIT](./LICENSE) © `Abcd789JK`

---

## 附录：仓库首次配置待办

- [x] 脚本内地址已指向 `Abcd789JK/mihomo_scripts`（`REPO_RAW` / `SHELL_REPO` / 镜像地址，见 `docs/migration.md`）
- [ ] 确认默认分支为 `main`
- [ ] 创建 `beta` 分支并推送
- [ ] 配置 `main` / `beta` / `v*` tag 的保护规则
- [ ] 开启 Actions 的 "Read repository contents" 权限
- [ ] 开启 Secret scanning + Push protection
- [ ] 首次 `git tag` 前确认 CHANGELOG 已更新
