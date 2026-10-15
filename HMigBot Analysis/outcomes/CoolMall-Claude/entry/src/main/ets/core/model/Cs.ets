/**
 * Customer service models (source: core/model/entity/CsConn.kt, CsMsg.kt, CsSession.kt)
 *
 * Kotlin nested class CsMsg.MessageContent is flattened to MessageContent.
 */

/** Customer service connection */
export class CsConn {
  id: number = 0;
  userId: number = 0;
  connId: string = '';
  type: number = 0;
  createTime: string | null = null;
  updateTime: string | null = null;
}

/** Message content (CsMsg.MessageContent) */
export class MessageContent {
  /** TEXT / IMAGE / VOICE / VIDEO / FILE / LINK / LOCATION / EMOJI */
  type: string = '';
  data: string = '';
}

/** Customer service message */
export class CsMsg {
  id: number = 0;
  userId: number = 0;
  sessionId: number = 0;
  content: MessageContent = new MessageContent();
  /** 0 feedback (user), 1 reply (admin) */
  type: number = 0;
  /** 0 unread, 1 read */
  status: number = 0;
  nickName: string = '';
  avatarUrl: string = '';
  adminUserName: string = '';
  adminUserHeadImg: string = '';
  createTime: string | null = null;
  updateTime: string | null = null;
}

/** Customer service session */
export class CsSession {
  id: number = 0;
  userId: number = 0;
  lastMsg: CsMsg | null = null;
  adminUnreadCount: number = 0;
  nickName: string = '';
  avatarUrl: string = '';
  createTime: string | null = null;
  updateTime: string | null = null;
}
