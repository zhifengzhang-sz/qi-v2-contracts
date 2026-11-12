import Lean.Data.Json

/-!
# The market data contract's rules

The formal definition of the rules (../README.md). The records are those of `../proto/market.proto`, field for field;
each rule is a name and what holds of a record that keeps it. Go and TypeScript implement the same rules by the same
names, and `../examples.json` holds records with the rules each breaks, which all three check.
-/

namespace Market

/-- A rule of records of `α`: its name, and what holds of a record that keeps it. -/
structure Rule (α : Type) where
  name : String
  holds : α → Prop
  [dec : DecidablePred holds]

/-- The names of the rules of `rules` that `x` breaks, in their order. -/
def broken {α : Type} (rules : List (Rule α)) (x : α) : List String :=
  rules.filterMap fun r => if @decide _ (r.dec x) then none else some r.name

/-- A complete bar. -/
structure KLine where
  index : Nat
  date : Nat
  «open» : Float
  high : Float
  low : Float
  close : Float
  volume : Float
  deriving Lean.FromJson, Repr

/-- A bar still going on. -/
structure OngoingKLine where
  index : Nat
  date : Nat
  «open» : Float
  high : Float
  low : Float
  close : Float
  volume : Float
  asOf : Nat
  deriving Lean.FromJson, Repr

/-- Every price and the volume a finite number. -/
abbrev KLine.finite (k : KLine) : Prop := ∀ x ∈ [k.open, k.high, k.low, k.close, k.volume], x.isFinite

/-- The open and the close within the low and the high. -/
abbrev KLine.range (k : KLine) : Prop := k.low ≤ k.open ∧ k.low ≤ k.close ∧ k.open ≤ k.high ∧ k.close ≤ k.high

/-- The volume not negative. -/
abbrev KLine.volumeNotNegative (k : KLine) : Prop := 0 ≤ k.volume

def KLine.rules : List (Rule KLine) :=
  [⟨"finite", KLine.finite⟩, ⟨"range", KLine.range⟩, ⟨"volumeNotNegative", KLine.volumeNotNegative⟩]

/-- An ongoing K-line's fields as a K-line's. -/
def OngoingKLine.kline (o : OngoingKLine) : KLine := ⟨o.index, o.date, o.open, o.high, o.low, o.close, o.volume⟩

/-- Its values not updated before it began. -/
abbrev OngoingKLine.asOfNotBeforeDate (o : OngoingKLine) : Prop := o.date ≤ o.asOf

/-- An ongoing K-line's rules: its K-line's, and `asOfNotBeforeDate`. -/
def OngoingKLine.rules : List (Rule OngoingKLine) :=
  KLine.rules.map (fun r => @Rule.mk _ r.name (fun o => r.holds o.kline) (fun o => r.dec o.kline)) ++
    [⟨"asOfNotBeforeDate", OngoingKLine.asOfNotBeforeDate⟩]

end Market
