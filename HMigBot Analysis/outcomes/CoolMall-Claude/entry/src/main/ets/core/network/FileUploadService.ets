/**
 * Image upload to Tencent COS (source: core/network/service/FileUploadService.kt,
 * service/impl/FileUploadServiceImpl.kt, datasource/fileupload/FileUploadNetworkDataSourceImpl.kt)
 *
 * DATA-A19: step 1 `base/comm/upload` (credentials + url, main client with Authorization);
 *           step 2 multipart POST to url with fields key=`app/base/{uuid32}_image.{ext}`, tmpSecretId,
 *           tmpSecretKey, sessionToken, file. Success → data = url + '/' + key, code 1000.
 * DATA-A20: batch uploads go one by one; any failure fails the batch with `批量上传失败: …`.
 *           Upload client: 30s timeouts, NO Authorization header.
 * The picked file (file:// / media URI) is first copied into the app cacheDir, then read and uploaded.
 */
import { http } from '@kit.NetworkKit';
import { fileIo, ReadOptions } from '@kit.CoreFileKit';
import { application } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { NetworkResponse } from '../model/Response';
import { OssUpload } from '../model/Market';
import { LogUtils } from '../util/LogUtils';
import { CommonService } from './service/CommonService';

export class FileUploadService {
  private static readonly TAG: string = 'FileUploadService';
  /** Upload client timeout (source FileUploadQualifier OkHttpClient: 30s) */
  static readonly UPLOAD_TIMEOUT_MS: number = 30000;

  private static resp<T>(data: T | null, code: number, message: string): NetworkResponse<T> {
    const r = new NetworkResponse<T>();
    r.data = data;
    r.code = code;
    r.message = message;
    return r;
  }

  private static errMsg(err: Error): string {
    return (err !== null && err !== undefined && err.message !== undefined) ? err.message : String(err);
  }

  /** Upload credentials (source getUploadCredentials → CommonService.uploadFile) */
  static getUploadCredentials(): Promise<NetworkResponse<OssUpload>> {
    return CommonService.uploadFile();
  }

  /** Upload one image: fetch credentials, then upload (source FileUploadNetworkDataSource.uploadImage) */
  static async uploadImage(fileUri: string): Promise<NetworkResponse<string>> {
    try {
      LogUtils.dTag(FileUploadService.TAG, '开始上传单个图片文件');
      const credentialsResponse = await FileUploadService.getUploadCredentials();
      if (NetworkResponse.succeeded(credentialsResponse) && credentialsResponse.data !== null &&
        credentialsResponse.data !== undefined) {
        const ossUpload: OssUpload = credentialsResponse.data;
        const credentials = ossUpload.credentials;
        const uploadUrl = ossUpload.url;
        if (credentials !== null && credentials !== undefined && uploadUrl !== null && uploadUrl !== undefined) {
          const uploadResult = await FileUploadService.uploadImageToTencent(fileUri, uploadUrl,
            credentials.tmpSecretId ?? '', credentials.tmpSecretKey ?? '', credentials.sessionToken ?? '');
          if (uploadResult.code === 1000 && uploadResult.data !== null && uploadResult.data !== undefined) {
            LogUtils.dTag(FileUploadService.TAG, `单个图片上传成功，URL: ${uploadResult.data}`);
          }
          return uploadResult;
        }
        LogUtils.eTag(FileUploadService.TAG, '上传凭证无效');
        return FileUploadService.resp<string>(null, 400, '上传凭证无效');
      }
      LogUtils.eTag(FileUploadService.TAG, `获取上传凭证失败: ${credentialsResponse.message}`);
      return FileUploadService.resp<string>(null, credentialsResponse.code, credentialsResponse.message ?? '');
    } catch (e) {
      return FileUploadService.resp<string>(null, 500, `上传过程中发生错误: ${FileUploadService.errMsg(e as Error)}`);
    }
  }

  /** Upload several images with one set of credentials (source FileUploadNetworkDataSource.uploadImages) */
  static async uploadImages(fileUris: string[]): Promise<NetworkResponse<string[]>> {
    try {
      LogUtils.dTag(FileUploadService.TAG, `开始批量上传 ${fileUris.length} 个图片文件`);
      const credentialsResponse = await FileUploadService.getUploadCredentials();
      if (NetworkResponse.succeeded(credentialsResponse) && credentialsResponse.data !== null &&
        credentialsResponse.data !== undefined) {
        const ossUpload: OssUpload = credentialsResponse.data;
        const credentials = ossUpload.credentials;
        const uploadUrl = ossUpload.url;
        if (credentials !== null && credentials !== undefined && uploadUrl !== null && uploadUrl !== undefined) {
          const uploadResult = await FileUploadService.uploadImagesToTencent(fileUris, uploadUrl,
            credentials.tmpSecretId ?? '', credentials.tmpSecretKey ?? '', credentials.sessionToken ?? '');
          if (uploadResult.code === 1000 && uploadResult.data !== null && uploadResult.data !== undefined) {
            LogUtils.dTag(FileUploadService.TAG, `批量图片上传成功，URL列表: ${uploadResult.data.join(',')}`);
          }
          return uploadResult;
        }
        LogUtils.eTag(FileUploadService.TAG, '上传凭证无效');
        return FileUploadService.resp<string[]>(null, 400, '上传凭证无效');
      }
      LogUtils.eTag(FileUploadService.TAG, `获取上传凭证失败: ${credentialsResponse.message}`);
      return FileUploadService.resp<string[]>(null, credentialsResponse.code, credentialsResponse.message ?? '');
    } catch (e) {
      return FileUploadService.resp<string[]>(null, 500, `批量上传过程中发生错误: ${FileUploadService.errMsg(e as Error)}`);
    }
  }

  /** Upload a single image to Tencent COS (source uploadImageToTencent) */
  static async uploadImageToTencent(fileUri: string, uploadUrl: string, tmpSecretId: string,
    tmpSecretKey: string, sessionToken: string): Promise<NetworkResponse<string>> {
    const fileName = FileUploadService.generateFileName(fileUri);
    let cachePath = '';
    try {
      const fileBytes = FileUploadService.copyAndRead(fileUri, fileName);
      cachePath = fileBytes.path;
      const bytes: ArrayBuffer | null = fileBytes.data;
      if (bytes === null) {
        return FileUploadService.resp<string>(null, 400, '无法读取文件内容');
      }
      const fileKey = `app/base/${fileName}`;
      const parts: http.MultiFormData[] = [
        FileUploadService.textPart('key', fileKey),
        FileUploadService.textPart('tmpSecretId', tmpSecretId),
        FileUploadService.textPart('tmpSecretKey', tmpSecretKey),
        FileUploadService.textPart('sessionToken', sessionToken),
        FileUploadService.filePart(fileName, FileUploadService.getMimeType(fileUri), bytes)
      ];
      const header: Record<string, string> = {
        'Content-Type': 'multipart/form-data'
      };
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        header: header,
        multiFormDataList: parts,
        connectTimeout: FileUploadService.UPLOAD_TIMEOUT_MS,
        readTimeout: FileUploadService.UPLOAD_TIMEOUT_MS,
        expectDataType: http.HttpDataType.STRING,
        usingCache: false
      };
      const client = http.createHttp();
      let status = 0;
      try {
        const response = await client.request(uploadUrl, options);
        status = response.responseCode as number;
      } finally {
        client.destroy();
      }
      if (status >= 200 && status < 300) {
        const fileUrl = `${uploadUrl}/${fileKey}`;
        LogUtils.dTag(FileUploadService.TAG, `文件上传成功，URL: ${fileUrl}`);
        return FileUploadService.resp<string>(fileUrl, 1000, '上传成功');
      }
      LogUtils.eTag(FileUploadService.TAG, `文件上传失败，响应码: ${status}`);
      return FileUploadService.resp<string>(null, status, `上传失败: HTTP ${status}`);
    } catch (e) {
      LogUtils.eTag(FileUploadService.TAG, '文件上传异常', e as Error);
      return FileUploadService.resp<string>(null, 500, `上传异常: ${FileUploadService.errMsg(e as Error)}`);
    } finally {
      FileUploadService.removeQuietly(cachePath);
    }
  }

  /** Upload images one by one; the first failure fails the batch (source uploadImagesToTencent) */
  static async uploadImagesToTencent(fileUris: string[], uploadUrl: string, tmpSecretId: string,
    tmpSecretKey: string, sessionToken: string): Promise<NetworkResponse<string[]>> {
    try {
      const uploadedUrls: string[] = [];
      for (const uri of fileUris) {
        const single = await FileUploadService.uploadImageToTencent(uri, uploadUrl, tmpSecretId, tmpSecretKey,
          sessionToken);
        if (NetworkResponse.succeeded(single)) {
          if (single.data !== null && single.data !== undefined) {
            uploadedUrls.push(single.data);
          }
        } else {
          LogUtils.eTag(FileUploadService.TAG, `批量上传失败: ${single.message}`);
          return FileUploadService.resp<string[]>(null, single.code, `批量上传失败: ${single.message}`);
        }
      }
      LogUtils.dTag(FileUploadService.TAG, `批量上传成功，共上传 ${uploadedUrls.length} 个文件`);
      return FileUploadService.resp<string[]>(uploadedUrls, 1000, '批量上传成功');
    } catch (e) {
      return FileUploadService.resp<string[]>(null, 500, `批量上传异常: ${FileUploadService.errMsg(e as Error)}`);
    }
  }

  private static filePart(fileName: string, mimeType: string, data: ArrayBuffer): http.MultiFormData {
    const part: http.MultiFormData = {
      name: 'file',
      contentType: mimeType,
      remoteFileName: fileName,
      data: data
    };
    return part;
  }

  private static textPart(name: string, value: string): http.MultiFormData {
    const part: http.MultiFormData = {
      name: name,
      contentType: 'text/plain',
      data: value
    };
    return part;
  }

  /**
   * Copy the source file into cacheDir, then read its bytes. data == null when unreadable.
   * Sync fileIo calls throw BusinessError on missing/unauthorized paths: they are guarded here, a
   * partial cache copy is removed, and the error is rethrown so the caller's existing catch keeps the
   * source "upload error" response semantics.
   */
  private static copyAndRead(fileUri: string, fileName: string): CachedFile {
    const result = new CachedFile();
    const ctx = application.getApplicationContext();
    const dest = `${ctx.cacheDir}/${fileName}`;
    result.path = dest;
    try {
      const src = fileIo.openSync(fileUri, fileIo.OpenMode.READ_ONLY);
      try {
        fileIo.copyFileSync(src.fd, dest);
      } finally {
        fileIo.closeSync(src);
      }
      const size = fileIo.statSync(dest).size;
      if (size <= 0) {
        return result;
      }
      const buffer = new ArrayBuffer(size);
      const file = fileIo.openSync(dest, fileIo.OpenMode.READ_ONLY);
      try {
        let offset = 0;
        while (offset < size) {
          const readOptions: ReadOptions = { offset: offset, length: size - offset };
          const n = fileIo.readSync(file.fd, buffer, readOptions);
          if (n <= 0) {
            break;
          }
          offset += n;
        }
        if (offset < size) {
          return result;
        }
      } finally {
        fileIo.closeSync(file);
      }
      result.data = buffer;
      return result;
    } catch (e) {
      LogUtils.eTag(FileUploadService.TAG, `读取待上传文件失败: ${FileUploadService.errMsg(e as Error)}`);
      FileUploadService.removeQuietly(dest);
      throw e as Error;
    }
  }

  private static removeQuietly(path: string): void {
    if (path.length === 0) {
      return;
    }
    try {
      if (fileIo.accessSync(path)) {
        fileIo.unlinkSync(path);
      }
    } catch (e) {
      LogUtils.wTag(FileUploadService.TAG, `cache cleanup failed: ${path}`);
    }
  }

  /** `{uuid without dashes}_image.{ext}` (source generateFileName) */
  private static generateFileName(uri: string): string {
    const uuid = util.generateRandomUUID(false).split('-').join('');
    return `${uuid}_image.${FileUploadService.getFileExtension(uri)}`;
  }

  /** Extension guessed from the uri string, default jpg (source getFileExtension) */
  private static getFileExtension(uri: string): string {
    const s = uri.toLowerCase();
    if (s.includes('.jpg')) {
      return 'jpg';
    }
    if (s.includes('.jpeg')) {
      return 'jpeg';
    }
    if (s.includes('.png')) {
      return 'png';
    }
    if (s.includes('.webp')) {
      return 'webp';
    }
    return 'jpg';
  }

  /** MIME type from the extension (source: ContentResolver.getType, default image/jpeg) */
  private static getMimeType(uri: string): string {
    const ext = FileUploadService.getFileExtension(uri);
    if (ext === 'png') {
      return 'image/png';
    }
    if (ext === 'webp') {
      return 'image/webp';
    }
    return 'image/jpeg';
  }
}

/** Internal: cached copy path + bytes */
class CachedFile {
  path: string = '';
  data: ArrayBuffer | null = null;
}
