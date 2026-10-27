import Lean.Data.Json

/-!
# 缠论's records

The algorithm's records, of whatever implementation gives them (../SPEC.md, The records), the same as the TypeScript
form's `contracts.ts`. The algorithm is a chain, and so are its records: the K-line, then 包含's merged bar, 分型 at a
merged bar, the lines (笔 of level −2, 线段 of level −1, 走势 of level L), and 中枢 of level L. They cross from one
project to another as JSON (`Chanlun/Codec.lean`).

A K-line's `date` is its time, seconds since 1970, UTC; every other date is the position of its K-line in the run,
from 0, `none` where not set. Every configuration after 包含 is on merged bars, by their number (`mno`). A price is
a whole number, the price times the data's scale. `stored` is 1 for what the algorithm has settled, 0 for what it has
not yet.
-/
namespace Chanlun

open Lean (ToJson FromJson)

/-- A K-line. -/
structure KLine where
  rno : Nat
  /-- its time, seconds since 1970, UTC -/
  date : Nat
  up : Bool
  «open» : Int
  high : Int
  low : Int
  close : Int
  volume : Nat
  confirmRno : Nat
  confirmDate : Option Nat
  stored : Nat
  deriving Repr, BEq, Inhabited, ToJson, FromJson

/-- 包含's merged bar `mno`: from `startDate` to `endDate`, its first and last K-lines. -/
structure MergedBar where
  rno : Nat
  mno : Nat
  up : Bool
  high : Int
  low : Int
  startDate : Nat
  confirmStartDate : Option Nat
  endDate : Nat
  confirmEndDate : Option Nat
  stored : Nat
  deriving Repr, BEq, Inhabited, ToJson, FromJson

/-- 分型: a top (`ding`) or a bottom at the merged bar `mno`, dated by the algorithm at `date`. -/
structure Fractal where
  rno : Nat
  date : Nat
  mno : Nat
  ding : Bool
  turningpoint : Bool
  high : Int
  low : Int
  confirmStartDate : Option Nat
  confirmEndDate : Option Nat
  confirmTurningPointDate : Option Nat
  stored : Nat
  deriving Repr, BEq, Inhabited, ToJson, FromJson

/-- A line: its level (−2 a 笔, −1 a 线段, L a 走势 of level L), up or down, from the merged bar `startBar` to the
merged bar `endBar`, the algorithm's dates `startDate` and `endDate` beside. -/
structure Line where
  level : Int
  isUp : Bool
  startDate : Nat
  confirmStartDate : Option Nat
  endDate : Nat
  confirmEndDate : Option Nat
  high : Int
  low : Int
  startRno : Nat
  endRno : Nat
  stored : Nat
  startBar : Nat
  endBar : Nat
  deriving Repr, BEq, Inhabited, ToJson, FromJson

/-- 中枢 of level L, from the merged bar `startBar` to the merged bar `endBar`, its band ZD to ZG within its range DD
to GG (at the merged bars `ggBar` and `ddBar`); the algorithm's `buy` to `tp2Rno` kept as their text. -/
structure Centre where
  level : Nat
  startRno : Nat
  startDate : Nat
  endRno : Nat
  endDate : Nat
  entrance : Bool
  exit : Bool
  zg : Int
  zd : Int
  gg : Int
  ggRno : Nat
  ggDate : Nat
  dd : Int
  ddRno : Nat
  ddDate : Nat
  d : Int
  g : Int
  buy : String
  tp0 : String
  tp0Rno : String
  tp1 : String
  tp1Rno : String
  tp2 : String
  tp2Rno : String
  confirmStartDate : Option Nat
  confirmEndDate : Option Nat
  stored : Nat
  startBar : Nat
  endBar : Nat
  ggBar : Nat
  ddBar : Nat
  deriving Repr, BEq, Inhabited, ToJson, FromJson

/-- A run: its K-lines, merged bars, 分型, 笔 (strokes), 线段 (segments), and by level from 0 its 走势 (trends) and
中枢 (centres). -/
structure Run where
  klines : Array KLine
  merged : Array MergedBar
  fractals : Array Fractal
  strokes : Array Line
  segments : Array Line
  trends : Array (Array Line)
  centres : Array (Array Centre)
  deriving Repr, BEq, Inhabited, ToJson, FromJson

/-- The time of the K-line at a position: how a date of a record is turned back into a time. -/
def Run.timeAt (r : Run) (p : Nat) : Option Nat := (r.klines[p]?).map (·.date)

end Chanlun
