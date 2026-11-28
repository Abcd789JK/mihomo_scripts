# 更新日志

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

约定：发布通道由 Git 分支承载（`main` 正式版 / `beta` 测试版）。版本号按通道区分：
`main` 为 `X.Y.Z`，`beta` 为 `X.Y.Z-beta`（小写后缀，禁止 `X.Y.Z-beta-beta` 这类重复后缀）。
`-beta` 只用于版本号显示，不进入下载链接或 tag 地址；`beta` 合并到 `main` 时删除 `-beta` 后缀、保留数字版本号。
版本定义、界面显示、更新检测与发布流程保持一致。

## [2.6.1-beta] - 2026-11-27

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

- 安装脚本通道规则：不带参数默认安装正式版 `main`，不再把 `channel.txt` 当作默认值；显式 `main` / `beta` 安装对应通道，非法参数报错退出，全新安装与覆盖安装规则一致。
- 通道记录只在全部安装步骤成功后写入，安装失败不再覆盖原有记录；管理脚本自更新沿用当前通道并从对应通道取源。
- 版本号按修改内容升级：本次界面显示与命名调整属向后兼容的小改动，由 `2.6.0` 升至 `2.6.1`；`beta` 分支版本号加 `-beta` 后缀显示为 `2.6.1-beta`，合并到 `main` 时移除后缀。
- 仓库结构：`install.sh`、`mihomo.sh` 移到仓库根目录，`main` 与 `beta` 两个分支的目录结构、文件名称完全一致，
  版本隔离只由分支承担。
- 资源地址改为运行期拼接：`REPO_URL` 为基础地址，`REPO_RAW`、`SHELL_URL`、`INSTALL_URL`、`CONFIG_URL`
  由 `apply_release_channel` 按通道派生，删除硬编码的 `REPO_BRANCH` 常量与 `refs/heads/<分支>` 地址。
- 发布方式改为把 `beta` 合并到 `main`；合并时移除版本号中的 `-beta` 后缀、保留数字版本号，下载地址无需修改。
- 版本号按通道区分：`main` 为 `X.Y.Z`，`beta` 为 `X.Y.Z-beta`；`is_semver` 与 `extract_script_version` 拒绝重复后缀与非法声明，`compare_semver` 与更新检测保持可比较，不会误判或循环更新。
- 菜单与状态显示统一命名：「软件版本」→「内核版本」，「版本通道」→「内核通道」（正式版 stable / 测试版 alpha），「发布通道」→「脚本通道」（正式版 main / 测试版 beta），「更新时间」→「脚本更新」（仅表示管理脚本文件头的更新时间）；「已运行」→「运行中」，「已设置」→「已启用」，菜单 7 / 8 改为「启用 / 禁用开机自启」，提示语改为「请选择操作」，菜单 9「切换软件版本」→「切换内核通道」；系统名称按品牌名规范显示。
- 状态区按系统运行 / 版本更新 / 网络访问三组排列，50 字符分隔线分组；成功用绿色、测试版用黄色、异常用红色、停止 / 禁用 / 无数据 / 未安装用灰色或默认色，面板地址用蓝色；正常停止不再显示为异常，IPv4 / IPv6 缺失统一显示「无」。脚本版本只在页头「名  称」行显示一次，状态区不重复。
- `README.md` 重写：项目介绍、两个通道的安装命令与区别、更新方式、测试版风险、旧版本迁移路径。
- `tests/smoke.sh` 重写：八组检查改为结构 / 语法 / 行尾 / 版本 / 通道机制 / 通道读写 / 可执行位，两个分支跑同一份。
- PR 模板、Issue 模板同步改为按分支区分通道，不再提及旧目录生成物；`-beta` 仅作为测试版版本号后缀出现。

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
