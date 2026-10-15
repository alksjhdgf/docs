/**
 * LottieRenderer — draws a LottieComposition frame onto a CanvasRenderingContext2D (tab-icon Lottie runtime,
 * HOME-A04). Rendering follows lottie-android:
 *   - the composition is fitted and centered in the box (LottieAnimation default ContentScale.Fit)
 *   - layers draw bottom-up (last layer first); each layer applies its parent chain's transforms, then its own,
 *     and multiplies its own opacity into its contents
 *   - inside a group, items draw last-to-first; a fill / stroke paints every path / ellipse listed before it
 *     in the same group; a trim path trims the paths and groups listed before it in its group
 *   - trims cut each path individually by arc length (start / end in %, offset in degrees)
 */
import { PathData } from './LottieValues';
import {
  LottieComposition,
  LottieLayer,
  LottieShape,
  LottieTransform,
  SHAPE_ELLIPSE,
  SHAPE_FILL,
  SHAPE_GROUP,
  SHAPE_PATH,
  SHAPE_STROKE,
  SHAPE_TRIM
} from './LottieComposition';

/** Bezier flattening steps per segment (only used for trimmed paths) */
const FLATTEN_STEPS: number = 16;

class TrimSpec {
  start: number = 0;
  end: number = 1;
  offset: number = 0;
}

class Polyline {
  xs: number[] = [];
  ys: number[] = [];
}

function clamp01(v: number): number {
  return Math.min(1, Math.max(0, v));
}

function floorMod(a: number, b: number): number {
  return a - b * Math.floor(a / b);
}

function hex2(v: number): string {
  const n: number = Math.round(clamp01(v) * 255);
  return (n < 16 ? '0' : '') + n.toString(16).toUpperCase();
}

/** Lottie color (0..1 or 0..255 components) → '#RRGGBB' */
function colorHex(c: number[]): string {
  let scale: number = 1;
  for (let i = 0; i < Math.min(3, c.length); i++) {
    if (c[i] > 1) {
      scale = 255;
    }
  }
  const r: number = c.length > 0 ? c[0] / scale : 0;
  const g: number = c.length > 1 ? c[1] / scale : 0;
  const b: number = c.length > 2 ? c[2] / scale : 0;
  return '#' + hex2(r) + hex2(g) + hex2(b);
}

function trimAt(shape: LottieShape, frame: number): TrimSpec {
  const t: TrimSpec = new TrimSpec();
  t.start = clamp01(shape.trimStart.scalarAt(frame) / 100);
  t.end = clamp01(shape.trimEnd.scalarAt(frame) / 100);
  t.offset = shape.trimOffset.scalarAt(frame) / 360;
  return t;
}

/** Trims listed in `shapes` strictly between indices `from` and `to` */
function trimsBetween(shapes: LottieShape[], from: number, to: number, frame: number): TrimSpec[] {
  const result: TrimSpec[] = [];
  for (let m = from + 1; m < to; m++) {
    if (shapes[m].kind === SHAPE_TRIM) {
      result.push(trimAt(shapes[m], frame));
    }
  }
  return result;
}

function flatten(path: PathData): Polyline {
  const pl: Polyline = new Polyline();
  const n: number = path.v.length;
  if (n === 0) {
    return pl;
  }
  pl.xs.push(path.v[0][0]);
  pl.ys.push(path.v[0][1]);
  const segments: number = path.closed ? n : n - 1;
  for (let j = 0; j < segments; j++) {
    const a: number[] = path.v[j];
    const nextIndex: number = (j + 1) % n;
    const b: number[] = path.v[nextIndex];
    const ao: number[] = j < path.o.length ? path.o[j] : [0, 0];
    const bi: number[] = nextIndex < path.i.length ? path.i[nextIndex] : [0, 0];
    const c1x: number = a[0] + ao[0];
    const c1y: number = a[1] + ao[1];
    const c2x: number = b[0] + bi[0];
    const c2y: number = b[1] + bi[1];
    for (let s = 1; s <= FLATTEN_STEPS; s++) {
      const t: number = s / FLATTEN_STEPS;
      const u: number = 1 - t;
      pl.xs.push(u * u * u * a[0] + 3 * u * u * t * c1x + 3 * u * t * t * c2x + t * t * t * b[0]);
      pl.ys.push(u * u * u * a[1] + 3 * u * u * t * c1y + 3 * u * t * t * c2y + t * t * t * b[1]);
    }
  }
  return pl;
}

function cumulativeLengths(pl: Polyline): number[] {
  const lengths: number[] = [0];
  for (let i = 1; i < pl.xs.length; i++) {
    lengths.push(lengths[i - 1] + Math.hypot(pl.xs[i] - pl.xs[i - 1], pl.ys[i] - pl.ys[i - 1]));
  }
  return lengths;
}

/** Portion of the polyline between arc lengths `from` and `to` (0 <= from < to <= total) */
function subPolyline(pl: Polyline, lengths: number[], from: number, to: number): Polyline {
  const out: Polyline = new Polyline();
  const count: number = pl.xs.length;
  for (let i = 1; i < count; i++) {
    const l0: number = lengths[i - 1];
    const l1: number = lengths[i];
    if (l1 < from || l0 > to || l1 <= l0) {
      continue;
    }
    if (out.xs.length === 0) {
      const f0: number = Math.max(0, (from - l0) / (l1 - l0));
      out.xs.push(pl.xs[i - 1] + (pl.xs[i] - pl.xs[i - 1]) * f0);
      out.ys.push(pl.ys[i - 1] + (pl.ys[i] - pl.ys[i - 1]) * f0);
    }
    const f1: number = Math.min(1, (to - l0) / (l1 - l0));
    out.xs.push(pl.xs[i - 1] + (pl.xs[i] - pl.xs[i - 1]) * f1);
    out.ys.push(pl.ys[i - 1] + (pl.ys[i] - pl.ys[i - 1]) * f1);
    if (l1 >= to) {
      break;
    }
  }
  return out;
}

/** lottie-android Utils.applyTrimPathIfNeeded on a flattened path */
function applyTrim(pl: Polyline, trim: TrimSpec): Polyline[] {
  const result: Polyline[] = [];
  if (Math.abs(trim.end - trim.start) < 1e-6) {
    return result; // start == end: nothing is drawn
  }
  if (trim.start < 0.01 && trim.end > 0.99) {
    result.push(pl); // ~100%: the full path
    return result;
  }
  const lengths: number[] = cumulativeLengths(pl);
  const total: number = lengths[lengths.length - 1];
  if (total <= 0) {
    return result;
  }
  let newStart: number = Math.min(trim.start, trim.end) * total + trim.offset * total;
  let newEnd: number = Math.max(trim.start, trim.end) * total + trim.offset * total;
  if (newStart >= total && newEnd >= total) {
    newStart = floorMod(newStart, total);
    newEnd = floorMod(newEnd, total);
  }
  if (newStart < 0) {
    newStart = floorMod(newStart, total);
  }
  if (newEnd < 0) {
    newEnd = floorMod(newEnd, total);
  }
  if (newStart === newEnd) {
    return result;
  }
  if (newStart >= newEnd) {
    newStart -= total;
  }
  result.push(subPolyline(pl, lengths, Math.max(0, newStart), Math.min(total, newEnd)));
  if (newEnd > total) {
    result.push(subPolyline(pl, lengths, 0, newEnd - total));
  } else if (newStart < 0) {
    result.push(subPolyline(pl, lengths, total + newStart, total));
  }
  return result;
}

function addPath(ctx: CanvasRenderingContext2D, path: PathData, trims: TrimSpec[]): void {
  const n: number = path.v.length;
  if (n === 0) {
    return;
  }
  if (trims.length === 0) {
    ctx.moveTo(path.v[0][0], path.v[0][1]);
    const segments: number = path.closed ? n : n - 1;
    for (let j = 0; j < segments; j++) {
      const a: number[] = path.v[j];
      const nextIndex: number = (j + 1) % n;
      const b: number[] = path.v[nextIndex];
      const ao: number[] = j < path.o.length ? path.o[j] : [0, 0];
      const bi: number[] = nextIndex < path.i.length ? path.i[nextIndex] : [0, 0];
      ctx.bezierCurveTo(a[0] + ao[0], a[1] + ao[1], b[0] + bi[0], b[1] + bi[1], b[0], b[1]);
    }
    if (path.closed) {
      ctx.closePath();
    }
    return;
  }
  let pieces: Polyline[] = [flatten(path)];
  for (let t = 0; t < trims.length; t++) {
    const next: Polyline[] = [];
    for (let p = 0; p < pieces.length; p++) {
      const trimmed: Polyline[] = applyTrim(pieces[p], trims[t]);
      for (let q = 0; q < trimmed.length; q++) {
        next.push(trimmed[q]);
      }
    }
    pieces = next;
  }
  for (let p = 0; p < pieces.length; p++) {
    const pl: Polyline = pieces[p];
    if (pl.xs.length < 2) {
      continue;
    }
    ctx.moveTo(pl.xs[0], pl.ys[0]);
    for (let i = 1; i < pl.xs.length; i++) {
      ctx.lineTo(pl.xs[i], pl.ys[i]);
    }
  }
}

/** translate(p) · rotate(r) · scale(s) · translate(-a); false when the scale collapses the content */
function applyTransform(ctx: CanvasRenderingContext2D, t: LottieTransform, frame: number): boolean {
  const p: number[] = t.position.valueAt(frame);
  const s: number[] = t.scale.valueAt(frame);
  const a: number[] = t.anchor.valueAt(frame);
  const r: number = t.rotation.scalarAt(frame);
  const sx: number = (s.length > 0 ? s[0] : 100) / 100;
  const sy: number = (s.length > 1 ? s[1] : sx * 100) / 100;
  if (Math.abs(sx) < 1e-4 || Math.abs(sy) < 1e-4) {
    return false;
  }
  ctx.translate(p.length > 0 ? p[0] : 0, p.length > 1 ? p[1] : 0);
  if (r !== 0) {
    ctx.rotate(r * Math.PI / 180);
  }
  ctx.scale(sx, sy);
  ctx.translate(-(a.length > 0 ? a[0] : 0), -(a.length > 1 ? a[1] : 0));
  return true;
}

function applyLayerChain(ctx: CanvasRenderingContext2D, comp: LottieComposition, layer: LottieLayer, frame: number,
  depth: number): boolean {
  if (layer.parentIndex >= 0 && depth < 16) {
    const parent: LottieLayer | null = comp.layerByIndex(layer.parentIndex);
    if (parent !== null && !applyLayerChain(ctx, comp, parent, frame, depth + 1)) {
      return false;
    }
  }
  return applyTransform(ctx, layer.transform, frame);
}

function paint(ctx: CanvasRenderingContext2D, shapes: LottieShape[], k: number, frame: number, alpha: number,
  inherited: TrimSpec[]): void {
  const item: LottieShape = shapes[k];
  const color: number[] = item.color.valueAt(frame);
  const colorAlpha: number = color.length > 3 ? clamp01(color[3] > 1 ? color[3] / 255 : color[3]) : 1;
  const opacity: number = alpha * clamp01(item.opacity.scalarAt(frame) / 100) * colorAlpha;
  if (opacity <= 0) {
    return;
  }
  ctx.beginPath();
  let hasGeometry: boolean = false;
  for (let j = 0; j < k; j++) {
    const shape: LottieShape = shapes[j];
    if (shape.kind !== SHAPE_PATH && shape.kind !== SHAPE_ELLIPSE) {
      continue;
    }
    addPath(ctx, shape.geometryAt(frame), inherited.concat(trimsBetween(shapes, j, k, frame)));
    hasGeometry = true;
  }
  if (!hasGeometry) {
    return;
  }
  ctx.globalAlpha = opacity;
  if (item.kind === SHAPE_FILL) {
    ctx.fillStyle = colorHex(color);
    const rule: CanvasFillRule = item.evenOdd ? 'evenodd' : 'nonzero';
    ctx.fill(rule);
  } else {
    const width: number = item.strokeWidth.scalarAt(frame);
    if (width <= 0) {
      return;
    }
    ctx.strokeStyle = colorHex(color);
    ctx.lineWidth = width;
    const cap: CanvasLineCap = item.lineCap === 1 ? 'butt' : (item.lineCap === 3 ? 'square' : 'round');
    const join: CanvasLineJoin = item.lineJoin === 1 ? 'miter' : (item.lineJoin === 3 ? 'bevel' : 'round');
    ctx.lineCap = cap;
    ctx.lineJoin = join;
    ctx.miterLimit = item.miterLimit;
    ctx.stroke();
  }
}

function drawShapes(ctx: CanvasRenderingContext2D, shapes: LottieShape[], frame: number, alpha: number,
  inherited: TrimSpec[]): void {
  for (let k = shapes.length - 1; k >= 0; k--) {
    const item: LottieShape = shapes[k];
    if (item.kind === SHAPE_GROUP) {
      const groupAlpha: number = alpha * clamp01(item.transform.opacity.scalarAt(frame) / 100);
      if (groupAlpha <= 0) {
        continue;
      }
      ctx.save();
      if (applyTransform(ctx, item.transform, frame)) {
        drawShapes(ctx, item.children, frame, groupAlpha,
          inherited.concat(trimsBetween(shapes, k, shapes.length, frame)));
      }
      ctx.restore();
    } else if (item.kind === SHAPE_FILL || item.kind === SHAPE_STROKE) {
      paint(ctx, shapes, k, frame, alpha, inherited);
    }
  }
}

/** Clear the box and draw `comp` at `frame`, fitted and centered in boxWidth x boxHeight */
export function drawLottieFrame(ctx: CanvasRenderingContext2D, comp: LottieComposition, frame: number,
  boxWidth: number, boxHeight: number): void {
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.globalAlpha = 1;
  ctx.clearRect(0, 0, boxWidth, boxHeight);
  const scale: number = Math.min(boxWidth / comp.width, boxHeight / comp.height);
  const offsetX: number = (boxWidth - comp.width * scale) / 2;
  const offsetY: number = (boxHeight - comp.height * scale) / 2;
  for (let li = comp.layers.length - 1; li >= 0; li--) {
    const layer: LottieLayer = comp.layers[li];
    if (!layer.isShapeLayer || frame < layer.inPoint || frame >= layer.outPoint) {
      continue;
    }
    const layerAlpha: number = clamp01(layer.transform.opacity.scalarAt(frame) / 100);
    if (layerAlpha <= 0) {
      continue;
    }
    ctx.save();
    ctx.translate(offsetX, offsetY);
    ctx.scale(scale, scale);
    if (applyLayerChain(ctx, comp, layer, frame, 0)) {
      drawShapes(ctx, layer.shapes, frame, layerAlpha, []);
    }
    ctx.restore();
  }
  ctx.globalAlpha = 1;
}
