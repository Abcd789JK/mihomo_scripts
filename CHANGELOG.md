# 更新日志

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

约定：发布通道由 Git 分支承载（`main` 正式版 / `beta` 测试版），版本号不再带 `-beta` 后缀。
同一版本号在 `beta` 上可能比 `main` 多若干提交，两者的差异由分支与 tag 决定，不由版本字符串决定。

## [2.6.0] - 2026-11-27

**结构调整：一套代码、两个分支、两个安装通道。**

### Added

- 发布通道机制：`install.sh` 用位置参数 `main` / `beta` 指定通道，安装成功后写入 `/root/mihomo/channel.txt`；
  `mihomo.sh` 启动时读取该文件，自更新、重装、默认配置下载、pinned commit 查询全部跟随通道。
- `valid_release_channel` / `apply_release_channel` / `read_release_channel` / `save_release_channel` 四个共用函数，
  两份脚本实现一致，通道取值严格校验，非法值直接拒绝（退出码 2）。
- 旧版本兼容：没有 `channel.txt` 时按正式版 `main` 处理并在屏幕上提示，不会静默切到测试版；
  重装时用当前通道调用安装脚本，测试版机器不会被带回正式版。
- 通道记录非法（内容损坏或手工改坏）时直接报错停止，不做自动回退——此时任何猜测都可能
  把测试版机器切到正式版；修正 `channel.txt` 或用位置参数重新指定即可。
- `tests/smoke.sh` 新增通道读写**实际执行**检查：抽取两份脚本中的通道函数，在隔离临时目录里验证
  「保存 → 读回 → 缺文件回退 main → 非法内容回退 main」。
- 菜单状态区新增「发布通道」一行，与内核「版本通道」分开显示。

### Changed

- 仓库结构：`install.sh`、`mihomo.sh` 移到仓库根目录，`main` 与 `beta` 两个分支的目录结构、文件名称完全一致，
  版本隔离只由分支承担。
- 资源地址改为运行期拼接：`REPO_URL` 为基础地址，`REPO_RAW`、`SHELL_URL`、`INSTALL_URL`、`CONFIG_URL`
  由 `apply_release_channel` 按通道派生，删除硬编码的 `REPO_BRANCH` 常量与 `refs/heads/<分支>` 地址。
- 发布方式改为把 `beta` 快进合并到 `main`（`git merge --ff-only beta`），合并时无需修改任何分支变量或下载地址。
- `README.md` 重写：项目介绍、两个通道的安装命令与区别、更新方式、测试版风险、旧版本迁移路径。
- `tests/smoke.sh` 重写：八组检查改为结构 / 语法 / 行尾 / 版本 / 通道机制 / 通道读写 / 可执行位，两个分支跑同一份。
- PR 模板、Issue 模板同步改为按分支区分通道，不再提及生成物与 `-beta` 后缀。

### Removed

- 删除 `mihomo/`（正式版生成物目录）与 `mihomo_beta/`（测试版源目录），通道不再用目录区分。
- 删除 `tools/sync-mihomo.sh`：没有第二份生成物，生成器随之失去作用。
- 删除 `docs/migration.md`：旧仓库路径迁移清单已完成，内容并入 `README.md` 的迁移章节。

### Fixed

- 旧版本文档与模板中指向 `mihomo/install.sh`、`mihomo_beta/install.sh` 的过时安装地址全部更新为根目录地址。

## [2.5.3] - 2026-11-22

### Added

- 仓库从 `Tools` 拆分为独立的 mihomo 脚本仓库，`tests/smoke.sh`、GitHub Actions CI、`.gitignore`、
  `.gitattributes`、PR / Issue 模板一并建立。
- 新增 `REPO_BRANCH` 常量，让脚本的自更新、重装与 pinned commit 查询绑定所在分支（2.6.0 已改为通道机制）。

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
