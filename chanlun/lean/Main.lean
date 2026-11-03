import Chanlun

/-- A decoded run written again as its canonical JSON. A fault to stderr, exit 1. -/
def give {K : Type} [Lean.ToJson K] : Except String (Chanlun.RunOf K) → IO UInt32
  | .ok run => do IO.print (Chanlun.encodeRun run); return 0
  | .error e => do IO.eprintln s!"decode: {e}"; return 1

/-- A run's JSON decoded and written again as its canonical JSON (the conformance check's Lean side), with `--massive`
a run of Massive's K-lines: `lake exe decode [--massive] FILE`. -/
def main (args : List String) : IO UInt32 := do
  match args with
  | [file] => give (Chanlun.decodeRun (← IO.FS.readFile file))
  | ["--massive", file] => give (Chanlun.decodeMassiveRun (← IO.FS.readFile file))
  | _ => IO.eprintln "usage: lake exe decode [--massive] FILE"; return 1
