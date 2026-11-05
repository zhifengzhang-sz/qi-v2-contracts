import Chanlun.Contract

/-!
# A run's records as JSON, and an ongoing K-line's

How records cross from one project to another (../SPEC.md, The JSON), the same as the TypeScript form's `codec.ts`.
Decoding takes a run's JSON: every object only the fields of its record (a field not there that may be not set is
`none`), each field of its kind, then every record's rules (`RunOf.check`). Encoding writes the canonical text every form
writes, so that the conformance check compares them as texts: the run's parts in their order, a record a line, its
fields in the order of their names, a field not set left out.
-/

namespace Chanlun

open Lean (Json ToJson FromJson toJson fromJson?)

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

/-- An object's names. -/
def namesOf (j : Json) : Except String (List String) :=
  match j with
  | .obj kvs => .ok (kvs.foldl (fun acc k _ => acc ++ [k]) [])
  | _ => .error "not an object"

/-- Every name of an object one of `allowed`, and none `null`: a field not set is left out, as the TypeScript form's
schemas have it. -/
def strict (at_ : String) (allowed : List String) (j : Json) : Except String Unit := do
  let names ← (namesOf j).mapError (s!"{at_}: " ++ ·)
  match names.find? (fun n => !allowed.contains n) with
  | some n => .error s!"{at_}: {n} is no field of it"
  | none =>
    match names.find? (fun n => j.getObjValD n == Json.null) with
    | some n => .error s!"{at_}.{n}: null, where a field not set is left out"
    | none => .ok ()

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

/-- The records' rules (../SPEC.md, The records), the same as the TypeScript form's schemas. -/
def KLine.rule (k : KLine) : Option String :=
  if !(k.low ≤ min k.open k.close && max k.open k.close ≤ k.high) then
    some "a K-line's open and close within its low and high"
  else none

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

def Consolidation.rule (c : Consolidation) : Option String :=
  if !(c.start < c.end && c.dd ≤ c.zd && c.zd ≤ c.zg && c.zg ≤ c.gg) then
    some "a 中枢 from a merged bar to a later one, its band ZD to ZG within its range DD to GG"
  else none

/-- Every record's rules, and the run's K-lines at least one, in the order of their times, no time twice. -/
def RunOf.check {K : Type} [KLineOf K] (r : RunOf K) : Except String Unit := do
  let klines := r.klines.map KLineOf.base
  if klines.size = 0 then .error "klines: a run has at least one K-line"
  everyOf "klines" klines KLine.rule
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
  -- `moves` and `consolidations` at most one record going on, the last
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

/-- An ongoing K-line's rules: its K-line's, and `asOf` not before its `date`. -/
def OngoingOf.check {K : Type} [KLineOf K] (o : OngoingOf K) : Except String Unit := do
  let k := KLineOf.base o.kline
  if let some e := k.rule then throw s!"the ongoing K-line: {e}"
  if o.asOf < k.date then throw "the ongoing K-line: its asOf not before its date"

private def numeric (c : Char) : Bool := c.isDigit || c == '-' || c == '+' || c == '.' || c == 'e' || c == 'E'

/-- A number written in digits, no exponent: a whole number of at most 16 digits, or a decimal of at most 6 digits after
the point and 15 from the first that is not 0, the last not 0 (a fraction is a price's or a quantity's only, and they
have no more). -/
private def wellWritten (tok : List Char) : Bool :=
  let ds := match tok with | '-' :: rest => rest | _ => tok
  let whole := ds.takeWhile Char.isDigit
  let wholeOk := !whole.isEmpty && (whole.length == 1 || whole.head! != '0')
  match ds.drop whole.length with
  | [] => wholeOk && whole.length ≤ 16
  | '.' :: fraction =>
    wholeOk && !fraction.isEmpty && fraction.all Char.isDigit && fraction.getLast! != '0' && fraction.length ≤ 6 &&
      ((whole ++ fraction).dropWhile (· == '0')).length ≤ 15
  | _ => false

/-- The scan of `literals`: `inStr` within a string, `esc` after its backslash. -/
private partial def scan : List Char → Bool → Bool → Option String
  | [], _, _ => none
  | _ :: rest, true, true => scan rest true false
  | c :: rest, true, false => if c == '\\' then scan rest true true else scan rest (c != '"') false
  | c :: rest, false, _ =>
    if c == '"' then scan rest true false
    else if c.isDigit || c == '-' then
      let tok := c :: rest.takeWhile numeric
      if wellWritten tok then scan (rest.dropWhile numeric) false false else some (String.ofList tok)
    else scan rest false false

/-- Every number of the text written in digits, as `wellWritten` has it; strings skipped. Checked on the text, before it
is parsed, as the TypeScript form checks it (and so a number such as `1e999999999` is never parsed). The first number
that is not, if any. -/
def literals (text : String) : Option String := scan text.toList false false

/-- A string's characters after its opening `"`, up to its closing one, and what follows it. -/
private partial def stringBody : List Char → List Char → List Char × List Char
  | [], acc => (acc.reverse, [])
  | '\\' :: c :: rest, acc => stringBody rest (c :: '\\' :: acc)
  | '"' :: rest, acc => (acc.reverse, rest)
  | c :: rest, acc => stringBody rest (c :: acc)

/-- The scan of `twice`: for each object or array open around the place, the names of the object so far, or `none`. -/
private partial def twiceScan : List Char → List (Option (List String)) → Option String
  | [], _ => none
  | '{' :: rest, open_ => twiceScan rest (some [] :: open_)
  | '[' :: rest, open_ => twiceScan rest (none :: open_)
  | '}' :: rest, open_ => twiceScan rest open_.tail
  | ']' :: rest, open_ => twiceScan rest open_.tail
  | '"' :: rest, open_ =>
    let (body, after) := stringBody rest []
    match after.dropWhile Char.isWhitespace, open_ with
    | ':' :: _, some names :: up =>
      let raw := String.ofList body
      let name := match Json.parse s!"\"{raw}\"" with
        | .ok (.str s) => s
        | _ => raw
      if names.contains name then some name else twiceScan after (some (name :: names) :: up)
    | _, _ => twiceScan after open_
  | _ :: rest, open_ => twiceScan rest open_

/-- The first name given twice in one object of the text, if any; the text JSON. `Json.parse` keeps one of the two. -/
def twice (text : String) : Option String := twiceScan text.toList []

/-- The largest whole number the contract takes, either way: 2^53 − 1, the largest JSON number every reader holds
exactly. -/
def bound : Int := 9007199254740991

/-- Every whole number of the JSON within the bound (a decimal is bounded by its digits, by `literals`). -/
partial def bounded : Json → Bool
  | .num n => n.exponent > 0 || n.mantissa.natAbs ≤ bound.toNat
  | .arr xs => xs.all bounded
  | .obj kvs => kvs.foldl (fun acc _ v => acc && bounded v) true
  | _ => true

/-- A JSON text as JSON, its numbers well written and within the bound, no name twice in one object. -/
def parsed (text : String) : Except String Json := do
  if let some bad := literals text then
    throw s!"{bad}: a number in digits, a whole number of at most 16, a decimal of at most 6 after the point and 15 in all"
  let j ← (Json.parse text).mapError (fun _ => "not JSON")
  if let some name := twice text then throw s!"{name}: a name twice in one object"
  if !bounded j then throw s!"a number past {bound} either way"
  return j

/-- A run's JSON as its records, K-lines of `K`; a fault as a value, its place and message. -/
def decodeOf (K : Type) [KLineOf K] [FromJson K] (text : String) : Except String (RunOf K) := do
  let j ← parsed text
  strict "the run" parts j
  for p in parts do strictPart (fieldsOf (KLineOf.fields K)) j p
  let r : RunOf K ← fromJson? j
  r.check
  return r

/-- An ongoing K-line's JSON as its record, a K-line of `K`; a fault as a value, its place and message. -/
def decodeOngoingOf (K : Type) [KLineOf K] [FromJson K] (text : String) : Except String (OngoingOf K) := do
  let j ← parsed text
  strict "the ongoing K-line" (KLineOf.fields K ++ ["asOf"]) j
  let o : OngoingOf K ← fromJson? j
  o.check
  return o

/-- An ongoing K-line of the base contract as its record. -/
def decodeOngoingKLine (text : String) : Except String OngoingKLine := decodeOngoingOf KLine text

/-- Massive's ongoing K-line as its record. -/
def decodeMassiveOngoingKLine (text : String) : Except String MassiveOngoingKLine := decodeOngoingOf MassiveKLine text

/-- A run of the base contract's K-lines as its records. -/
def decodeRun (text : String) : Except String Run := decodeOf KLine text

/-- A run of Massive's K-lines as its records. -/
def decodeMassiveRun (text : String) : Except String MassiveRun := decodeOf MassiveKLine text

/-- A record's JSON, a field not set left out (the derived `ToJson` writes it `null`). -/
private def record {α : Type} [ToJson α] (x : α) : String :=
  match toJson x with
  | .obj kvs => (Json.mkObj (kvs.foldl (fun acc k v => if v == Json.null then acc else acc ++ [(k, v)]) [])).compress
  | j => j.compress

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

/-- An ongoing K-line's canonical JSON, of one the contract allows: its record, and a line break. -/
def encodeOngoingKLine {K : Type} [ToJson K] (o : OngoingOf K) : String := record o ++ "\n"

end Chanlun
