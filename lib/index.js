/**
 * dsh-computer-use-windows — native Windows desktop control for DeepSeek
 * Harness text-only agents.
 *
 * Tools:
 *   computer_screenshot  — capture the full screen (or a region) to the
 *                          session workspace and return the path + size.
 *   computer_cursor      — report the current cursor position.
 *   computer_move        — move the cursor to (x, y).
 *   computer_click       — move to (x, y) and left-click.
 *   computer_rightclick  — move to (x, y) and right-click.
 *   computer_drag        — drag from (x1,y1) to (x2,y2) with a duration.
 *   computer_scroll      — scroll the wheel (positive up, negative down).
 *   computer_type        — type literal text via SendKeys.
 *   computer_key         — send a special key chord (e.g. "{ENTER}", "^c").
 *   computer_screen      — report the primary screen bounds.
 *
 * Vision loop: pair computer_screenshot with dsh-vision-toolkit's
 * vision_glance / vision_ground to locate UI elements, then act with the
 * computer_* input tools.
 *
 * @module dsh-computer-use-windows
 */
import { execFile } from 'node:child_process';
import { join } from 'node:path';
import { defineTool } from '@deepseek-ai/dsh-tools';
export const name = '@dsh-external/dsh-computer-use-windows';
export const inject = ['tools'];
const PS1 = join(new URL('.', import.meta.url).pathname.slice(1), '..', 'scripts', 'computer-use.ps1');
function renderText(_args, value) {
    return [{ type: 'text', text: typeof value === 'string' ? value : JSON.stringify(value, null, 2) }];
}
function sessionWorkspace(exec) {
    return exec.agent?.session?.header?.cwd ?? process.cwd();
}
/** Run the PowerShell helper with a timeout; resolves with collected output. */
function runPs(args, timeoutMs) {
    return new Promise((resolve) => {
        const ps = process.env.SystemRoot
            ? join(process.env.SystemRoot, 'System32', 'WindowsPowerShell', 'v1.0', 'powershell.exe')
            : 'powershell.exe';
        const argv = [
            '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
            '-File', PS1, ...args,
        ];
        let stdout = '';
        let stderr = '';
        let settled = false;
        const child = execFile(ps, argv, { windowsHide: true, timeout: timeoutMs }, (error, so, se) => {
            if (settled)
                return;
            settled = true;
            stdout = so;
            stderr = se;
            resolve({ ok: error === null, stdout, stderr, ...(error === undefined || error === null ? {} : { error: error.message }) });
        });
        child.stdout?.on('data', (d) => { stdout += d; });
        child.stderr?.on('data', (d) => { stderr += d; });
        setTimeout(() => {
            if (settled)
                return;
            settled = true;
            child.kill();
            resolve({ ok: false, stdout, stderr, error: `timed out after ${timeoutMs}ms` });
        }, timeoutMs);
    });
}
function psOut(res) {
    const lines = res.stdout.trim().split(/\r?\n/).filter(Boolean);
    return {
        ok: res.ok,
        output: lines,
        ...(res.stderr.trim() === '' ? {} : { stderr: res.stderr.trim() }),
        ...(res.error === undefined ? {} : { error: res.error }),
    };
}
/** Loose but valid output schema for every tool: an open object. */
const OUT = {
    type: 'object',
    additionalProperties: true,
    description: 'Structured tool result.',
};
/** Build one tool. `execute` returns `any` to satisfy schema inference. */
function tool(toolName, description, parameters, execute) {
    return defineTool({
        name: toolName,
        description,
        parameters: parameters,
        output: { schema: OUT, render: renderText },
        timeoutMs: 30000,
        async execute(args, exec) {
            return execute(args, exec);
        },
    });
}
/** One shared tools array assembled at plugin apply time. */
export function buildTools() {
    return [
        tool('computer_screenshot', 'Capture the full screen (or a pixel region) to the session workspace and return the saved PNG path plus dimensions. Pair with vision_glance / vision_ground to locate UI elements.', {
            region: { type: 'string', description: 'Optional "x,y,width,height". Omit for the full primary screen.' },
            output: { type: 'string', description: 'Optional output filename. Defaults to a timestamped name.' },
        }, async (args, exec) => {
            const ws = sessionWorkspace(exec);
            const outName = typeof args.output === 'string' && args.output.trim() !== ''
                ? args.output.trim()
                : `computer-shot-${Date.now()}.png`;
            const outFile = join(ws, outName);
            const region = typeof args.region === 'string' ? args.region : '';
            let rArgs = [];
            if (region.trim() !== '') {
                const parts = region.split(',').map((s) => s.trim());
                if (parts.length !== 4 || parts.some((p) => !/^\d+$/.test(p))) {
                    return { ok: false, error: 'region must be "x,y,width,height" with four non-negative integers' };
                }
                const [x, y, w, h] = parts;
                rArgs = ['-X1', x, '-Y1', y, '-X2', w, '-Y2', h];
            }
            const res = await runPs(['-Action', 'screenshot', '-OutFile', outFile, ...rArgs], 30000);
            if (!res.ok)
                return psOut(res);
            const m = /^saved:(.+):(\d+):(\d+)$/m.exec(res.stdout.trim());
            if (!m)
                return { ok: false, error: 'unexpected screenshot output', output: res.stdout.trim().split(/\r?\n/) };
            return { ok: true, path: m[1], width: Number(m[2]), height: Number(m[3]) };
        }),
        tool('computer_cursor', 'Report the current cursor position as x,y.', {}, async () => {
            const res = await runPs(['-Action', 'cursor'], 10000);
            if (!res.ok)
                return psOut(res);
            const m = /^cursor:(\d+):(\d+)$/m.exec(res.stdout.trim());
            if (!m)
                return { ok: false, error: 'unexpected cursor output', output: res.stdout.trim().split(/\r?\n/) };
            return { ok: true, x: Number(m[1]), y: Number(m[2]) };
        }),
        tool('computer_move', 'Move the cursor to absolute screen coordinates (x, y).', { x: { type: 'integer' }, y: { type: 'integer' } }, async (args) => {
            const res = await runPs(['-Action', 'move', '-X1', String(args.x), '-Y1', String(args.y)], 10000);
            if (!res.ok)
                return psOut(res);
            return { ok: true, x: Number(args.x), y: Number(args.y) };
        }),
        tool('computer_click', 'Move the cursor to (x, y) and left-click once. Use coordinates from vision_ground / vision_detect on a computer_screenshot.', { x: { type: 'integer' }, y: { type: 'integer' } }, async (args) => {
            const res = await runPs(['-Action', 'click', '-X1', String(args.x), '-Y1', String(args.y)], 15000);
            if (!res.ok)
                return psOut(res);
            return { ok: true, x: Number(args.x), y: Number(args.y) };
        }),
        tool('computer_rightclick', 'Move the cursor to (x, y) and right-click once.', { x: { type: 'integer' }, y: { type: 'integer' } }, async (args) => {
            const res = await runPs(['-Action', 'rightclick', '-X1', String(args.x), '-Y1', String(args.y)], 15000);
            if (!res.ok)
                return psOut(res);
            return { ok: true, x: Number(args.x), y: Number(args.y) };
        }),
        tool('computer_drag', 'Drag the mouse from (fromX, fromY) to (toX, toY). DurationMs controls speed (default 200).', {
            fromX: { type: 'integer' }, fromY: { type: 'integer' },
            toX: { type: 'integer' }, toY: { type: 'integer' },
            durationMs: { type: 'integer', description: 'Drag duration in ms (default 200).' },
        }, async (args) => {
            const dur = typeof args.durationMs === 'number' ? args.durationMs : 200;
            const res = await runPs(['-Action', 'drag', '-FromX', String(args.fromX), '-FromY', String(args.fromY), '-ToX', String(args.toX), '-ToY', String(args.toY), '-DurationMs', String(dur)], 20000);
            if (!res.ok)
                return psOut(res);
            return { ok: true, fromX: Number(args.fromX), fromY: Number(args.fromY), toX: Number(args.toX), toY: Number(args.toY) };
        }),
        tool('computer_scroll', 'Scroll the mouse wheel. Positive delta scrolls up, negative scrolls down (e.g. 120 = one notch up, -120 = one notch down).', { delta: { type: 'integer', description: 'Wheel delta in multiples of 120.' } }, async (args) => {
            const res = await runPs(['-Action', 'scroll', '-ScrollDelta', String(args.delta)], 10000);
            if (!res.ok)
                return psOut(res);
            return { ok: true, delta: Number(args.delta) };
        }),
        tool('computer_type', 'Type literal text into the focused field via SendKeys. Use {ENTER}, {TAB}, {BACKSPACE} for keys, ^c/^v/^a for shortcuts.', { text: { type: 'string', required: true, description: 'Text or SendKeys sequence to type.' } }, async (args) => {
            const res = await runPs(['-Action', 'type', '-Text', String(args.text)], 15000);
            if (!res.ok)
                return psOut(res);
            return { ok: true, chars: String(args.text).length };
        }),
        tool('computer_key', 'Send a special key or chord to the focused window, e.g. "{ENTER}", "{TAB}", "{ESC}", "^c", "%{F4}".', { key: { type: 'string', required: true, description: 'SendKeys key specification.' } }, async (args) => {
            const res = await runPs(['-Action', 'key', '-Key', String(args.key)], 15000);
            if (!res.ok)
                return psOut(res);
            return { ok: true, key: String(args.key) };
        }),
        tool('computer_screen', 'Report the primary screen bounds as x,y,width,height.', {}, async () => {
            const res = await runPs(['-Action', 'screen'], 10000);
            if (!res.ok)
                return psOut(res);
            const m = /^screen:(-?\d+):(-?\d+):(\d+):(\d+)$/m.exec(res.stdout.trim());
            if (!m)
                return { ok: false, error: 'unexpected screen output', output: res.stdout.trim().split(/\r?\n/) };
            return { ok: true, x: Number(m[1]), y: Number(m[2]), width: Number(m[3]), height: Number(m[4]) };
        }),
    ];
}
/** Plugin apply: register all computer_* tools as global tools. */
export function apply(ctx) {
    const disposers = [];
    for (const def of buildTools()) {
        disposers.push(ctx.tools.register(def));
    }
    return () => {
        for (const dispose of disposers.reverse())
            dispose();
    };
}
//# sourceMappingURL=index.js.map