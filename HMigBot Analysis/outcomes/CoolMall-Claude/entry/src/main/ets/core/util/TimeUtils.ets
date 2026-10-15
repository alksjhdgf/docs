/**
 * TimeUtils (source: core/util/time/TimeUtils.kt) — DATA-A24 / CS-A10.
 * - formatChatTime: today -> HH:mm, otherwise yyyy-MM-dd HH:mm; "H:mm"/"HH:mm" input returned as is;
 *   unparsable input returned unchanged; null/empty -> ''.
 * - shouldShowTimeHeader(current, previous): divider only when the two messages are > 10 minutes apart.
 * - shouldShowTimeHeaderInList(messages, index): list is newest-first (reverse layout); index 0 never shows.
 * Times are interpreted in the device local time zone (SimpleDateFormat(Locale.getDefault()) equivalent).
 */
import { CsMsg } from '../model/Cs';

const SHORT_TIME_REGEX: RegExp = new RegExp('^\\d{1,2}:\\d{2}$');
// Prefix match like SimpleDateFormat.parse (trailing text ignored).
const DATE_TIME_SEC_REGEX: RegExp = new RegExp('^\\s*(\\d+)-(\\d+)-(\\d+)\\s+(\\d+):(\\d+):(\\d+)');
const DATE_TIME_MIN_REGEX: RegExp = new RegExp('^\\s*(\\d+)-(\\d+)-(\\d+)\\s+(\\d+):(\\d+)');
const TEN_MINUTES_MS: number = 10 * 60 * 1000;

function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

function toInt(s: string | undefined): number {
  return s === undefined ? 0 : parseInt(s, 10);
}

export class TimeUtils {
  /** yyyy-MM-dd HH:mm */
  static formatFull(date: Date): string {
    return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())} ` +
      `${pad2(date.getHours())}:${pad2(date.getMinutes())}`;
  }

  /** HH:mm */
  static formatTime(date: Date): string {
    return `${pad2(date.getHours())}:${pad2(date.getMinutes())}`;
  }

  /**
   * Format a chat message time. Input "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm" or "HH:mm".
   */
  static formatChatTime(dateString: string | null | undefined): string {
    if (dateString === null || dateString === undefined || dateString.length === 0) {
      return '';
    }
    try {
      if (SHORT_TIME_REGEX.test(dateString)) {
        return dateString;
      }
      const date: Date | null = TimeUtils.parseTimeString(dateString);
      if (date === null) {
        return dateString;
      }
      return TimeUtils.isToday(date) ? TimeUtils.formatTime(date) : TimeUtils.formatFull(date);
    } catch (e) {
      return dateString;
    }
  }

  /** Same calendar day (year + day-of-year) as now. */
  static isToday(date: Date): boolean {
    const today: Date = new Date();
    return today.getFullYear() === date.getFullYear() &&
      today.getMonth() === date.getMonth() &&
      today.getDate() === date.getDate();
  }

  /**
   * Whether a time divider should be shown between two messages (> 10 minutes apart).
   * current empty -> false; previous empty -> true (first message); unparsable -> true.
   */
  static shouldShowTimeHeader(currentTimeString: string | null | undefined,
    previousTimeString: string | null | undefined): boolean {
    if (currentTimeString === null || currentTimeString === undefined || currentTimeString.length === 0) {
      return false;
    }
    if (previousTimeString === null || previousTimeString === undefined || previousTimeString.length === 0) {
      return true;
    }
    const currentTime: Date | null = TimeUtils.parseTimeString(currentTimeString);
    const previousTime: Date | null = TimeUtils.parseTimeString(previousTimeString);
    if (currentTime === null || previousTime === null) {
      return true;
    }
    return Math.abs(currentTime.getTime() - previousTime.getTime()) > TEN_MINUTES_MS;
  }

  /** Work-card alias: shouldShowTime(prev, cur) — note the (previous, current) argument order. */
  static shouldShowTime(prev: string | null | undefined, cur: string | null | undefined): boolean {
    return TimeUtils.shouldShowTimeHeader(cur, prev);
  }

  /**
   * Parse "HH:mm" (today), "yyyy-MM-dd HH:mm:ss" or "yyyy-MM-dd HH:mm" into a local Date; null on failure.
   */
  static parseTimeString(timeString: string): Date | null {
    try {
      if (SHORT_TIME_REGEX.test(timeString)) {
        const parts: string[] = timeString.split(':');
        const d: Date = new Date();
        d.setHours(toInt(parts[0]), toInt(parts[1]), 0, 0);
        return d;
      }
      let m: RegExpExecArray | null = null;
      if (timeString.includes(':') && timeString.split(':').length === 3) {
        m = DATE_TIME_SEC_REGEX.exec(timeString);
      } else {
        m = DATE_TIME_MIN_REGEX.exec(timeString);
      }
      if (m === null) {
        return null;
      }
      const sec: number = m.length > 6 && m[6] !== undefined ? toInt(m[6]) : 0;
      // Lenient like SimpleDateFormat: out-of-range fields roll over via the Date constructor.
      const date: Date = new Date(toInt(m[1]), toInt(m[2]) - 1, toInt(m[3]), toInt(m[4]), toInt(m[5]), sec, 0);
      return isNaN(date.getTime()) ? null : date;
    } catch (e) {
      return null;
    }
  }

  /**
   * Whether the message at currentIndex should show a time header.
   * messages are newest-first (reverse layout): index 0 is the visually last message and never shows one;
   * otherwise compare with messages[currentIndex - 1].
   */
  static shouldShowTimeHeaderInList(messages: CsMsg[], currentIndex: number): boolean {
    if (messages.length === 0 || currentIndex < 0 || currentIndex >= messages.length) {
      return false;
    }
    const currentTime: string | null | undefined = messages[currentIndex].createTime;
    if (currentTime === null || currentTime === undefined || currentTime.length === 0) {
      return false;
    }
    if (currentIndex === 0) {
      return false;
    }
    const previousTime: string | null | undefined = messages[currentIndex - 1].createTime;
    return TimeUtils.shouldShowTimeHeader(currentTime, previousTime);
  }
}
