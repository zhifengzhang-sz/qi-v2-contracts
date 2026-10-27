// The bars of the vectors' run (run.json's K-lines): one-minute bars made up, not of any market, so that the vectors
// can be public. A price is a whole number (the price times 100): waves of four sizes and a little noise from a fixed
// seed, so every run gives the same bars. Writes them to stdout, a bar a line: date (seconds, UTC), open, high, low,
// close, volume.
//   bun chanlun/vectors/bars.ts 4000
const n = Number(process.argv[2] ?? "600");
const start = 1767623400; // 2026-01-05 14:30:00 UTC
// a linear congruential generator: the same numbers from the same seed
const lcg = (s: number): number => (s * 1103515245 + 12345) % 2147483648;
const seeds = Array.from({ length: n * 3 }).reduce<number[]>((a) => [...a, lcg(a.at(-1) ?? 20261027)], []);
const noise = (i: number, k: number): number => (seeds[i * 3 + k] ?? 0) % 1000;
const wave = (i: number): number =>
  10000 +
  Math.round(
    900 * Math.sin((2 * Math.PI * i) / 1300) +
      300 * Math.sin((2 * Math.PI * i) / 240) +
      110 * Math.sin((2 * Math.PI * i) / 61) +
      35 * Math.sin((2 * Math.PI * i) / 13),
  ) +
  ((noise(i, 0) % 21) - 10);
const lines = Array.from({ length: n }, (_, i) => {
  const open = i === 0 ? wave(0) : wave(i - 1);
  const close = wave(i);
  const high = Math.max(open, close) + (noise(i, 1) % 9);
  const low = Math.min(open, close) - (noise(i, 2) % 9);
  return `${start + 60 * i},${open},${high},${low},${close},${1000 + noise(i, 0)}`;
});
process.stdout.write(`${lines.join("\n")}\n`);
