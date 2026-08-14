// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "alicedhaha/minivcd_mbt"

version = "0.1.3"

readme = "README.md"

repository = "https://github.com/alicedhaha/MiniVCD-MBT.git"

license = "MIT"

keywords = [ "vcd", "verilog", "waveform", "parser", "cli" ]

preferred_target = "native"

description = "A lightweight VCD waveform parser and CLI written in MoonBit."

import {
  "moonbitlang/x@0.4.49",
}
