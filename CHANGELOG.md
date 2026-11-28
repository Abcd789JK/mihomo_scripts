# 更新日志

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

约定：发布通道由 Git 分支承载（`main` 正式版 / `beta` 测试版），版本号按通道区分——`main` 为 `X.Y.Z`，`beta` 为 `X.Y.Z-beta`。`-beta` 只用于版本号显示，不进入下载链接或 tag 地址；`beta` 合并到 `main` 时删除后缀、保留数字版本号。

## [2.6.3-beta] - 2026-11-28

**重装改为原地覆盖并可选择备份配置；移除管理脚本的日志文件；修复回滚与订阅编号处理。**

### Changed

- 菜单 1 重装不再把 `/root/mihomo` 暂存为 `/root/mihomo.old`，改为原地覆盖，由安装器询问是否保留现有订阅与配置（保留则先备份 `config.yaml`），重装后无需重新输入订阅。
- `mihomo.sh` 不再写 `/var/log/mihomo.log`：日志只输出到 stderr，内核日志仍由 `journalctl` / `logread` 提供，脚本输出与内核日志不再混在一起。
- 文档：`README_CN.md` 改名为 `PVE_TUN.md` 并在 README 顶部加入跳转；两个变更日志合并为本文件。

### Fixed

- 回滚路径（二进制与配置）改为受保护写法：复制失败时打印可手动执行的恢复命令，不再让 `set -e` 在回滚途中退出而留下"提示已回滚、实际未回滚"的状态。新增 `rollback_binary` / `rollback_config` 共用函数。
- 覆盖安装替换二进制后按现有配置重启一次，后续步骤失败时不会把机器留在停服状态。
- 订阅编号识别不再依赖固定缩进：`provider_key` 按编号数值匹配，4 空格缩进或 `provider_1:` 未补零的手工配置也能修改和删除；修改订阅时保留原有缩进层级。
- `inject_providers` 增加重复键校验：同名 provider 直接拒绝，不再写出两份互相覆盖的键。
- `install.sh --channel=`（空值）按缺参报错，不再静默当作未指定。

### Removed

- 管理脚本的日志文件功能：`/var/log/mihomo.log`、`log_trim`、`log_append`、`log_clean` 及相关常量；卸载时顺带清理旧版本留下的这两个日志文件。
- `升级日志.md`：内容并入本文件。

## [2.6.2-beta] - 2026-11-28

**文档与通道记录的一致性修复。**

### Changed

- `README.md` 成为唯一事实来源：安装与镜像命令、覆盖安装、配置备份、订阅与面板密钥的保留方式全部按实际代码校正，删除过渡阶段说明。
- 文档与界面区分两件事：更新内核不影响配置；覆盖安装保留订阅与面板密钥。
- 删除界面、帮助与注释中过时的固定内核版本示例，统一为 `v<版本>` / `alpha-<哈希>` 占位。

### Fixed

- `save_release_channel`：原子替换失败时退化为直接写入；仍然失败则按实际生效的通道告警并给出修正命令，避免下次自更新意外换通道。
- 安装进度总数与实际步骤数对齐（`STEP_TOTAL` 10 → 11），最后一步不再显示 `[11/10]`。
- `tests/smoke.sh` 头部注释恢复按分支区分版本号；Issue 模板术语改为「脚本通道」。

## [2.6.1-beta] - 2026-11-27

**结构调整：一套代码、两个分支、两个安装通道。**

### Added

- 通道机制：`install.sh` 用位置参数 `main` / `beta` 指定通道，成功后写入 `/root/mihomo/channel.txt`；`mihomo.sh` 启动时读取它，自更新、重装、默认配置下载都跟随该通道。
- `valid_release_channel` / `apply_release_channel` / `read_release_channel` / `save_release_channel` 四个共用函数，通道取值严格校验，非法值直接拒绝（退出码 2）。
- 旧版本兼容：缺少 `channel.txt` 时按 `main` 处理并提示，不会静默切到测试版；记录非法时直接报错停止，不做自动回退。
- `tests/smoke.sh` 新增通道读写实测：在隔离临时目录验证「保存 → 读回 → 缺文件回退 main → 非法内容拒绝」。

### Changed

- 安装通道规则：不带参数装正式版 `main`，显式传 `beta` 装测试版，非法参数报错退出；全新安装与覆盖安装规则一致。
- 通道记录只在全部安装步骤成功后写入，安装失败不覆盖原有记录。
- 仓库结构：两份脚本移到仓库根目录，两个分支结构完全一致，版本隔离只由分支承担；资源地址改为运行期按通道拼接，删除硬编码分支常量。
- 菜单与状态区统一命名（内核版本 / 内核通道 / 脚本通道 / 脚本更新），状态区按系统运行、版本更新、网络访问三组排列，脚本版本只在页头显示一次。
- `README.md` 与 `tests/smoke.sh` 重写；PR / Issue 模板按分支区分通道。

### Removed

- 删除 `mihomo/`、`mihomo_beta/` 目录与 `tools/sync-mihomo.sh`：通道不再用目录区分，生成器随之失效。
- 删除 `docs/migration.md`：迁移清单并入 `README.md`。

### Fixed

- 文档与模板中指向 `mihomo/install.sh`、`mihomo_beta/install.sh` 的旧安装地址全部更新为根目录地址。

## [2.6.0] - 2026-11-27

### Added

- 正式版 `main` 与测试版 `beta` 两个通道独立安装、独立更新；通道写入 `/root/mihomo/channel.txt`，重装、更新与默认配置下载自动沿用。
- 新安装默认启用 TUN 透明代理、fake-ip DNS 与 mrs 规则集分流，附带 zashboard 面板，装完只需添加机场订阅。
- 国内网络自动改用镜像与备用地址获取脚本、内核与版本信息。

### Changed

- 安装脚本与配套文件移到仓库根目录，旧路径不再发布，旧版安装需按新地址重装一次。
- 覆盖安装保留机场订阅与面板密钥，其余配置项恢复默认；配置写操作前备份为 `config.yaml.bak`，校验不通过时不覆盖原文件。

## [2.5.3] - 2026-11-22

### Added

- 仓库从 `Tools` 拆分为独立的 mihomo 脚本仓库，`tests/smoke.sh`、GitHub Actions CI、`.gitignore`、`.gitattributes`、PR / Issue 模板一并建立。

### Changed

- 默认配置与服务模板从 `Config/`、`Service/` 子目录提到仓库根目录（`mihomo.yaml`、`mihomo.service`、`mihomo.openrc`）。
- 脚本内仓库地址迁移到 `Abcd789JK/mihomo_scripts`。

### Fixed

- `mihomo.service`、`mihomo.openrc` 原为 CRLF 行尾，systemd / OpenRC 会把 `\r` 读进路径导致启动失败，已统一为 LF。

<!--
模板：

## [x.y.z] - YYYY-MM-DD

### Added
### Changed
### Fixed
### Removed
### Security
-->
