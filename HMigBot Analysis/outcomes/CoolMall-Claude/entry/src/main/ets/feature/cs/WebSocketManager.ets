/**
 * WebSocketManager (source: feature/cs/util/WebSocketManager.kt) — CS-A12 / A13 / A14 / A16.
 *
 * OkHttp WebSocket → @kit.NetworkKit webSocket; the Socket.IO v4 frames are handled by hand as in the source:
 *  - URL wss://mall.dusksnow.top/socket.io/?EIO=4&transport=websocket (hard-coded, not BASE_URL)
 *  - on open: send namespace auth `40/cs,{"isAdmin":false,"token":"<token>"}`
 *  - heartbeat: server `2` → client `3` (no client-side ping, like OkHttp pingInterval 0)
 *  - `40/cs,` or `42/cs,["message","连接成功"]` → Connected
 *  - `42["msg",{..}]` / `42/cs,["msg",{..}]` → CsMsg pushed to onMessageReceived
 *  - send `42/cs,["send",{"sessionId":N,"content":{"type":"<type>","data":"<content>"}}]` (content concatenated
 *    verbatim, no JSON escaping — same as the source)
 *  - failure: retryCount < 3 → retryConnection only waits 1000*n ms and does NOT reconnect (source behavior;
 *    a real reconnect happens when ChatViewModel.sendMessage finds the socket disconnected)
 *  - disconnect(): close(1000, "正常关闭"), state Disconnected.
 */
import { webSocket } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { CsMsg } from '../../core/model/Cs';
import { LogUtils } from '../../core/util/LogUtils';
import { CsMsgMapper } from './CsMsgMapper';
import { WebSocketConnectionKind, WebSocketConnectionState } from './WebSocketConnectionState';

const TAG: string = 'WebSocketManager';
const WS_URL: string = 'wss://mall.dusksnow.top/socket.io/?EIO=4&transport=websocket';
const MSG_PREFIX: string = '42["msg",';
const CS_MSG_PREFIX: string = '42/cs,["msg",';
const CS_MESSAGE_PREFIX: string = '42/cs,["message",';
const CONNECTED_NOTICE: string = '42/cs,["message","连接成功"]';
const NORMAL_CLOSE_CODE: number = 1000;
const NORMAL_CLOSE_REASON: string = '正常关闭';

export type CsMessageCallback = (message: CsMsg) => void;
export type CsConnectionStateCallback = (state: WebSocketConnectionState) => void;

/** Kotlin substringAfter(prefix).substringBeforeLast("]") */
function extractPayload(text: string, prefix: string): string {
  const start: number = text.indexOf(prefix);
  const after: string = start < 0 ? text : text.substring(start + prefix.length);
  const end: number = after.lastIndexOf(']');
  return end < 0 ? after : after.substring(0, end);
}

export class WebSocketManager {
  private connectionState: WebSocketConnectionState = WebSocketConnectionState.DISCONNECTED;
  private ws: webSocket.WebSocket | null = null;
  private retryCount: number = 0;
  private readonly maxRetries: number = 3;
  private retryTimer: number = -1;
  private onMessageReceived: CsMessageCallback | null = null;
  private onConnectionStateChanged: CsConnectionStateCallback | null = null;

  setOnMessageReceived(callback: CsMessageCallback): void {
    this.onMessageReceived = callback;
  }

  setOnConnectionStateChanged(callback: CsConnectionStateCallback): void {
    this.onConnectionStateChanged = callback;
  }

  getConnectionState(): WebSocketConnectionState {
    return this.connectionState;
  }

  /** Open the socket and authenticate on the /cs namespace with the user token. */
  connect(token: string): void {
    if (this.connectionState.kind === WebSocketConnectionKind.Connecting) {
      LogUtils.dTag(TAG, 'WebSocket正在连接中，忽略重复连接请求');
      return;
    }
    this.updateConnectionState(WebSocketConnectionState.CONNECTING);
    LogUtils.dTag(TAG, '开始建立WebSocket连接');
    LogUtils.dTag(TAG, `用户Token: ${token.substring(0, 15)}...`);

    // A previous (failed / closed) socket is released before a new one is created.
    this.releaseSocket(false);

    const socket: webSocket.WebSocket = webSocket.createWebSocket();
    this.ws = socket;

    socket.on('open', (err: BusinessError, value: Object) => {
      if (this.ws !== socket) {
        return;
      }
      if (err) {
        LogUtils.eTag(TAG, `WebSocket open error: ${err.code} ${err.message}`);
        return;
      }
      LogUtils.dTag(TAG, `WebSocket连接成功: ${JSON.stringify(value)}`);
      this.retryCount = 0;
      const authMessage: string = `40/cs,{"isAdmin":false,"token":"${token}"}`;
      LogUtils.dTag(TAG, `发送认证消息: ${authMessage.substring(0, 20)}...`);
      socket.send(authMessage).catch((e: BusinessError) => {
        LogUtils.eTag(TAG, `认证消息发送失败: ${e.message}`);
      });
    });

    socket.on('message', (err: BusinessError, value: string | ArrayBuffer) => {
      if (this.ws !== socket || err) {
        return;
      }
      if (typeof value !== 'string') {
        LogUtils.dTag(TAG, '收到未处理的二进制消息');
        return;
      }
      const text: string = value as string;
      LogUtils.dTag(TAG, `收到WebSocket消息: ${text}...`);
      if (text === '2') {
        LogUtils.dTag(TAG, '收到心跳包');
        socket.send('3').then((ok: boolean) => {
          if (ok) {
            LogUtils.dTag(TAG, '心跳响应发送成功');
          } else {
            LogUtils.eTag(TAG, '心跳响应发送失败');
          }
        }).catch((e: BusinessError) => {
          LogUtils.eTag(TAG, `心跳响应发送失败: ${e.message}`);
        });
      }
      this.handleWebSocketMessage(text);
    });

    socket.on('error', (err: BusinessError) => {
      if (this.ws !== socket) {
        return;
      }
      this.handleFailure(err !== undefined && err !== null && err.message ? err.message : '连接错误');
    });

    socket.on('close', (err: BusinessError, value: webSocket.CloseResult) => {
      if (this.ws !== socket) {
        return;
      }
      LogUtils.dTag(TAG, `WebSocket连接关闭: code=${value?.code}, reason=${value?.reason}`);
      this.updateConnectionState(WebSocketConnectionState.DISCONNECTED);
    });

    socket.connect(WS_URL).then((ok: boolean) => {
      LogUtils.dTag(TAG, `connect requested: ${ok}`);
    }).catch((e: BusinessError) => {
      if (this.ws !== socket) {
        return;
      }
      // Only report once: the 'error' event may already have moved the state out of Connecting.
      if (this.connectionState.kind === WebSocketConnectionKind.Connecting) {
        this.handleFailure(e !== undefined && e !== null && e.message ? e.message : '连接错误');
      }
    });
  }

  /** Source onFailure: Error state + delayed retry bookkeeping (no actual reconnect, as in the source). */
  private handleFailure(message: string): void {
    LogUtils.eTag(TAG, `WebSocket连接失败: ${message}`);
    this.updateConnectionState(WebSocketConnectionState.error(message));
    if (this.retryCount < this.maxRetries) {
      this.retryCount++;
      this.retryConnection();
    }
  }

  /** Source retryConnection: only waits 1000 * retryCount ms; reconnecting needs a new token from outside. */
  private retryConnection(): void {
    LogUtils.dTag(TAG, `WebSocket连接失败，${1000 * this.retryCount}毫秒后尝试重连 (第${this.retryCount})次`);
    if (this.retryTimer >= 0) {
      clearTimeout(this.retryTimer);
    }
    this.retryTimer = setTimeout(() => {
      this.retryTimer = -1;
    }, 1000 * this.retryCount);
  }

  private handleWebSocketMessage(text: string): void {
    try {
      if (text.startsWith('40/cs,')) {
        // 40/cs,{"sid":"..."}
        LogUtils.dTag(TAG, 'WebSocket认证成功');
        this.updateConnectionState(WebSocketConnectionState.CONNECTED);
      } else if (text.startsWith('0{')) {
        LogUtils.dTag(TAG, 'WebSocket握手成功');
      } else if (text === '2') {
        // heartbeat already answered in the message listener
      } else if (text.startsWith(MSG_PREFIX)) {
        const message: CsMsg = CsMsgMapper.from(JSON.parse(extractPayload(text, MSG_PREFIX)) as CsMsg);
        LogUtils.dTag(TAG, `收到消息通知(42): id=${message.id}, type=${message.type}`);
        if (this.onMessageReceived !== null) {
          this.onMessageReceived(message);
        }
      } else if (text.startsWith(CS_MSG_PREFIX)) {
        const message: CsMsg = CsMsgMapper.from(JSON.parse(extractPayload(text, CS_MSG_PREFIX)) as CsMsg);
        LogUtils.dTag(TAG, `收到消息通知(42/cs): id=${message.id}, type=${message.type}`);
        if (this.onMessageReceived !== null) {
          this.onMessageReceived(message);
        }
      } else if (text.includes(CONNECTED_NOTICE)) {
        LogUtils.dTag(TAG, `收到连接成功消息: ${text}`);
        this.updateConnectionState(WebSocketConnectionState.CONNECTED);
      } else if (text.startsWith(CS_MESSAGE_PREFIX)) {
        LogUtils.dTag(TAG, `收到连接状态消息: ${text}`);
      } else {
        LogUtils.dTag(TAG, `收到未处理的消息类型: ${text}`);
      }
    } catch (e) {
      LogUtils.eTag(TAG, '解析WebSocket消息失败', e as Error);
    }
  }

  /**
   * Send a chat message. Resolves false when not connected or when the frame could not be sent
   * (then the state becomes Error("消息发送失败"), as in the source).
   */
  async sendMessage(sessionId: number, content: string, type: string = 'text'): Promise<boolean> {
    if (this.connectionState.kind !== WebSocketConnectionKind.Connected || this.ws === null) {
      LogUtils.eTag(TAG, '发送消息失败: WebSocket未连接');
      return false;
    }
    const frame: string =
      `42/cs,["send",{"sessionId":${sessionId},"content":{"type":"${type}","data":"${content}"}}]`;
    LogUtils.dTag(TAG, `发送消息: ${frame.substring(0, 50)}...`);
    let success: boolean = false;
    try {
      success = await this.ws.send(frame);
    } catch (e) {
      success = false;
    }
    if (!success) {
      LogUtils.eTag(TAG, '消息发送失败');
      this.updateConnectionState(WebSocketConnectionState.error('消息发送失败'));
    } else {
      LogUtils.dTag(TAG, '消息发送成功');
    }
    return success;
  }

  /** Close the socket normally (1000) and mark Disconnected. */
  disconnect(): void {
    LogUtils.dTag(TAG, '断开WebSocket连接');
    this.releaseSocket(true);
    if (this.retryTimer >= 0) {
      clearTimeout(this.retryTimer);
      this.retryTimer = -1;
    }
    this.updateConnectionState(WebSocketConnectionState.DISCONNECTED);
  }

  isConnected(): boolean {
    return this.connectionState.kind === WebSocketConnectionKind.Connected;
  }

  private releaseSocket(normalClose: boolean): void {
    const socket: webSocket.WebSocket | null = this.ws;
    if (socket === null) {
      return;
    }
    this.ws = null;
    const options: webSocket.WebSocketCloseOptions = { code: NORMAL_CLOSE_CODE, reason: NORMAL_CLOSE_REASON };
    socket.close(options).catch((e: BusinessError) => {
      LogUtils.dTag(TAG, `close: ${e.message}${normalClose ? '' : ' (stale socket)'}`);
    }).finally(() => {
      socket.off('open');
      socket.off('message');
      socket.off('error');
      socket.off('close');
    });
  }

  private updateConnectionState(state: WebSocketConnectionState): void {
    this.connectionState = state;
    if (this.onConnectionStateChanged !== null) {
      this.onConnectionStateChanged(state);
    }
  }
}
