/**
 * ChatViewModel (source: feature/cs/viewmodel/ChatViewModel.kt) — CS-A03..A16.
 *
 * - init(context): wires WebSocket callbacks, creates the sound manager, then createSession().
 * - createSession: POST cs/session/create → connect WebSocket + load history page 1 + mark unread as read;
 *   failure → uiState 'error' (after the 320 ms minimum loading time).
 * - loadHistoryMessages: POST cs/msg/page {sessionId, page, size 10, order createTime, sort desc};
 *   hasMore = pagination.size * pagination.page < total (or list.size >= 10 without pagination);
 *   page 1 replaces, later pages append (dedup by id); load-more failure rolls the page number back.
 * - messages are newest-first (index 0 = newest), rendered bottom-up by the page.
 * - addNewMessage: inserted at index 0 if the id is new, marks it for the entrance animation, plays the
 *   receive sound for agent replies (type == 1) and emits the new-message event (page scrolls to newest).
 * - sendMessage: blank → nothing; not connected → reconnect only; success → send sound + clear input.
 * - dispose(): close the WebSocket (1000) and release the sounds (source onCleared).
 */
import { common } from '@kit.AbilityKit';
import { LoadMoreState } from '../../core/common/LoadMoreState';
import { MIN_LOADING_TIME_MS, NetWorkUiState } from '../../core/common/BaseNetWorkViewModel';
import { CustomerServiceRepository } from '../../core/data/repository/CustomerServiceRepository';
import { AppState } from '../../core/data/AppState';
import { CsMsg, CsSession } from '../../core/model/Cs';
import { MessagePageRequest, ReadMessageRequest } from '../../core/model/Request';
import { NetworkPageData, NetworkPageMeta } from '../../core/model/Response';
import { ResultHandler } from '../../core/network/ResultHandler';
import { LogUtils } from '../../core/util/LogUtils';
import { ChatSoundManager } from './ChatSoundManager';
import { CsMsgMapper } from './CsMsgMapper';
import { WebSocketManager } from './WebSocketManager';
import { WebSocketConnectionState } from './WebSocketConnectionState';

const TAG: string = 'ChatViewModel';
/** New message entrance animation length before its "new" flag is cleared (source delay(500)) */
const NEW_MESSAGE_ANIMATION_MS: number = 500;

@ObservedV2
export class ChatViewModel {
  /** Page UI state (source BaseNetWorkUiState<Unit>) */
  @Trace uiState: NetWorkUiState = 'loading';
  /** Messages, newest first */
  @Trace messages: CsMsg[] = [];
  /** Ids of messages that should play the entrance animation */
  @Trace newMessageIds: number[] = [];
  /** Whether history is loading */
  @Trace isLoadingHistory: boolean = false;
  /** Load-more state of the history item */
  @Trace loadMoreState: LoadMoreState = LoadMoreState.PullToLoad;
  /** Input box text */
  @Trace inputText: string = '';

  /** New message event (source newMessageEvent SharedFlow) — set by the page */
  onNewMessage: (() => void) | null = null;

  private sessionId: number = 0;
  private connectionState: WebSocketConnectionState = WebSocketConnectionState.DISCONNECTED;
  private currentPage: number = 1;
  private readonly pageSize: number = 10;
  private hasMoreData: boolean = true;
  private webSocketManager: WebSocketManager = new WebSocketManager();
  private chatSoundManager: ChatSoundManager | null = null;
  private loadingStartTime: number = 0;
  private disposed: boolean = false;
  private initialized: boolean = false;
  private timers: number[] = [];

  /** Messages oldest first (display order of the bottom-anchored list) */
  @Computed
  get ascendingMessages(): CsMsg[] {
    return this.messages.slice().reverse();
  }

  /** Source init {}: callbacks + sound manager + createSession */
  init(context: common.Context | undefined): void {
    if (this.initialized) {
      return;
    }
    this.initialized = true;
    this.chatSoundManager = new ChatSoundManager(context);
    this.setupWebSocketCallbacks();
    this.createSession();
  }

  private setupWebSocketCallbacks(): void {
    this.webSocketManager.setOnMessageReceived((message: CsMsg) => {
      if (this.disposed) {
        return;
      }
      this.addNewMessage(message);
    });
    this.webSocketManager.setOnConnectionStateChanged((state: WebSocketConnectionState) => {
      this.connectionState = state;
    });
  }

  private createSession(): void {
    this.beginLoading();
    LogUtils.dTag(TAG, '开始创建会话');
    ResultHandler.handleAsync<CsSession>(CustomerServiceRepository.createSession(), {
      onSuccess: (session: CsSession) => {
        if (this.disposed) {
          return;
        }
        this.sessionId = session.id ?? 0;
        LogUtils.dTag(TAG, `会话创建成功: sessionId = ${this.sessionId}`);
        this.connectWebSocket();
        this.loadHistoryMessages(true);
        this.markMessagesAsRead();
      },
      onError: (message: string) => {
        if (this.disposed) {
          return;
        }
        LogUtils.eTag(TAG, `会话创建失败: ${message}`);
        this.afterMinLoading(() => {
          this.uiState = 'error';
        });
        this.connectionState = WebSocketConnectionState.error('创建会话失败');
      }
    });
  }

  /** Load one history page (currentPage) */
  loadHistoryMessages(isInitialLoad: boolean = false): void {
    if (this.isLoadingHistory) {
      return;
    }
    const sessionId: number = this.sessionId;
    if (sessionId <= 0) {
      return;
    }
    LogUtils.dTag(TAG, `开始加载历史消息: sessionId = ${sessionId}, page = ${this.currentPage}`);
    this.isLoadingHistory = true;
    if (this.currentPage > 1) {
      this.loadMoreState = LoadMoreState.Loading;
    }
    const params: MessagePageRequest = new MessagePageRequest();
    params.sessionId = sessionId;
    params.page = this.currentPage;
    params.size = this.pageSize;

    ResultHandler.handleAsync<NetworkPageData<CsMsg>>(CustomerServiceRepository.getMessagePage(params), {
      onSuccess: (data: NetworkPageData<CsMsg>) => {
        if (this.disposed) {
          return;
        }
        const newMessages: CsMsg[] = CsMsgMapper.fromList(data.list);
        const pagination: NetworkPageMeta | null | undefined = data.pagination;
        LogUtils.dTag(TAG, `历史消息加载成功: ${newMessages.length} 条消息`);
        if (pagination !== null && pagination !== undefined) {
          const total: number = pagination.total ?? 0;
          const size: number = pagination.size ?? this.pageSize;
          const pageNum: number = pagination.page ?? this.currentPage;
          this.hasMoreData = size * pageNum < total;
        } else {
          this.hasMoreData = newMessages.length >= this.pageSize;
        }
        if (this.currentPage === 1) {
          this.messages = newMessages;
        } else {
          const existingIds: Set<number> = new Set<number>();
          for (const m of this.messages) {
            existingIds.add(m.id);
          }
          const unique: CsMsg[] = newMessages.filter((m: CsMsg) => !existingIds.has(m.id));
          this.messages = this.messages.concat(unique);
        }
        this.isLoadingHistory = false;
        if (isInitialLoad) {
          this.afterMinLoading(() => {
            this.uiState = 'success';
          });
        }
        this.loadMoreState = this.hasMoreData ? LoadMoreState.PullToLoad : LoadMoreState.NoMore;
      },
      onError: (message: string) => {
        if (this.disposed) {
          return;
        }
        LogUtils.eTag(TAG, `历史消息加载失败: ${message}`);
        this.isLoadingHistory = false;
        if (this.currentPage > 1) {
          this.currentPage--;
          this.loadMoreState = LoadMoreState.Error;
        } else if (isInitialLoad) {
          this.afterMinLoading(() => {
            this.uiState = 'error';
          });
        }
      }
    });
  }

  /** Load the next history page (also the retry of the failed load-more item) */
  loadMoreMessages(): void {
    if (this.loadMoreState === LoadMoreState.Loading || this.loadMoreState === LoadMoreState.NoMore ||
      !this.hasMoreData) {
      return;
    }
    this.currentPage++;
    this.loadHistoryMessages();
  }

  /** Source refreshMessages (not wired to UI in the source either) */
  refreshMessages(): void {
    if (this.isLoadingHistory) {
      return;
    }
    this.currentPage = 1;
    this.hasMoreData = true;
    this.loadHistoryMessages();
  }

  /** Connect with the current user token */
  connectWebSocket(): void {
    const token: string = AppState.instance.auth?.token ?? '';
    this.webSocketManager.connect(token);
  }

  private addNewMessage(message: CsMsg): void {
    const exists: boolean = this.messages.some((m: CsMsg) => m.id === message.id);
    if (exists) {
      return;
    }
    // mark first so the list item is created with its entrance transition
    this.newMessageIds = this.newMessageIds.concat([message.id]);
    this.messages = [message].concat(this.messages);
    this.schedule(() => {
      this.clearMessageAnimation(message.id);
    }, NEW_MESSAGE_ANIMATION_MS);
    if (message.type === 1) {
      this.chatSoundManager?.playMessageReceivedSound();
    }
    if (this.onNewMessage !== null) {
      this.onNewMessage();
    }
  }

  isNewMessage(id: number): boolean {
    return this.newMessageIds.indexOf(id) >= 0;
  }

  updateInputText(text: string): void {
    this.inputText = text;
  }

  clearMessageAnimation(messageId: number): void {
    this.newMessageIds = this.newMessageIds.filter((id: number) => id !== messageId);
  }

  /** Send the current input as a text message */
  async sendMessage(): Promise<void> {
    const content: string = this.inputText;
    const type: string = 'text';
    if (content.trim().length === 0) {
      return;
    }
    const sessionId: number = this.sessionId;
    if (sessionId <= 0) {
      LogUtils.eTag(TAG, '发送消息失败: 无效的会话ID');
      return;
    }
    if (!this.webSocketManager.isConnected()) {
      LogUtils.eTag(TAG, '发送消息失败: WebSocket未连接');
      this.connectWebSocket();
      return;
    }
    const success: boolean = await this.webSocketManager.sendMessage(sessionId, content, type);
    if (this.disposed) {
      return;
    }
    if (success) {
      LogUtils.dTag(TAG, '消息发送成功');
      this.chatSoundManager?.playMessageSentSound();
      this.inputText = '';
    } else {
      this.connectWebSocket();
    }
  }

  /** Mark unread (status == 0) messages as read; failures are only logged */
  async markMessagesAsRead(): Promise<void> {
    const unread: CsMsg[] = this.messages.filter((m: CsMsg) => m.status === 0);
    if (unread.length === 0) {
      return;
    }
    const request: ReadMessageRequest = new ReadMessageRequest();
    request.ids = unread.map((m: CsMsg) => m.id);
    LogUtils.dTag(TAG, `标记消息已读: ${request.ids.join(', ')}`);
    try {
      await CustomerServiceRepository.readMessage(request);
      LogUtils.dTag(TAG, '消息已标记为已读');
    } catch (e) {
      LogUtils.eTag(TAG, '标记消息已读失败', e as Error);
    }
  }

  /** Error view retry → recreate the session */
  retryRequest(): void {
    if (this.uiState === 'error') {
      this.beginLoading();
    }
    this.createSession();
  }

  private beginLoading(): void {
    this.uiState = 'loading';
    this.loadingStartTime = Date.now();
  }

  /** Run `action` once the page has been loading for at least 320 ms */
  private afterMinLoading(action: () => void): void {
    const elapsed: number = Date.now() - this.loadingStartTime;
    const remaining: number = Math.max(MIN_LOADING_TIME_MS - elapsed, 0);
    if (remaining > 0) {
      this.schedule(action, remaining);
    } else {
      action();
    }
  }

  private schedule(action: () => void, delayMs: number): void {
    const id: number = setTimeout(() => {
      this.timers = this.timers.filter((t: number) => t !== id);
      if (!this.disposed) {
        action();
      }
    }, delayMs);
    this.timers.push(id);
  }

  disconnectWebSocket(): void {
    this.webSocketManager.disconnect();
  }

  /** Source onCleared: close the socket and release the sounds */
  dispose(): void {
    if (this.disposed) {
      return;
    }
    this.disposed = true;
    this.onNewMessage = null;
    for (const t of this.timers) {
      clearTimeout(t);
    }
    this.timers = [];
    this.disconnectWebSocket();
    this.chatSoundManager?.release();
    this.chatSoundManager = null;
  }
}
