import Lean.Data.Json

/-!
# The market data's records

The K-lines, of whatever source gives them (../SPEC.md, The records), the same as the TypeScript form's
`contracts.ts`: the K-line of the base, and its ongoing K-line. They cross from one project to another as JSON
(`Market/Codec.lean`).

A K-line's `date` is its begin time, milliseconds since 1970, UTC. A price and a quantity are decimals, held exactly. A
contract derived from this one takes its units and its JSON (`Market/Codec.lean`), refers to its K-lines by their
positions, and holds none; a taker of a record of its own, a source's K-line with fields of its own among them, takes
the K-line and its units (`KLineOf`, `OngoingOf`).
-/
namespace Market

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
  /-- its place in its series, from 0 -/
  index : Nat
  /-- its begin time, milliseconds since 1970, UTC -/
  date : Nat
  «open» : Price
  high : Price
  low : Price
  close : Price
  volume : Quantity
  deriving Repr, BEq, Inhabited, ToJson, FromJson

/-- What the rules and the decoding of an ongoing K-line made over a K-line (`OngoingOf.check`, `decodeOngoingOf`)
need of it, the base contract's or a taker's own with fields of its own (../SPEC.md, K-line): the base's fields, and
the names of its fields. A contract derived from this one takes its units and its JSON, refers to its K-lines by
their positions, and holds none: it needs none of this. -/
class KLineOf (K : Type) where
  base : K → KLine
  fields : List String

instance : KLineOf KLine where
  base := id
  fields := ["index", "date", "open", "high", "low", "close", "volume"]

/-- The ongoing K-line, made over a K-line `K`: its K-line's fields and rule, `index` the place it will take when
complete, and `asOf`, when its values were last updated, not before its `date`. A bar still going on, in no series yet.
Its JSON is one object: the K-line's fields and `asOf`. -/
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

end Market
