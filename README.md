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

```text
mihomo_scripts/
├── mihomo_beta/                # ★ beta 通道：唯一手工维护的源码
│   ├── install.sh              #   安装器（版本号含 -beta 后缀）
│   └── mihomo.sh               #   管理菜单
├── mihomo/                     # 稳定版通道：由 tools/sync-mihomo.sh 生成
│   ├── install.sh              #   请勿手工修改，会被下次生成覆盖
│   └── mihomo.sh
├── tools/
│   └── sync-mihomo.sh          # beta → 稳定版的生成器（唯一发布出口）
├── tests/
│   └── smoke.sh                # 静态自检，无需 root，CI 与本地同款
├── docs/
│   └── migration.md            # 从旧仓库迁移的路径替换清单
├── .github/
│   ├── workflows/ci.yml        # 语法 / 行尾 / 版本 / 生成一致性
│   ├── ISSUE_TEMPLATE/bug_report.yml
│   └── pull_request_template.md
├── .gitattributes              # 强制 LF，标记生成物
├── .editorconfig
├── .gitignore                  # 凭据、订阅、日志、临时文件
├── CHANGELOG.md
├── LICENSE
└── README.md
```

**唯一维护入口是 `mihomo_beta/`**。`mihomo/` 是构建产物，改动会在下次 `sync-mihomo.sh` 运行时被判为"预期外差异"并拒绝覆盖——这是设计上的防呆，不是 bug。

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

这是本仓库最重要的一条纪律：**永远只改 `mihomo_beta/`**。

```bash
# 1. 修改源码（版本号必须带 -beta 后缀）
vim mihomo_beta/mihomo.sh

# 2. 生成稳定版：自动去掉 -beta 后缀、替换仓库路径
bash tools/sync-mihomo.sh

# 3. 静态自检（CI 同款，无需 root）
bash tests/smoke.sh

# 4. 实机验证：安装 → 启动 → 切换节点 → 查看日志 → 卸载

# 5. 推送到 beta 分支（发布时再以 PR 合入 main）
git add -A && git commit -m "feat(mihomo): ..."
git push origin beta
```

`sync-mihomo.sh` 在覆盖稳定版之前会依次校验：

1. `bash -n` 语法正确；
2. 文件为 LF 行尾（无 `\r`）；
3. 文件头 `# ver` 与 `readonly SCRIPT_VERSION` 完全一致；
4. 稳定版无 `mihomo_beta` 路径残留；
5. 归一化版本号与路径后，与 beta 源**逐字节一致**（防止夹带手工改动）。

任一项失败即中止，稳定版保持原样，不会出现"生成了一半"的状态。

**版本号规则**

| 位置 | beta 通道 | 稳定版 |
|---|---|---|
| 文件头 `# ver` | `2.5.3-beta` | `2.5.3` |
| `readonly SCRIPT_VERSION` | `2.5.3-beta` | `2.5.3` |

两处必须同时改、且完全一致，否则生成器直接拒绝运行。

---

## 六、分支与发布

**`main` = 正式版，`beta` = 测试版。** 两条都是长期分支，通道身份由分支决定：

| 分支 | 通道 | 内容 | 规则 |
|---|---|---|---|
| `main` | 正式版 | 对外发布。`mihomo/` 为当前稳定版，`mihomo_beta/` 为最近一次晋升的快照 | 禁止直推，只接受来自 `beta` 或 `hotfix/*` 的 PR |
| `beta` | 测试版 | 日常开发与实机验证的主战场，改动落在 `mihomo_beta/` | 允许直推；合并 PR 前必须跑通 `smoke.sh` |
| `feature/<slug>` `fix/<slug>` | 实验 | 单个功能或修复，从 `beta` 拉出 | 合并后自动删除 |
| `hotfix/<slug>` | 应急 | 从 `main` 拉出，修完**同时**合回 `main` 与 `beta` | 合并后自动删除 |

**分支与目录的对应关系**（两套概念不要混）：

- 分支管"这条线在做哪个通道"，目录管"脚本从哪个路径取"。
- 用户下载：正式版取 `main/mihomo/`，测试版取 `beta/mihomo_beta/`。
- 脚本自更新与重装**统一从 `main` 的 `mihomo_beta/` 拉取**（`SHELL_URL` / `INSTALL_URL` 写死在 `REPO_RAW` 上），所以 `main` 上必须保留 `mihomo_beta/`，不能只留 `mihomo/`。

**发布流程（beta → main）**

```bash
# 1. 在 beta 上完成开发与实机验证
git switch beta && bash tests/smoke.sh

# 2. 开 PR：beta → main，squash merge
#    合并后 main 上的 mihomo_beta/ 即为新版本源

# 3. 在 main 上重新生成稳定版并自检
git switch main && git pull
bash tools/sync-mihomo.sh && bash tests/smoke.sh

# 4. 打 tag 发布（手动推送）
git tag -a v2.5.3 -m "release: v2.5.3"
git push origin v2.5.3
```

- 第 3 步不能省：squash 只搬运源码，`mihomo/` 必须由 `main` 上的 `mihomo_beta/` 现场生成，否则 CI 的生成物一致性检查会失败。
- `main` 上用 **squash merge**，一个提交对应一次发布，回滚只需 revert 一个 SHA。
- tag 一旦发布即不可变；需要改动就发新版本号，不要重推同名 tag。
- 紧急回滚：`git revert <发布提交SHA>` → 开 PR → 打 `v2.5.4`。**不要 force push `main`**。
- `beta` 长期不分叉：每次发布后可用 `git switch beta && git merge main` 把 tag 前后的稳定化改动带回来，避免两条线越走越远。

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
