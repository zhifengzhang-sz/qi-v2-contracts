import Lean.Data.Json

/-!
# 缠论's records

The algorithm's records, of whatever implementation gives them (../SPEC.md, The records), the same as the TypeScript
form's `contracts.ts`. The algorithm is a chain, and so are its records: the K-line, then 包含's merged bar, 分型 at a
merged bar, the lines (笔, 线段, and 走势 of level L), and 中枢 of level L. They cross from one project to another as JSON
(`Chanlun/Codec.lean`).

A K-line's `date` is its begin time, milliseconds since 1970, UTC. Every configuration after 包含 is on merged bars, by
their number (a merged bar's `mIndex`). A price and a quantity are decimals, held exactly. A configuration still going
on, a merged bar still merging, a line not yet ended, a 中枢 under construction, has no `confirmEnd` (`none`): one rule
for the three, and in a run at most one record of a part, or of a level, is going on, the last (`Chanlun/Codec.lean`).
-/
namespace Chanlun

open Lean (Json JsonNumber ToJson FromJson)

/-- A decimal as the contract writes it (../SPEC.md, Units): at most 6 digits after the point and at most 15 from the
first that is not 0, of a number as read, whose mantissa holds those digits. -/
def decimal (n : JsonNumber) : Bool :=
  n.exponent ≤ 6 && (Nat.repr n.mantissa.natAbs).length ≤ 15

/-- Two decimals compared exactly, `a ≤ b`. -/
def decimalLE (a b : JsonNumber) : Bool :=
  a.mantissa * (10 : Int) ^ b.exponent ≤ b.mantissa * (10 : Int) ^ a.exponent

/-- Two decimals compared exactly, `a = b` as values: `1.5` written as ⟨15, 1⟩ or ⟨1500, 3⟩ is the one value. -/
def decimalEq (a b : JsonNumber) : Bool :=
  a.mantissa * (10 : Int) ^ b.exponent == b.mantissa * (10 : Int) ^ a.exponent

/-- A price: a decimal, held exactly, `value.mantissa` × 10^−`value.exponent`; `==` and `≤` compare values. -/
structure Price where
  value : JsonNumber
  deriving Repr, Inhabited

instance : BEq Price := ⟨fun a b => decimalEq a.value b.value⟩
instance : ToJson Price := ⟨fun p => .num p.value⟩
instance : FromJson Price := ⟨fun j => do
  let n ← j.getNum?
  if decimal n then pure ⟨n⟩
  else throw s!"{n}: a price a decimal of at most 6 digits after the point and 15 from the first that is not 0"⟩
instance : LE Price := ⟨fun a b => decimalLE a.value b.value = true⟩
instance (a b : Price) : Decidable (a ≤ b) := inferInstanceAs (Decidable (decimalLE a.value b.value = true))
instance : Min Price := minOfLe
instance : Max Price := maxOfLe

/-- A quantity: a decimal as a price is, not negative; `==` compares values. -/
structure Quantity where
  value : JsonNumber
  deriving Repr, Inhabited

instance : BEq Quantity := ⟨fun a b => decimalEq a.value b.value⟩
instance : ToJson Quantity := ⟨fun q => .num q.value⟩
instance : FromJson Quantity := ⟨fun j => do
  let n ← j.getNum?
  if decimal n && n.mantissa ≥ 0 then pure ⟨n⟩
  else throw s!"{n}: a quantity a decimal as a price is, not negative"⟩

/-- A K-line, the base contract, 7 fields: a complete bar. -/
structure KLine where
  /-- its place in the run, from 0 -/
  index : Nat
  /-- its begin time, milliseconds since 1970, UTC -/
  date : Nat
  «open» : Price
  high : Price
  low : Price
  close : Price
  volume : Quantity
  deriving Repr, BEq, Inhabited, ToJson, FromJson

/-- Massive's K-line, 9 fields: the base, and `vw` and `n` of Massive's row; its `date` the row's `t`. -/
structure MassiveKLine extends KLine where
  vw : Price
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

/-- The ongoing K-line of a data source, defined once over the source's K-line `K`, as the run is: its K-line's fields
and rule, `index` the place it will take when complete, and `asOf`, when its values were last updated, not before its
`date`. A bar still going on, in no run. Its JSON is one object: the K-line's fields and `asOf`. -/
structure OngoingOf (K : Type) where
  kline : K
  asOf : Nat
  deriving Repr, BEq, Inhabited

instance {K : Type} [ToJson K] : ToJson (OngoingOf K) :=
  ⟨fun o => (Lean.toJson o.kline).setObjVal! "asOf" (Lean.toJson o.asOf)⟩
instance {K : Type} [FromJson K] : FromJson (OngoingOf K) :=
  ⟨fun j => do
    let kline ← Lean.fromJson? j
    let asOf ← (j.getObjVal? "asOf").mapError (fun _ => "asOf: a field missing")
    return ⟨kline, ← (Lean.fromJson? asOf).mapError (s!"asOf: " ++ ·)⟩⟩

/-- The ongoing K-line of the base contract. -/
abbrev OngoingKLine := OngoingOf KLine

/-- Massive's ongoing K-line. -/
abbrev MassiveOngoingKLine := OngoingOf MassiveKLine

/-- 包含's merged bar `mIndex`: from `start` to `end`, its first and last K-lines; `extremes` the K-lines of its extreme,
of its high when it goes up, of its low when it goes down, at least one, each from `start` to `end`, in ascending order,
none twice; `index` one of `extremes`: the K-line that represents the merged bar. The contract does not say which one is
chosen. `confirmEnd` the K-line that confirmed its end, `none` while it is still merging. -/
structure MergedBar where
  index : Nat
  mIndex : Nat
  up : Bool
  high : Price
  low : Price
  start : Nat
  «end» : Nat
  confirmEnd : Option Nat
  extremes : Array Nat
  deriving Repr, BEq, Inhabited, ToJson, FromJson

/-- 分型: its merged bar, `mIndex`. -/
structure Fractal where
  mIndex : Nat
  deriving Repr, BEq, Inhabited, ToJson, FromJson

/-- A line: from the merged bar `start` to the merged bar `end`, `confirmEnd` the merged bar at which it was confirmed,
`none` while it is still going on. -/
structure Line where
  start : Nat
  «end» : Nat
  confirmEnd : Option Nat
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
  zg : Price
  zd : Price
  gg : Price
  dd : Price
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
