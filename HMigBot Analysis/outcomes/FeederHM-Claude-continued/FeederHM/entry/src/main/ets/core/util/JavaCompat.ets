/**
 * JavaCompat.ets —— Java 语义兼容层统一入口（工程内其他单元只 import 本文件）。
 * 实现分布于 JavaCodec（异常/编解码/字符类）、JavaUri（java.net.URI）、JavaUrl（java.net.URL）、
 * JavaHash（hashCode）、JavaTime（ZonedDateTime/Instant）。
 */
export {
  MalformedURLException,
  URISyntaxException,
  IllegalArgumentException,
  DateTimeParseException,
  utf8Encode,
  utf8Decode,
  javaUrlEncode,
  javaUrlDecode,
  isIPv6Literal
} from './JavaCodec';
export { JavaUri, javaUriDecode, javaUriQuote } from './JavaUri';
export { JavaUrl } from './JavaUrl';
export {
  javaStringHashCode,
  javaIntHashCode,
  javaLongHashCode,
  javaBooleanHashCode,
  javaListHashCode,
  kotlinDataClassHashCode,
  javaInstantHashCode,
  javaIntRem
} from './JavaHash';
export {
  JavaZonedDateTime,
  zonedDateTimeToString,
  zoneOffsetToString,
  localOffsetSeconds,
  instantOfEpochMilli,
  instantToEpochMilli,
  instantOfEpochSecond,
  instantEpochSecond,
  instantToString,
  instantParse,
  instantNow,
  instantMinusMinutes
} from './JavaTime';
