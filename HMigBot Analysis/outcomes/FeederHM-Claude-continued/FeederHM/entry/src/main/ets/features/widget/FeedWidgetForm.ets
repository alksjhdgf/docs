/**
 * FeedWidgetForm.ets —— 源 widget/FeedWidget.kt（Glance AppWidget）的 ArkTS 卡片 UI（form_config.json 的 src）。
 *
 * 布局（源 FeedWidget.kt:192-325）：Column(fillMaxHeight, background, padding 4)
 *  - 标题栏 Row：[ic_stat_f + "Feeder"]（点按 → 打开应用主界面）— Spacer — [同步图标] — [设置图标]（NW-A18）
 *  - Syncing（同步进行中 / 初次加载）：居中 "Refreshing"（NW-A21）
 *  - Ready：List（start 12）每项卡片 Row（surfaceVariant 底，padding 8）：可选源图标 + Column[标题 ≤2 行粗体 16；摘要 ≤2 行 12]；
 *    未读 → 主文字色；已读 → 次要文字色且图标置灰（NW-A19）。空列表无空态文案（只有标题栏）。
 * 交互（postCardAction）：
 *  - 标题区 → router EntryAbility（feederWidgetAction=open_app）
 *  - 同步图标 → message {feederWidgetAction: sync} → FeedFormAbility.onFormEvent → 同步后 updateForm（NW-A22）
 *  - 设置图标 → router EntryAbility（feederWidgetAction=settings）→ FeedWidgetSettings 页（NW-A23）
 *  - 条目 → router EntryAbility（feederWidgetAction=open_article, feederWidgetItemId）→ 文章深链（NW-A20）
 *
 * 平台约束：ArkTS 卡片的数据只经 formBindingData → 卡片 LocalStorage 下发，卡片侧只能以 @LocalStorageProp 接收，
 * 故本文件（且仅本文件）使用卡片专用的 @Entry/@Component/@LocalStorageProp（状态管理 V2 无卡片 LocalStorage 绑定）。
 * 卡片运行在卡片渲染进程，不得 import 应用业务模块：数据形状与常量在此自包含（与 FeedFormAbility 中的同名类字段一致）。
 */

/** 与 FeedFormAbility.WidgetCardItem 字段一致（formBindingData JSON 下发） */
class FeedWidgetCardItem {
  itemId: number = 0;
  title: string = '';
  snippet: string = '';
  unread: boolean = true;
  /** `memory://<formImages key>`；空串 = 无图标 */
  icon: string = '';
}

/** 卡片 → 应用 router 事件参数（EntryAbility 侧 NotificationActions.onWant 解析） */
class FeedWidgetRouterParams {
  feederWidgetAction: string = '';
  feederWidgetItemId: number = 0;
}

class FeedWidgetRouterEvent {
  action: string = 'router';
  abilityName: string = 'EntryAbility';
  params: FeedWidgetRouterParams = new FeedWidgetRouterParams();
}

class FeedWidgetMessageParams {
  feederWidgetAction: string = '';
}

class FeedWidgetMessageEvent {
  action: string = 'message';
  params: FeedWidgetMessageParams = new FeedWidgetMessageParams();
}

export const WIDGET_ACTION_OPEN_APP: string = 'open_app';
export const WIDGET_ACTION_OPEN_ARTICLE: string = 'open_article';
export const WIDGET_ACTION_SETTINGS: string = 'settings';
export const WIDGET_ACTION_SYNC: string = 'sync';

const feedWidgetStorage: LocalStorage = new LocalStorage();

@Entry(feedWidgetStorage)
@Component
struct FeedWidgetForm {
  /** 源 WidgetState：起始先 Syncing（NW-A21） */
  @LocalStorageProp('syncing') syncing: boolean = true;
  @LocalStorageProp('items') items: FeedWidgetCardItem[] = [];

  private postRouter(action: string, itemId: number): void {
    const ev: FeedWidgetRouterEvent = new FeedWidgetRouterEvent();
    const p: FeedWidgetRouterParams = new FeedWidgetRouterParams();
    p.feederWidgetAction = action;
    p.feederWidgetItemId = itemId;
    ev.params = p;
    postCardAction(this, ev);
  }

  private postSync(): void {
    const ev: FeedWidgetMessageEvent = new FeedWidgetMessageEvent();
    const p: FeedWidgetMessageParams = new FeedWidgetMessageParams();
    p.feederWidgetAction = WIDGET_ACTION_SYNC;
    ev.params = p;
    postCardAction(this, ev);
  }

  @Builder
  headerBuilder() {
    Row() {
      Row({ space: 4 }) {
        Image($r('app.media.ic_widget_f'))
          .width(24)
          .height(24)
          .objectFit(ImageFit.Contain)
          .fillColor($r('sys.color.font_primary'))
        Text($r('app.string.widget_title'))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
      }
      .padding(4)
      .onClick(() => {
        this.postRouter(WIDGET_ACTION_OPEN_APP, 0);
      })

      Blank()

      Image($r('app.media.ic_stat_sync'))
        .width(24)
        .height(24)
        .margin(8)
        .fillColor($r('sys.color.font_primary'))
        .onClick(() => {
          this.postSync();
        })

      Image($r('app.media.ic_settings'))
        .width(24)
        .height(24)
        .margin(8)
        .fillColor($r('sys.color.font_primary'))
        .onClick(() => {
          this.postRouter(WIDGET_ACTION_SETTINGS, 0);
        })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  itemBuilder(item: FeedWidgetCardItem) {
    Row({ space: 8 }) {
      if (item.icon.length > 0) {
        Image(item.icon)
          .width(40)
          .height(40)
          .objectFit(ImageFit.Contain)
          .grayscale(item.unread ? 0 : 1)
          .opacity(item.unread ? 1 : 0.6)
      }
      Column({ space: 2 }) {
        Text(item.title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor(item.unread ? $r('sys.color.font_primary') : $r('sys.color.font_secondary'))
        Text(item.snippet)
          .fontSize(12)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor(item.unread ? $r('sys.color.font_primary') : $r('sys.color.font_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(8)
    .borderRadius(8)
    .backgroundColor($r('sys.color.comp_background_secondary'))
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.postRouter(WIDGET_ACTION_OPEN_ARTICLE, item.itemId);
    })
  }

  build() {
    Column() {
      this.headerBuilder()
      if (this.syncing) {
        Column() {
          Text($r('app.string.widget_refreshing'))
            .fontSize(14)
            .fontColor($r('sys.color.font_primary'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        List({ space: 4 }) {
          ForEach(this.items, (item: FeedWidgetCardItem) => {
            ListItem() {
              this.itemBuilder(item)
            }
          }, (item: FeedWidgetCardItem) => `${item.itemId}|${item.unread}|${item.icon}|${item.title}|${item.snippet}`)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 12 })
        .edgeEffect(EdgeEffect.None)
      }
    }
    .width('100%')
    .height('100%')
    .padding(4)
    .backgroundColor($r('sys.color.background_primary'))
  }
}
