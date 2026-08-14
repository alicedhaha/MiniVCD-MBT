# MiniVCD-MBT Project Application

## Basic Information

| Item | Content |
| --- | --- |
| Project Name | MiniVCD-MBT |
| Contestant | 黄东红 |
| GitHub Repository | https://github.com/alicedhaha/MiniVCD-MBT |
| GitLink Repository | https://gitlink.org.cn/alicedhh/MiniVCD-MBT |
| Mooncakes Package | https://mooncakes.io/docs/alicedhaha/minivcd_mbt |
| Project Direction | MoonBit engineering tooling / digital waveform parsing |
| Project Type | Original project |
| Account Mapping | `alicedhaha` on GitHub and `alicedhh` on GitLink are both accounts of 黄东红 on different platforms |

## Project Summary

MiniVCD-MBT is a lightweight VCD parser and command-line viewer written in MoonBit. It reads legal Value Change Dump files, extracts hierarchical signal declarations and timestamped value changes, supports signal queries and basic edge statistics, and exports parsed results to CSV. The project focuses on being small, complete, testable, reproducible, and publishable instead of trying to replace professional EDA tools.

## Direction And Use Cases

The project targets MoonBit application ecosystem and engineering tool construction. It is suitable for RTL debugging, teaching experiments, quick VCD inspection in script-based workflows, and as a reusable parsing foundation for future waveform-related MoonBit tools.

## Core Features

1. Parse VCD headers such as `$date`, `$version`, `$timescale`, `$scope`, `$upscope`, `$var`, and `$enddefinitions`.
2. Build hierarchical signal names such as `top.cpu.clk`.
3. Parse scalar values `0`, `1`, `x`, `z` and binary vector changes.
4. Parse timestamped signal changes, including `$dumpvars`, `$dumpall`, `$dumpon`, and `$dumpoff` blocks.
5. Provide query APIs for signals, per-signal changes, point-in-time values, and file summaries.
6. Provide basic statistics including change count, first/last change time, rising edges, and falling edges.
7. Provide parsed-data diagnostics, signal coverage, timestamp buckets, snapshots, Markdown/text reports, and VCD regression comparison helpers.
8. Export all changes or one signal's changes to CSV.
9. Provide the `minivcd` CLI with `info`, `signals`, `changes`, `stats`, `value`, and `export` commands.

## Current Scale And Tests

The project now contains 5378 physical MoonBit lines, 4921 nonblank MoonBit lines, and 4320 nonblank non-comment MoonBit lines. Under the strict nonblank non-comment count, it includes 2518 product-code lines and 1802 test-code lines. The test suite has 240 tests and covers parsing, malformed inputs, scalar/vector values, query APIs, statistics, CSV export, diagnostics, snapshots, coverage summaries, Markdown reports, and VCD comparison helpers.

## Originality And Compliance

MiniVCD-MBT is an original MoonBit implementation. Before development, related keywords were checked on mooncakes.io and no mature MoonBit package with the same VCD parsing and CLI scope was found. The repository uses the MIT License and keeps source code, tests, examples, and documentation public for review and reuse.
