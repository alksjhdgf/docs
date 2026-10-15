/**
 * WebSocketConnectionState (source: feature/cs/state/WebSocketConnectionState.kt).
 * Kotlin sealed class Disconnected / Connecting / Connected / Error(message) → kind enum + message.
 */
export enum WebSocketConnectionKind {
  Disconnected = 0,
  Connecting = 1,
  Connected = 2,
  Error = 3
}

export class WebSocketConnectionState {
  kind: WebSocketConnectionKind = WebSocketConnectionKind.Disconnected;
  /** Only meaningful for Error */
  message: string = '';

  constructor(kind: WebSocketConnectionKind, message?: string) {
    this.kind = kind;
    this.message = message ?? '';
  }

  static readonly DISCONNECTED: WebSocketConnectionState =
    new WebSocketConnectionState(WebSocketConnectionKind.Disconnected);
  static readonly CONNECTING: WebSocketConnectionState =
    new WebSocketConnectionState(WebSocketConnectionKind.Connecting);
  static readonly CONNECTED: WebSocketConnectionState =
    new WebSocketConnectionState(WebSocketConnectionKind.Connected);

  static error(message: string): WebSocketConnectionState {
    return new WebSocketConnectionState(WebSocketConnectionKind.Error, message);
  }
}
