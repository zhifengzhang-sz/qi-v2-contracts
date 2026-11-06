import Market.Contract

/-!
# The records as JSON

How records cross from one project to another (../SPEC.md, The JSON), the same as the TypeScript form's `codec.ts`.
Decoding takes an ongoing K-line's JSON: the object only the fields of its record, each field of its kind, then its
rules (`OngoingOf.check`). Encoding writes the canonical text every form writes, so that the conformance check compares
them as texts: a record's fields in the order of their names, a field not set left out. A contract built on this one
reads and writes its own records by the same (`parsed`, `strict`, `record`): 缠论's run.
-/

namespace Market

open Lean (Json ToJson FromJson toJson fromJson?)

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

/-- A K-line's rule (../SPEC.md, K-line), the same as the TypeScript form's schema. -/
def KLine.rule (k : KLine) : Option String :=
  if !(k.low ≤ min k.open k.close && max k.open k.close ≤ k.high) then
    some "a K-line's open and close within its low and high"
  else none

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

/-- A record's JSON, a field not set left out (the derived `ToJson` writes it `null`). -/
def record {α : Type} [ToJson α] (x : α) : String :=
  match toJson x with
  | .obj kvs => (Json.mkObj (kvs.foldl (fun acc k v => if v == Json.null then acc else acc ++ [(k, v)]) [])).compress
  | j => j.compress

/-- An ongoing K-line's canonical JSON, of one the contract allows: its record, and a line break. -/
def encodeOngoingKLine {K : Type} [ToJson K] (o : OngoingOf K) : String := record o ++ "\n"

end Market
