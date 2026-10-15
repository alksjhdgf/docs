/**
 * GoodsRoutesCommentPage — goods comment list (source: feature/goods/view/GoodsCommentScreen.kt
 * GoodsCommentRoute / GoodsCommentScreen / GoodsCommentContentView).
 *
 * Param: GoodsCommentParam(goodsId). A missing / foreign param keeps the page with an empty state.
 *
 * AppScaffold(`商品评论`, back → previous page; the center top bar pads the status bar — GOODS-A22) {
 *   NetWorkStateView: loading → GoodsCommentLoadingSkeleton, empty → EmptyData, error → EmptyNetwork + retry
 *   (GOODS-A19); success → RefreshList (pull to refresh, load more near the bottom, `no more` footer —
 *   GOODS-A20) of CommentCard (GOODS-A21)
 * }
 */
import { BaseNetWorkListViewModel } from '../core/common/BaseNetWorkListViewModel';
import { Comment } from '../core/model/Goods';
import { GoodsCommentParam } from '../core/navigation/RouteParams';
import { AppScaffold } from '../core/ui/base/AppScaffold';
import { RefreshList } from '../core/ui/base/RefreshList';
import { EmptyData, NetWorkStateView } from '../core/ui/base/StateViews';
import { CommentCard } from '../feature/goods/detail/CommentCard';
import { GoodsCommentLoadingSkeleton } from '../feature/goods/detail/GoodsCommentSkeleton';
import { GoodsCommentViewModel } from '../feature/goods/detail/GoodsCommentViewModel';

@Builder
export function GoodsRoutesCommentPageBuilder() {
  GoodsRoutesCommentPage()
}

@ComponentV2
struct GoodsRoutesCommentPage {
  @Local vm: GoodsCommentViewModel = new GoodsCommentViewModel();
  /** Required route param missing → empty state */
  @Local paramMissing: boolean = false;

  private listScroller: Scroller = new Scroller();
  private started: boolean = false;

  aboutToDisappear(): void {
    this.vm.dispose();
  }

  private onParam(p: Object | undefined): void {
    if (this.started) {
      return;
    }
    this.started = true;
    if (p !== undefined && p !== null && p instanceof GoodsCommentParam) {
      this.vm.start((p as GoodsCommentParam).goodsId);
    } else {
      this.paramMissing = true;
    }
  }

  @Builder
  loadingSkeleton() {
    GoodsCommentLoadingSkeleton()
  }

  @Builder
  commentItem(item: Object, index: number) {
    CommentCard({ comment: item as Comment })
  }

  @Builder
  listContent() {
    RefreshList({
      listVm: this.vm as BaseNetWorkListViewModel<Object>,
      listScroller: this.listScroller,
      itemKey: (item: Object, index: number): string => {
        const c: Comment = item as Comment;
        return 'comment_' + index + '_' + c.id + '_' + c.starCount + '_' + (c.pics?.length ?? 0) + '_' +
          (c.content ?? '').length;
      },
      itemBuilder: (item: Object, index: number): void => {
        this.commentItem(item, index)
      }
    })
  }

  @Builder
  pageContent() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.paramMissing) {
        EmptyData()
      } else {
        NetWorkStateView({
          uiState: this.vm.uiState,
          useCustomLoading: true,
          customLoading: (): void => {
            this.loadingSkeleton()
          },
          content: (): void => {
            this.listContent()
          },
          onRetry: () => {
            this.vm.retryRequest();
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  build() {
    NavDestination() {
      AppScaffold({
        titleText: $r('app.string.goods_comment_title'),
        content: (): void => {
          this.pageContent()
        }
      })
    }
    .hideTitleBar(true)
    .onReady((ctx: NavDestinationContext) => {
      this.onParam(ctx.pathInfo.param as Object | undefined);
    })
  }
}
