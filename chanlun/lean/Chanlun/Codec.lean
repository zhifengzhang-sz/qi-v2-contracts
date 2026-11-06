import Chanlun.Contract

/-!
# A run's records as JSON

How records cross from one project to another (../SPEC.md, The JSON), the same as the TypeScript form's `codec.ts`,
under market's JSON (`Market.parsed`, `Market.strict`, `Market.record`).
Decoding takes a run's JSON: every object only the fields of its record (a field not there that may be not set is
`none`), each field of its kind, then every record's rules (`RunOf.check`). Encoding writes the canonical text every form
writes, so that the conformance check compares them as texts: the run's parts in their order, a record a line, its
fields in the order of their names, a field not set left out.
-/

namespace Chanlun

open Lean (Json ToJson FromJson toJson fromJson?)
open Market (KLine MassiveKLine KLineOf parsed strict record)

/-- Each record's fields (../SPEC.md, The records), the K-line's those of the run's. -/
def fieldsOf (klines : List String) : String → List String
  | "klines" => klines
  | "merged" => ["index", "mIndex", "up", "high", "low", "start", "end", "confirmEnd", "extremes"]
  | "fractals" => ["mIndex"]
  | "segments" | "moves" => ["start", "end", "confirmEnd", "level"]
  | "consolidations" => ["level", "start", "end", "confirmEnd", "zg", "zd", "gg", "dd"]
  | _ => ["start", "end", "confirmEnd"]

/-- The run's parts, in their order. -/
def parts : List String := ["klines", "merged", "fractals", "strokes", "segments", "moves", "consolidations"]

/-- Every record of a part's array, or of each level's array, only the fields of its record. -/
def strictPart (fields : String → List String) (j : Json) (part : String) : Except String Unit := do
  let arr ← (j.getObjValD part).getArr?.mapError (s!"{part}: " ++ ·)
  let levelled := part == "segments" || part == "moves" || part == "consolidations"
  arr.size.fold (init := .ok ()) fun i _ acc => do
    acc
    if levelled then
      let inner ← (arr[i]!).getArr?.mapError (s!"{part}.{i}: " ++ ·)
      inner.size.fold (init := .ok ()) fun k _ acc2 => do
        acc2
        strict s!"{part}.{i}.{k}" (fields part) inner[k]!
    else strict s!"{part}.{i}" (fields part) arr[i]!

/-- A rule over every record of an array, its fault named by its place. -/
def everyOf {α : Type} (at_ : String) (xs : Array α) (rule : α → Option String) : Except String Unit :=
  xs.size.fold (init := .ok ()) fun i _ acc => do
    acc
    match rule xs[i] with
    | some e => .error s!"{at_}.{i}: {e}"
    | none => .ok ()

/-- The records' rules (../SPEC.md, The records), the same as the TypeScript form's schemas; a K-line's, market's
(`Market.KLine.rule`). -/
def MergedBar.rule (m : MergedBar) : Option String :=
  if !(m.start ≤ m.end && m.low ≤ m.high) then
    some "a merged bar's first K-line not after its last, its low at most its high"
  else if m.extremes.isEmpty then some "a merged bar's extremes hold at least one K-line"
  else if !m.extremes.contains m.index then some "a merged bar's index one of its extremes"
  else if !m.extremes.all (fun p => m.start ≤ p && p ≤ m.end) then
    some "a merged bar's extremes from its start to its end"
  else if !(List.range (m.extremes.size - 1)).all (fun i => m.extremes[i]! < m.extremes[i + 1]!) then
    some "a merged bar's extremes in ascending order, none twice"
  else none

def Line.rule (l : Line) : Option String :=
  if l.start < l.end then none else some "a line from a merged bar to a later one"

/-- A run's records strictly increasing by `start`, given their starts. -/
def startsRise (at_ name : String) (starts : Array Nat) : Except String Unit :=
  starts.size.fold (init := .ok ()) fun i _ acc => do
    acc
    if i > 0 && starts[i - 1]! ≥ starts[i]! then
      .error s!"{at_}.{i}: a run's {name} strictly increasing by start"

/-- At most one record of a part, or of a level, going on (its `confirmEnd` not set), and it the last. -/
def ongoingLast (at_ name : String) (ends : Array (Option Nat)) : Except String Unit :=
  ends.size.fold (init := .ok ()) fun i _ acc => do
    acc
    if i + 1 < ends.size && ends[i]!.isNone then
      .error s!"{at_}.{i}: a run's {name} every one confirmed but the last"

/-- A part by level ends with a level that is not empty: its levels 0 to its highest with a record, `[]` if none, so
that one run has one text. Given its levels' sizes. -/
def lastLevel (part : String) (sizes : Array Nat) : Except String Unit :=
  match sizes.back? with
  | some 0 => .error s!"{part}.{sizes.size - 1}: a part by level's last level not empty"
  | _ => .ok ()

def Consolidation.rule (c : Consolidation) : Option String :=
  if !(c.start < c.end && c.dd ≤ c.zd && c.zd ≤ c.zg && c.zg ≤ c.gg) then
    some "a 中枢 from a merged bar to a later one, its band ZD to ZG within its range DD to GG"
  else none

/-- Every record's rules, and the run's K-lines at least one, in the order of their times, no time twice. -/
def RunOf.check {K : Type} [KLineOf K] (r : RunOf K) : Except String Unit := do
  let klines := r.klines.map KLineOf.base
  if klines.size = 0 then .error "klines: a run has at least one K-line"
  everyOf "klines" klines Market.KLine.rule
  klines.size.fold (init := .ok ()) fun i _ acc => do
    acc
    if i > 0 && klines[i - 1]!.date ≥ klines[i]!.date then
      .error s!"klines.{i}: a run's K-lines in the order of their times, no time twice"
  everyOf "merged" r.merged MergedBar.rule
  everyOf "strokes" r.strokes Line.rule
  r.segments.size.fold (init := .ok ()) fun l _ acc => do
    acc
    everyOf s!"segments.{l}" (r.segments[l].map (·.toLine)) Line.rule
  r.moves.size.fold (init := .ok ()) fun l _ acc => do
    acc
    everyOf s!"moves.{l}" (r.moves[l].map (·.toLine)) Line.rule
  r.consolidations.size.fold (init := .ok ()) fun l _ acc => do
    acc
    everyOf s!"consolidations.{l}" r.consolidations[l] Consolidation.rule
  -- the run's own rules: the K-lines and merged bars numbered by their place; the 分型 strictly increasing by `mIndex`;
  -- the 笔 and each level's 线段, 走势 and 中枢 strictly increasing by `start`; every position a K-line's, every bar a
  -- merged bar's; each level's 线段, 走势 and 中枢 of that level; in `merged`, in `strokes` and in each level of `segments`,
  -- `moves` and `consolidations` at most one record going on, the last; each part by level ending with a level that is
  -- not empty
  lastLevel "segments" (r.segments.map (·.size))
  lastLevel "moves" (r.moves.map (·.size))
  lastLevel "consolidations" (r.consolidations.map (·.size))
  r.fractals.size.fold (init := .ok ()) fun i _ acc => do
    acc
    if i > 0 && r.fractals[i - 1]!.mIndex ≥ r.fractals[i]!.mIndex then
      .error s!"fractals.{i}: a run's 分型 strictly increasing by mIndex"
  startsRise "strokes" "笔" (r.strokes.map (·.start))
  r.segments.size.fold (init := .ok ()) fun l _ acc => do
    acc
    startsRise s!"segments.{l}" "线段" (r.segments[l].map (·.start))
  r.moves.size.fold (init := .ok ()) fun l _ acc => do
    acc
    startsRise s!"moves.{l}" "走势" (r.moves[l].map (·.start))
  r.consolidations.size.fold (init := .ok ()) fun l _ acc => do
    acc
    startsRise s!"consolidations.{l}" "中枢" (r.consolidations[l].map (·.start))
  ongoingLast "merged" "merged bars" (r.merged.map (·.confirmEnd))
  ongoingLast "strokes" "笔" (r.strokes.map (·.confirmEnd))
  r.segments.size.fold (init := .ok ()) fun l _ acc => do
    acc
    ongoingLast s!"segments.{l}" "线段" (r.segments[l].map (·.confirmEnd))
  r.moves.size.fold (init := .ok ()) fun l _ acc => do
    acc
    ongoingLast s!"moves.{l}" "走势" (r.moves[l].map (·.confirmEnd))
  r.consolidations.size.fold (init := .ok ()) fun l _ acc => do
    acc
    ongoingLast s!"consolidations.{l}" "中枢" (r.consolidations[l].map (·.confirmEnd))
  everyOf "klines" (klines.mapIdx (·, ·)) fun (i, k) =>
    if k.index = i then none else some "a K-line's index its place in the run"
  everyOf "merged" (r.merged.mapIdx (·, ·)) fun (i, m) =>
    if m.mIndex = i then none else some "a merged bar's number its place among the merged bars"
  let n := klines.size
  let b := r.merged.size
  let inRun (ps bs : List (Option Nat)) : Option String :=
    if ps.any (fun p => p.any (· ≥ n)) then some "a position past the run's K-lines"
    else if bs.any (fun x => x.any (· ≥ b)) then some "a merged bar past the run's merged bars"
    else none
  let lineIn (l : Line) := inRun [] [some l.start, some l.end, l.confirmEnd]
  everyOf "merged" r.merged fun m =>
    inRun (([m.index, m.start, m.end, m.confirmEnd] : List (Option Nat)) ++ m.extremes.toList.map some)
      [m.mIndex]
  everyOf "fractals" r.fractals fun f => inRun [] [f.mIndex]
  everyOf "strokes" r.strokes lineIn
  r.segments.size.fold (init := .ok ()) fun l _ acc => do
    acc
    everyOf s!"segments.{l}" r.segments[l] (lineIn ·.toLine)
  r.segments.size.fold (init := .ok ()) fun l _ acc => do
    acc
    everyOf s!"segments.{l}" r.segments[l] fun s => if s.level = l then none else some s!"a 线段 here of level {l}"
  r.moves.size.fold (init := .ok ()) fun l _ acc => do
    acc
    everyOf s!"moves.{l}" r.moves[l] (lineIn ·.toLine)
  r.moves.size.fold (init := .ok ()) fun l _ acc => do
    acc
    everyOf s!"moves.{l}" r.moves[l] fun m => if m.level = l then none else some s!"a 走势 here of level {l}"
  r.consolidations.size.fold (init := .ok ()) fun l _ acc => do
    acc
    everyOf s!"consolidations.{l}" r.consolidations[l] fun c =>
      inRun [] [c.start, c.end, c.confirmEnd]
  r.consolidations.size.fold (init := .ok ()) fun l _ acc => do
    acc
    everyOf s!"consolidations.{l}" r.consolidations[l] fun c =>
      if c.level = l then none else some s!"a 中枢 here of level {l}"

/-- A run's JSON as its records, K-lines of `K`; a fault as a value, its place and message. -/
def decodeOf (K : Type) [KLineOf K] [FromJson K] (text : String) : Except String (RunOf K) := do
  let j ← parsed text
  strict "the run" parts j
  for p in parts do strictPart (fieldsOf (KLineOf.fields K)) j p
  let r : RunOf K ← fromJson? j
  r.check
  return r

/-- A run of the base contract's K-lines as its records. -/
def decodeRun (text : String) : Except String Run := decodeOf KLine text

/-- A run of Massive's K-lines as its records. -/
def decodeMassiveRun (text : String) : Except String MassiveRun := decodeOf MassiveKLine text

private def records {α : Type} [ToJson α] (xs : Array α) : String :=
  if xs.isEmpty then "[]"
  else "[\n" ++ ",\n".intercalate (xs.toList.map record) ++ "\n]"

private def levels {α : Type} [ToJson α] (xss : Array (Array α)) : String :=
  if xss.isEmpty then "[]"
  else "[\n" ++ ",\n".intercalate (xss.toList.map records) ++ "\n]"

/-- A run's canonical JSON, of a run the contract allows (`decodeOf`'s, or one `RunOf.check` passes). -/
def encodeRun {K : Type} [ToJson K] (r : RunOf K) : String :=
  "{\n" ++ ",\n".intercalate [
    s!"\"klines\": {records r.klines}",
    s!"\"merged\": {records r.merged}",
    s!"\"fractals\": {records r.fractals}",
    s!"\"strokes\": {records r.strokes}",
    s!"\"segments\": {levels r.segments}",
    s!"\"moves\": {levels r.moves}",
    s!"\"consolidations\": {levels r.consolidations}"] ++ "\n}\n"

end Chanlun
