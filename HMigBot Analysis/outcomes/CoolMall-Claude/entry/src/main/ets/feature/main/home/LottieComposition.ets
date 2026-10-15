/**
 * LottieComposition — a small Bodymovin (Lottie) shape-layer runtime used by the bottom navigation tab icons
 * (source: BottomNavigationBar.kt TabLottieAnimation → com.airbnb.lottie.compose.LottieAnimation, HOME-A04).
 *
 * Parses the raw Lottie JSON (TabLottieData.ets, verbatim copies of raw/home|category|cart|me.json) into typed
 * nodes and evaluates them at any (fractional) frame, following lottie-android semantics:
 *   - keyframes: cubic-bezier easing from the out tangent (o) of the current and the in tangent (i) of the
 *     next keyframe, per dimension; hold keyframes (h = 1); values before the first / after the last keyframe
 *     are clamped; spatial position keyframes (to / ti) move along their cubic path by arc length
 *   - layer time = composition time (a shape layer's own `st` is not applied, as in lottie-android);
 *     a layer is drawn while ip <= frame < op; parents contribute their transform only (not opacity)
 *   - transforms: translate(p) · rotate(r) · scale(s / 100) · translate(-a); group `tr` opacity multiplies
 *   - shapes: path (sh, animated vertex interpolation), ellipse (el), fill (fl, nonzero / even-odd),
 *     stroke (st, width / cap / join / miter), trim paths (tm, start / end / offset)
 * Drawing is done by LottieRenderer onto a CanvasRenderingContext2D.
 */
import {
  AnimatedPath, AnimatedValue, PathData, RawComposition, RawItem, RawLayer, RawProp, RawTransform
} from './LottieValues';

// ---------------------------------------------------------------------------------------- nodes

/** Layer `ks` / group `tr` transform */
export class LottieTransform {
  anchor: AnimatedValue = AnimatedValue.constant([0, 0]);
  position: AnimatedValue = AnimatedValue.constant([0, 0]);
  scale: AnimatedValue = AnimatedValue.constant([100, 100]);
  rotation: AnimatedValue = AnimatedValue.constant([0]);
  opacity: AnimatedValue = AnimatedValue.constant([100]);

  static parse(a: RawProp | undefined, p: RawProp | undefined, s: RawProp | undefined, r: RawProp | undefined,
    o: RawProp | undefined): LottieTransform {
    const t: LottieTransform = new LottieTransform();
    t.anchor = AnimatedValue.parse(a, [0, 0]);
    t.position = AnimatedValue.parse(p, [0, 0]);
    t.scale = AnimatedValue.parse(s, [100, 100]);
    t.rotation = AnimatedValue.parse(r, [0]);
    t.opacity = AnimatedValue.parse(o, [100]);
    return t;
  }
}

export const SHAPE_GROUP: string = 'gr';
export const SHAPE_PATH: string = 'sh';
export const SHAPE_ELLIPSE: string = 'el';
export const SHAPE_FILL: string = 'fl';
export const SHAPE_STROKE: string = 'st';
export const SHAPE_TRIM: string = 'tm';

/** One shape item (group / path / ellipse / fill / stroke / trim); unsupported types are skipped */
export class LottieShape {
  kind: string = '';
  // group
  children: LottieShape[] = [];
  transform: LottieTransform = new LottieTransform();
  // path / ellipse
  path: AnimatedPath = new AnimatedPath();
  ellipsePosition: AnimatedValue = AnimatedValue.constant([0, 0]);
  ellipseSize: AnimatedValue = AnimatedValue.constant([0, 0]);
  // fill / stroke
  color: AnimatedValue = AnimatedValue.constant([0, 0, 0, 1]);
  opacity: AnimatedValue = AnimatedValue.constant([100]);
  strokeWidth: AnimatedValue = AnimatedValue.constant([1]);
  lineCap: number = 2;
  lineJoin: number = 2;
  miterLimit: number = 4;
  evenOdd: boolean = false;
  // trim
  trimStart: AnimatedValue = AnimatedValue.constant([0]);
  trimEnd: AnimatedValue = AnimatedValue.constant([100]);
  trimOffset: AnimatedValue = AnimatedValue.constant([0]);

  static parseList(items: RawItem[] | undefined): LottieShape[] {
    const result: LottieShape[] = [];
    if (items === undefined || items === null) {
      return result;
    }
    for (let i = 0; i < items.length; i++) {
      const shape: LottieShape | null = LottieShape.parse(items[i]);
      if (shape !== null) {
        result.push(shape);
      }
    }
    return result;
  }

  static parse(raw: RawItem): LottieShape | null {
    if (raw.hd === true) {
      return null;
    }
    const s: LottieShape = new LottieShape();
    s.kind = raw.ty;
    if (raw.ty === SHAPE_GROUP) {
      const items: RawItem[] = raw.it ?? [];
      for (let i = 0; i < items.length; i++) {
        const item: RawItem = items[i];
        if (item.ty === 'tr') {
          s.transform = LottieTransform.parse(item.a, item.p, item.s,
            item.r !== undefined ? item.r as RawProp : undefined, item.o);
        }
      }
      s.children = LottieShape.parseList(items);
    } else if (raw.ty === SHAPE_PATH) {
      s.path = AnimatedPath.parse(raw.ks);
    } else if (raw.ty === SHAPE_ELLIPSE) {
      s.ellipsePosition = AnimatedValue.parse(raw.p, [0, 0]);
      s.ellipseSize = AnimatedValue.parse(raw.s, [0, 0]);
    } else if (raw.ty === SHAPE_FILL || raw.ty === SHAPE_STROKE) {
      s.color = AnimatedValue.parse(raw.c, [0, 0, 0, 1]);
      s.opacity = AnimatedValue.parse(raw.o, [100]);
      if (raw.ty === SHAPE_STROKE) {
        s.strokeWidth = AnimatedValue.parse(raw.w, [1]);
        s.lineCap = raw.lc ?? 2;
        s.lineJoin = raw.lj ?? 2;
        s.miterLimit = raw.ml ?? 4;
      } else {
        s.evenOdd = typeof raw.r === 'number' && (raw.r as number) === 2;
      }
    } else if (raw.ty === SHAPE_TRIM) {
      s.trimStart = AnimatedValue.parse(raw.s, [0]);
      s.trimEnd = AnimatedValue.parse(raw.e, [100]);
      s.trimOffset = AnimatedValue.parse(raw.o, [0]);
    } else {
      return null;
    }
    return s;
  }

  /** Path geometry of a path / ellipse item at `frame` */
  geometryAt(frame: number): PathData {
    if (this.kind === SHAPE_ELLIPSE) {
      const p: number[] = this.ellipsePosition.valueAt(frame);
      const size: number[] = this.ellipseSize.valueAt(frame);
      return PathData.ellipse(p.length > 0 ? p[0] : 0, p.length > 1 ? p[1] : 0, size.length > 0 ? size[0] : 0,
        size.length > 1 ? size[1] : 0);
    }
    return this.path.pathAt(frame);
  }
}

/** Shape layer (ty 4); other layer types are ignored */
export class LottieLayer {
  index: number = -1;
  parentIndex: number = -1;
  inPoint: number = 0;
  outPoint: number = 0;
  isShapeLayer: boolean = false;
  transform: LottieTransform = new LottieTransform();
  shapes: LottieShape[] = [];
}

export class LottieComposition {
  width: number = 0;
  height: number = 0;
  inPoint: number = 0;
  outPoint: number = 0;
  frameRate: number = 30;
  layers: LottieLayer[] = [];

  /** Parse Bodymovin JSON; null when it cannot be read */
  static parse(json: string): LottieComposition | null {
    try {
      const raw: RawComposition = JSON.parse(json) as RawComposition;
      const comp: LottieComposition = new LottieComposition();
      comp.width = raw.w ?? 0;
      comp.height = raw.h ?? 0;
      comp.inPoint = raw.ip ?? 0;
      comp.outPoint = raw.op ?? 0;
      comp.frameRate = raw.fr ?? 30;
      const layers: RawLayer[] = raw.layers ?? [];
      for (let i = 0; i < layers.length; i++) {
        const rl: RawLayer = layers[i];
        const layer: LottieLayer = new LottieLayer();
        layer.index = rl.ind ?? i;
        layer.parentIndex = rl.parent ?? -1;
        layer.inPoint = rl.ip ?? 0;
        layer.outPoint = rl.op ?? 0;
        layer.isShapeLayer = rl.ty === 4 && rl.hd !== true;
        const ks: RawTransform | undefined = rl.ks;
        if (ks !== undefined && ks !== null) {
          layer.transform = LottieTransform.parse(ks.a, ks.p, ks.s, ks.r, ks.o);
        }
        layer.shapes = LottieShape.parseList(rl.shapes);
        comp.layers.push(layer);
      }
      if (comp.width <= 0 || comp.height <= 0 || comp.outPoint <= comp.inPoint) {
        return null;
      }
      return comp;
    } catch (e) {
      console.error(`LottieComposition parse error: ${(e as Error)?.message ?? ''}`);
      return null;
    }
  }

  /** Playback duration (source animateLottieCompositionAsState: (op - ip) / fr seconds, speed 1) */
  durationMs(): number {
    return (this.outPoint - this.inPoint) / (this.frameRate > 0 ? this.frameRate : 30) * 1000;
  }

  layerByIndex(index: number): LottieLayer | null {
    for (let i = 0; i < this.layers.length; i++) {
      if (this.layers[i].index === index) {
        return this.layers[i];
      }
    }
    return null;
  }
}
