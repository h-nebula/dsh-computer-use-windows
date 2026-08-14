# DSH Computer Use（Windows）

为 [DeepSeek Harness](https://github.com/deepseek-ai/DeepSeek-Harness) 纯文本 Agent 提供**原生 Windows 桌面控制**能力——截取屏幕、配合视觉工具定位界面元素，然后在真实桌面上移动鼠标、点击、拖拽、滚动、打字。零外部依赖：截图与输入全部转发给 Windows 自带的 PowerShell（`user32.dll` + `System.Windows.Forms`）。

与 [`dsh-vision-toolkit`](https://github.com/Anionex/dsh-vision-toolkit) 天然配合：先用 `computer_screenshot` 截图，再对截图运行 `vision_glance` / `vision_ground` 找到按钮或输入框，最后用 `computer_click` / `computer_type` 执行操作。

> 这是 macOS 专属项目 [`dsh-computer-use`](https://github.com/dsh-external/dsh-computer-use) 的 Windows 对应实现。
> macOS 用户请使用原项目；Windows 用户使用本插件。

## 工具

| 工具 | 用途 |
|---|---|
| `computer_screenshot` | 截取全屏（或指定 `x,y,width,height` 区域）保存到会话工作区，返回 PNG 路径与尺寸 |
| `computer_cursor` | 查询当前光标位置 |
| `computer_move` | 移动光标到 `(x, y)` |
| `computer_click` | 移动到 `(x, y)` 并左键单击 |
| `computer_rightclick` | 移动到 `(x, y)` 并右键单击 |
| `computer_drag` | 从 `(fromX, fromY)` 拖拽到 `(toX, toY)` |
| `computer_scroll` | 滚动鼠标滚轮（`delta` 以 120 为单位，负数向下滚） |
| `computer_type` | 输入文字（短文本/按键序列走 SendKeys；长文本或含换行、特殊字符的内容自动改走剪贴板粘贴 `^v`） |
| `computer_key` | 发送按键组合，例如 `{ENTER}`、`{ESC}`、`%{F4}` |
| `computer_screen` | 查询主屏幕边界（x,y,width,height） |

## 安装

```sh
git clone https://github.com/h-nebula/dsh-computer-use-windows
dsh plugin --profile web add "$PWD/dsh-computer-use-windows"
# 重启 dsh web，当前 Agent 即可获得 computer_* 工具
```

`lib/` 已提交，使用者无需构建。

## 使用循环

1. `computer_screenshot` → 得到截图路径。
2. `vision_glance images=["<路径>"] query="找到登录按钮"` 或 `vision_ground image="<路径>" target="登录按钮"` → 得到像素框。
3. `computer_click x=<框中心x> y=<框中心y>` 或 `computer_type text="..."`。

## 安全须知

- 这些工具操作**运行 DSH 的主机的真实桌面**：会移动真实光标、发送真实输入事件。不要在你不信任其完整 UI 控制权的机器上安装本插件。
- 截图写入会话工作区，可能包含屏幕上的敏感内容，请像对待其他工作区文件一样处理。
- 输入会发送给当前获得焦点的窗口，没有按应用定向的能力（与 macOS 版 `dsh-computer-use` 不同）。
- 除显式工具调用外，不进行任何键盘记录或屏幕捕获。

## 开发

```sh
npm install   # 仅 devDependencies（typescript、@types/node）
npm run build # tsc -> lib/
```

## 许可证

MIT
