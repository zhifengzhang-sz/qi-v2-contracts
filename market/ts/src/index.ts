// @qi/market: the market data contract (../SPEC.md): the K-lines as Zod schemas, and an ongoing K-line's records as
// JSON; for a contract built on it, its units and its JSON (decodeAs, encodeRecord).

export {
  type DecodedOngoing,
  decodeAs,
  decodeMassiveOngoingKLine,
  decodeOngoingKLine,
  encodeOngoingKLine,
  encodeRecord,
} from "./codec.ts";
export {
  type KLine,
  klineSchema,
  type MassiveKLine,
  type MassiveOngoingKLine,
  massiveKlineSchema,
  massiveOngoingKlineSchema,
  type OngoingKLine,
  ongoingKlineSchema,
  positionSchema,
  priceSchema,
} from "./contracts.ts";
