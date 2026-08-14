# MiniVCD-MBT

A lightweight VCD waveform parser and CLI written in MoonBit.

MiniVCD-MBT reads a Value Change Dump file, extracts digital signal declarations
and value changes, and provides small command-line queries and CSV export. It is
intentionally a focused parser/viewer rather than a full EDA application.

## Features

- VCD header parsing (`$date`, `$version`, `$timescale`)
- Hierarchical signals from `$scope` and `$upscope`
- Four-state scalar values (`0`, `1`, `x`, `z`)
- Binary vectors
- Signal lookup, change history, and point-in-time value queries
- Change count and basic rising/falling edge statistics
- CSV export
- Five-command CLI

## Installation

Install a current MoonBit toolchain, then build the project:

```bash
moon update
moon build --target native
```

During development, run the CLI directly with `moon run cmd/minivcd -- ...`.
After the package is published, library users can install it with:

```bash
moon add alicedhaha/minivcd_mbt
```

## Usage

Show file metadata:

```bash
moon run cmd/minivcd -- info examples/demo.vcd
```

List signals:

```bash
moon run cmd/minivcd -- signals examples/demo.vcd
```

Show one signal's changes:

```bash
moon run cmd/minivcd -- changes examples/demo.vcd top.clk
```

Query the most recent value at or before a timestamp:

```bash
moon run cmd/minivcd -- value examples/demo.vcd top.counter 20
```

Export all changes:

```bash
moon run cmd/minivcd -- export examples/demo.vcd output.csv
```

The standalone executable uses the same five commands with the shorter form
`minivcd <command> ...`.

## Library Example

Add `alicedhaha/minivcd_mbt` to the consuming package's `moon.pkg`, then call the
parser and query API:

```moonbit
let text =
  #|$timescale 1ns $end
  #|$scope module top $end
  #|$var wire 1 ! clk $end
  #|$upscope $end
  #|$enddefinitions $end
  #|#0 0!
  #|#5 1!

let vcd = @minivcd_mbt.parse_vcd(text) catch { _ => panic() }
let value = @minivcd_mbt.value_at(vcd, "top.clk", 5L) catch { _ => panic() }
assert_eq(value, Some("1"))
```

The main public functions are `parse_vcd`/`parse`, `list_signals`,
`find_signal`, `signal_changes`, `value_at`, `signal_stats`, and `export_csv`.

## Supported Features

- Basic VCD headers and unknown skippable header commands
- Simple module hierarchy
- `wire`, `reg`, and other declared signal type names as metadata
- Scalar digital changes
- Binary vector changes
- Non-negative timestamps
- `$dumpvars` initial values

Malformed input raises a readable `VcdError`; normal input errors do not panic.

## Limitations

MiniVCD-MBT does not support:

- FSDB or FST files
- Verilog/SystemVerilog compilation or simulation
- A waveform GUI or waveform drawing
- Real/string signal advanced processing
- Streaming very large files
- Clock frequency, duty-cycle, jitter, glitch, or activity analysis

## Testing

Run all tests with:

```bash
moon test
```

For stricter local validation:

```bash
moon check --deny-warn
moon test --deny-warn
```

## License

MIT
