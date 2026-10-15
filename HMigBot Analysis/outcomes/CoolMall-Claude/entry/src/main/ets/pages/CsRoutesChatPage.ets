/**
 * CsRoutesChatPage — customer service chat (source: feature/cs/view/ChatScreen.kt ChatRoute / ChatScreen /
 * ChatContentView / MessageList / JumpToBottom) — CS-A01..A21.
 *
 * Login wall (CS-A01) is handled by AppNavigator (CS_ROUTES_CHAT is a login-required route).
 * Column(bg_page) {
 *   CenterTopAppBar `客服聊天` (back → AppNavigator.back(), pads the status bar)
 *   NetWorkStateView(loading = ChatLoadingSkeleton, error = shared network error + retry → recreate session) {
 *     Column {
 *       Stack(Bottom) {
 *         List(stackFromEnd) { ChatLoadMore (visual top), messages oldest → newest (visual bottom) }
 *         `回到底部` tag when more than 3 items are scrolled away from the newest one
 *       }
 *       ChatInputArea
 *     }
 *   }
 * }
 * Compose LazyColumn(reverseLayout) over newest-first data → List.stackFromEnd over the same data reversed:
 * newest at the bottom, the load-more item at the top, older pages inserted above without moving the view.
 * Keyboard: KeyboardAvoidMode.RESIZE while the page is shown (Compose imePadding), restored afterwards.
 */
import { curves, KeyboardAvoidMode } from '@kit.ArkUI';
import { LoadMoreState } from '../core/common/LoadMoreState';
import { CsMsg } from '../core/model/Cs';
import { CenterTopAppBar } from '../core/ui/base/TopAppBars';
import { NetWorkStateView } from '../core/ui/base/StateViews';
import { Tag, TagStyle, TagType } from '../core/ui/widget/Tags';
import { Dimens } from '../core/designsystem/Dimens';
import { TimeUtils } from '../core/util/TimeUtils';
import { ChatViewModel } from '../feature/cs/ChatViewModel';
import { ChatLoadMore } from '../feature/cs/ChatLoadMore';
import { ChatLoadingSkeleton } from '../feature/cs/ChatSkeleton';
import { ChatMessageItem } from '../feature/cs/ChatMessageItem';
import { ChatInputArea } from '../feature/cs/ChatInputArea';

/** Delay before scrolling to a newly pushed message (source delay(50)) */
const NEW_MESSAGE_SCROLL_DELAY_MS: number = 50;
/** JumpToBottom shows when firstVisibleItemIndex (reverse layout) > 2 */
const JUMP_TO_BOTTOM_THRESHOLD: number = 2;

@Builder
export function CsRoutesChatPageBuilder() {
  CsRoutesChatPage()
}

@ComponentV2
struct CsRoutesChatPage {
  @Local vm: ChatViewModel = new ChatViewModel();
  /** First / last visible List index (index 0 = load-more item, 1..N = messages oldest → newest) */
  @Local listStart: number = -1;
  @Local listEnd: number = -1;
  @Local jumpToBottomEnabled: boolean = false;
  /** List width for the horizontal slide-in of new messages */
  @Local listWidth: number = 360;
  private scroller: Scroller = new Scroller();
  private prevAvoidMode: KeyboardAvoidMode | null = null;
  private alive: boolean = true;
  private scrollTimer: number = -1;

  aboutToAppear(): void {
    this.alive = true;
    this.vm.onNewMessage = () => {
      this.onNewMessageEvent();
    };
    this.vm.init(this.getUIContext().getHostContext());
  }

  aboutToDisappear(): void {
    this.alive = false;
    if (this.scrollTimer >= 0) {
      clearTimeout(this.scrollTimer);
      this.scrollTimer = -1;
    }
    this.restoreKeyboardAvoidMode();
    this.vm.dispose();
  }

  private applyKeyboardAvoidMode(): void {
    try {
      if (this.prevAvoidMode === null) {
        this.prevAvoidMode = this.getUIContext().getKeyboardAvoidMode();
      }
      this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    } catch (e) {
      console.info('TODO:setKeyboardAvoidMode:CsRoutesChatPage');
    }
  }

  private restoreKeyboardAvoidMode(): void {
    if (this.prevAvoidMode === null) {
      return;
    }
    try {
      this.getUIContext().setKeyboardAvoidMode(this.prevAvoidMode);
    } catch (e) {
      console.info('TODO:restoreKeyboardAvoidMode:CsRoutesChatPage');
    }
    this.prevAvoidMode = null;
  }

  /** Source newMessageEvent collector: after 50 ms animate to the newest message */
  private onNewMessageEvent(): void {
    if (this.scrollTimer >= 0) {
      clearTimeout(this.scrollTimer);
    }
    this.scrollTimer = setTimeout(() => {
      this.scrollTimer = -1;
      if (this.alive) {
        this.scrollToNewest();
      }
    }, NEW_MESSAGE_SCROLL_DELAY_MS);
  }

  private scrollToNewest(): void {
    this.scroller.scrollToIndex(this.vm.messages.length, true, ScrollAlign.END);
  }

  /** Auto load-more: the load-more item (index 0) is visible and the state is PullToLoad */
  private maybeLoadMore(): void {
    if (this.listStart === 0 && this.vm.messages.length > 0 &&
      this.vm.loadMoreState === LoadMoreState.PullToLoad) {
      this.vm.loadMoreMessages();
    }
  }

  @Monitor('vm.loadMoreState')
  onLoadMoreStateChanged(): void {
    this.maybeLoadMore();
  }

  private onListScrollIndex(start: number, end: number): void {
    this.listStart = start;
    this.listEnd = end;
    const total: number = this.vm.messages.length;
    // reverse-layout firstVisibleItemIndex = number of items between the bottom edge and the newest message
    this.jumpToBottomEnabled = end >= 0 && (total - end) > JUMP_TO_BOTTOM_THRESHOLD;
    this.maybeLoadMore();
  }

  /** Index in the ascending (display) list → index in the newest-first list */
  private showHeaderAt(ascIndex: number): boolean {
    const messages: CsMsg[] = this.vm.messages;
    return TimeUtils.shouldShowTimeHeaderInList(messages, messages.length - 1 - ascIndex);
  }

  private messageKey(msg: CsMsg, ascIndex: number): string {
    return msg.id + '_' + (this.showHeaderAt(ascIndex) ? 'h' : 'n');
  }

  /** Entrance animation of a pushed message: user from the right, agent from the left, + fade in */
  private enterEffect(msg: CsMsg): TransitionEffect {
    if (!this.vm.isNewMessage(msg.id)) {
      return TransitionEffect.IDENTITY;
    }
    const offsetX: number = msg.type === 0 ? this.listWidth : -this.listWidth;
    const appear: TransitionEffect = TransitionEffect.translate({ x: offsetX })
      .animation({ duration: 400, curve: Curve.FastOutSlowIn })
      .combine(TransitionEffect.OPACITY.animation({ duration: 300, delay: 100, curve: Curve.FastOutSlowIn }));
    return TransitionEffect.asymmetric(appear, TransitionEffect.IDENTITY);
  }

  @Builder
  skeleton() {
    ChatLoadingSkeleton()
  }

  @Builder
  messageList() {
    Stack({ alignContent: Alignment.Bottom }) { // JumpToBottom: align(Alignment.BottomCenter)
      List({ scroller: this.scroller }) {
        // load-more item: last item in reverse layout = visual top
        ListItem() {
          ChatLoadMore({
            loadState: this.vm.loadMoreState,
            onRetry: () => {
              this.vm.loadMoreMessages();
            }
          })
        }

        ForEach(this.vm.ascendingMessages, (msg: CsMsg, index: number) => {
          ListItem() {
            ChatMessageItem({
              msg: msg,
              isUserMe: msg.type === 0, // 0 user feedback, 1 agent reply
              showTimeHeader: this.showHeaderAt(index)
            })
          }
          .transition(this.enterEffect(msg))
        }, (msg: CsMsg, index: number) => this.messageKey(msg, index))
      }
      .width('100%')
      .height('100%')
      .stackFromEnd(true)
      .contentStartOffset(Dimens.spacePaddingSmall) // contentPadding vertical = SpacePaddingSmall
      .contentEndOffset(Dimens.spacePaddingSmall)
      .scrollBar(BarState.Off)
      .onScrollIndex((start: number, end: number) => {
        this.onListScrollIndex(start, end);
      })
      .onAreaChange((oldArea: Area, newArea: Area) => {
        const w: number = Number(newArea.width);
        if (w > 0 && w !== this.listWidth) {
          this.listWidth = w;
        }
      })

      if (this.jumpToBottomEnabled) {
        Row() {
          Tag({
            tagText: $r('app.string.back_to_bottom'),
            tagType: TagType.PRIMARY,
            tagStyle: TagStyle.LIGHT,
            tagRadius: Dimens.radiusExtraLarge // ShapeExtraLarge
          })
        }
        .margin({ bottom: Dimens.spacePaddingSmall })
        .borderRadius(Dimens.radiusExtraLarge)
        .clip(true)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          this.scrollToNewest();
        })
        .transition(TransitionEffect.asymmetric(
          TransitionEffect.OPACITY.animation({ duration: 300 })
            .combine(TransitionEffect.scale({ x: 0.8, y: 0.8 })
              .animation({ curve: curves.springMotion(0.44, 0.5) })),
          TransitionEffect.OPACITY.animation({ duration: 200 })
            .combine(TransitionEffect.scale({ x: 0.8, y: 0.8 }).animation({ duration: 200 }))
        ))
      }
    }
    .width('100%')
    .layoutWeight(1)
  }

  /** Source ChatContentView: message list (weight 1) + input area, lifted by the keyboard */
  @Builder
  successContent() {
    Column() {
      this.messageList()
      ChatInputArea({
        inputText: this.vm.inputText,
        onInputTextChange: (text: string) => {
          this.vm.updateInputText(text);
        },
        onSendMessage: () => {
          this.vm.sendMessage();
        }
      })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    NavDestination() {
      Column() {
        CenterTopAppBar({ titleText: $r('app.string.customer_service_chat') })
        Column() {
          NetWorkStateView({
            uiState: this.vm.uiState,
            useCustomLoading: true,
            onRetry: () => {
              this.vm.retryRequest();
            },
            customLoading: (): void => {
              this.skeleton()
            },
            content: (): void => {
              this.successContent()
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.bg_page'))
      .alignItems(HorizontalAlign.Start)
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.bg_page'))
    .onShown(() => {
      this.applyKeyboardAvoidMode();
    })
    .onHidden(() => {
      this.restoreKeyboardAvoidMode();
    })
  }
}
