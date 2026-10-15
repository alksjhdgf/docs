/**
 * FeedbackSubmitViewModel (source: feature/feedback/viewmodel/FeedbackSubmitViewModel.kt) — USER-A39~A44.
 *
 * - BaseNetWorkViewModel<DictDataResponse>: POST dict/info/data { types: ["feedbackType"] } (loading /
 *   success / error + retry). The page calls executeRequest() on entry (source init { executeRequest() }).
 * - Form state: selectedFeedbackType, contact, content, selectedImages (picker URIs), uploadedImageUrls,
 *   isSubmitting. isFormValid = type selected && content not blank.
 * - onSubmitButtonClick(): invalid → error toast `请选择反馈类型并填写反馈内容`; submitting → warning toast
 *   `正在提交中...`; otherwise isSubmitting = true and upload + submit:
 *     no images → app/feedback/submit directly (images omitted = null);
 *     images → FileUploadRepository.uploadImages (base/comm/upload credentials → Tencent COS
 *       app/base/<uuid>_image.<ext>) → URLs → submit; upload failure only resets isSubmitting.
 *   Submit success → toast `反馈提交成功，感谢您的反馈` + back with RefreshResult(refresh = true);
 *   finally isSubmitting = false.
 */
import { BaseNetWorkViewModel } from '../../core/common/BaseNetWorkViewModel';
import { CommonRepository } from '../../core/data/repository/CommonRepository';
import { FeedbackRepository } from '../../core/data/repository/FeedbackRepository';
import { FileUploadRepository } from '../../core/data/repository/FileUploadRepository';
import { DictItem } from '../../core/model/Market';
import { DictDataRequest, FeedbackSubmitRequest } from '../../core/model/Request';
import { DictDataResponse, NetworkResponse } from '../../core/model/Response';
import { AppNavigator } from '../../core/navigation/AppNavigator';
import { ResultHandler } from '../../core/network/ResultHandler';
import { LogUtils } from '../../core/util/LogUtils';
import { ToastUtils } from '../../core/util/ToastUtils';
import { FEEDBACK_TYPE_DICT } from './FeedbackListViewModel';

const TAG: string = 'FeedbackSubmitViewModel';

@ObservedV2
export class FeedbackSubmitViewModel extends BaseNetWorkViewModel<DictDataResponse> {
  /** Selected feedback type */
  @Trace selectedFeedbackType: DictItem | null = null;
  /** Contact information */
  @Trace contact: string = '';
  /** Feedback content */
  @Trace content: string = '';
  /** Selected images (picker URIs) */
  @Trace selectedImages: string[] = [];
  /** Uploaded image URLs */
  @Trace uploadedImageUrls: string[] = [];
  /** Submitting */
  @Trace isSubmitting: boolean = false;

  /** dict/info/data feedbackType (source requestApiFlow) */
  protected requestApiFlow(): Promise<NetworkResponse<DictDataResponse>> {
    const request: DictDataRequest = new DictDataRequest();
    request.types = [FEEDBACK_TYPE_DICT];
    return CommonRepository.getDictData(request);
  }

  /** Feedback types of the loaded dictionary (source `it.feedbackType!!`; missing → empty) */
  feedbackTypes(): DictItem[] {
    const d: DictDataResponse | null = this.data;
    const items: DictItem[] | null | undefined = d !== null ? d.feedbackType : null;
    return (items !== null && items !== undefined) ? items : [];
  }

  selectFeedbackType(feedbackType: DictItem): void {
    this.selectedFeedbackType = feedbackType;
  }

  updateContact(contact: string): void {
    this.contact = contact;
  }

  updateContent(content: string): void {
    this.content = content;
  }

  /** Replace the selected images and clear previously uploaded URLs (source updateSelectedImages) */
  updateSelectedImages(images: string[]): void {
    this.selectedImages = images;
    this.uploadedImageUrls = [];
  }

  /** Type selected and content not blank (source isFormValid) */
  isFormValid(): boolean {
    return this.selectedFeedbackType !== null && this.content.trim().length > 0;
  }

  /** Submit button (source onSubmitButtonClick) */
  onSubmitButtonClick(): void {
    if (!this.isFormValid()) {
      ToastUtils.showError($r('app.string.please_select_type_and_fill_content'));
      return;
    }
    if (this.isSubmitting) {
      ToastUtils.showWarning($r('app.string.submitting'));
      LogUtils.wTag(TAG, '正在提交中，请勿重复提交');
      return;
    }
    this.isSubmitting = true;
    this.uploadImagesAndSubmit();
  }

  /** Upload the images (if any), then submit (source uploadImagesAndSubmit) */
  private uploadImagesAndSubmit(): void {
    const imagesToUpload: string[] = this.selectedImages;
    if (imagesToUpload.length === 0) {
      this.submitFeedbackToServer();
      return;
    }
    LogUtils.dTag(TAG, `开始上传 ${imagesToUpload.length} 张图片`);
    FileUploadRepository.uploadImages(imagesToUpload).then((result: NetworkResponse<string[]>) => {
      if (this.disposed) {
        return;
      }
      const urls: string[] | null | undefined = result.data;
      if (ResultHandler.isSuccess(result) && urls !== null && urls !== undefined) {
        this.uploadedImageUrls = urls;
        LogUtils.dTag(TAG, `图片上传成功！上传的图片URL列表: ${urls.join(', ')}`);
        this.submitFeedbackToServer();
      } else {
        this.isSubmitting = false;
        LogUtils.eTag(TAG, `图片上传失败: ${result.message}`);
      }
    }).catch((e: Error) => {
      if (!this.disposed) {
        this.isSubmitting = false;
        LogUtils.eTag(TAG, `图片上传失败: ${e?.message ?? ''}`);
      }
    });
  }

  /** app/feedback/submit (source submitFeedbackToServer) */
  private submitFeedbackToServer(): void {
    const request: FeedbackSubmitRequest = new FeedbackSubmitRequest();
    // contact default "" is omitted (encodeDefaults = false)
    if (this.contact.length > 0) {
      request.contact = this.contact;
    }
    const selected: DictItem | null = this.selectedFeedbackType;
    request.type = (selected !== null) ? (selected.value ?? 0) : 0;
    request.content = this.content;
    // images = uploadedImageUrls.ifEmpty { null } (null is omitted)
    if (this.uploadedImageUrls.length > 0) {
      request.images = this.uploadedImageUrls;
    }
    ResultHandler.handleAsync<boolean>(FeedbackRepository.submitFeedback(request), {
      onSuccess: (success: boolean): void => {
        if (this.disposed) {
          return;
        }
        ToastUtils.showSuccess($r('app.string.feedback_submit_success'));
        // source popBackStackWithResult(RefreshResultKey, RefreshResult(refresh = true))
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
