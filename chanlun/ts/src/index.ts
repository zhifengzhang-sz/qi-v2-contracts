// @qi/chanlun: 缠论's contract (../SPEC.md): what the algorithm makes beyond the K-line as Zod schemas, and a run's
// records as JSON. Its units and its JSON are market's (@qi/market), and so is the K-line.

export { type Decoded, decodeRun, encodeRun, type Run, runSchema } from "./codec.ts";
export {
  type Consolidation,
  consolidationSchema,
  type Fractal,
  fractalSchema,
  type Line,
  lineSchema,
  type MergedBar,
  type Move,
  mergedBarSchema,
  moveSchema,
  type Segment,
  type Stroke,
  segmentSchema,
  strokeSchema,
} from "./contracts.ts";
