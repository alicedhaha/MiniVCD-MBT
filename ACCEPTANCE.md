# MiniVCD-MBT Acceptance Record

Date: 2026-08-14

## Environment

- `moon 0.1.20260724`
- `moonc v0.10.5`
- `moonrun 0.1.20260724`

## Reproduction Commands

The repository also includes `scripts/verify.ps1`, which runs the same checks and demo commands in one pass on Windows.

```bash
moon fmt --check
moon check --target all --deny-warn
moon build --target all
moon test --target all --deny-warn
moon info
git diff --exit-code
moon run cmd/minivcd -- info examples/demo.vcd
moon run cmd/minivcd -- signals examples/demo.vcd
moon run cmd/minivcd -- changes examples/demo.vcd top.clk
moon run cmd/minivcd -- stats examples/demo.vcd top.clk
moon run cmd/minivcd -- value examples/demo.vcd top.counter 20
moon run cmd/minivcd -- export examples/demo.vcd output.csv
```

## Actual Results

- `moon fmt --check`: passed.
- `moon check --target all --deny-warn`: passed for all targets.
- `moon build --target all`: passed for all targets.
- `moon test --target all --deny-warn`: passed 201/201 on `wasm`, `wasm-gc`, `js`, and `native`.
- `moon info`: passed.
- `git diff --exit-code`: passed after `moon info`.
- `info`: `Timescale: 1ns`, `Signals: 3`, `Changes: 16`, `Start time: 0`, `End time: 40`.
- `signals`: listed `top.clk`, `top.rst`, and `top.counter`.
- `changes`: `top.clk` changes were `0, 5, 10, 15, 20, 25, 30, 35, 40`.
- `stats`: `top.clk` reported `Changes: 9`, `Rising edges: 4`, `Falling edges: 4`.
- `value`: `top.counter @ 20 = 0010`.
- `export`: generated CSV with 16 rows of waveform changes.

## Repository And Publish Status

- GitHub repository: public, default branch `main`.
- GitLink repository: `main` is up to date, and `master` has been synchronized to the same latest commit so the default page no longer points at stale content.
- Mooncakes package: `alicedhaha/minivcd_mbt@0.1.3` published.
- MoonBit source scale: 4001 lines total, including 2387 product lines and 1614 test lines.

## Notes

- The GitHub account `alicedhaha` and GitLink account `alicedhh` both belong to contestant 黄东红.
- The project is an original MoonBit implementation and uses the MIT License.
