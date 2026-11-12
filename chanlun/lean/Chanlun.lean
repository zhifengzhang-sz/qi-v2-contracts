import Lean.Data.Json

/-!
# 缠论's contract's rules

The formal definition of the rules (../README.md). The records are those of `../proto/chanlun.proto`, field for field;
each rule is a name and what holds of a record that keeps it. Each rule is of one record alone. Go and TypeScript
implement the same rules by the same names, and `../examples.json` holds records with the rules each breaks, which all
three check.
-/

namespace Chanlun

/-- A rule of records of `α`: its name, and what holds of a record that keeps it. -/
structure Rule (α : Type) where
  name : String
  holds : α → Prop
  [dec : DecidablePred holds]

/-- The names of the rules of `rules` that `x` breaks, in their order. -/
def broken {α : Type} (rules : List (Rule α)) (x : α) : List String :=
  rules.filterMap fun r => if @decide _ (r.dec x) then none else some r.name

/-- 包含's merged bar. -/
structure MergedBar where
  mIndex : Nat
  up : Bool
  start : Nat
  «end» : Nat
  confirmEnd : Option Nat
  extremes : List Nat
  index : Nat
  high : Float
  low : Float
  deriving Lean.FromJson, Repr

/-- 分型. -/
structure Fractal where
  mIndex : Nat
  deriving Lean.FromJson, Repr

/-- A line: a 笔. -/
structure Line where
  start : Nat
  «end» : Nat
  confirmEnd : Option Nat
  deriving Lean.FromJson, Repr

/-- 线段 of a level. -/
structure Segment where
  start : Nat
  «end» : Nat
  confirmEnd : Option Nat
  level : Nat
  deriving Lean.FromJson, Repr

/-- 走势 of a level. -/
structure Move where
  start : Nat
  «end» : Nat
  confirmEnd : Option Nat
  level : Nat
  deriving Lean.FromJson, Repr

/-- 中枢 of a level. -/
structure Consolidation where
  level : Nat
  start : Nat
  «end» : Nat
  confirmEnd : Option Nat
  zg : Float
  zd : Float
  gg : Float
  dd : Float
  deriving Lean.FromJson, Repr

/-- Its high and its low finite numbers. -/
abbrev MergedBar.finite (m : MergedBar) : Prop := m.high.isFinite ∧ m.low.isFinite

/-- Its low not above its high. -/
abbrev MergedBar.range (m : MergedBar) : Prop := m.low ≤ m.high

/-- Each of its extremes from its first K-line to its last. -/
abbrev MergedBar.extremesWithin (m : MergedBar) : Prop := ∀ p ∈ m.extremes, m.start ≤ p ∧ p ≤ m.«end»

/-- Its extremes in ascending order, none twice. -/
abbrev MergedBar.extremesAscending (m : MergedBar) : Prop := m.extremes.Pairwise (· < ·)

/-- Its index one of its extremes. -/
abbrev MergedBar.indexInExtremes (m : MergedBar) : Prop := m.index ∈ m.extremes

def MergedBar.rules : List (Rule MergedBar) :=
  [⟨"finite", MergedBar.finite⟩, ⟨"range", MergedBar.range⟩, ⟨"extremesWithin", MergedBar.extremesWithin⟩,
    ⟨"extremesAscending", MergedBar.extremesAscending⟩, ⟨"indexInExtremes", MergedBar.indexInExtremes⟩]

/-- Why no rule says a merged bar's first K-line is not after its last: its index is one of its extremes, which are
from its first to its last. -/
theorem MergedBar.startNotAfterEnd (m : MergedBar) (h : m.indexInExtremes) (w : m.extremesWithin) :
    m.start ≤ m.«end» :=
  Nat.le_trans (w m.index h).1 (w m.index h).2

/-- A 分型 has no rule. -/
def Fractal.rules : List (Rule Fractal) := []

/-- Its start before its end. -/
abbrev Line.startBeforeEnd (l : Line) : Prop := l.start < l.«end»

def Line.rules : List (Rule Line) := [⟨"startBeforeEnd", Line.startBeforeEnd⟩]

/-- Its start before its end. -/
abbrev Segment.startBeforeEnd (s : Segment) : Prop := s.start < s.«end»

def Segment.rules : List (Rule Segment) := [⟨"startBeforeEnd", Segment.startBeforeEnd⟩]

/-- Its start before its end. -/
abbrev Move.startBeforeEnd (m : Move) : Prop := m.start < m.«end»

def Move.rules : List (Rule Move) := [⟨"startBeforeEnd", Move.startBeforeEnd⟩]

/-- Its band and its range finite numbers. -/
abbrev Consolidation.finite (c : Consolidation) : Prop := ∀ x ∈ [c.zg, c.zd, c.gg, c.dd], x.isFinite

/-- Its start before its end. -/
abbrev Consolidation.startBeforeEnd (c : Consolidation) : Prop := c.start < c.«end»

/-- Its band, ZD to ZG, within its range, DD to GG. -/
abbrev Consolidation.bands (c : Consolidation) : Prop := c.dd ≤ c.zd ∧ c.zd ≤ c.zg ∧ c.zg ≤ c.gg

def Consolidation.rules : List (Rule Consolidation) :=
  [⟨"finite", Consolidation.finite⟩, ⟨"startBeforeEnd", Consolidation.startBeforeEnd⟩,
    ⟨"bands", Consolidation.bands⟩]

end Chanlun
