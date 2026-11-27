# 更新日志

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

约定：`-beta` 后缀为测试通道版本，去掉后缀即为对应的稳定版版本号。

## [Unreleased]

### Added

- 仓库从 `Tools` 拆分为独立的 mihomo 脚本仓库，双通道目录（`mihomo_beta/` 源、`mihomo/` 生成物）保持不变。
- 新增 `tests/smoke.sh`：语法、行尾、版本一致性、生成物一致性静态自检，无需 root。
- 新增 GitHub Actions CI：`smoke` 阻塞检查 + `shellcheck` 观察性检查。
- 新增 `.gitignore`：覆盖凭据、订阅、运行期配置、日志、备份、证书私钥与临时文件。
- 新增 `.gitattributes`：强制核心脚本 LF 行尾，并将 `mihomo/` 标记为生成物。
- 新增 PR 模板、Issue 模板与 `docs/migration.md` 迁移清单。

### Changed

- `README.md` 重写：按脚本真实行为描述（`mihomo` 为纯交互菜单，无命令行子命令），补充双通道维护流程与版本号规则。

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
