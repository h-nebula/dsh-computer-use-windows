# DSH Computer Use (Windows)

Native **Windows desktop control** for [DeepSeek Harness](https://github.com/deepseek-ai/DeepSeek-Harness)
text-only agents — screenshot the screen, locate UI elements with vision, then
move / click / drag / scroll / type on the real desktop. No external
dependencies: input and capture are forwarded to Windows' built-in
PowerShell (`user32.dll` + `System.Windows.Forms`).

Pairs naturally with [`dsh-vision-toolkit`](https://github.com/Anionex/dsh-vision-toolkit):
take a `computer_screenshot`, run `vision_glance` / `vision_ground` on it to
find a button or field, then act with `computer_click` / `computer_type`.

> This is the Windows counterpart of the macOS-only
> [`dsh-computer-use`](https://github.com/dsh-external/dsh-computer-use).
> macOS users should use that project; Windows users can use this one.

## Tools

| Tool | Purpose |
|---|---|
| `computer_screenshot` | Capture the full screen (or a `x,y,width,height` region) into the session workspace as PNG. |
| `computer_cursor` | Report the current cursor position. |
| `computer_move` | Move the cursor to `(x, y)`. |
| `computer_click` | Move to `(x, y)` and left-click. |
| `computer_rightclick` | Move to `(x, y)` and right-click. |
| `computer_drag` | Drag from `(fromX, fromY)` to `(toX, toY)`. |
| `computer_scroll` | Scroll the wheel (`delta` in 120-unit notches, negative = down). |
| `computer_type` | Type literal text (SendKeys syntax: `{ENTER}`, `^c`, ...). |
| `computer_key` | Send a key chord, e.g. `{ENTER}`, `{ESC}`, `%{F4}`. |
| `computer_screen` | Report primary screen bounds. |

## Install

```sh
git clone https://github.com/h-nebula/dsh-computer-use-windows
dsh plugin --profile web add "$PWD/dsh-computer-use-windows"
# restart dsh web, then the computer_* tools appear for the current Agent
```

`lib/` is committed, so no build step is required for consumers.

## Usage loop

1. `computer_screenshot` → get `path`.
2. `vision_glance images=["<path>"] query="find the login button"` or
   `vision_ground image="<path>" target="the login button"` → get pixel box.
3. `computer_click x=<x1+..> y=<y1+..>` or `computer_type text="..."`.

## Security notes

- These tools control the **real desktop** of the machine running DSH: they
  move the actual cursor and send real input events. Do not install this
  bundle on a host you do not trust with full UI control.
- Screenshots are written inside the session workspace and may contain
  sensitive on-screen content. Treat them like any workspace file.
- Input goes to whatever window is focused at the time; there is no per-app
  targeting (unlike the macOS `dsh-computer-use`).
- No keylogging or screen capture happens outside explicit tool calls.

## Development

```sh
npm install   # devDependencies only (typescript, @types/node)
npm run build # tsc -> lib/
npm test      # (not yet wired)
```

## License

MIT
