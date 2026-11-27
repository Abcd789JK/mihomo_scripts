# mihomo 一键安装与管理脚本

> 仓库地址：`https://github.com/Abcd789JK/mihomo_scripts`
> 当前版本：`2.6.0`
> CI 状态：![CI](https://github.com/Abcd789JK/mihomo_scripts/actions/workflows/ci.yml/badge.svg)

面向 Linux 服务器、软路由与容器环境的 mihomo（Clash.Meta）内核一键安装与交互式管理脚本。

脚本采用**一条代码、两个分支、两个安装通道**的发布方式：仓库根目录只有一份 `install.sh` 与一份 `mihomo.sh`，`main` 分支是正式版，`beta` 分支是测试版。两个分支的目录结构与文件名完全一致，版本隔离只由 Git 分支承担，不再依赖 `mihomo/`、`mihomo_beta/` 之类的重复目录。

---

## 一、特性

| 能力 | 说明 |
|---|---|
| 一键安装 | 自动识别发行版与架构、补齐依赖、下载内核、写入 systemd/OpenRC 服务、生成订阅配置与 zashboard 面板 |
| 交互式管理 | `mihomo` 命令进入菜单，覆盖重装、更新、卸载、启停、自启、版本切换、配置管理、日志、脚本自更新 |
| 双通道 | `main` 正式版与 `beta` 测试版各自独立安装、独立更新，安装时选定、装后持久保存 |
| 通道自识别 | 脚本内不写死分支名，资源地址由通道动态拼出；`beta` 合入 `main` 时无需修改任何代码 |
| 静态自检 | `tests/smoke.sh` 与 CI 同源：结构、语法、行尾、版本、通道机制、通道读写实际执行 |
| 国内可用 | 内置 jsDelivr 镜像回退，GitHub API 限流时改用重定向获取版本号 |

---

## 二、目录结构

两个分支结构完全相同，**没有通道目录**：

```text
mihomo_scripts/
├── install.sh              # 一键安装脚本（位置参数指定发布通道）
├── mihomo.sh               # 交互管理脚本（启动时读取已保存的通道）
├── mihomo.yaml             # 默认配置（脚本从仓库根目录下载）
├── mihomo.service          # systemd 单元
├── mihomo.openrc           # OpenRC 服务脚本
├── tests/smoke.sh          # 静态自检 + 通道读写实际执行，两个分支通用
├── .github/                # CI、Issue / PR 模板
├── CHANGELOG.md  LICENSE  README.md
└── .gitattributes  .gitignore  .editorconfig
```

`main` 与 `beta` 的差异只存在于被修改过的提交里，不存在"这个分支少一个目录"的情况，因此两个分支可以直接快进合并。

---

## 三、安装

需要 **root 权限**，支持 x86_64 / i686 / aarch64 / armv7l / s390x。

**正式版（默认通道，推荐）**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Abcd789JK/mihomo_scripts/main/install.sh) main
```

**测试版（尝鲜 / 协助验证）**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Abcd789JK/mihomo_scripts/beta/install.sh) beta
```

命令末尾的 `main` / `beta` 就是发布通道，也可以先下载再执行：

```bash
curl -fsSL -o install.sh https://raw.githubusercontent.com/Abcd789JK/mihomo_scripts/main/install.sh
bash install.sh main
```

**国内网络（jsDelivr 镜像，把 `@main` 换成 `@beta` 即测试版）**

```bash
bash <(curl -fsSL https://cdn.jsdelivr.net/gh/Abcd789JK/mihomo_scripts@main/install.sh) main
```

**钉住版本（生产环境推荐）**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Abcd789JK/mihomo_scripts/v2.6.0/install.sh) main
```

> tag 比 `main` 稳定：不会在你执行的那一刻正好装到"刚合并、尚未实机验证"的中间态。

**安装结果**

| 项目 | 路径 |
|---|---|
| 安装目录 / 配置 | `/root/mihomo/`（配置为 `/root/mihomo/config.yaml`） |
| 发布通道记录 | `/root/mihomo/channel.txt` |
| 命令入口 | `/usr/bin/mihomo` |
| 服务 | `/etc/systemd/system/mihomo.service` 或 `/etc/init.d/mihomo` |
| 转发参数 | `/etc/sysctl.d/99-ip-forward.conf` |

支持的发行版：Debian/Ubuntu 系（含 Mint、Kali、Armbian）、Fedora/RHEL/CentOS/Rocky/Alma/Amazon Linux、Arch/Manjaro/EndeavourOS、Alpine、openSUSE/SLES。其他发行版会跳过依赖安装，工具齐全时仍可继续。

---

## 四、发布通道

**通道只决定脚本本身从哪个分支获取**，安装后写入 `/root/mihomo/channel.txt`，之后的自更新、重装、默认配置下载都跟着它走。

| | 正式版 `main` | 测试版 `beta` |
|---|---|---|
| 定位 | 稳定发布，经过实机验证与验收 | 日常开发与验证，功能与修复先到这里 |
| 脚本来源 | `main` 分支 | `beta` 分支 |
| 更新节奏 | 发布时更新（合并 + tag） | 每次推送即生效 |
| 风险 | 低 | 可能存在未验证的行为变化 |
| 适合 | 生产节点、长期运行 | 尝鲜、协助验证、提前发现问题 |

**通道与内核版本是两件事**：

- 位置参数 `main` / `beta` 选的是**脚本发布通道**；
- `--channel stable|alpha` 选的是**mihomo 内核版本通道**（如 `v1.19.32` 与 `alpha-94b13ae`）。

正式版脚本配 alpha 内核是完全合法的组合，两者互不约束。

**通道的读取与回退顺序**

1. 安装时给了位置参数 → 用参数，并写入 `channel.txt`；
2. 没给参数但已有 `channel.txt` → 沿用（重装不会把测试版机器带回正式版）；
3. 两者都没有（旧版本用户）→ 按正式版 `main` 处理，并在屏幕上明确提示。

`channel.txt` 内容非法（手工改坏或写入中断）时**直接报错停止，不做任何猜测**——因为此时无论选哪条通道，都可能把测试版机器切到正式版，反之亦然。修复方式二选一：

```bash
printf 'main\n' > /root/mihomo/channel.txt      # 修正记录（把 main 换成 beta 即测试版）
bash install.sh main                            # 或用参数重新指定通道
```

**测试版风险提示**

- `beta` 是开发分支，可能包含未完成的功能、未通过的边界处理，甚至服务启动失败；
- 升级测试版前建议先备份 `/root/mihomo/config.yaml`；
- 生产环境请使用 `main` 或版本 tag；
- 从测试版回到正式版：重跑正式版安装命令（`... main/install.sh) main`），订阅与配置会被保留。

---

## 五、管理与更新

安装完成后执行 `mihomo` 进入交互菜单（**脚本不提供命令行子命令**）：

| 菜单项 | 功能 |
|---|---|
| 1 | 重新安装 mihomo（沿用当前发布通道，订阅与配置保留） |
| 2 | 更新内核版本 |
| 3 | 卸载 mihomo |
| 4 / 5 / 6 | 启动 / 停止 / 重启服务 |
| 7 / 8 | 开启 / 关闭开机自启 |
| 9 | 切换正式版 / 测试版内核 |
| 10 | 配置管理（订阅、端口、规则等） |
| 11 | 查看实时日志 |
| 12 | 更新管理脚本自身 |
| 0 或 q | 退出 |

菜单状态区的「发布通道」显示当前脚本来自 `main` 还是 `beta`，「版本通道」显示内核是稳定版还是 alpha。

**脚本更新方式**

| 方式 | 行为 |
|---|---|
| 菜单 12「更新脚本」 | 按当前通道拉取最新脚本：下载 → 语法与版本校验 → 备份 → 原子替换 → 复核，失败自动回滚 `.bak` |
| 重跑安装命令 | 覆盖安装，保留订阅配置；也可用通道参数主动切换通道 |
| 内核更新（菜单 2 / 9） | 只换 mihomo 二进制，与脚本通道无关 |

更新失败时保留原脚本与原配置，不会因为网络问题导致现有服务不可用。

---

## 六、分支与发布

**`main` = 正式版，`beta` = 测试版**，两条长期分支，目录结构一致。

| 分支 | 通道 | 规则 |
|---|---|---|
| `main` | 正式版 | 禁止直推；只接受从 `beta` 的快进合并与发布 tag |
| `beta` | 测试版 | 日常开发、修复、文档全部在这里提交；提交前跑 `tests/smoke.sh` |

**日常开发**

```bash
git switch beta
# 修改 install.sh / mihomo.sh
bash tests/smoke.sh            # 静态自检 + 通道读写实际执行
# 实机验证：安装 → 启动 → 切换节点 → 查看日志 → 卸载
git add install.sh mihomo.sh   # 只暂存本次改动的文件
git commit -m "feat(mihomo): ..."
git push origin beta
```

**发布正式版（合并 `beta` → `main`）**

常规发布就是快进：

```bash
git switch beta && bash tests/smoke.sh && git push origin beta

git switch main
git merge --ff-only beta         # 快进失败即停止，说明冲突原因，不要在 main 上手工合并
git tag -a v2.6.0 -m "release: v2.6.0"
git push origin main && git push origin v2.6.0
git switch beta                  # 发布后回到 beta 继续开发
```

**2.6.0 是首次结构切换，两条历史已分叉**：`main` 上那个「从 main 删除 mihomo_beta」的提交（`a427505`）在新结构下已无意义，而 `beta` 又不在它的下游，所以第一次不能快进。首次按下面做一次对齐，之后恢复上面的快进流程：

```bash
git switch beta                  # main 不能是当前分支
git branch -f main beta          # 以 beta 为准把 main 指到同一提交
git push origin main             # origin/main 仍停在 Initial commit，属快进推送，无需强推
```

> 对齐完成前，`main` 分支上的 `install.sh` 不存在，README 里的正式版安装命令会 404；这是过渡期的正常状态，正式版用户请等 2.6.0 发布后再用 `main` 的地址，或安装 `beta` 并显式指定通道。

- 快进合并意味着 `main` 得到的内容与 `beta` 完全一致，**不需要改任何分支变量或下载地址**；
- 禁止 `push --force` 覆盖历史；
- 回滚：`git revert <发布提交SHA>` 后发新 PATCH 版本，不要重推同名 tag。

---

## 七、开发约定

- 提交信息遵循 `type(scope): subject`，例如 `fix(install): 修正 Alpine 下 apk 判断`。
- 提交前必须本地跑通 `bash tests/smoke.sh`。
- 版本号只在 `install.sh` 与 `mihomo.sh` 各改一处（文件头 `# ver` 与 `readonly SCRIPT_VERSION`），两个文件版本必须一致，且**不带 `-beta` 后缀**——通道由分支承载，后缀会破坏快进合并。
- 所有 `.sh` 必须 LF 行尾，`.gitattributes` 已强制；Windows 端请勿用记事本保存。
- 新增脚本时同步更新：本文件目录结构、`tests/smoke.sh` 检查列表、`.gitattributes` 行尾规则。
- 不要在脚本里硬编码订阅链接、节点信息、API Token；这些属于运行期配置，不进版本库。

---

## 八、旧版本升级与迁移

2.6.0 起，脚本从"目录区分通道"改为"分支区分通道"，仓库路径也随之变化：

| 旧地址（2.5.x 及更早） | 新地址（2.6.0+） |
|---|---|
| `<repo>/main/mihomo/install.sh` | `<repo>/main/install.sh` |
| `<repo>/beta/mihomo_beta/install.sh` | `<repo>/beta/install.sh` |
| 无通道记录 | `/root/mihomo/channel.txt` |

旧安装可直接升级，不会丢配置：

1. 用新地址重跑安装命令（正式版用户加 `main`，测试版用户加 `beta`）；
2. 安装器检测到已有 `/root/mihomo/` 会先备份配置，再保留订阅与配置；
3. 安装完成后写入 `channel.txt`，此后菜单 12 的自更新只走该通道；
4. 不想重装也可以先跑 `mihomo` 看一眼：没有 `channel.txt` 时脚本按正式版处理并提示，不会自动跳到测试版。

旧版本的 `mihomo/`、`mihomo_beta/` 路径在 2.6.0 之后不再发布，旧脚本的自更新会因 404 失败——这也是安全的：失败时保留原脚本，不会把机器留在半更新状态。此时按上面第 1 步重装即可。

---

## 九、安全与免责

- 本仓库不含任何订阅地址、节点信息或凭据；`.env`、`config*.yaml`、证书私钥均已在 `.gitignore` 中排除。
- 脚本会修改系统服务与 `sysctl` 参数，**执行前请阅读源码**，尤其是 `install.sh` 的依赖安装与服务写入部分。
- 安装器成功后会删除自身 `install.sh`，这是预期行为，不是异常。
- 本项目仅用于学习与自建网络环境，请遵守所在地区的法律法规。

---

## 十、License

[MIT](./LICENSE) © `Abcd789JK`

---

## 附录：仓库维护待办

- [ ] 确认默认分支为 `main`，`beta` 为长期分支
- [ ] 配置 `main` / `beta` / `v*` tag 的分支保护规则
- [ ] 开启 Actions 的 "Read repository contents" 权限
- [ ] 开启 Secret scanning + Push protection
- [ ] 打 tag 前确认 `CHANGELOG.md` 已更新
