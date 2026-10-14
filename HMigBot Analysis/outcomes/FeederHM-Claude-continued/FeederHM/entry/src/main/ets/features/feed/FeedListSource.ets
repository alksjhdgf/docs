/**
 * FeedListSource — Feed 列表的数据侧：
 *  - FeedItemsDataSource：LazyForEach 的 IDataSource（Paging3 LazyPagingItems 的等价物；快照替换 → onDataReloaded，
 *    键含全部影响显示的字段，未变条目不重建）。
 * 卡片翻译（源 TranslatedFeedCards）由翻译单元 features/translation/FeedCardTranslations 实现，FeedViewModel 持有。
 */
import { FeedListItem } from '../../core/model/FeedItem';

/** 条目显示键：id + 全部可变显示字段（规则 A2.6） */
export function feedItemKey(item: FeedListItem): string {
  const img: string = item.image !== null ? item.image.url : '';
  return `${item.id}|${item.unread}|${item.bookmarked}|${item.title}|${item.snippet}|${item.feedTitle}|` +
    `${item.pubDate}|${img}|${item.feedImageUrl}|${item.wordCount}|${item.link}`;
}

export class FeedItemsDataSource implements IDataSource {
  private items: FeedListItem[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): FeedListItem {
    return this.items[index];
  }

  snapshot(): FeedListItem[] {
    return this.items;
  }

  setItems(items: FeedListItem[]): void {
    this.items = items;
    for (const l of this.listeners) {
      l.onDataReloaded();
    }
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const i: number = this.listeners.indexOf(listener);
    if (i >= 0) {
      this.listeners.splice(i, 1);
    }
  }
}
