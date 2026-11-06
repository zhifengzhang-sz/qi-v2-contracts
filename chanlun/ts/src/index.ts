// @qi/chanlun: 缠论's contract (../SPEC.md): the algorithm's records as Zod schemas, and a run's records as JSON. Its
// K-line is market's (@qi/market).

export {
  type Decoded,
  decodeMassiveRun,
  decodeRun,
  encodeRun,
  type MassiveRun,
  massiveRunSchema,
  type Run,
  type RunOf,
  runSchema,
  timeAt,
} from "./codec.ts";
export {
  type Consolidation,
  consolidationSchema,
  type Fractal,
  fractalSchema,
  klinesSchema,
  type Line,
  lineSchema,
  type MergedBar,
  type Move,
  massiveKlinesSchema,
  mergedBarSchema,
  moveSchema,
  type Segment,
  type Stroke,
  segmentSchema,
  strokeSchema,
} from "./contracts.ts";
