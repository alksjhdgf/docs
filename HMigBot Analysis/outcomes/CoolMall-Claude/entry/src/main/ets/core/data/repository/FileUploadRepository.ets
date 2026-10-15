/**
 * FileUploadRepository (source: core/data/repository/FileUploadRepository.kt).
 * Thin wrapper: source flow{ emit(api()) }.flowOn(IO) → Promise of the service call.
 * Results are NetworkResponse envelopes (never rejected); handle with ResultHandler.
 */
import { NetworkResponse } from '../../model/Response';
import { FileUploadService } from '../../network/FileUploadService';

export class FileUploadRepository {
  /** single image upload (DATA-A19); fileUri = picker/sandbox uri (source android Uri) */
  static uploadImage(fileUri: string): Promise<NetworkResponse<string>> {
    return FileUploadService.uploadImage(fileUri);
  }

  /** batch upload, one by one (DATA-A20) */
  static uploadImages(fileUris: string[]): Promise<NetworkResponse<string[]>> {
    return FileUploadService.uploadImages(fileUris);
  }
}
