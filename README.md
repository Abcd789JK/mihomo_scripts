# mihomo 一键安装与管理脚本

> 仓库地址：`https://github.com/Abcd789JK/mihomo_scripts`
> 当前版本：`2.6.0`

面向 Linux 服务器、软路由与容器环境的 mihomo（Clash.Meta）内核一键安装与交互式管理脚本。安装器自动识别发行版与架构、补齐依赖、下载内核、写入 systemd / OpenRC 服务，并生成一份开箱可用的配置：默认启用 TUN 透明代理、fake-ip DNS 与 mrs 规则集分流，自带 zashboard 面板，装完只差填入机场订阅。

脚本分成两个发布通道：`main` 是正式版，`beta` 是测试版。安装时用命令末尾的位置参数选择通道，之后的重装、更新、配置下载都会沿用这个选择。

最短路径——root 下执行第一条完成安装，第二条进入管理菜单：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Abcd789JK/mihomo_scripts/main/install.sh) main
mihomo
```

---

## 一、特性

| 能力 | 说明 |
|---|---|
| 一键安装 | 自动识别发行版与架构、补齐依赖、下载内核、写入 systemd/OpenRC 服务、生成订阅配置与 zashboard 面板 |
| 开箱可用 | 默认 TUN + fake-ip DNS + mrs 规则集分流，国内域名与节点域名分别解析，装完只差一条机场订阅 |
| 交互式管理 | `mihomo` 命令进入菜单，覆盖重装、更新、卸载、启停、自启、版本切换、配置管理、日志、脚本自更新 |
| 双通道 | `main` 正式版与 `beta` 测试版各自独立安装、独立更新，安装时选定、装后持久保存 |
| 国内可用 | 网络受限时自动改用镜像与备用地址，仍能取回脚本与内核 |

---

## 二、目录结构

仓库只需要这几个文件，两个通道用的是同一套：

```text
mihomo_scripts/
├── install.sh              # 一键安装脚本（位置参数指定发布通道）
├── mihomo.sh               # 交互管理脚本（启动时读取已保存的通道）
├── mihomo.yaml             # 默认配置（脚本从仓库根目录下载）
├── mihomo.service          # systemd 单元
├── mihomo.openrc           # OpenRC 服务脚本
└── CHANGELOG.md  LICENSE  README.md  README_CN.md
```

`README_CN.md` 是面向新装机的图文教程，侧重系统准备（换源、依赖、PVE 开启 TUN），其中的关键步骤已并入本文第三、四章。

两个通道装出来的目录完全一样，区别只在脚本内容：`main` 取正式版，`beta` 取测试版。

**安装后的运行时目录**

| 路径 | 内容 |
|---|---|
| `/root/mihomo/mihomo` | 内核二进制 |
| `/root/mihomo/config.yaml` | 运行配置，权限 `600`，面板密钥写在里面 |
| `/root/mihomo/config.yaml.bak` | 最近一次修改前的配置备份（固定覆盖同一份） |
| `/root/mihomo/ui/` | zashboard 面板静态文件 |
| `/root/mihomo/version.txt` | 当前内核版本 |
| `/root/mihomo/channel.txt` | 发布通道记录 |
| `/usr/bin/mihomo` | 交互菜单入口 |
| `/var/log/mihomo.log` | 管理脚本的操作日志，超出上限自动截断 |

---

## 三、环境要求

**系统与权限**：需要 **root 权限**，支持 x86_64 / i686 / aarch64 / armv7l / s390x。

支持的发行版：Debian/Ubuntu 系（含 Mint、Kali、Armbian）、Fedora/RHEL/CentOS/Rocky/Alma/Amazon Linux、Arch/Manjaro/EndeavourOS、Alpine、openSUSE/SLES。其中 Debian/Ubuntu 验证最充分，建议优先选用。其他发行版会跳过依赖安装，工具齐全时仍可继续。

**依赖**：安装器会自动安装 `unzip`、`gzip`、`jq`、`ca-certificates`、`iptables`，并按需补 `tzdata`、`iproute2`；`curl` 与 `wget` 必须自备其一（能取回脚本就说明已有一个），脚本不会代为安装。

### TUN 与内核参数

默认配置启用 TUN 透明代理（`stack: mixed`），需要内核提供 `/dev/net/tun`；同时 `tun.auto-redirect` 依赖 nftables。安装器会检查这两项并在缺失时给出警告：

- 没有 `/dev/net/tun`：TUN 不可用，透明代理失效，但 `7890` 端口代理仍可正常使用；
- 没有 nftables：服务会因 `auto-redirect` 启动失败，装好 `nftables` 或把该项改为 `false` 即可。

IP 转发由安装器写入 `/etc/sysctl.d/99-ip-forward.conf`（`net.ipv4.ip_forward` 与 `net.ipv6.conf.all.forwarding`），无需手工开启。

### PVE / LXC 开启 TUN

容器默认看不到 `/dev/net/tun`，需要把它直通进去。两条路径按 PVE 版本选择。

**PVE 8.x 及以上（面板操作）**：创建容器后先不要启动，选中容器依次点击 **资源 - 添加 - 直通设备（Device Passthrough）**，设备填 `/dev/net/tun`，然后再启动。

**PVE 7.x（面板没有直通设备入口，改用命令行）**：在 PVE 节点的 Shell 里编辑容器配置（`100` 换成实际 CT ID）：

```bash
nano /etc/pve/lxc/100.conf
```

在文件末尾追加，保存后重启容器：

```conf
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
```

> cgroup v1 的老内核把第一行写成 `lxc.cgroup.devices.allow: c 10:200 rwm`。

配好后启动容器，执行 `ls -l /dev/net/tun` 确认设备存在；缺失时安装器的 TUN 检测会给出警告。

### 系统准备（可选）

脚本本身会补齐依赖并自带镜像回退，只有在系统源不可用、或拉取脚本超时时才需要先做下面几步。

<details>
<summary>展开：各发行版的换源、更新与基础工具</summary>

**Debian 12 / 13（清华源，装 13 时把下面四行的 `bookworm` 全部换成 `trixie`）**

```bash
cat > /etc/apt/sources.list <<'EOF'
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-backports main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security bookworm-security main contrib non-free non-free-firmware
EOF
apt update && apt full-upgrade -y
apt install -y curl git wget nano
```

**Ubuntu 24.04（清华源，deb822 格式）**

```bash
cat > /etc/apt/sources.list.d/ubuntu.sources <<'EOF'
Types: deb
URIs: https://mirrors.tuna.tsinghua.edu.cn/ubuntu/
Suites: noble noble-updates noble-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: https://mirrors.tuna.tsinghua.edu.cn/ubuntu/
Suites: noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
apt update && apt full-upgrade -y
apt install -y curl git wget nano
```

24.04 之前的版本仍写 `/etc/apt/sources.list`：把 `noble` 换成 `jammy`，并把上面的 `Types/URIs/...` 还原为 `deb <镜像地址> jammy main restricted universe multiverse` 形式。

**Fedora**

```bash
sed -e 's|^metalink=|#metalink=|g' \
    -e 's|^#baseurl=http://download.example/pub/fedora/linux|baseurl=https://mirrors.tuna.tsinghua.edu.cn/fedora|g' \
    -i.bak /etc/yum.repos.d/fedora.repo /etc/yum.repos.d/fedora-updates.repo
dnf upgrade --refresh -y
dnf install -y curl git wget nano bash
```

**Alpine**

```bash
sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories
apk update && apk upgrade
apk add curl git wget nano bash
```

**Arch**

```bash
pacman -S --noconfirm reflector && \
  reflector --country China --age 6 --protocol https --sort rate --save /etc/pacman.d/mirrorlist && \
  pacman -Syyu --noconfirm
pacman -S --noconfirm curl git wget nano bash
```

Arch 若报 PGP 签名错误，依次执行 `pacman-key --init`、`pacman-key --populate archlinux`、`pacman -Syu --noconfirm`。

</details>

### root 远程登录（可选）

PVE 容器默认关闭 root 密码登录，需要 SSH 登录时按对应发行版执行：

<details>
<summary>展开：各发行版开启 root 密码登录</summary>

**Debian / Ubuntu**

```bash
apt install -y openssh-server && \
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
systemctl enable --now ssh
```

**Fedora / RHEL 系**

```bash
dnf install -y openssh-server && \
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
systemctl enable --now sshd
```

**Alpine**

```bash
apk add --no-cache openssh && \
mkdir -p /etc/ssh && ssh-keygen -A && \
sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
rc-update add sshd && \
rc-service sshd restart
```

**Arch**

```bash
pacman -Sy --noconfirm openssh && \
ssh-keygen -A && \
sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
systemctl enable --now sshd
```

</details>

> 以上改的是 `sshd_config` 的全局登录策略。只在受控内网开启，用完建议改回密钥登录（`PermitRootLogin prohibit-password`）。

---

## 四、安装

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

> tag 指向已发布的固定版本，比跟随 `main` 更适合长期运行，不会在两版切换的间隙装到中间状态。

> 若正式版地址返回 404，说明 `main` 分支尚未发布 `install.sh`，改用上面的 `beta` 通道安装即可。

### 安装过程

安装器按固定顺序推进，每一步失败都会明确报错并停止：检测系统环境 → 检测网络连通性 → 安装运行依赖 → 检查 IP 转发 → 检测架构 → 下载内核 → 安装系统服务 → 安装管理面板 → 安装管理脚本 → 记录发布通道 → 写入配置。

过程中会询问三件事：

| 询问 | 说明 |
|---|---|
| 内核版本通道 | 未给 `--channel` 时询问，默认 `stable`；`alpha` 为抢先版内核 |
| 面板密钥 | 默认启用，安装器本地生成随机密钥并写入配置；关闭后面板无鉴权，只适合完全隔离的内网 |
| 是否添加机场订阅 | 可以选 `n` 只装默认配置，之后用菜单 10 补上 |

安装成功后会自动删除本次运行的 `install.sh`，避免留在磁盘上；通过管道执行（`bash <(curl ...)`）时本来就没有落地文件，无需清理。

### 覆盖安装

已有安装时重跑安装命令即为覆盖安装。交互模式下先问是否继续、是否保留现有订阅与配置（选不保留则直接覆盖，不生成备份），确认后行为如下：

- 现有 `config.yaml` 先备份为 `config.yaml.bak`；
- **只保留机场订阅段**（`proxy-providers`）与面板密钥，其余配置项恢复成默认配置；
- 自定义过的端口、DNS、规则、代理组不会保留，需要的话请另外保存一份 `config.yaml`；
- 安装完成后继续使用原来的发布通道，订阅无需重新输入。

### 安装结果

| 项目 | 路径 / 值 |
|---|---|
| 安装目录 / 配置 | `/root/mihomo/`（配置为 `/root/mihomo/config.yaml`） |
| 发布通道记录 | `/root/mihomo/channel.txt` |
| 命令入口 | `/usr/bin/mihomo` |
| 服务 | `/etc/systemd/system/mihomo.service` 或 `/etc/init.d/mihomo` |
| 转发参数 | `/etc/sysctl.d/99-ip-forward.conf` |
| 面板 | `http://<本机 IP>:9090/ui`（地址与密钥在安装结束的横幅里打印） |

装完直接执行 `mihomo`，进入菜单 **10 配置管理 → 1 新增机场订阅** 填入订阅链接即可。

---

## 五、配置说明

### 默认配置

配置文件在 `/root/mihomo/config.yaml`，权限 `600`。默认值：

| 配置项 | 默认值 | 说明 |
|---|---|---|
| `mixed-port` | `7890` | HTTP / SOCKS5 混合端口，不鉴权，建议只在内网开放 |
| `allow-lan` | `true` | 允许局域网设备通过本机代理 |
| `external-controller` | `0.0.0.0:9090` | 面板与 API 监听地址，密钥由安装器生成并注入 |
| `external-ui` | `ui` | 面板静态目录，对应 `/root/mihomo/ui` |
| `tun.enable` | `true` | TUN 透明代理，`stack: mixed` |
| `tun.auto-route` / `auto-redirect` | `true` | 自动接管路由 / 自动写入 nftables 重定向规则 |
| `dns.enhanced-mode` | `fake-ip` | fake-ip 模式，`ipv6: false` |
| `rule-providers` | mrs | 规则集取自 meta-rules-dat，按域名与 IP 分流 |

脚本默认只启用 TUN，不提供 TProxy 模式切换；确实需要 TProxy 时请自行编写 nftables 规则并修改配置，这部分不在本项目支持范围内。

### 机场订阅

订阅通过菜单写入 `proxy-providers` 段，编号从 `provider_01` 依次排列，每条包含 `url`、`type: http`、`interval: 86400`、`health-check`，并用机场名称作为节点名前缀（`[机场名]`）：

```yaml
proxy-providers:
  provider_01:
    url: "https://example.com/subscribe?token=xxx"
    type: http
    interval: 86400
    health-check: {enable: true, url: "https://www.gstatic.com/generate_204", interval: 300}
    override:
      additional-prefix: "[机场1]"
```

订阅不能全部删除，至少保留一个；订阅链接必须是 Clash / mihomo 兼容的 YAML，`base64` 之类的通用订阅不能直接使用。

### 修改与生效

- 所有写操作（新增 / 修改 / 删除订阅、重置配置）都先备份为 `config.yaml.bak`，校验通过后才覆盖当前配置；校验不通过时原文件保持不动。
- **重置配置文件**（菜单 10 → 4）用仓库里的默认配置覆盖当前配置，订阅需要重新输入，原配置保留在 `config.yaml.bak`。
- 手改 `config.yaml` 后建议先校验再重启，避免把语法错误带进运行态：

```bash
/root/mihomo/mihomo -t -f /root/mihomo/config.yaml   # 语法校验
systemctl restart mihomo                             # 或菜单 6
```

### 面板密钥

密钥写在 `external-controller` 的 `secret` 字段，安装结束时只在屏幕上显示一次，不会写进日志。菜单 **10 → 5** 可以启用、禁用或更换密钥，更换后需要重新登录面板。

---

## 六、使用方法

### 交互菜单

安装完成后执行 `mihomo` 进入交互菜单（**脚本不提供命令行子命令**）：

| 菜单项 | 功能 |
|---|---|
| 1 | 安装 mihomo（覆盖安装沿用当前发布通道，旧目录暂存为 `/root/mihomo.old`） |
| 2 | 更新内核版本 |
| 3 | 卸载 mihomo（可选把订阅配置保留到 `/root/mihomo-config.yaml.bak`） |
| 4 / 5 / 6 | 启动 / 停止 / 重启服务 |
| 7 / 8 | 添加 / 关闭开机自启 |
| 9 | 切换软件版本（内核 `stable` ↔ `alpha`） |
| 10 | 配置管理（新增 / 修改 / 删除订阅、重置配置、面板密钥） |
| 11 | 查看实时日志 |
| 12 | 更新管理脚本自身 |
| 0 或 q | 退出 |

菜单状态区的「发布通道」显示当前脚本来自 `main` 还是 `beta`，「版本通道」显示内核是稳定版还是 alpha。

### 管理面板

浏览器打开 `http://<本机 IP>:9090/ui`，用安装结束时打印的密钥登录。面板里可以切换代理组、查看连接与规则命中、刷新订阅、测速。

### 服务与日志

```bash
systemctl status mihomo          # Debian / Ubuntu / Fedora 等 systemd 系统
journalctl -u mihomo -o cat -f   # 实时日志（菜单 11 等价）
rc-service mihomo status         # Alpine / OpenRC
logread | grep mihomo            # OpenRC 下的日志
```

管理脚本自身的操作记录在 `/var/log/mihomo.log`，与内核日志分开。

### 更新管理脚本（菜单 12）

管理脚本与内核分开更新：菜单 12 替换的是 `/usr/bin/mihomo` 这个菜单程序，菜单 2 / 9 换的是内核二进制。升级脚本不会重启服务，也不会改动 `config.yaml` 与订阅。

**什么情况下用菜单 12**

- 安装后过了一段时间，想用上新版菜单与已修复的问题（当前版本号显示在菜单页头）；
- 想确认有没有新版，或本次更新只想换脚本、不想动内核；
- `beta` 通道的更新想立刻用上（`beta` 每次推送即生效，`main` 随正式版一起发布）。

想固定某个版本、或要换通道时不要用菜单 12，改用第四章的安装命令，见下方对照表。

**操作步骤**

1. 以 root 身份执行 `mihomo`，在菜单里输入 `12`。
2. 脚本联网检查当前通道的最新版本，把候选脚本下载到临时目录，并做语法校验与版本号比对。
3. 出现「发现新版本：`x.y.z`（当前 `a.b.c`）」后询问 `是否更新管理脚本？(y/N)`，默认 `N`，输入 `y` 回车继续。
4. 原脚本备份为 `/usr/bin/mihomo.bak`，替换后再次复核版本号，成功时提示 `管理脚本已更新：a.b.c -> x.y.z`。
5. 3 秒后自动用新版本重新进入菜单，不用退出重开。

**结果与注意事项**

| 情况 | 脚本行为 |
|---|---|
| 已是最新版本 | 提示「当前已是最新版本」，不写入任何文件 |
| 远端版本低于本地 | 拒绝降级并说明原因，避免镜像缓存或远端回退把脚本换成旧版 |
| 下载失败、语法或版本校验不通过 | 中止更新，`/usr/bin/mihomo` 保持原样 |
| 替换后复核失败 | 自动回滚到 `mihomo.bak`，并打印手动恢复命令 |

- 新版菜单运行异常时手动回滚：`cp -f /usr/bin/mihomo.bak /usr/bin/mihomo`。
- 更新只动菜单脚本，运行中的内核、配置与订阅都不受影响，不需要重启 `mihomo` 服务。
- 要写入 `/usr/bin`，必须在 root 下运行；网络不通时先按第三章换源或改用镜像，也可以直接重跑安装命令。

**几种更新方式的区别**

| 想做的事 | 用什么 | 影响范围 |
|---|---|---|
| 升级菜单脚本 | 菜单 12 | 只替换 `/usr/bin/mihomo` |
| 升级内核到当前版本通道的最新版 | 菜单 2 | 只替换内核二进制，服务会重启 |
| 在 `stable` / `alpha` 内核之间切换 | 菜单 9 | 只替换内核二进制，服务会重启 |
| 换发布通道（`main` ↔ `beta`） | 重跑对应通道的安装命令 | 脚本与配套文件，订阅保留 |
| 固定到某个发布版本 | 用 tag 地址重跑安装命令（如 `v2.6.0`） | 同上 |

> 菜单 12 只在当前仓库内升级。脚本还停留在 2.5.x 及更早、或装自旧仓库时，它只能拿到旧地址上的版本，必须按第八章用新地址重装一次。

### 卸载

菜单 3 会停止服务、取消自启、删除服务单元、`/root/mihomo/`（含重装时暂存的 `/root/mihomo.old`）与 `/etc/sysctl.d/99-ip-forward.conf`。卸载前会单独询问是否保留订阅配置，选保留则复制到 `/root/mihomo-config.yaml.bak`，重装后可以取回里面的订阅链接。`/usr/bin/mihomo` 不自动删除，卸载结束时会打印删除命令。

---

## 七、发布通道

**通道只决定脚本本身从哪个分支获取**，安装后写入 `/root/mihomo/channel.txt`，之后的自更新、重装、默认配置下载都跟着它走。

| | 正式版 `main` | 测试版 `beta` |
|---|---|---|
| 定位 | 稳定版本 | 开发中的版本 |
| 脚本来源 | `main` 分支 | `beta` 分支 |
| 更新节奏 | 随正式版发布更新 | 每次推送即生效 |
| 风险 | 低 | 可能存在未验证的行为变化 |
| 适合 | 生产节点、长期运行 | 尝鲜、协助验证、提前发现问题 |

**通道与内核版本是两件事**：

- 位置参数 `main` / `beta` 选的是**脚本发布通道**；
- `--channel stable|alpha` 选的是**mihomo 内核版本通道**（如 `v1.19.32` 与 `alpha-94b13ae`）。

正式版脚本配 alpha 内核是完全合法的组合，两者互不约束。

**通道是怎么确定的**

1. 安装时给了位置参数 → 用参数，并写入 `channel.txt`；
2. 没给参数但已有 `channel.txt` → 沿用（重装不会把测试版机器带回正式版）；
3. 两者都没有（旧版本用户）→ 按正式版 `main` 处理，并在屏幕上明确提示。

`channel.txt` 内容非法（手工改坏或写入中断）时**直接报错停止，不做静默回退**，避免把测试版机器误切到正式版（或反之）。修复方式二选一：

```bash
printf 'main\n' > /root/mihomo/channel.txt      # 修正记录（把 main 换成 beta 即测试版）
bash install.sh main                            # 或用参数重新指定通道
```

**测试版风险提示**

- `beta` 是开发分支，可能包含未完成的功能、未处理好的边界情况，甚至服务启动失败；
- 升级测试版前建议先备份 `/root/mihomo/config.yaml`；
- 生产环境请使用 `main` 或版本 tag；
- 从测试版回到正式版：重跑第四章的正式版安装命令，订阅与配置会被保留。

---

## 八、旧版本升级到当前仓库

2.6.0 起安装脚本移到了仓库根目录，安装地址和通道机制都变了。旧版安装不能靠脚本自带的自更新升上来，要用新地址重装一次。

**先确认自己是不是旧版**

```bash
cat /root/mihomo/channel.txt   # 没有这个文件 = 2.5.x 及更早，需要迁移
mihomo                         # 菜单页头显示当前脚本版本
```

| 当前状态 | 是否需要迁移 |
|---|---|
| 装自旧仓库 `Abcd789JK/Tools`（地址含 `Script/mihomo/`） | 需要 |
| 装自本仓库 2.5.x 及更早（地址含 `main/mihomo/` 或 `beta/mihomo_beta/`） | 需要 |
| 已有 `/root/mihomo/channel.txt`，菜单页头为 2.6.0 或更新 | 不需要，后续用第六章的菜单 12 跟进 |

**新旧地址对照**

| 旧地址 | 新地址（2.6.0+） |
|---|---|
| `.../Tools/.../Script/mihomo/install.sh` | `.../mihomo_scripts/main/install.sh` |
| `<repo>/main/mihomo/install.sh` | `<repo>/main/install.sh` |
| `<repo>/beta/mihomo_beta/install.sh` | `<repo>/beta/install.sh` |
| 无通道记录 | `/root/mihomo/channel.txt` |

**升级步骤**

1. 先备份配置（订阅链接与面板密钥都在里面）：

    ```bash
    cp -f /root/mihomo/config.yaml /root/mihomo-config-backup.yaml
    ```

2. 用新地址重跑安装命令：原来装正式版的加 `main`，原来装测试版的加 `beta`。**不要顺手换通道**，否则测试版机器会被带到正式版（或反之）。命令见第四章。
3. 安装器提示「检测到已存在的安装目录」时，先问「继续将覆盖安装」输入 `y`；再问「是否保留现有订阅与配置」保持默认 `Y` 回车。这一步才会保留订阅与面板密钥。
4. 装完确认通道记录与版本：

    ```bash
    cat /root/mihomo/channel.txt   # 应输出 main 或 beta
    mihomo                         # 页头版本应为 2.6.0 或更新
    ```

5. 面板地址与密钥一般不变；打不开时到菜单 10 → 5 查看或更换密钥。

**注意事项**

- 订阅不会丢：安装器只保留机场订阅段（`proxy-providers`）与面板密钥，端口、DNS、规则、代理组等自定义项会恢复默认，需要的话从第 1 步的备份里取回。
- 内核会重新下载为当前版本通道的最新版，服务在安装结束时自动重启。
- 旧脚本的自更新仍指向旧地址，仓库调整后可能失效（404）；失败时保留原脚本，不会把机器留在半更新状态，按上面步骤重装即可。
- 迁移后请改掉手边保存的旧命令，继续用旧地址会装回旧版本。
- 旧仓库里的 `mihomo/`、`mihomo_beta/` 目录不再维护，以后升级只认新地址。

---

## 九、常见问题

**服务启动失败，日志提到 nftables 或 `auto-redirect`**
装 `nftables`（`apt install -y nftables`），或把配置里的 `tun.auto-redirect` 改为 `false` 后重启服务——TUN 仍靠 `auto-route` 工作，只是少了自动重定向规则。

**容器里没有 `/dev/net/tun`**
按第三章给 LXC 直通设备（8.x 及以上用面板的直通设备，7.x 改 `lxc.conf`）。直通不可行时 TUN 会失效，但 `mixed-port` 7890 仍可用：把这台机器当作 HTTP/SOCKS5 代理使用即可。

**面板打不开**
地址必须以 `/ui` 结尾（`http://<IP>:9090/ui`）；确认防火墙或云安全组放行 9090；提示需要密钥时，密钥在安装结束的横幅里，或到菜单 10 → 5 查看 / 更换。只想本机访问就把 `external-controller` 改成 `127.0.0.1:9090`。

**7890 端口被外部扫到**
`mixed-port` 没有鉴权，只能用防火墙限制来源；不需要局域网代理时把 `allow-lan` 关闭。

**安装命令 404 或 raw 拉不下来**
换 jsDelivr 镜像，或在地址前加 `https://github.boki.moe/` 前缀；`main` 分支还没发布安装脚本时先用 `beta` 通道。

**执行完 `install.sh` 文件不见了**
安装成功后脚本会删除自身，属预期行为；通过管道执行（`bash <(curl ...)`）时没有落地文件，不存在这个问题。

**覆盖安装后自定义端口、规则都没了**
覆盖安装只保留机场订阅段与面板密钥，其余配置项恢复默认。需要保留的自定义项请先备份 `config.yaml`，装完再合回去。

**添加订阅后没有节点**
订阅必须是 Clash / mihomo 兼容的 YAML，`base64` 之类的通用订阅不行；先在浏览器直接打开链接确认能下载到内容，再检查面板里对应的 `provider` 是否刷新成功。

**日志时间与本地时间不一致**
补时区数据并设置时区：

```bash
# Debian / Ubuntu
apt install -y tzdata && timedatectl set-timezone Asia/Hong_Kong
# Alpine
apk add --no-cache tzdata && \
  ln -sf /usr/share/zoneinfo/Asia/Hong_Kong /etc/localtime && \
  echo "Asia/Hong_Kong" > /etc/timezone
```

**`/root/mihomo.old` 占了空间**
重装时旧目录会被暂存到这里，方便取回配置与订阅；确认不再需要后执行 `rm -rf /root/mihomo.old`。

**Alpine 上 `systemctl` 不存在**
Alpine 用 OpenRC：服务操作走 `rc-service mihomo start|stop|restart`，自启用 `rc-update add mihomo`，日志用 `logread | grep mihomo`。

**如何从测试版回到正式版**
重跑正式版安装命令即可，订阅与配置会保留，`channel.txt` 随之改回 `main`。

---

## 十、安全与免责

- 仓库里不含任何订阅地址、节点信息或凭据；`.env`、`config*.yaml`、证书私钥这类文件不会被纳入版本控制。
- 脚本会修改系统服务与 `sysctl` 参数，**执行前请阅读源码**，尤其是 `install.sh` 的依赖安装与服务写入部分。
- 安装器成功后会删除自身 `install.sh`，这是预期行为，不是异常。
- 管理面板默认监听 `0.0.0.0:9090`，请保留密钥鉴权，或用防火墙限制来源；`mixed-port` 7890 不鉴权，同样不要直接暴露在公网。
- 本项目仅用于学习与自建网络环境，请遵守所在地区的法律法规。

---

## 十一、License

[MIT](./LICENSE) © `Abcd789JK`
