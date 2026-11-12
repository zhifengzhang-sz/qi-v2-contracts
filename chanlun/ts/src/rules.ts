// The rules of ../../lean/Chanlun.lean, by the same names. Each check gives the names of the rules a record breaks, in
// their order there, [] if it breaks none.

import type { Consolidation, Fractal, Line, MergedBar, Move, Segment } from "./chanlun_pb.ts";

type Rule = readonly [name: string, holds: boolean];

const broken = (rules: readonly Rule[]): string[] => rules.filter(([, holds]) => !holds).map(([name]) => name);

const finite = (...xs: number[]): boolean => xs.every(Number.isFinite);

export const checkMergedBar = (m: MergedBar): string[] =>
  broken([
    ["finite", finite(m.high, m.low)],
    ["range", m.low <= m.high],
    ["extremesWithin", m.extremes.every((p) => m.start <= p && p <= m.end)],
    ["extremesAscending", m.extremes.every((p, i) => i === 0 || (m.extremes[i - 1] ?? p) < p)],
    ["indexInExtremes", m.extremes.includes(m.index)],
  ]);

// A 分型 has no rule.
export const checkFractal = (_: Fractal): string[] => [];

const startBeforeEnd = (l: Line | Segment | Move): string[] => broken([["startBeforeEnd", l.start < l.end]]);
export const checkLine = (l: Line): string[] => startBeforeEnd(l);
export const checkSegment = (s: Segment): string[] => startBeforeEnd(s);
export const checkMove = (m: Move): string[] => startBeforeEnd(m);

export const checkConsolidation = (c: Consolidation): string[] =>
  broken([
    ["finite", finite(c.zg, c.zd, c.gg, c.dd)],
    ["startBeforeEnd", c.start < c.end],
    ["bands", c.dd <= c.zd && c.zd <= c.zg && c.zg <= c.gg],
  ]);
