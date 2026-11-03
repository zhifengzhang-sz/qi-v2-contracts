import Chanlun

/-- A decoded record written again as its canonical JSON. A fault to stderr, exit 1. -/
def give {α : Type} (encode : α → String) : Except String α → IO UInt32
  | .ok x => do IO.print (encode x); return 0
  | .error e => do IO.eprintln s!"decode: {e}"; return 1

/-- A run's JSON decoded and written again as its canonical JSON (the conformance check's Lean side), with `--massive`
a run of Massive's K-lines, with `--ongoing` an ongoing K-line, of the base or with `--massive` Massive's:
`lake exe decode [--massive] [--ongoing] FILE`. The file's bytes are read as UTF-8, a byte that is not UTF-8 refused. -/
def main (args : List String) : IO UInt32 := do
  let massive := args.contains "--massive"
  let ongoing := args.contains "--ongoing"
  match args.filter (fun a => a != "--massive" && a != "--ongoing") with
  | [file] =>
    if file.startsWith "--" then
      IO.eprintln "usage: lake exe decode [--massive] [--ongoing] FILE"; return 1
    match String.fromUTF8? (← IO.FS.readBinFile file) with
    | none => IO.eprintln "decode: text not UTF-8"; return 1
    | some text =>
      match massive, ongoing with
      | false, false => give Chanlun.encodeRun (Chanlun.decodeRun text)
      | true, false => give Chanlun.encodeRun (Chanlun.decodeMassiveRun text)
      | false, true => give Chanlun.encodeOngoingKLine (Chanlun.decodeOngoingKLine text)
      | true, true => give Chanlun.encodeOngoingKLine (Chanlun.decodeMassiveOngoingKLine text)
  | _ => IO.eprintln "usage: lake exe decode [--massive] [--ongoing] FILE"; return 1
