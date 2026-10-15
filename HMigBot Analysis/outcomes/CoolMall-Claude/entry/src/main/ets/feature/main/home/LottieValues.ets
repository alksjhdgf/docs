/**
 * LottieValues — raw Bodymovin JSON shapes and the animatable value / path evaluators of the tab-icon Lottie
 * runtime (see LottieComposition.ets). Keyframe semantics follow lottie-android: per-dimension cubic-bezier
 * easing (o of the current, i of the next keyframe), hold keyframes, clamped ends, spatial (to / ti) position
 * paths walked by arc length, vertex-wise path interpolation.
 */

// ---------------------------------------------------------------------------------------- raw JSON shapes

export interface RawEase {
  x: Object;
  y: Object;
}

export interface RawKeyframe {
  t: number;
  s?: Object;
  e?: Object;
  h?: number;
  i?: RawEase;
  o?: RawEase;
  to?: number[];
  ti?: number[];
}

export interface RawProp {
  a?: number;
  k: Object;
}

export interface RawPathData {
  i: number[][];
  o: number[][];
  v: number[][];
  c: boolean;
}

export interface RawItem {
  ty: string;
  hd?: boolean;
  it?: RawItem[];
  ks?: RawProp;
  p?: RawProp;
  s?: RawProp;
  e?: RawProp;
  o?: RawProp;
  c?: RawProp;
  w?: RawProp;
  a?: RawProp;
  r?: Object;
  lc?: number;
  lj?: number;
  ml?: number;
}

export interface RawTransform {
  a?: RawProp;
  p?: RawProp;
  s?: RawProp;
  r?: RawProp;
  o?: RawProp;
}

export interface RawLayer {
  ty: number;
  ind?: number;
  parent?: number;
  ip: number;
  op: number;
  hd?: boolean;
  ks: RawTransform;
  shapes?: RawItem[];
}

export interface RawComposition {
  w: number;
  h: number;
  ip: number;
  op: number;
  fr: number;
  layers: RawLayer[];
}

// ---------------------------------------------------------------------------------------- helpers

/** Number or number[] → number[] */
function toNumbers(value: Object | undefined): number[] {
  if (value === undefined || value === null) {
    return [];
  }
  if (typeof value === 'number') {
    return [value as number];
  }
  if (Array.isArray(value)) {
    const list: Object[] = value as Object[];
    const result: number[] = [];
    for (let i = 0; i < list.length; i++) {
      const item: Object = list[i];
      result.push(typeof item === 'number' ? item as number : 0);
    }
    return result;
  }
  return [];
}

function isAnimated(prop: RawProp): boolean {
  if (prop.a === 1) {
    return true;
  }
  const k: Object = prop.k;
  if (Array.isArray(k)) {
    const list: Object[] = k as Object[];
    return list.length > 0 && typeof list[0] === 'object';
  }
  return false;
}

/** Cubic-bezier easing curve (0,0) (x1,y1) (x2,y2) (1,1) — lottie-android PathInterpolator */
export class CubicEase {
  x1: number;
  y1: number;
  x2: number;
  y2: number;
  linear: boolean;

  constructor(x1: number, y1: number, x2: number, y2: number) {
    // lottie-android clamps x to [0, 1] and y to [-100, 100]
    this.x1 = Math.min(1, Math.max(0, x1));
    this.y1 = Math.min(100, Math.max(-100, y1));
    this.x2 = Math.min(1, Math.max(0, x2));
    this.y2 = Math.min(100, Math.max(-100, y2));
    this.linear = this.x1 === this.y1 && this.x2 === this.y2;
  }

  private static bez(t: number, p1: number, p2: number): number {
    const u: number = 1 - t;
    return 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t;
  }

  solve(x: number): number {
    if (x <= 0) {
      return 0;
    }
    if (x >= 1) {
      return 1;
    }
    if (this.linear) {
      return x;
    }
    let lo: number = 0;
    let hi: number = 1;
    let t: number = x;
    for (let i = 0; i < 40; i++) {
      const cx: number = CubicEase.bez(t, this.x1, this.x2);
      if (Math.abs(cx - x) < 1e-6) {
        break;
      }
      if (cx < x) {
        lo = t;
      } else {
        hi = t;
      }
      t = (lo + hi) / 2;
    }
    return CubicEase.bez(t, this.y1, this.y2);
  }
}

function easesOf(kf: RawKeyframe): CubicEase[] {
  const result: CubicEase[] = [];
  if (kf.o === undefined || kf.i === undefined) {
    result.push(new CubicEase(0, 0, 1, 1));
    return result;
  }
  const ox: number[] = toNumbers(kf.o.x);
  const oy: number[] = toNumbers(kf.o.y);
  const ix: number[] = toNumbers(kf.i.x);
  const iy: number[] = toNumbers(kf.i.y);
  const dims: number = Math.max(1, Math.max(Math.max(ox.length, oy.length), Math.max(ix.length, iy.length)));
  for (let d = 0; d < dims; d++) {
    result.push(new CubicEase(
      ox.length > 0 ? ox[Math.min(d, ox.length - 1)] : 0,
      oy.length > 0 ? oy[Math.min(d, oy.length - 1)] : 0,
      ix.length > 0 ? ix[Math.min(d, ix.length - 1)] : 1,
      iy.length > 0 ? iy[Math.min(d, iy.length - 1)] : 1));
  }
  return result;
}

/** Point on the cubic P0 → P3 (control points P1, P2) at arc-length fraction `fraction` (2D) */
function pointOnSpatialCurve(p0: number[], p1: number[], p2: number[], p3: number[], fraction: number): number[] {
  const samples: number = 32;
  const xs: number[] = [];
  const ys: number[] = [];
  const lengths: number[] = [0];
  for (let i = 0; i <= samples; i++) {
    const t: number = i / samples;
    const u: number = 1 - t;
    xs.push(u * u * u * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t * t * t * p3[0]);
    ys.push(u * u * u * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t * t * t * p3[1]);
    if (i > 0) {
      lengths.push(lengths[i - 1] + Math.hypot(xs[i] - xs[i - 1], ys[i] - ys[i - 1]));
    }
  }
  const total: number = lengths[samples];
  const f: number = Math.min(1, Math.max(0, fraction));
  if (total <= 0) {
    return [p0[0] + (p3[0] - p0[0]) * f, p0[1] + (p3[1] - p0[1]) * f];
  }
  const target: number = total * f;
  for (let i = 1; i <= samples; i++) {
    if (lengths[i] >= target) {
      const seg: number = lengths[i] - lengths[i - 1];
      const local: number = seg > 0 ? (target - lengths[i - 1]) / seg : 0;
      return [xs[i - 1] + (xs[i] - xs[i - 1]) * local, ys[i - 1] + (ys[i] - ys[i - 1]) * local];
    }
  }
  return [xs[samples], ys[samples]];
}

// ---------------------------------------------------------------------------------------- animated values

class ValueKeyframe {
  time: number = 0;
  start: number[] = [];
  hold: boolean = false;
  eases: CubicEase[] = [];
  spatialOut: number[] | null = null;
  spatialIn: number[] | null = null;
}

/** Animatable number / vector property */
export class AnimatedValue {
  staticValue: number[] = [];
  frames: ValueKeyframe[] = [];

  static constant(values: number[]): AnimatedValue {
    const v: AnimatedValue = new AnimatedValue();
    v.staticValue = values;
    return v;
  }

  static parse(prop: RawProp | undefined, fallback: number[]): AnimatedValue {
    if (prop === undefined || prop === null) {
      return AnimatedValue.constant(fallback);
    }
    if (!isAnimated(prop)) {
      const values: number[] = toNumbers(prop.k);
      return AnimatedValue.constant(values.length > 0 ? values : fallback);
    }
    const v: AnimatedValue = new AnimatedValue();
    const raw: RawKeyframe[] = prop.k as RawKeyframe[];
    for (let i = 0; i < raw.length; i++) {
      const kf: RawKeyframe = raw[i];
      const frame: ValueKeyframe = new ValueKeyframe();
      frame.time = kf.t;
      // Bodymovin 5.x: start value in `s`; older exports keep the end value in the previous keyframe's `e`
      frame.start = kf.s !== undefined ? toNumbers(kf.s) : (i > 0 ? toNumbers(raw[i - 1].e) : fallback);
      if (frame.start.length === 0) {
        frame.start = i > 0 ? v.frames[i - 1].start : fallback;
      }
      frame.hold = kf.h === 1;
      frame.eases = easesOf(kf);
      if (kf.to !== undefined && kf.ti !== undefined && kf.to.length >= 2 && kf.ti.length >= 2 &&
        (kf.to[0] !== 0 || kf.to[1] !== 0 || kf.ti[0] !== 0 || kf.ti[1] !== 0)) {
        frame.spatialOut = kf.to;
        frame.spatialIn = kf.ti;
      }
      v.frames.push(frame);
    }
    if (v.frames.length === 0) {
      v.staticValue = fallback;
    }
    return v;
  }

  valueAt(frame: number): number[] {
    const count: number = this.frames.length;
    if (count === 0) {
      return this.staticValue;
    }
    if (frame <= this.frames[0].time) {
      return this.frames[0].start;
    }
    if (frame >= this.frames[count - 1].time) {
      return this.frames[count - 1].start;
    }
    let k: number = 0;
    while (k < count - 2 && this.frames[k + 1].time <= frame) {
      k++;
    }
    const a: ValueKeyframe = this.frames[k];
    const b: ValueKeyframe = this.frames[k + 1];
    if (a.hold || b.time <= a.time) {
      return a.start;
    }
    const linear: number = (frame - a.time) / (b.time - a.time);
    if (a.spatialOut !== null && a.spatialIn !== null && a.start.length >= 2 && b.start.length >= 2) {
      const f: number = a.eases[0].solve(linear);
      const out: number[] = a.spatialOut;
      const inn: number[] = a.spatialIn;
      return pointOnSpatialCurve(a.start, [a.start[0] + out[0], a.start[1] + out[1]],
        [b.start[0] + inn[0], b.start[1] + inn[1]], b.start, f);
    }
    const result: number[] = [];
    for (let d = 0; d < a.start.length; d++) {
      const to: number = d < b.start.length ? b.start[d] : a.start[d];
      const ease: CubicEase = a.eases[Math.min(d, a.eases.length - 1)];
      result.push(a.start[d] + (to - a.start[d]) * ease.solve(linear));
    }
    return result;
  }

  scalarAt(frame: number): number {
    const v: number[] = this.valueAt(frame);
    return v.length > 0 ? v[0] : 0;
  }
}

/** Bezier path data: vertices with in / out tangents relative to their vertex */
export class PathData {
  closed: boolean = false;
  v: number[][] = [];
  i: number[][] = [];
  o: number[][] = [];

  static from(raw: RawPathData | undefined): PathData {
    const p: PathData = new PathData();
    if (raw === undefined || raw === null) {
      return p;
    }
    p.closed = raw.c === true;
    p.v = raw.v ?? [];
    p.i = raw.i ?? [];
    p.o = raw.o ?? [];
    return p;
  }

  /** Lottie ellipse (starts at the top, clockwise) as 4 cubic segments */
  static ellipse(cx: number, cy: number, w: number, h: number): PathData {
    const rx: number = w / 2;
    const ry: number = h / 2;
    const kx: number = rx * 0.5519150244935105;
    const ky: number = ry * 0.5519150244935105;
    const p: PathData = new PathData();
    p.closed = true;
    p.v = [[cx, cy - ry], [cx + rx, cy], [cx, cy + ry], [cx - rx, cy]];
    p.i = [[-kx, 0], [0, -ky], [kx, 0], [0, ky]];
    p.o = [[kx, 0], [0, ky], [-kx, 0], [0, -ky]];
    return p;
  }

  static lerp(a: PathData, b: PathData, f: number): PathData {
    if (a.v.length !== b.v.length) {
      return f < 1 ? a : b;
    }
    const p: PathData = new PathData();
    p.closed = a.closed;
    p.v = PathData.lerpPoints(a.v, b.v, f);
    p.i = PathData.lerpPoints(a.i, b.i, f);
    p.o = PathData.lerpPoints(a.o, b.o, f);
    return p;
  }

  private static lerpPoints(a: number[][], b: number[][], f: number): number[][] {
    const result: number[][] = [];
    for (let j = 0; j < a.length; j++) {
      const pa: number[] = a[j];
      const pb: number[] = j < b.length ? b[j] : pa;
      result.push([pa[0] + (pb[0] - pa[0]) * f, pa[1] + (pb[1] - pa[1]) * f]);
    }
    return result;
  }
}

class PathKeyframe {
  time: number = 0;
  path: PathData = new PathData();
  hold: boolean = false;
  ease: CubicEase = new CubicEase(0, 0, 1, 1);
}

/** Animatable path (sh.ks) */
export class AnimatedPath {
  staticPath: PathData = new PathData();
  frames: PathKeyframe[] = [];

  static parse(prop: RawProp | undefined): AnimatedPath {
    const ap: AnimatedPath = new AnimatedPath();
    if (prop === undefined || prop === null) {
      return ap;
    }
    if (!isAnimated(prop)) {
      ap.staticPath = PathData.from(prop.k as RawPathData);
      return ap;
    }
    const raw: RawKeyframe[] = prop.k as RawKeyframe[];
    for (let i = 0; i < raw.length; i++) {
      const kf: RawKeyframe = raw[i];
      const source: Object | undefined = kf.s !== undefined ? kf.s : (i > 0 ? raw[i - 1].e : undefined);
      const frame: PathKeyframe = new PathKeyframe();
      frame.time = kf.t;
      if (source !== undefined && Array.isArray(source) && (source as Object[]).length > 0) {
        frame.path = PathData.from((source as Object[])[0] as RawPathData);
      } else if (i > 0) {
        frame.path = ap.frames[i - 1].path;
      }
      frame.hold = kf.h === 1;
      frame.ease = easesOf(kf)[0];
      ap.frames.push(frame);
    }
    return ap;
  }

  pathAt(frame: number): PathData {
    const count: number = this.frames.length;
    if (count === 0) {
      return this.staticPath;
    }
    if (frame <= this.frames[0].time) {
      return this.frames[0].path;
    }
    if (frame >= this.frames[count - 1].time) {
      return this.frames[count - 1].path;
    }
    let k: number = 0;
    while (k < count - 2 && this.frames[k + 1].time <= frame) {
      k++;
    }
    const a: PathKeyframe = this.frames[k];
    const b: PathKeyframe = this.frames[k + 1];
    if (a.hold || b.time <= a.time) {
      return a.path;
    }
    return PathData.lerp(a.path, b.path, a.ease.solve((frame - a.time) / (b.time - a.time)));
  }
}
