# Agent Viewer

一个基于 Web 的看板式管理面板，用于管理多个运行在 tmux 会话中的 Claude Code AI Agent。通过统一的 Web 界面即可完成 Agent 的创建、监控、交互和清理。

<img width="1466" height="725" alt="Screenshot 2026-02-09 at 14 54 21" src="https://github.com/user-attachments/assets/cd31b988-f649-4e92-9844-7a1ece9aa634" />

支持通过 Tailscale 在手机上远程管理你的 Agent

![IMG_7782](https://github.com/user-attachments/assets/c7298d61-dd37-4d0f-8b0a-d9d1f0231782)

## 环境要求

- [Node.js](https://nodejs.org/) (v18+)
- [tmux](https://github.com/tmux/tmux)
- [Claude CLI](https://docs.anthropic.com/en/docs/claude-code)（确保 `claude` 命令在系统 PATH 中可用）

### macOS 安装依赖

```bash
brew install node tmux
npm install -g @anthropic-ai/claude-code
```

## 安装

```bash
git clone <repo-url> && cd agent-viewer
npm install
```

## 使用方法

```bash
npm start
```

在浏览器中打开 http://localhost:4200 即可访问。

### 配置项

| 环境变量 | 默认值       | 说明                                      |
|----------|-------------|-------------------------------------------|
| `PORT`   | `4200`      | 服务端口                                   |
| `HOST`   | `localhost` | 绑定地址（设为 `0.0.0.0` 可开放网络访问）    |

示例：

```bash
HOST=0.0.0.0 PORT=3000 npm start
```

## 通过 Tailscale 远程访问

你可以使用 [Tailscale](https://tailscale.com/) 从手机（或任何设备）远程访问 Agent Viewer。

### 1. 在 Mac 上安装 Tailscale

```bash
brew install tailscale
```

或从 [tailscale.com/download](https://tailscale.com/download) 下载。

### 2. 在手机上安装 Tailscale

从 [App Store](https://apps.apple.com/app/tailscale/id1470499037) 或 [Google Play](https://play.google.com/store/apps/details?id=com.tailscale.ipn) 下载 Tailscale 应用，并使用同一账号登录。

### 3. 启动服务

```bash
npm start
```

服务默认绑定 `0.0.0.0`，因此已可通过所有网络接口（包括 Tailscale）访问。

### 4. 在手机上打开

查找你 Mac 的 Tailscale IP（可在 Tailscale 应用中查看，或通过 `tailscale ip` 命令获取），然后访问：

```
http://<tailscale-ip>:4200
```

如果启用了 [MagicDNS](https://tailscale.com/kb/1081/magicdns)，也可以使用机器名代替 IP：

```
http://<机器名>:4200
```

## 功能特性

- **创建 Agent** — 点击 `[+ SPAWN]` 按钮或按 `N` 键，输入项目路径和提示词。每个 Agent 会在独立的 tmux 会话中运行 `claude`。
- **看板分栏** — Agent 根据状态自动分配到"运行中（Running）"、"空闲（Idle）"和"已完成（Completed）"三个栏目。
- **自动发现** — 已有的运行 Claude 的 tmux 会话会被自动检测并添加到看板中。
- **实时输出** — 点击 `VIEW OUTPUT` 查看完整的终端输出，支持 ANSI 彩色渲染。
- **发送消息** — 在任意卡片的输入框中输入内容，按 `Ctrl+Enter` 即可向 Agent 发送后续消息。
- **文件上传** — 将文件拖拽到卡片上，或点击 `FILE` 按钮向 Agent 发送文件。
- **重新启动** — 已完成的 Agent 可以在同一项目目录下使用新的提示词重新启动。
- **终端连接** — 点击 `ATTACH` 可复制 `tmux attach` 命令，直接在终端中接入 Agent 会话。

## 项目架构

本项目是一个极简的两文件应用，无需构建工具或前端框架：

| 文件 | 说明 |
|------|------|
| `server.js` | Express 后端，负责 Agent 生命周期管理、tmux 集成、状态检测和 SSE 广播 |
| `public/index.html` | 完整前端（HTML/CSS/JS），使用原生 JavaScript，集成在单个文件中 |

### 后端核心模块

- **Agent 注册表**：内存对象 + `.agent-registry.json` 文件持久化，跟踪 Agent 的标签、项目路径、提示词、状态和时间戳，服务重启时自动恢复。
- **状态检测**：每 3 秒轮询 tmux 输出，通过模式匹配 Claude Code 的终端信号判断 Agent 状态（运行中 / 空闲 / 已完成）。
- **Tmux 集成**：通过 `tmux new-session` 创建会话、`tmux capture-pane -e -p` 捕获输出、`tmux send-keys` 发送消息，所有外部命令均设有超时保护（5-15 秒）。
- **自动发现**：扫描所有 tmux 会话，构建进程树检测 Claude 子进程，自动将发现的会话纳入管理。
- **智能标签**：创建时先用启发式方法生成快速标签，随后异步调用 Claude Haiku 生成更智能的标签，通过 SSE 实时更新 UI。

### 前端特性

- 三列看板布局（运行中 / 空闲 / 已完成），SSE 驱动实时更新
- 内置完整的 ANSI→HTML 转换器，支持 16/256/24-bit 色彩
- 支持拖拽排序和文件上传
- 终端风格暗色主题（扫描线效果、等宽字体）

### API 接口

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/agents` | 获取所有 Agent 及其状态 |
| POST | `/api/agents` | 创建新 Agent |
| POST | `/api/agents/:name/send` | 向 Agent 发送消息 / 重新启动 |
| POST | `/api/agents/:name/upload` | 上传文件给 Agent |
| POST | `/api/agents/:name/keys` | 发送原始 tmux 按键 |
| POST | `/api/agents/:name/plan-feedback` | 发送计划反馈 |
| DELETE | `/api/agents/:name` | 终止 Agent 会话 |
| DELETE | `/api/agents/:name/cleanup` | 从注册表中移除 Agent |
| DELETE | `/api/cleanup/completed` | 批量清理已完成的 Agent |
| GET | `/api/agents/:name/output` | 获取 Agent 终端输出 |
| GET | `/api/events` | SSE 实时事件流 |
| GET | `/api/browse` | 目录浏览器 |
| GET | `/api/recent-projects` | 最近使用的项目路径 |

## 注意事项

- 确保 `tmux` 和 `claude` 命令已安装且在系统 PATH 中可用。
- Agent 会话名称格式为 `agent-{标签}`（小写、连字符分隔）。
- 文件上传采用手动 Multipart 解析，无需额外依赖。
- 项目唯一的 npm 依赖为 `express`，无需构建步骤，直接通过 Node.js 运行。
