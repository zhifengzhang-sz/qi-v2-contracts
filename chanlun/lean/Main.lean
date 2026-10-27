import Chanlun

/-- A run's JSON decoded and written again as its canonical JSON (the conformance check's Lean side):
`lake exe decode FILE`. A fault to stderr, exit 1. -/
def main (args : List String) : IO UInt32 := do
  match args with
  | [file] =>
    match Chanlun.decodeRun (← IO.FS.readFile file) with
    | .ok run => IO.print (Chanlun.encodeRun run); return 0
    | .error e => IO.eprintln s!"decode: {e}"; return 1
  | _ => IO.eprintln "usage: lake exe decode FILE"; return 1
