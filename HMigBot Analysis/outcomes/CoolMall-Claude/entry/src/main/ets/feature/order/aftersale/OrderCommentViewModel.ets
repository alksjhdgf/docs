/**
 * OrderCommentViewModel (source: feature/order/viewmodel/OrderCommentViewModel.kt) — ORDB-A25~A29.
 *
 * - rating (default 5), commentContent, selectedImages (picker URIs), uploadedImageUrls, isSubmitting.
 * - onSubmitButtonClick(): invalid form → error toast `请先填写评价内容和评分`; already submitting → warning
 *   toast `正在提交中...`; otherwise isSubmitting = true and upload-then-submit:
 *   images → FileUploadRepository.uploadImages (credentials + Tencent COS batch upload) → URL list;
 *   upload failure ends the submitting state and submits nothing.
 *   goods/comment/submit(orderId, data = {orderId, goodsId, content, starCount, pics}) → success toast
 *   `评价提交成功` + back with refresh; finally isSubmitting = false.
 *
 * Outbound JSON: the source Json has encodeDefaults = false, so `Comment` fields equal to their defaults
 * (id/userId 0, starCount 5, pics null, …) are not sent. CommentSubmitData mirrors that wire shape.
 */
import { FileUploadRepository } from '../../../core/data/repository/FileUploadRepository';
import { GoodsRepository } from '../../../core/data/repository/GoodsRepository';
import { GoodsCommentSubmitRequest } from '../../../core/model/Request';
import { NetworkResponse } from '../../../core/model/Response';
import { AppNavigator } from '../../../core/navigation/AppNavigator';
import { ResultHandler } from '../../../core/network/ResultHandler';
import { LogUtils } from '../../../core/util/LogUtils';
import { ToastUtils } from '../../../core/util/ToastUtils';

/** Source Comment defaults (kotlinx omits fields equal to these) */
const DEFAULT_ID: number = 0;
const DEFAULT_CONTENT: string = '';
const DEFAULT_STAR_COUNT: number = 5;

/** Wire shape of `Comment` with defaults omitted (encodeDefaults = false) */
class CommentSubmitData {
  orderId?: number;
  goodsId?: number;
  content?: string;
  starCount?: number;
  pics?: string[];
}

/** Wire shape of GoodsCommentSubmitRequest(orderId: Long, data: Comment) — both fields have no default */
class CommentSubmitBody {
  orderId: number = 0;
  data: CommentSubmitData = new CommentSubmitData();
}

@ObservedV2
export class OrderCommentViewModel {
  /** Route params (source navKey.orderId / navKey.goodsId) */
  orderId: number = 0;
  goodsId: number = 0;

  /** Comment content */
  @Trace commentContent: string = '';
  /** Rating (source default 5) */
  @Trace rating: number = 5;
  /** Selected image URIs */
  @Trace selectedImages: string[] = [];
  /** Uploaded image URLs */
  @Trace uploadedImageUrls: string[] = [];
  /** Submitting state */
  @Trace isSubmitting: boolean = false;

  /** Set after dispose(): late callbacks must not touch state */
  private disposed: boolean = false;

  /** Update the comment content (source updateCommentContent) */
  updateCommentContent(content: string): void {
    this.commentContent = content;
  }

  /** Update the rating (source updateRating) */
  updateRating(score: number): void {
    this.rating = score;
  }

  /** rating > 0 && content not blank (source isFormValid) */
  isFormValid(): boolean {
    return this.rating > 0 && this.commentContent.trim().length > 0;
  }

  /** Update the selected images and clear previously uploaded URLs (source updateSelectedImages) */
  updateSelectedImages(images: string[]): void {
    this.selectedImages = images;
    this.uploadedImageUrls = [];
  }

  /** Submit button click (source onSubmitButtonClick) */
  onSubmitButtonClick(): void {
    if (!this.isFormValid()) {
      ToastUtils.showError($r('app.string.please_fill_comment'));
      LogUtils.w(`表单验证失败：评分=${this.rating}, 内容长度=${this.commentContent.length}`);
      return;
    }
    if (this.isSubmitting) {
      ToastUtils.showWarning($r('app.string.submitting'));
      LogUtils.w('正在提交中，请勿重复提交');
      return;
    }
    this.isSubmitting = true;
    this.uploadImagesAndSubmit();
  }

  /** Call from the page's aboutToDisappear */
  dispose(): void {
    this.disposed = true;
  }

  /** Upload images (if any), then submit (source uploadImagesAndSubmit) */
  private uploadImagesAndSubmit(): void {
    const imagesToUpload: string[] = this.selectedImages.slice();
    if (imagesToUpload.length === 0) {
      this.submitCommentToServer();
      return;
    }
    LogUtils.d(`开始上传 ${imagesToUpload.length} 张图片`);
    FileUploadRepository.uploadImages(imagesToUpload)
      .then((result: NetworkResponse<string[]>): void => {
        if (this.disposed) {
          return;
        }
        const urls: string[] | null | undefined = result?.data;
        if (NetworkResponse.succeeded(result) && urls !== null && urls !== undefined) {
          this.uploadedImageUrls = urls;
          LogUtils.d(`图片上传成功！上传的图片URL列表: ${urls.join(',')}`);
          LogUtils.d(`共上传 ${urls.length} 张图片`);
          this.submitCommentToServer();
        } else {
          this.isSubmitting = false;
          LogUtils.e(`图片上传失败: ${result?.message ?? ''}`);
        }
      })
      .catch((e: Object): void => {
        if (!this.disposed) {
          this.isSubmitting = false;
        }
        LogUtils.e(`图片上传失败: ${(e as Error)?.message ?? ''}`);
      });
  }

  /** Build the request body with source default-omission semantics */
  private buildRequest(): CommentSubmitBody {
    const data: CommentSubmitData = new CommentSubmitData();
    if (this.orderId !== DEFAULT_ID) {
      data.orderId = this.orderId;
    }
    if (this.goodsId !== DEFAULT_ID) {
      data.goodsId = this.goodsId;
    }
    if (this.commentContent !== DEFAULT_CONTENT) {
      data.content = this.commentContent;
    }
    if (this.rating !== DEFAULT_STAR_COUNT) {
      data.starCount = this.rating;
    }
    // pics = uploadedImageUrls.ifEmpty { null }; null is the default → omitted
    if (this.uploadedImageUrls.length > 0) {
      data.pics = this.uploadedImageUrls.slice();
    }
    const body: CommentSubmitBody = new CommentSubmitBody();
    body.orderId = this.orderId;
    body.data = data;
    return body;
  }

  /** goods/comment/submit (source submitCommentToServer) */
  private submitCommentToServer(): void {
    const body: CommentSubmitBody = this.buildRequest();
    // Same endpoint/shape as GoodsCommentSubmitRequest; only default-valued Comment fields are left out.
    const request: GoodsCommentSubmitRequest = body as Object as GoodsCommentSubmitRequest;
    ResultHandler.handleAsync<boolean>(GoodsRepository.submitGoodsComment(request), {
      onSuccess: (data: boolean): void => {
        if (this.disposed) {
          return;
        }
        ToastUtils.showSuccess($r('app.string.comment_submit_success'));
        LogUtils.d('评价提交成功');
        AppNavigator.backWithRefresh();
      },
      onFinally: (): void => {
        if (!this.disposed) {
          this.isSubmitting = false;
        }
      }
    });
  }
}
