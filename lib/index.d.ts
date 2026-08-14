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
import { type ToolDefinition } from '@deepseek-ai/dsh-tools';
export declare const name = "@dsh-external/dsh-computer-use-windows";
export declare const inject: string[];
/** One shared tools array assembled at plugin apply time. */
export declare function buildTools(): ToolDefinition[];
/** Plugin apply: register all computer_* tools as global tools. */
export declare function apply(ctx: any): (() => void) | void;
//# sourceMappingURL=index.d.ts.map