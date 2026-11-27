# 更新日志

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

约定：`-beta` 后缀为测试通道版本，去掉后缀即为对应的稳定版版本号。

## [Unreleased]

### Added

- 仓库从 `Tools` 拆分为独立的 mihomo 脚本仓库，双通道目录（`mihomo_beta/` 源、`mihomo/` 生成物）保持不变。
- 新增 `REPO_BRANCH` 常量：脚本的自更新、重装与 pinned commit 查询绑定到所在分支，`main` 因此不必保留 `mihomo_beta/`。
- 新增 `tests/smoke.sh`：资源、语法、行尾、版本、通道分支、生成物一致性八组静态检查，按分支自动切换，无需 root。
- 新增 GitHub Actions CI：`smoke` 阻塞检查 + `shellcheck` 观察性检查。
- 新增 `.gitignore`：覆盖凭据、订阅、运行期配置、日志、备份、证书私钥与临时文件。
- 新增 `.gitattributes`：强制脚本与根目录资源 LF 行尾，并将 `mihomo/` 标记为生成物。
- 新增 PR 模板、Issue 模板与 `docs/migration.md` 迁移清单。

### Changed

- 通道改为分支承载：`main` 只保留正式版产物，`beta` 保留源与生成预览；发布改为把 `mihomo/` 目录晋升到 `main`，不再整分支合并。
- 默认配置与服务模板从 `Config/`、`Service/` 子目录提到仓库根目录（`mihomo.yaml`、`mihomo.service`、`mihomo.openrc`），与 `CONFIG_URL` / `SERVICE_URL_*` 对齐。
- `sync-mihomo.sh` 增加第三条改写规则（`REPO_BRANCH="beta"` → `"main"`）、根目录资源存在性校验，并在 `main` 上主动拒绝运行。
- `README.md` 重写：按脚本真实行为描述（`mihomo` 为纯交互菜单，无命令行子命令），说明分支与目录的对应关系及晋升流程。

### Fixed

- `mihomo.service`、`mihomo.openrc` 原为 CRLF 行尾，systemd / OpenRC 会把 `\r` 读进路径导致启动失败，已统一为 LF。

## [2.5.3] - 待发布

### Changed

- 迁移至新仓库后，脚本内 `REPO_RAW`、`SHELL_REPO` 与稳定版/测试版原始地址指向新仓库，路径前缀由 `Script/mihomo_beta` 调整为 `mihomo_beta`。
- 迁移细节见 `docs/migration.md`；此版本与 `2.5.3-beta` 在功能上完全一致。

<!--
模板：

## [x.y.z] - YYYY-MM-DD

### Added
### Changed
### Fixed
### Removed
### Security
-->
