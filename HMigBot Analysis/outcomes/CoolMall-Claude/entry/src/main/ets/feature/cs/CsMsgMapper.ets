/**
 * CsMsgMapper — turns a JSON.parse result (plain object, missing fields = undefined; conventions J2) into a
 * real CsMsg with the source defaults (kotlinx default values), so UI code can read every field safely.
 */
import { CsMsg, MessageContent } from '../../core/model/Cs';

export class CsMsgMapper {
  static from(raw: CsMsg | null | undefined): CsMsg {
    const msg: CsMsg = new CsMsg();
    if (raw === null || raw === undefined) {
      return msg;
    }
    msg.id = raw.id ?? 0;
    msg.userId = raw.userId ?? 0;
    msg.sessionId = raw.sessionId ?? 0;
    const content: MessageContent = new MessageContent();
    const rawContent: MessageContent | null | undefined = raw.content;
    if (rawContent !== null && rawContent !== undefined) {
      content.type = rawContent.type ?? '';
      content.data = rawContent.data ?? '';
    }
    msg.content = content;
    msg.type = raw.type ?? 0;
    msg.status = raw.status ?? 0;
    msg.nickName = raw.nickName ?? '';
    msg.avatarUrl = raw.avatarUrl ?? '';
    msg.adminUserName = raw.adminUserName ?? '';
    msg.adminUserHeadImg = raw.adminUserHeadImg ?? '';
    msg.createTime = raw.createTime ?? null;
    msg.updateTime = raw.updateTime ?? null;
    return msg;
  }

  static fromList(list: CsMsg[] | null | undefined): CsMsg[] {
    const result: CsMsg[] = [];
    if (list === null || list === undefined) {
      return result;
    }
    for (const item of list) {
      result.push(CsMsgMapper.from(item));
    }
    return result;
  }
}
