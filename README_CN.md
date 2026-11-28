# Linux 安装 mihomo 图文教程

> 本文件只保留 PVE / LXC 开启 TUN 的截图步骤与安装入口。换源、依赖、配置说明、覆盖安装与常见问题一律以 [README.md](./README.md) 为准，两者若有出入，以 README.md 为准。

## 一、PVE 8.x：面板直通 TUN

### 1. 创建 LXC 容器

在 PVE 创建容器后先不要启动。

### 2. 添加直通设备

选中容器，鼠标依次点击 **资源 - 添加 - 直通设备（Device Passthrough）**：

![PVE 8.x 添加直通设备](https://github.com/user-attachments/assets/f185b446-cc76-4337-817b-0139f688445f)

### 3. 填入 /dev/net/tun

设备填 `/dev/net/tun`，确认后启动容器：

![填写 /dev/net/tun](https://github.com/user-attachments/assets/7ad8bb51-d593-439a-9fdf-2649d3f44e82)

启动后执行 `ls -l /dev/net/tun` 确认设备存在；缺失时安装器的 TUN 检测会给出警告。

## 二、PVE 7.x：命令行直通

面板没有直通设备入口时，在 PVE 节点的 Shell 里操作：

![PVE 节点 Shell](https://github.com/user-attachments/assets/ba043dca-b12b-4b92-963c-4f809305ec11)

编辑容器配置，把 `100` 换成实际 CT ID：

```bash
nano /etc/pve/lxc/100.conf
```

在文件末尾追加，保存后重启容器：

```conf
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
```

> cgroup v1 的老内核把第一行写成 `lxc.cgroup.devices.allow: c 10:200 rwm`。

## 三、安装 mihomo

以 root 身份执行，正式版（默认通道，命令不带参数）：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Abcd789JK/mihomo_scripts/main/install.sh)
```

测试版从 `beta` 分支取脚本，并显式带上 `beta` 参数：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Abcd789JK/mihomo_scripts/beta/install.sh) beta
```

装完执行 `mihomo` 进入菜单，**10 配置管理 → 1 新增机场订阅** 填入订阅链接。面板地址与密钥在安装结束的横幅里打印，之后可在菜单 **10 → 5** 查看。

## 四、下一步

- 依赖、换源、root 远程登录、TUN 与 nftables 的关系：见 [README.md](./README.md) 第三章「环境要求」。
- 覆盖安装、订阅与面板密钥保留、卸载：见 README.md 第四、六章。
- 服务状态、日志与常见问题：见 README.md 第六、九章。
