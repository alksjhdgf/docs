/**
 * SyncCrypto —— 源 crypto/AesCbcWithIntegrity.kt（SecretKeys / CipherTextIvMac）的鸿蒙实现（cryptoFramework）。
 *
 * 格式逐位照源（SY-A44..A48，与 Android 端互通）：
 *  - 密钥串：`base64(16 字节 AES 密钥):base64(32 字节 HMAC-SHA256 密钥)`，标准 Base64 无换行（NO_WRAP）。
 *  - 加密：UTF-8 明文；随机 16 字节 IV；AES/CBC/PKCS5Padding（= cryptoFramework PKCS7，16 字节分组下等价）；
 *    MAC = HMAC-SHA256(IV ‖ 密文)；输出 `base64(IV):base64(MAC):base64(密文)`。
 *  - 解密：先恒定时间比较 MAC，不符抛 GeneralSecurityException 且不解密；段数 ≠ 3 抛 IllegalArgumentException。
 * 源 generateKeyFromPassword（PBKDF2）在源工程无调用方，同样提供（cryptoFramework PBKDF2|SHA1，10000 次）。
 */
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { base64DecodeStrict, base64Encode, decodeUtf8, encodeUtf8 } from '../../core/util/TextCodec';

const CIPHER_TRANSFORMATION: string = 'AES128|CBC|PKCS7';
const AES_KEY_ALG: string = 'AES128';
const HMAC_KEY_ALG: string = 'HMAC|SHA256';
const HMAC_MD: string = 'SHA256';
const AES_KEY_LENGTH_BITS: number = 128;
const IV_LENGTH_BYTES: number = 16;
const PBE_ITERATION_COUNT: number = 10000;
const PBE_SALT_LENGTH_BITS: number = AES_KEY_LENGTH_BITS;
const HMAC_KEY_LENGTH_BITS: number = 256;

/** java.security.GeneralSecurityException */
export class GeneralSecurityException extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'GeneralSecurityException';
  }
}

/** java.security.InvalidKeyException（GeneralSecurityException 子类） */
export class InvalidKeyException extends GeneralSecurityException {
  constructor(message: string) {
    super(message);
    this.name = 'InvalidKeyException';
  }
}

/** java.lang.IllegalArgumentException（require 失败 / 密钥段数错误） */
export class SyncIllegalArgumentException extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'IllegalArgumentException';
  }
}

/**
 * android.util.Base64.decode(s, NO_WRAP)：标准字母表；忽略空白；允许缺省 '=' 填充；非法字符抛 IllegalArgumentException。
 */
export function androidBase64Decode(input: string): Uint8Array {
  let s: string = '';
  for (let i = 0; i < input.length; i++) {
    const ch: string = input.charAt(i);
    if (ch !== ' ' && ch !== '\n' && ch !== '\r' && ch !== '\t') {
      s += ch;
    }
  }
  const rem: number = s.length % 4;
  if (rem === 1) {
    throw new SyncIllegalArgumentException('bad base-64');
  }
  if (rem === 2) {
    s += '==';
  } else if (rem === 3) {
    s += '=';
  }
  const out: Uint8Array | null = base64DecodeStrict(s);
  if (out === null) {
    throw new SyncIllegalArgumentException('bad base-64');
  }
  return out;
}

function randomBytes(length: number): Uint8Array {
  const rnd: cryptoFramework.Random = cryptoFramework.createRandom();
  return rnd.generateRandomSync(length).data;
}

function blob(data: Uint8Array): cryptoFramework.DataBlob {
  const b: cryptoFramework.DataBlob = { data: data };
  return b;
}

/** 源 class SecretKeys：保留原始字节（SecretKeySpec.encoded），按需转为 cryptoFramework SymKey */
export class SecretKeys {
  readonly confidentialityKey: Uint8Array;
  readonly integrityKey: Uint8Array;

  constructor(confidentialityKey: Uint8Array, integrityKey: Uint8Array) {
    this.confidentialityKey = new Uint8Array(confidentialityKey);
    this.integrityKey = new Uint8Array(integrityKey);
  }

  /** 源 toString：`base64(aes):base64(hmac)` */
  toString(): string {
    return `${base64Encode(this.confidentialityKey)}:${base64Encode(this.integrityKey)}`;
  }

  equals(other: SecretKeys | null): boolean {
    if (other === null) {
      return false;
    }
    return bytesEqual(this.confidentialityKey, other.confidentialityKey) &&
      bytesEqual(this.integrityKey, other.integrityKey);
  }

  aesKey(): cryptoFramework.SymKey {
    return cryptoFramework.createSymKeyGenerator(AES_KEY_ALG).convertKeySync(blob(this.confidentialityKey));
  }

  hmacKey(): cryptoFramework.SymKey {
    return cryptoFramework.createSymKeyGenerator(HMAC_KEY_ALG).convertKeySync(blob(this.integrityKey));
  }
}

function bytesEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) {
    return false;
  }
  for (let i = 0; i < a.length; i++) {
    if (a[i] !== b[i]) {
      return false;
    }
  }
  return true;
}

/** 源 class CipherTextIvMac */
export class CipherTextIvMac {
  readonly cipherText: Uint8Array;
  readonly iv: Uint8Array;
  readonly mac: Uint8Array;

  constructor(c: Uint8Array, i: Uint8Array, h: Uint8Array) {
    this.cipherText = new Uint8Array(c);
    this.iv = new Uint8Array(i);
    this.mac = new Uint8Array(h);
  }

  /** 源次构造 CipherTextIvMac(base64IvAndCiphertext)：`iv:mac:ciphertext` */
  static parse(base64IvAndCiphertext: string): CipherTextIvMac {
    const civArray: string[] = base64IvAndCiphertext.split(':');
    if (civArray.length !== 3) {
      throw new SyncIllegalArgumentException('Cannot parse iv:mac:ciphertext');
    }
    const iv: Uint8Array = androidBase64Decode(civArray[0]);
    const mac: Uint8Array = androidBase64Decode(civArray[1]);
    const cipherText: Uint8Array = androidBase64Decode(civArray[2]);
    return new CipherTextIvMac(cipherText, iv, mac);
  }

  /** 源 toString：`base64(iv):base64(mac):base64(cipherText)` */
  toString(): string {
    return `${base64Encode(this.iv)}:${base64Encode(this.mac)}:${base64Encode(this.cipherText)}`;
  }

  equals(other: CipherTextIvMac | null): boolean {
    if (other === null) {
      return false;
    }
    return bytesEqual(this.cipherText, other.cipherText) && bytesEqual(this.iv, other.iv) &&
      bytesEqual(this.mac, other.mac);
  }

  static ivCipherConcat(iv: Uint8Array, cipherText: Uint8Array): Uint8Array {
    const combined: Uint8Array = new Uint8Array(iv.length + cipherText.length);
    combined.set(iv, 0);
    combined.set(cipherText, iv.length);
    return combined;
  }
}

/** 源 object AesCbcWithIntegrity */
export class AesCbcWithIntegrity {
  static encodeKey(keys: SecretKeys): string {
    return keys.toString();
  }

  /** SY-A44：段数 ≠ 2 → IllegalArgumentException；长度不符 → InvalidKeyException */
  static decodeKey(keysStr: string): SecretKeys {
    const keysArr: string[] = keysStr.split(':');
    if (keysArr.length !== 2) {
      throw new SyncIllegalArgumentException('Cannot parse aesKey:hmacKey');
    }
    const confidentialityKey: Uint8Array = androidBase64Decode(keysArr[0]);
    if (confidentialityKey.length !== AES_KEY_LENGTH_BITS / 8) {
      throw new InvalidKeyException(`Base64 decoded key is not ${AES_KEY_LENGTH_BITS} bytes`);
    }
    const integrityKey: Uint8Array = androidBase64Decode(keysArr[1]);
    if (integrityKey.length !== HMAC_KEY_LENGTH_BITS / 8) {
      throw new InvalidKeyException(`Base64 decoded key is not ${HMAC_KEY_LENGTH_BITS} bytes`);
    }
    return new SecretKeys(confidentialityKey, integrityKey);
  }

  static isKeyDecodable(keysStr: string): boolean {
    try {
      AesCbcWithIntegrity.decodeKey(keysStr);
      return true;
    } catch (e) {
      return false;
    }
  }

  /** SY-A45：随机 128 位 AES 密钥 + 随机 32 字节 HMAC 密钥 */
  static generateKey(): SecretKeys {
    const confidentialityKey: Uint8Array = randomBytes(AES_KEY_LENGTH_BITS / 8);
    const integrityKey: Uint8Array = randomBytes(HMAC_KEY_LENGTH_BITS / 8);
    return new SecretKeys(confidentialityKey, integrityKey);
  }

  /** 源 generateKeyFromPassword（PBKDF2WithHmacSHA1，10000 次，输出 384 位拆分为 AES+HMAC） */
  static generateKeyFromPassword(password: string, salt: Uint8Array): SecretKeys {
    const spec: cryptoFramework.PBKDF2Spec = {
      algName: 'PBKDF2',
      password: password,
      salt: salt,
      iterations: PBE_ITERATION_COUNT,
      keySize: (AES_KEY_LENGTH_BITS + HMAC_KEY_LENGTH_BITS) / 8
    };
    const kdf: cryptoFramework.Kdf = cryptoFramework.createKdf('PBKDF2|SHA1');
    const keyBytes: Uint8Array = kdf.generateSecretSync(spec).data;
    const confidentialityKeyBytes: Uint8Array = keyBytes.slice(0, AES_KEY_LENGTH_BITS / 8);
    const integrityKeyBytes: Uint8Array =
      keyBytes.slice(AES_KEY_LENGTH_BITS / 8, AES_KEY_LENGTH_BITS / 8 + HMAC_KEY_LENGTH_BITS / 8);
    return new SecretKeys(confidentialityKeyBytes, integrityKeyBytes);
  }

  static generateKeyFromPasswordSalt(password: string, salt: string): SecretKeys {
    return AesCbcWithIntegrity.generateKeyFromPassword(password, androidBase64Decode(salt));
  }

  static generateSalt(): Uint8Array {
    return randomBytes(PBE_SALT_LENGTH_BITS);
  }

  static saltString(salt: Uint8Array): string {
    return base64Encode(salt);
  }

  static generateIv(): Uint8Array {
    return randomBytes(IV_LENGTH_BYTES);
  }

  /** SY-A46 */
  static encryptString(plaintext: string, secretKeys: SecretKeys): string {
    return AesCbcWithIntegrity.encryptBytes(encodeUtf8(plaintext), secretKeys).toString();
  }

  static encryptBytes(plaintext: Uint8Array, secretKeys: SecretKeys): CipherTextIvMac {
    const iv: Uint8Array = AesCbcWithIntegrity.generateIv();
    const cipher: cryptoFramework.Cipher = cryptoFramework.createCipher(CIPHER_TRANSFORMATION);
    const ivSpec: cryptoFramework.IvParamsSpec = { algName: 'IvParamsSpec', iv: blob(iv) };
    cipher.initSync(cryptoFramework.CryptoMode.ENCRYPT_MODE, secretKeys.aesKey(), ivSpec);
    const byteCipherText: Uint8Array = cipher.doFinalSync(blob(plaintext)).data;
    const ivCipherConcat: Uint8Array = CipherTextIvMac.ivCipherConcat(iv, byteCipherText);
    const integrityMac: Uint8Array = AesCbcWithIntegrity.generateMac(ivCipherConcat, secretKeys);
    return new CipherTextIvMac(byteCipherText, iv, integrityMac);
  }

  /** SY-A47 */
  static decryptString(civ: string, secretKeys: SecretKeys): string {
    return decodeUtf8(AesCbcWithIntegrity.decryptBytes(CipherTextIvMac.parse(civ), secretKeys));
  }

  static decryptBytes(civ: CipherTextIvMac, secretKeys: SecretKeys): Uint8Array {
    const ivCipherConcat: Uint8Array = CipherTextIvMac.ivCipherConcat(civ.iv, civ.cipherText);
    const computedMac: Uint8Array = AesCbcWithIntegrity.generateMac(ivCipherConcat, secretKeys);
    if (!AesCbcWithIntegrity.constantTimeEq(computedMac, civ.mac)) {
      throw new GeneralSecurityException('MAC stored in civ does not match computed MAC.');
    }
    const cipher: cryptoFramework.Cipher = cryptoFramework.createCipher(CIPHER_TRANSFORMATION);
    const ivSpec: cryptoFramework.IvParamsSpec = { algName: 'IvParamsSpec', iv: blob(civ.iv) };
    cipher.initSync(cryptoFramework.CryptoMode.DECRYPT_MODE, secretKeys.aesKey(), ivSpec);
    return cipher.doFinalSync(blob(civ.cipherText)).data;
  }

  /** HMAC-SHA256(data) */
  static generateMac(byteCipherText: Uint8Array, secretKeys: SecretKeys): Uint8Array {
    const mac: cryptoFramework.Mac = cryptoFramework.createMac(HMAC_MD);
    mac.initSync(secretKeys.hmacKey());
    mac.updateSync(blob(byteCipherText));
    return mac.doFinalSync().data;
  }

  /** 恒定时间比较（长度不同直接 false） */
  static constantTimeEq(a: Uint8Array, b: Uint8Array): boolean {
    if (a.length !== b.length) {
      return false;
    }
    let result: number = 0;
    for (let i = 0; i < a.length; i++) {
      result = result | (a[i] ^ b[i]);
    }
    return result === 0;
  }
}

/** SyncDaos.setSecretKeyGenerator 注册用：源 AesCbcWithIntegrity.generateKey().toString() */
export function generateSecretKeyString(): string {
  return AesCbcWithIntegrity.generateKey().toString();
}
