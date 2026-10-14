/**
 * Either.ets —— 源 util/Either.kt（Arrow 风格 Either）移植。
 * Left = 失败 / Right = 成功；map/flatMap 只作用于 Right，Left 原样透传。
 * Kotlin 扩展函数（flatMap/getOrElse/flatten/merge/combine/compareTo）改为方法或静态函数；
 * widen/leftWiden 在 TS 结构化泛型下无意义，未移植。
 * 额外：catchingAsync —— 源 catching 为 inline，可在 suspend 上下文内包裹挂起调用；ArkTS 以 Promise 版等价。
 */

export abstract class Either<A, B> {
  abstract isLeft(): boolean;

  isRight(): boolean {
    return !this.isLeft();
  }

  /** Kotlin isLeft(predicate) */
  isLeftAnd(predicate: (left: A) => boolean): boolean {
    const l = this.asLeft();
    return l !== null && predicate(l.value);
  }

  /** Kotlin isRight(predicate) */
  isRightAnd(predicate: (right: B) => boolean): boolean {
    const r = this.asRight();
    return r !== null && predicate(r.value);
  }

  /** 窄化为 Left（不是则 null） */
  asLeft(): Left<A, B> | null {
    return this instanceof Left ? this as Left<A, B> : null;
  }

  /** 窄化为 Right（不是则 null） */
  asRight(): Right<A, B> | null {
    return this instanceof Right ? this as Right<A, B> : null;
  }

  fold<C>(ifLeft: (left: A) => C, ifRight: (right: B) => C): C {
    const r = this.asRight();
    if (r !== null) {
      return ifRight(r.value);
    }
    return ifLeft((this as Either<A, B> as Left<A, B>).value);
  }

  swap(): Either<B, A> {
    const r = this.asRight();
    if (r !== null) {
      return new Left<B, A>(r.value);
    }
    return new Right<B, A>((this as Either<A, B> as Left<A, B>).value);
  }

  map<C>(f: (right: B) => C): Either<A, C> {
    const r = this.asRight();
    if (r !== null) {
      return new Right<A, C>(f(r.value));
    }
    return new Left<A, C>((this as Either<A, B> as Left<A, B>).value);
  }

  mapLeft<C>(f: (left: A) => C): Either<C, B> {
    const l = this.asLeft();
    if (l !== null) {
      return new Left<C, B>(f(l.value));
    }
    return new Right<C, B>((this as Either<A, B> as Right<A, B>).value);
  }

  flatMap<C>(f: (right: B) => Either<A, C>): Either<A, C> {
    const r = this.asRight();
    if (r !== null) {
      return f(r.value);
    }
    return new Left<A, C>((this as Either<A, B> as Left<A, B>).value);
  }

  onRight(action: (right: B) => void): Either<A, B> {
    const r = this.asRight();
    if (r !== null) {
      action(r.value);
    }
    return this;
  }

  onLeft(action: (left: A) => void): Either<A, B> {
    const l = this.asLeft();
    if (l !== null) {
      action(l.value);
    }
    return this;
  }

  getOrNull(): B | null {
    const r = this.asRight();
    return r !== null ? r.value : null;
  }

  leftOrNull(): A | null {
    const l = this.asLeft();
    return l !== null ? l.value : null;
  }

  getOrElse(defaultFn: (left: A) => B): B {
    const r = this.asRight();
    if (r !== null) {
      return r.value;
    }
    return defaultFn((this as Either<A, B> as Left<A, B>).value);
  }

  /**
   * 两个 Right 用 combineRight 合并、两个 Left 用 combineLeft 合并；否则 this 为 Left 返回 this，this 为 Right 返回 other(Left)。
   */
  combine(other: Either<A, B>, combineLeft: (a1: A, a2: A) => A, combineRight: (b1: B, b2: B) => B): Either<A, B> {
    const l1 = this.asLeft();
    if (l1 !== null) {
      const l2 = other.asLeft();
      if (l2 !== null) {
        return new Left<A, B>(combineLeft(l1.value, l2.value));
      }
      return this;
    }
    const r1 = this as Either<A, B> as Right<A, B>;
    const r2 = other.asRight();
    if (r2 !== null) {
      return new Right<A, B>(combineRight(r1.value, r2.value));
    }
    return other;
  }

  static left<A, B>(value: A): Either<A, B> {
    return new Left<A, B>(value);
  }

  static right<A, B>(value: B): Either<A, B> {
    return new Right<A, B>(value);
  }

  /** 捕获 block 抛出的任何错误 → Left(onCatch(t))；成功 → Right(block())。 */
  static catching<E, R>(onCatch: (t: Error) => E, block: () => R): Either<E, R> {
    try {
      return new Right<E, R>(block());
    } catch (t) {
      const err = t as Error;
      console.debug('FEEDER_EITHER', 'Catching caught exception', err.message);
      return new Left<E, R>(onCatch(err));
    }
  }

  /** catching 的异步版本（block 返回 Promise；其拒绝同样转为 Left）。 */
  static async catchingAsync<E, R>(onCatch: (t: Error) => E, block: () => Promise<R>): Promise<Either<E, R>> {
    try {
      const v: R = await block();
      return new Right<E, R>(v);
    } catch (t) {
      const err = t as Error;
      console.debug('FEEDER_EITHER', 'Catching caught exception', err.message);
      return new Left<E, R>(onCatch(err));
    }
  }

  /** Kotlin Either<A, Either<A, B>>.flatten() */
  static flatten<A, B>(e: Either<A, Either<A, B>>): Either<A, B> {
    return e.flatMap<B>((inner: Either<A, B>): Either<A, B> => inner);
  }

  /** Kotlin Either<A, A>.merge() */
  static merge<A>(e: Either<A, A>): A {
    return e.fold<A>((a: A): A => a, (b: A): A => b);
  }

  /**
   * Kotlin compareTo：Left < Right；同侧用给定比较器。
   */
  static compare<A, B>(one: Either<A, B>, other: Either<A, B>, compareLeft: (a1: A, a2: A) => number,
    compareRight: (b1: B, b2: B) => number): number {
    const l1 = one.asLeft();
    if (l1 !== null) {
      const l2 = other.asLeft();
      return l2 !== null ? compareLeft(l1.value, l2.value) : -1;
    }
    const r1 = one as Either<A, B> as Right<A, B>;
    const r2 = other.asRight();
    return r2 !== null ? compareRight(r1.value, r2.value) : 1;
  }
}

export class Left<A, B> extends Either<A, B> {
  readonly value: A;

  constructor(value: A) {
    super();
    this.value = value;
  }

  isLeft(): boolean {
    return true;
  }

  toString(): string {
    return `Either.Left(${this.value})`;
  }
}

export class Right<A, B> extends Either<A, B> {
  readonly value: B;

  constructor(value: B) {
    super();
    this.value = value;
  }

  isLeft(): boolean {
    return false;
  }

  toString(): string {
    return `Either.Right(${this.value})`;
  }
}

/** Kotlin `A.left()` */
export function leftOf<A, B>(value: A): Either<A, B> {
  return new Left<A, B>(value);
}

/** Kotlin `A.right()` */
export function rightOf<A, B>(value: B): Either<A, B> {
  return new Right<A, B>(value);
}

/** Kotlin identity */
export function identity<A>(value: A): A {
  return value;
}
