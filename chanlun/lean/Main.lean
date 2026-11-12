import Chanlun

/-! The examples (../examples.json) checked against the rules: each record breaks exactly the rules it names. -/

open Lean

def brokenBy {α : Type} [FromJson α] (rules : List (Chanlun.Rule α)) (value : Json) : Except String (List String) :=
  Chanlun.broken rules <$> fromJson? value

def check (record : String) : Json → Except String (List String) :=
  match record with
  | "MergedBar" => brokenBy Chanlun.MergedBar.rules
  | "Fractal" => brokenBy Chanlun.Fractal.rules
  | "Line" => brokenBy Chanlun.Line.rules
  | "Segment" => brokenBy Chanlun.Segment.rules
  | "Move" => brokenBy Chanlun.Move.rules
  | "Consolidation" => brokenBy Chanlun.Consolidation.rules
  | _ => fun _ => throw s!"{record}: no such record"

def main (args : List String) : IO UInt32 := do
  let [path] := args | IO.eprintln "usage: examples <examples.json>"; return 2
  let examples ← IO.ofExcept ((Json.parse (← IO.FS.readFile path)) >>= Json.getArr?)
  let mut wrong := 0
  for e in examples do
    let record ← IO.ofExcept (e.getObjValAs? String "record")
    let breaks ← IO.ofExcept (e.getObjValAs? (List String) "breaks")
    let got ← IO.ofExcept (check record (e.getObjValD "value"))
    if got != breaks then
      IO.eprintln s!"{e.compress}: breaks {got}"
      wrong := wrong + 1
  IO.println s!"examples: {examples.size - wrong} of {examples.size} break the rules they name"
  return if wrong == 0 then 0 else 1
