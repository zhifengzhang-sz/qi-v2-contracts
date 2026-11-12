// The rules of ../../lean/Market.lean, by the same names. Each check gives the names of the rules a record breaks, in
// their order there, [] if it breaks none.

import type { KLine, OngoingKLine } from "./market_pb.ts";

type Rule = readonly [name: string, holds: boolean];

const broken = (rules: readonly Rule[]): string[] => rules.filter(([, holds]) => !holds).map(([name]) => name);

const finite = (...xs: number[]): boolean => xs.every(Number.isFinite);

const klineRules = (k: KLine | OngoingKLine): Rule[] => [
  ["finite", finite(k.open, k.high, k.low, k.close, k.volume)],
  ["range", k.low <= k.open && k.low <= k.close && k.open <= k.high && k.close <= k.high],
  ["volumeNotNegative", 0 <= k.volume],
];

export const checkKLine = (k: KLine): string[] => broken(klineRules(k));

// Its K-line's rules, and asOfNotBeforeDate.
export const checkOngoingKLine = (k: OngoingKLine): string[] =>
  broken([...klineRules(k), ["asOfNotBeforeDate", k.date <= k.asOf]]);
