import Chanlun

/-- A file's bytes as its answer: its canonical text, or its fault. -/
def answer (massive : Bool) (bytes : ByteArray) : Except String String :=
  match String.fromUTF8? bytes with
  | none => .error "text not UTF-8"
  | some text =>
    if massive then Chanlun.encodeRun <$> Chanlun.decodeMassiveRun text
    else Chanlun.encodeRun <$> Chanlun.decodeRun text

def usage : String :=
  "usage: lake exe decode [--massive] FILE | [--massive] --batch IN OUT"

/-- A run's JSON decoded and written again as its canonical JSON (the conformance check's Lean side), with `--massive`
a run of Massive's K-lines (an ongoing K-line is market's, ../../market/lean/Main.lean): `lake exe decode [--massive]
FILE`. The file's bytes are read as UTF-8, a byte that is not UTF-8 refused. A
fault to stderr, exit 1. With `--batch IN OUT`, every `.json` file of the folder `IN`, in the order of their names,
decoded so in one process (the generated cases, ../vectors/cases.ts), each one's answer written to `OUT` under its
name: its canonical text, or the line `decode: ` and its fault. -/
def main (args : List String) : IO UInt32 := do
  let massive := args.contains "--massive"
  let batch := args.contains "--batch"
  match batch, args.filter (fun a => a != "--massive" && a != "--batch") with
  | false, [file] =>
    if file.startsWith "--" then
      IO.eprintln s!"decode: {usage}"; return 1
    match answer massive (← IO.FS.readBinFile file) with
    | .ok text => IO.print text; return 0
    | .error e => IO.eprintln s!"decode: {e}"; return 1
  | true, [inDir, outDir] =>
    let entries ← System.FilePath.readDir inDir
    let names := (entries.map (·.fileName)).filter (·.endsWith ".json") |>.qsort (· < ·)
    for n in names do
      let out := match answer massive (← IO.FS.readBinFile (System.FilePath.mk inDir / n)) with
        | .ok text => text
        | .error e => s!"decode: {e}\n"
      IO.FS.writeFile (System.FilePath.mk outDir / n) out
    return 0
  | _, _ => IO.eprintln s!"decode: {usage}"; return 1
