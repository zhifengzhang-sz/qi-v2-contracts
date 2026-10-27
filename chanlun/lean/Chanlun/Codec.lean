import Chanlun.Contract

/-!
# A run's records as JSON

How records cross from one project to another (../SPEC.md, The JSON), the same as the TypeScript form's `codec.ts`.
Decoding takes a run's JSON: every object only the fields of its record (a field not there that may be not set is
`none`), each field of its kind, then every record's rules (`Run.check`). Encoding writes the canonical text both forms
write, so that the conformance check compares them as texts: the run's parts in their order, a record a line, its
fields in the order of their names, a field not set left out.
-/

namespace Chanlun

open Lean (Json ToJson FromJson toJson fromJson?)

/-- Each record's fields (../SPEC.md, The records). -/
def fieldsOf : String → List String
  | "klines" => ["rno", "date", "up", "open", "high", "low", "close", "volume", "confirmRno", "confirmDate", "stored"]
  | "merged" => ["rno", "mno", "up", "high", "low", "startDate", "confirmStartDate", "endDate", "confirmEndDate",
      "stored"]
  | "fractals" => ["rno", "date", "mno", "ding", "turningpoint", "high", "low", "confirmStartDate", "confirmEndDate",
      "confirmTurningPointDate", "stored"]
  | "centres" => ["level", "startRno", "startDate", "endRno", "endDate", "entrance", "exit", "zg", "zd", "gg", "ggRno",
      "ggDate", "dd", "ddRno", "ddDate", "d", "g", "buy", "tp0", "tp0Rno", "tp1", "tp1Rno", "tp2", "tp2Rno",
      "confirmStartDate", "confirmEndDate", "stored", "startBar", "endBar", "ggBar", "ddBar"]
  | _ => ["level", "isUp", "startDate", "confirmStartDate", "endDate", "confirmEndDate", "high", "low", "startRno",
      "endRno", "stored", "startBar", "endBar"]

/-- The run's parts, in their order. -/
def parts : List String := ["klines", "merged", "fractals", "strokes", "segments", "trends", "centres"]

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
def strictPart (j : Json) (part : String) : Except String Unit := do
  let arr ← (j.getObjValD part).getArr?.mapError (s!"{part}: " ++ ·)
  let levelled := part == "trends" || part == "centres"
  arr.size.fold (init := .ok ()) fun i _ acc => do
    acc
    if levelled then
      let inner ← (arr[i]!).getArr?.mapError (s!"{part}.{i}: " ++ ·)
      inner.size.fold (init := .ok ()) fun k _ acc2 => do
        acc2
        strict s!"{part}.{i}.{k}" (fieldsOf part) inner[k]!
    else strict s!"{part}.{i}" (fieldsOf part) arr[i]!

/-- A rule over every record of an array, its fault named by its place. -/
def everyOf {α : Type} (at_ : String) (xs : Array α) (rule : α → Option String) : Except String Unit :=
  xs.size.fold (init := .ok ()) fun i _ acc => do
    acc
    match rule xs[i] with
    | some e => .error s!"{at_}.{i}: {e}"
    | none => .ok ()

def storedRule (s : Nat) : Option String := if s ≤ 1 then none else some "stored is 0 or 1"

/-- The records' rules (../SPEC.md, The records), the same as the TypeScript form's schemas. -/
def KLine.rule (k : KLine) : Option String :=
  if !(k.low ≤ min k.open k.close && max k.open k.close ≤ k.high) then
    some "a K-line's open and close within its low and high"
  else storedRule k.stored

def MergedBar.rule (m : MergedBar) : Option String :=
  if !(m.startDate ≤ m.endDate && m.low ≤ m.high) then
    some "a merged bar's first K-line not after its last, its low at most its high"
  else storedRule m.stored

def Fractal.rule (f : Fractal) : Option String :=
  if !(f.low ≤ f.high) then some "a 分型's low at most its high" else storedRule f.stored

def Line.rule (l : Line) : Option String :=
  if !(l.level ≥ -2) then some "a line's level at least -2"
  else if !(l.startBar < l.endBar && l.low < l.high) then
    some "a line from a merged bar to a later one, its low below its high"
  else storedRule l.stored

/-- A text: printable ASCII (U+0020 to U+007E), so that both forms read and write it alike. -/
def printable (s : String) : Bool := s.all fun ch => 0x20 ≤ ch.toNat && ch.toNat ≤ 0x7e

def Centre.rule (c : Centre) : Option String :=
  if !(c.startBar ≤ c.endBar && c.dd ≤ c.zd && c.zd ≤ c.zg && c.zg ≤ c.gg) then
    some "a 中枢 from a merged bar to one not before it, its band ZD to ZG within its range DD to GG"
  else if ![c.buy, c.tp0, c.tp0Rno, c.tp1, c.tp1Rno, c.tp2, c.tp2Rno].all printable then
    some "a text of printable ASCII"
  else storedRule c.stored

/-- Every record's rules, and the run's K-lines at least one, in the order of their times, no time twice. -/
def Run.check (r : Run) : Except String Unit := do
  if r.klines.size = 0 then .error "klines: a run has at least one K-line"
  everyOf "klines" r.klines KLine.rule
  r.klines.size.fold (init := .ok ()) fun i _ acc => do
    acc
    if i > 0 && r.klines[i - 1]!.date ≥ r.klines[i]!.date then
      .error s!"klines.{i}: a run's K-lines in the order of their times, no time twice"
  everyOf "merged" r.merged MergedBar.rule
  everyOf "fractals" r.fractals Fractal.rule
  everyOf "strokes" r.strokes Line.rule
  everyOf "segments" r.segments Line.rule
  r.trends.size.fold (init := .ok ()) fun l _ acc => do acc; everyOf s!"trends.{l}" r.trends[l] Line.rule
  r.centres.size.fold (init := .ok ()) fun l _ acc => do acc; everyOf s!"centres.{l}" r.centres[l] Centre.rule
  -- the run's own rules: the merged bars numbered by their place; every position a K-line's, every bar a merged
  -- bar's; each part's lines and 中枢 of its level
  everyOf "merged" (r.merged.mapIdx (·, ·)) fun (i, m) =>
    if m.mno = i then none else some "a merged bar's number its place among the merged bars"
  let n := r.klines.size
  let b := r.merged.size
  let inRun (ps bs : List (Option Nat)) : Option String :=
    if ps.any (fun p => p.any (· ≥ n)) then some "a position past the run's K-lines"
    else if bs.any (fun x => x.any (· ≥ b)) then some "a merged bar past the run's merged bars"
    else none
  let lineIn (l : Line) := inRun [l.startDate, l.confirmStartDate, l.endDate, l.confirmEndDate] [l.startBar, l.endBar]
  everyOf "klines" r.klines fun k => inRun [k.confirmDate] []
  everyOf "merged" r.merged fun m => inRun [m.startDate, m.confirmStartDate, m.endDate, m.confirmEndDate] [m.mno]
  everyOf "fractals" r.fractals fun f =>
    inRun [f.date, f.confirmStartDate, f.confirmEndDate, f.confirmTurningPointDate] [f.mno]
  everyOf "strokes" r.strokes lineIn
  everyOf "segments" r.segments lineIn
  r.trends.size.fold (init := .ok ()) fun l _ acc => do acc; everyOf s!"trends.{l}" r.trends[l] lineIn
  r.centres.size.fold (init := .ok ()) fun l _ acc => do
    acc
    everyOf s!"centres.{l}" r.centres[l] fun c =>
      inRun [c.startDate, c.endDate, c.ggDate, c.ddDate, c.confirmStartDate, c.confirmEndDate]
        [c.startBar, c.endBar, c.ggBar, c.ddBar]
  let levelOf (want : Int) (l : Line) := if l.level = want then none else some s!"a line here of level {want}"
  everyOf "strokes" r.strokes (levelOf (-2))
  everyOf "segments" r.segments (levelOf (-1))
  r.trends.size.fold (init := .ok ()) fun l _ acc => do acc; everyOf s!"trends.{l}" r.trends[l] (levelOf l)
  r.centres.size.fold (init := .ok ()) fun l _ acc => do
    acc
    everyOf s!"centres.{l}" r.centres[l] fun c => if c.level = l then none else some s!"a 中枢 here of level {l}"

private def numeric (c : Char) : Bool := c.isDigit || c == '-' || c == '+' || c == '.' || c == 'e' || c == 'E'

private def whole (tok : List Char) : Bool :=
  let ds := match tok with | '-' :: rest => rest | _ => tok
  !ds.isEmpty && ds.length ≤ 16 && ds.all Char.isDigit && (ds.length == 1 || ds.head! != '0')

/-- The scan of `literals`: `inStr` within a string, `esc` after its backslash. -/
private partial def scan : List Char → Bool → Bool → Option String
  | [], _, _ => none
  | _ :: rest, true, true => scan rest true false
  | c :: rest, true, false => if c == '\\' then scan rest true true else scan rest (c != '"') false
  | c :: rest, false, _ =>
    if c == '"' then scan rest true false
    else if c.isDigit || c == '-' then
      let tok := c :: rest.takeWhile numeric
      if whole tok then scan (rest.dropWhile numeric) false false else some (String.ofList tok)
    else scan rest false false

/-- Every number of the text written as a whole number, digits only (no fraction, no exponent), of at most 16 digits;
the texts in strings skipped. Checked on the text, before it is parsed, as the TypeScript form checks it (and so a
number such as `1e999999999` is never parsed). The first number that is not, if any. -/
def literals (text : String) : Option String := scan text.toList false false

/-- The largest whole number the contract takes, either way: 2^53 − 1, the largest JSON number every reader holds
exactly. -/
def bound : Int := 9007199254740991

/-- Every number of the JSON within the bound. -/
partial def bounded : Json → Bool
  | .num n => n.exponent == 0 && n.mantissa.natAbs ≤ bound.toNat
  | .arr xs => xs.all bounded
  | .obj kvs => kvs.foldl (fun acc _ v => acc && bounded v) true
  | _ => true

/-- A run's JSON as its records; a fault as a value, its place and message. -/
def decodeRun (text : String) : Except String Run := do
  if let some bad := literals text then
    throw s!"{bad}: a number is a whole number, digits only, at most 16"
  let j ← (Json.parse text).mapError (fun _ => "not JSON")
  if !bounded j then throw s!"a number past {bound} either way"
  strict "the run" parts j
  for p in parts do strictPart j p
  let r : Run ← fromJson? j
  r.check
  return r

/-- A record's JSON, a field not set left out (the derived `ToJson` writes it `null`). A text is printable ASCII, so
`compress` escapes in it only `"` and `\\`, as the TypeScript form's `JSON.stringify` does. -/
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

/-- A run's canonical JSON, of a run the contract allows (`decodeRun`'s, or one `Run.check` passes). -/
def encodeRun (r : Run) : String :=
  "{\n" ++ ",\n".intercalate [
    s!"\"klines\": {records r.klines}",
    s!"\"merged\": {records r.merged}",
    s!"\"fractals\": {records r.fractals}",
    s!"\"strokes\": {records r.strokes}",
    s!"\"segments\": {records r.segments}",
    s!"\"trends\": {levels r.trends}",
    s!"\"centres\": {levels r.centres}"] ++ "\n}\n"

end Chanlun
