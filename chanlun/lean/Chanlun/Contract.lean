import Lean.Data.Json

/-!
# 缠论's records

The algorithm's records, of whatever implementation gives them (../SPEC.md, The records), the same as the TypeScript
form's `contracts.ts`. The algorithm is a chain, and so are its records: the K-line, then 包含's merged bar, 分型 at a
merged bar, the lines (笔, 线段, and 走势 of level L), and 中枢 of level L. They cross from one project to another as JSON
(`Chanlun/Codec.lean`).

A K-line's `date` is its begin time, seconds since 1970, UTC. Every configuration after 包含 is on merged bars, by
their number (a merged bar's `mIndex`). A price is a whole number, the price times the data's scale.
-/
namespace Chanlun

open Lean (ToJson FromJson)

/-- A K-line, the base contract, 7 fields. -/
structure KLine where
  /-- its place in the run, from 0 -/
  index : Nat
  /-- its begin time, seconds since 1970, UTC -/
  date : Nat
  «open» : Int
  high : Int
  low : Int
  close : Int
  volume : Nat
  deriving Repr, BEq, Inhabited, ToJson, FromJson

/-- Massive's K-line, 9 fields: the base, and `vw` and `n` of Massive's row. -/
structure MassiveKLine extends KLine where
  vw : Int
  n : Nat
  deriving Repr, BEq, Inhabited, ToJson, FromJson

/-- What a run needs of its K-lines, of the base contract or of a data source's: the base's fields, and the names of
its own. -/
class KLineOf (K : Type) where
  base : K → KLine
  fields : List String

instance : KLineOf KLine where
  base := id
  fields := ["index", "date", "open", "high", "low", "close", "volume"]

instance : KLineOf MassiveKLine where
  base := MassiveKLine.toKLine
  fields := ["index", "date", "open", "high", "low", "close", "volume", "vw", "n"]

/-- 包含's merged bar `mIndex`: from `start` to `end`, its first and last K-lines; `extremes` the K-lines of its extreme,
of its high when it goes up, of its low when it goes down, at least one, each from `start` to `end`, in ascending order,
none twice; `index` one of `extremes`: the K-line that represents the merged bar. The contract does not say which one is
chosen. -/
structure MergedBar where
  index : Nat
  mIndex : Nat
  up : Bool
  high : Int
  low : Int
  start : Nat
  confirmStart : Option Nat
  «end» : Nat
  confirmEnd : Option Nat
  extremes : Array Nat
  deriving Repr, BEq, Inhabited, ToJson, FromJson

/-- 分型: its merged bar, `mIndex`. -/
structure Fractal where
  mIndex : Nat
  deriving Repr, BEq, Inhabited, ToJson, FromJson

/-- A line: from the merged bar `start` to the merged bar `end`, `confirmEnd` the merged bar at which it was confirmed. -/
structure Line where
  start : Nat
  «end» : Nat
  confirmEnd : Nat
  deriving Repr, BEq, Inhabited, ToJson, FromJson

/-- 笔: a line. -/
abbrev Stroke := Line

/-- 线段 of level L: a line's fields, and its level. -/
structure Segment extends Line where
  level : Nat
  deriving Repr, BEq, Inhabited, ToJson, FromJson

/-- 走势 of level L: a line's fields, and its level. -/
structure Move extends Line where
  level : Nat
  deriving Repr, BEq, Inhabited, ToJson, FromJson

/-- 中枢 of level L, from the merged bar `start` to the merged bar `end`, `confirmEnd` the merged bar at which it was
confirmed, `none` while it is under construction; its band ZD to ZG within its range DD to GG. -/
structure Consolidation where
  level : Nat
  start : Nat
  «end» : Nat
  confirmEnd : Option Nat
  zg : Int
  zd : Int
  gg : Int
  dd : Int
  deriving Repr, BEq, Inhabited, ToJson, FromJson

/-- A run: its K-lines, of the base contract or of a data source's, merged bars, 分型, 笔 (strokes), and by level from 0
its 线段 (segments), 走势 (moves) and 中枢 (consolidations). -/
structure RunOf (K : Type) where
  klines : Array K
  merged : Array MergedBar
  fractals : Array Fractal
  strokes : Array Stroke
  segments : Array (Array Segment)
  moves : Array (Array Move)
  consolidations : Array (Array Consolidation)
  deriving Repr, BEq, Inhabited, ToJson, FromJson

/-- The run of the base contract's K-lines. -/
abbrev Run := RunOf KLine

/-- The run of Massive's K-lines. -/
abbrev MassiveRun := RunOf MassiveKLine

/-- The time of the K-line at a position: how a position is turned back into a time. -/
def RunOf.timeAt {K : Type} [KLineOf K] (r : RunOf K) (p : Nat) : Option Nat :=
  (r.klines[p]?).map fun k => (KLineOf.base k).date

end Chanlun
