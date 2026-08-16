# DeepSeek Harness 一键管理工具

> DeepSeek-Harness-Setup — 在 Windows 上双击 **DSH Manager.bat** 即可完成 [DeepSeek Harness](https://www.npmjs.com/package/@deepseek-ai/dsh) 的 **安装 / 启动 / 停止 / 卸载**，无需记忆任何命令。

**启动命令：`npx @deepseek-ai/dsh web`**（每次启动自动更新到最新版；如需离线固定版本可用 `-PreferGlobal` 走全局 `dsh web`）

---

## ✨ 功能特性

双击 `DSH Manager.bat` 打开中文菜单（自动显示当前状态：运行中 / 已安装未运行 / 未安装）：

| 菜单项 / 子命令 | 功能 |
| --- | --- |
| `[1]` / `DSH Manager.bat start` | **一键启动**：检测 `http://127.0.0.1:3080` 是否已运行；未运行则自动执行启动命令并等待服务就绪（默认最多 600 秒，可用 `-TimeoutS` 调整），随后在浏览器中打开 GUI。未安装时会提示先执行 `[3] 安装/修复`，不会直接拉起服务 |
| `[2]` / `DSH Manager.bat stop` | **一键停止**：停止占用 3080 端口的 DSH Web 服务器，"DSH Web Server" 窗口自动关闭 |
| `[3]` / `DSH Manager.bat install` | **一键安装/修复**：通过 npx 下载/校验 dsh（不装全局固定版本，始终以最新版为准），复制启动器文件到 `%LOCALAPPDATA%\DeepSeek Harness`，并在桌面创建 "DeepSeek Harness" 快捷方式（官方鲸鱼图标） |
| `[4]` / `DSH Manager.bat uninstall` | **一键卸载**：停止服务器 → 卸载 npm 全局包（若存在）→ 删除桌面快捷方式与安装目录 → 清理 npx 缓存；随后询问是否删除用户数据（**默认保留**，见"卸载说明"） |
| `[5]` | 退出 |

其它特点：

- ✅ 中文交互提示 + 状态显示，双击即用，无需命令行知识
- ✅ 子命令直达：`DSH Manager.bat start|stop|install|uninstall`（附加参数透传，如 `DSH Manager.bat uninstall -Force` 静默卸载）
- ✅ 幂等安装：重复执行安全，自动覆盖旧文件
- ✅ 安装/启动全程有进度提示（进度点 + 已等待时长），慢速下载不再像"卡住"
- ✅ 启动失败即时反馈：下载失败 / 命令报错立即提示，不会空等
- ✅ 卸载保护：清理 npx 缓存时自动跳过「正在被进程使用」的条目，不破坏运行中的 dsh 环境
- ✅ 无需管理员权限：npx 缓存位于用户目录，不安装全局包
- ✅ 卸载不删除用户数据（`DSH_HOME` 中的会话与配置）

## 📋 环境要求

- Windows 10 / 11（自带 PowerShell 5.1 及以上）
- [Node.js LTS](https://nodejs.org/zh-cn/download)（自带 npm）

## 🚀 快速开始

```text
1. 下载本项目（解压 zip 或 git clone）
2. 双击 DSH Manager.bat，选 [3] 安装（npx 下载/校验 dsh + 创建桌面快捷方式）
3. 双击桌面 "DeepSeek Harness" 快捷方式（或 DSH Manager.bat 选 [1]）—— 启动并打开浏览器
4. 需要停止时 DSH Manager.bat 选 [2]；需要卸载时选 [4]
```

> 💡 首次启动会自动下载 dsh 包，视网速可能需要几分钟，请耐心等待（启动器默认最多等待 10 分钟）。

## 📦 文件说明

| 文件 | 作用 |
| --- | --- |
| `DSH Manager.bat` | 统一管理入口（双击打开菜单，或命令行子命令直达） |
| `DSH-Manager.ps1` | 管理工具核心（菜单 + 状态显示 + 分发） |
| `DSH-Launcher.ps1` | 启动器（桌面快捷方式指向它） |
| `install.ps1` / `stop.ps1` / `uninstall.ps1` | 安装 / 停止 / 卸载后端 |
| `README.md` | 本说明文档 |
| `DSH-whale-official.ico` | 桌面快捷方式图标（官方鲸鱼） |

## ⚙️ 工作原理

- **启动命令（自动更新）**：默认使用 `npx -y @deepseek-ai/dsh web`——每次启动都会向 npm registry 检查并**自动更新到最新版**，适合快速迭代的项目。若需要更快、可离线的固定版本，可用 `-PreferGlobal` 改用已全局安装的 `dsh web`（`DSH Manager.bat start -PreferGlobal`），或当 npx 不可用时自动回退全局 dsh。
- **安装方式（同样 npx）**：安装通过 `npx -y @deepseek-ai/dsh --version` 下载并校验 dsh 到 npx 缓存（非阻塞、立即返回），**不安装全局固定版本**——保证安装与启动统一走 npx、始终最新。
- **端口检测**：基于 TCP 连接测试检测 `127.0.0.1:3080`（比系统网络 cmdlet 更可靠，受限环境下依然有效）。
- **等待机制**：服务器在独立控制台窗口（标题 "DSH Web Server"）中运行，服务停止后窗口自动关闭；启动进程提前退出（如 npx 下载失败）时立即报错，无需等待超时。
- **超时设置**：默认等待 600 秒，可自定义：`DSH Manager.bat start -TimeoutS 1800`。
- **进程定位**：停止/卸载通过 `Get-NetTCPConnection` 查找 3080 监听进程，失败时自动回退 `netstat -ano` 解析。
- **安装位置**：`%LOCALAPPDATA%\DeepSeek Harness`

## 🧹 卸载说明

- 推荐方式：`DSH Manager.bat` 选 `[4]`（会询问确认；静默执行可用 `DSH Manager.bat uninstall -Force`）。
- 卸载内容：停止服务器 → 卸载 npm 全局包（仅当存在旧版全局安装时）→ 删除桌面快捷方式 → 删除安装目录 → 清理 npx 缓存。
- **用户数据（可选清理）**：卸载完成前会询问是否同时删除用户数据——包括对话记录（会话历史）、配置文件等，位于 `DSH_HOME`（默认 `%USERPROFILE%\.dsh`）。**默认保留**（直接回车即可）：删除后历史会话与个性化设置不可恢复；保留则重新安装后可继续使用。`uninstall -Force` 静默模式同样默认保留。

## ❓ 常见问题

**Q：双击 DSH Manager.bat 菜单提示未检测到 Node.js？**
A：请先安装 Node.js LTS：<https://nodejs.org/zh-cn/download>，安装后重试。

**Q：启动后浏览器打开但页面无法访问？**
A：检查 3080 端口是否被其它程序占用（`netstat -ano | findstr :3080`），或查看 "DSH Web Server" 窗口中的报错信息。

**Q：首次启动很慢？**
A：首次运行需下载 dsh 包，与网速相关；启动器默认最多等待 600 秒，可调大：`DSH Manager.bat start -TimeoutS 1800`。

**Q：如何保证用的是最新版 dsh？**
A：启动器默认用 `npx -y @deepseek-ai/dsh web`，每次启动都会检查并自动更新到最新版。若你更看重速度/离线可用而接受固定版本，加 `-PreferGlobal` 改用全局安装的 dsh。

**Q：卸载之后想重新使用？**
A：重新 `DSH Manager.bat` 选 `[3]` 安装即可，全程幂等。

## 📄 License

[MIT](LICENSE)

## 🙏 致谢

- [@deepseek-ai/dsh](https://www.npmjs.com/package/@deepseek-ai/dsh) — DeepSeek Harness（本项目的一键管理对象）
