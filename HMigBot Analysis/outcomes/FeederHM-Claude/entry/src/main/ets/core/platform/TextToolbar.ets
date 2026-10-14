/**
 * TextToolbar.ets —— 源 ui/compose/utils/FeederTextToolbar.kt 的鸿蒙等价物（UT-A40/A41）。
 *
 * 源存在的原因：Compose 默认浮动工具栏不显示 PROCESS_TEXT 第三方处理器（如翻译 App）。
 * 鸿蒙：ArkUI Text/TextInput/RichEditor 的 `.editMenuOptions(new FeederEditMenuOptions(...))`。
 * - 固定项顺序：Copy / Paste / Cut / Select all 中当前可用（系统给出）的项。
 * - 仅当可复制（系统菜单含 COPY）时，追加"处理文本"项：系统自带的翻译/分享/搜索等处理项（保持系统顺序），
 *   以及应用内注册的处理器（registerTextProcessor，按显示名排序）。
 * - 鸿蒙无 PROCESS_TEXT 第三方生态（台账未登记，见降级候选 deg-acc-process-text）：第三方处理器无法枚举；应用内处理器直接拿到选中文本，
 *   不经剪贴板中转，因此剪贴板不会被污染（结果契约成立）。
 */

const LOG_TAG: string = 'FEEDER_TEXTTOOL';

/** 应用内文本处理器菜单项 id 前缀（源 itemId 100+index） */
export const TEXT_PROCESSOR_ID_PREFIX: string = 'feeder_process_text_';

export type TextProcessorHandler = (selectedText: string) => void;

export class TextProcessor {
  key: string = '';
  label: string = '';
  handler: TextProcessorHandler = (selectedText: string): void => {
    console.info(`TODO:processText:${selectedText.length}`);
  };
}

let processors: TextProcessor[] = [];
let processorSeq: number = 0;

/** 注册应用内"处理文本"项；返回反注册函数。 */
export function registerTextProcessor(label: string, handler: TextProcessorHandler): () => void {
  processorSeq++;
  const p = new TextProcessor();
  p.key = `${TEXT_PROCESSOR_ID_PREFIX}${processorSeq}`;
  p.label = label;
  p.handler = handler;
  processors.push(p);
  return (): void => {
    processors = processors.filter((x: TextProcessor): boolean => x.key !== p.key);
  };
}

/** 源 ResolveInfo.DisplayNameComparator：按显示名排序 */
export function sortedTextProcessors(): TextProcessor[] {
  const list = processors.slice();
  list.sort((a: TextProcessor, b: TextProcessor): number => a.label.localeCompare(b.label));
  return list;
}

function isFixedItem(item: TextMenuItem): boolean {
  return item.id.equals(TextMenuItemId.COPY) || item.id.equals(TextMenuItemId.PASTE) ||
    item.id.equals(TextMenuItemId.CUT) || item.id.equals(TextMenuItemId.SELECT_ALL);
}

function findItem(items: TextMenuItem[], id: TextMenuItemId): TextMenuItem | null {
  for (const it of items) {
    if (it.id.equals(id)) {
      return it;
    }
  }
  return null;
}

/**
 * 菜单排序规则（UT-A40）：Copy、Paste、Cut、Select all（存在者）在前；
 * 仅当 Copy 可用时追加处理文本项（系统处理项按系统顺序 + 应用内处理器按名称排序）。
 */
export function orderTextMenuItems(items: TextMenuItem[], extra: TextProcessor[]): TextMenuItem[] {
  const out: TextMenuItem[] = [];
  const fixedOrder: TextMenuItemId[] = [TextMenuItemId.COPY, TextMenuItemId.PASTE, TextMenuItemId.CUT, TextMenuItemId.SELECT_ALL];
  for (const id of fixedOrder) {
    const it = findItem(items, id);
    if (it !== null) {
      out.push(it);
    }
  }
  const canCopy = findItem(items, TextMenuItemId.COPY) !== null;
  if (canCopy) {
    for (const it of items) {
      if (!isFixedItem(it)) {
        out.push(it);
      }
    }
    for (const p of extra) {
      const item: TextMenuItem = {
        content: p.label,
        id: TextMenuItemId.of(p.key),
      };
      out.push(item);
    }
  }
  return out;
}

/** 从全文与选区取选中文本（range 缺省端点按 0 / 全长） */
export function selectedTextOf(fullText: string, range: TextRange): string {
  const start = range.start !== undefined ? Math.max(0, range.start) : 0;
  const end = range.end !== undefined ? Math.min(fullText.length, range.end) : fullText.length;
  if (end <= start) {
    return '';
  }
  return fullText.substring(start, end);
}

/**
 * 用法：`Text(this.body).copyOption(CopyOptions.LocalDevice).editMenuOptions(new FeederEditMenuOptions(() => this.body))`
 * textProvider 返回组件当前显示的纯文本（用于按选区取选中文本）。
 */
export class FeederEditMenuOptions implements EditMenuOptions {
  private textProvider: () => string;

  constructor(textProvider: () => string) {
    this.textProvider = textProvider;
  }

  onCreateMenu(menuItems: Array<TextMenuItem>): Array<TextMenuItem> {
    return orderTextMenuItems(menuItems, sortedTextProcessors());
  }

  /** 返回 true = 已由本应用处理（应用内处理器）；false = 交系统默认处理（复制/粘贴/剪切/全选/系统处理项）。 */
  onMenuItemClick(menuItem: TextMenuItem, range: TextRange): boolean {
    for (const p of processors) {
      if (menuItem.id.equals(TextMenuItemId.of(p.key))) {
        try {
          const text = selectedTextOf(this.textProvider(), range);
          if (text.length > 0) {
            p.handler(text);
          }
        } catch (e) {
          console.error(`${LOG_TAG}: text processor failed: ${JSON.stringify(e)}`);
        }
        return true;
      }
    }
    return false;
  }
}
