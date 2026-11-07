import Market

/-- A file's bytes as its answer: its canonical text, or its fault. -/
def answer (bytes : ByteArray) : Except String String :=
  match String.fromUTF8? bytes with
  | none => .error "text not UTF-8"
  | some text => Market.encodeOngoingKLine <$> Market.decodeOngoingKLine text

def usage : String :=
  "usage: lake exe decode --ongoing FILE | --ongoing --batch IN OUT"

/-- An ongoing K-line's JSON decoded and written again as its canonical JSON (the conformance check's Lean side):
`lake exe decode --ongoing FILE`. The file's bytes are read as UTF-8, a byte that is not UTF-8 refused. A fault to
stderr, exit 1. With `--batch IN OUT`, every `.json` file of the folder `IN`, in the order of their names, decoded so in
one process (the generated cases, ../vectors/cases.ts), each one's answer written to `OUT` under its name: its
canonical text, or the line `decode: ` and its fault. -/
def main (args : List String) : IO UInt32 := do
  let ongoing := args.contains "--ongoing"
  let batch := args.contains "--batch"
  match ongoing, batch, args.filter (fun a => a != "--ongoing" && a != "--batch") with
  | true, false, [file] =>
    if file.startsWith "--" then
      IO.eprintln s!"decode: {usage}"; return 1
    match answer (← IO.FS.readBinFile file) with
    | .ok text => IO.print text; return 0
    | .error e => IO.eprintln s!"decode: {e}"; return 1
  | true, true, [inDir, outDir] =>
    let entries ← System.FilePath.readDir inDir
    let names := (entries.map (·.fileName)).filter (·.endsWith ".json") |>.qsort (· < ·)
    for n in names do
      let out := match answer (← IO.FS.readBinFile (System.FilePath.mk inDir / n)) with
        | .ok text => text
        | .error e => s!"decode: {e}\n"
      IO.FS.writeFile (System.FilePath.mk outDir / n) out
    return 0
  | _, _, _ => IO.eprintln s!"decode: {usage}"; return 1
