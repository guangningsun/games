# 🎮 Games —— 100 款小游戏合集

> 一个 Godot 4 引擎驱动的休闲小游戏仓库，目标 **100 款**。

当前进度：**1 / 100** ✅

## 📜 当前游戏列表

| # | 名称 | 类型 | 引擎 | 状态 | 链接 |
|---|------|------|------|------|------|
| 01 | **Brick Breaker**（弹球砖块） | 经典打砖块 | Godot 4.3 | ✅ 完成 | [brick-breaker/](brick-breaker/) |

## 🎯 设计原则（适用于所有游戏）

- **平台优先**：微信小游戏（iOS / Android）+ 浏览器（HTML5 / Web）
- **包体最小**：Web 导出 < 50 MB（已 gzip 后约 8 MB）
- **零外部依赖**：美术/音效程序生成，不依赖网络
- **架构一致**：基于 `GameManager` 单例 + `HUD` + 关卡 JSON 配置
- **一脚本启动**：`./export.sh + ./deploy.sh` 一键发布

## 🛠 通用技术栈

| 层 | 选型 |
|---|------|
| 引擎 | Godot 4.3 Stable |
| 语言 | GDScript |
| 渲染 | Mobile renderer（Web 兼容） |
| 分辨率 | 720 × 1280（竖屏，微信小游戏标准） |
| 物理 | CharacterBody2D + 2D 碰撞体 |
| 资源 | JSON 关卡配置 + 程序生成像素贴图 |
| 部署 | SSH + scp + PM2 + Nginx 反向代理 |
| HTTPS | 自签名证书（127.0.0.1）或 Let's Encrypt（域名） |

## 🚀 快速开始（开发者）

```bash
# 1. 安装 Godot 4.3（macOS）
brew install --cask godot

# 2. 打开项目
godot --path brick-breaker/

# 3. 在编辑器内按 F5 运行

# 4. 命令行构建 Web 版
cd brick-breaker
./export.sh web

# 5. 本地预览
python3 serve_web.py     # 浏览器打开 http://127.0.0.1:8080
```

## 📦 部署到远程服务器

```bash
# 配置 ssh 公钥到服务器后
cd brick-breaker
DEPLOY_HOST=146.56.231.125 \
DEPLOY_USER=root \
DEPLOY_PORT=36000 \
./deploy.sh
```

部署脚本自动完成：
- 打包 `export/web/` 内容
- SCP 到服务器 `/opt/web/`
- 解压覆盖
- PM2 重启 `brick-breaker` 进程
- gzip 压缩（35 MB → 8 MB）

## 🎯 新游戏接入流程

每个新游戏作为子目录添加到仓库根：

```
games/
├── brick-breaker/      # 第 1 款 ✅
├── snake/               # 第 2 款（待开发）
├── chess/               # 第 3 款（待开发）
└── ...
```

新游戏目录结构：

```
<game-name>/
├── project.godot
├── README.md            # 游戏说明（玩法 + 截图 + 控制）
├── scenes/
├── scripts/
├── resources/levels/   # 关卡 JSON
├── export.sh            # 构建脚本（复制 brick-breaker 的）
└── deploy.sh            # 部署脚本
```

复用 `brick-breaker/export.sh` 和 `deploy.sh` 的设计，参考其实现。

## 📊 项目里程碑

- ✅ **M1** 物理循环（球/挡板/墙）
- ✅ **M2** 砖块系统 + 关卡加载
- ✅ **M3** 玩法完整（GameManager / HUD / 多关卡）
- ✅ **M4** 微信适配（WX Adapter / 导出 / 构建）
- ✅ **M5** 美术 + 音效 + 动效（程序生成）
- ✅ **M6** 道具系统（掉落 / 加分 / 加长挡板）
- ✅ **M7** 计时器 + 版本号 + 关卡翻倍
- 🚧 **M8~** 后续游戏

## 🧰 工具链

| 工具 | 用途 |
|------|------|
| `export.sh` | 构建 Web 版（godot --export-release） |
| `deploy.sh` | 上传到服务器 + PM2 重启 |
| `serve_web.py` | 本地预览（gzip HTTP server） |
| `serve_https.py` | 本地 HTTPS（Godot 4 Web 必须） |
| `setup_server.sh` | 服务器首次配置（apt + nginx） |

## 📝 License

MIT

---

**进度**：1 / 100 🚀

> "做一款游戏不难，做 100 款游戏是工程。"
> —— 给自己