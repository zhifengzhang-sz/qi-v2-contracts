import Chanlun

/-- A file's bytes as its answer: its canonical text, or its fault. -/
def answer (massive ongoing : Bool) (bytes : ByteArray) : Except String String :=
  match String.fromUTF8? bytes with
  | none => .error "text not UTF-8"
  | some text =>
    match massive, ongoing with
    | false, false => Chanlun.encodeRun <$> Chanlun.decodeRun text
    | true, false => Chanlun.encodeRun <$> Chanlun.decodeMassiveRun text
    | false, true => Chanlun.encodeOngoingKLine <$> Chanlun.decodeOngoingKLine text
    | true, true => Chanlun.encodeOngoingKLine <$> Chanlun.decodeMassiveOngoingKLine text

def usage : String :=
  "usage: lake exe decode [--massive] [--ongoing] FILE | [--massive] [--ongoing] --batch IN OUT"

/-- A run's JSON decoded and written again as its canonical JSON (the conformance check's Lean side), with `--massive`
a run of Massive's K-lines, with `--ongoing` an ongoing K-line, of the base or with `--massive` Massive's:
`lake exe decode [--massive] [--ongoing] FILE`. The file's bytes are read as UTF-8, a byte that is not UTF-8 refused. A
fault to stderr, exit 1. With `--batch IN OUT`, every `.json` file of the folder `IN`, in the order of their names,
decoded so in one process (the generated cases, ../vectors/cases.ts), each one's answer written to `OUT` under its
name: its canonical text, or the line `decode: ` and its fault. -/
def main (args : List String) : IO UInt32 := do
  let massive := args.contains "--massive"
  let ongoing := args.contains "--ongoing"
  let batch := args.contains "--batch"
  match batch, args.filter (fun a => a != "--massive" && a != "--ongoing" && a != "--batch") with
  | false, [file] =>
    if file.startsWith "--" then
      IO.eprintln usage; return 1
    match answer massive ongoing (← IO.FS.readBinFile file) with
    | .ok text => IO.print text; return 0
    | .error e => IO.eprintln s!"decode: {e}"; return 1
  | true, [inDir, outDir] =>
    let entries ← System.FilePath.readDir inDir
    let names := (entries.map (·.fileName)).filter (·.endsWith ".json") |>.qsort (· < ·)
    for n in names do
      let out := match answer massive ongoing (← IO.FS.readBinFile (System.FilePath.mk inDir / n)) with
        | .ok text => text
        | .error e => s!"decode: {e}\n"
      IO.FS.writeFile (System.FilePath.mk outDir / n) out
    return 0
  | _, _ => IO.eprintln usage; return 1
