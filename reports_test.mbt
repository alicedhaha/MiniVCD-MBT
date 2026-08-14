///|
fn report_vcd() -> @minivcd_mbt.VcdFile {
  parse_extended(
    (
      #|$timescale 1ns $end
      #|$scope module top $end
      #|$var wire 1 ! clk $end
      #|$var wire 4 " counter $end
      #|$var wire 1 # idle $end
      #|$upscope $end
      #|$enddefinitions $end
      #|#0 0! b0000 "
      #|#5 1!
      #|#10 0! b0001 "
      #|#15 1!
      #|#20 0! b0010 "
    ),
  )
}

///|
test "markdown summary has heading" {
  let text = @minivcd_mbt.markdown_summary(report_vcd())
  assert_true(text.contains("## VCD Summary"))
}

///|
test "markdown summary has timescale" {
  let text = @minivcd_mbt.markdown_summary(report_vcd())
  assert_true(text.contains("Timescale: 1ns"))
}

///|
test "markdown summary has scalar count" {
  let text = @minivcd_mbt.markdown_summary(report_vcd())
  assert_true(text.contains("Scalar signals: 2"))
}

///|
test "markdown summary has vector count" {
  let text = @minivcd_mbt.markdown_summary(report_vcd())
  assert_true(text.contains("Vector signals: 1"))
}

///|
test "markdown signals has table header" {
  let text = @minivcd_mbt.markdown_signals(report_vcd())
  assert_true(text.contains("| Signal | Type | Width | Identifier |"))
}

///|
test "markdown signals escapes pipe cells" {
  let signal : @minivcd_mbt.Signal = {
    identifier: "|",
    name: "a",
    full_name: "top.a",
    width: 1,
    signal_type: "wire",
  }
  let vcd : @minivcd_mbt.VcdFile = {
    date: "",
    version: "",
    timescale: "1ns",
    signals: [signal],
    changes: [],
  }
  let text = @minivcd_mbt.markdown_signals(vcd)
  assert_true(text.contains("\\|"))
}

///|
test "markdown signal changes has rows" {
  let text = @minivcd_mbt.markdown_signal_changes(report_vcd(), "top.clk") catch {
    _ => panic()
  }
  assert_true(text.contains("| 5 | 1 |"))
}

///|
test "markdown signal changes rejects missing signal" {
  try @minivcd_mbt.markdown_signal_changes(report_vcd(), "top.missing") catch {
    @minivcd_mbt.VcdError(message) =>
      assert_true(message.contains("signal not found"))
  } noraise {
    _ => panic()
  }
}

///|
test "markdown changes contains counter" {
  let text = @minivcd_mbt.markdown_changes(report_vcd())
  assert_true(text.contains("top.counter"))
}

///|
test "markdown signal stats contains edge counts" {
  let text = @minivcd_mbt.markdown_signal_stats(report_vcd(), "top.clk") catch {
    _ => panic()
  }
  assert_true(text.contains("Rising edges: 2"))
}

///|
test "markdown signal stats includes falling counts" {
  let text = @minivcd_mbt.markdown_signal_stats(report_vcd(), "top.clk") catch {
    _ => panic()
  }
  assert_true(text.contains("Falling edges: 2"))
}

///|
test "markdown value counts has zero count" {
  let text = @minivcd_mbt.markdown_value_counts(report_vcd(), "top.clk") catch {
    _ => panic()
  }
  assert_true(text.contains("| 0 | 3 |"))
}

///|
test "markdown value counts has one count" {
  let text = @minivcd_mbt.markdown_value_counts(report_vcd(), "top.clk") catch {
    _ => panic()
  }
  assert_true(text.contains("| 1 | 2 |"))
}

///|
test "markdown coverage has idle signal" {
  let text = @minivcd_mbt.markdown_coverage(report_vcd()) catch { _ => panic() }
  assert_true(text.contains("top.idle"))
}

///|
test "markdown coverage marks uncovered signal" {
  let text = @minivcd_mbt.markdown_coverage(report_vcd()) catch { _ => panic() }
  assert_true(text.contains("| top.idle | no |"))
}

///|
test "markdown issues reports no validation issues" {
  let text = @minivcd_mbt.markdown_issues(report_vcd())
  assert_true(text.contains("No validation issues found."))
}

///|
test "markdown issues table appears for constructed issue" {
  let signal : @minivcd_mbt.Signal = {
    identifier: "!",
    name: "a",
    full_name: "a",
    width: 1,
    signal_type: "wire",
  }
  let changes : Array[@minivcd_mbt.SignalChange] = [
    { timestamp: 0L, identifier: "!", value: "bad" },
  ]
  let vcd : @minivcd_mbt.VcdFile = {
    date: "",
    version: "",
    timescale: "1ns",
    signals: [signal],
    changes,
  }
  let text = @minivcd_mbt.markdown_issues(vcd)
  assert_true(text.contains("| Code | Timestamp | Signal | Message |"))
}

///|
test "markdown snapshot includes point in time value" {
  let snapshot = @minivcd_mbt.snapshot_at(report_vcd(), 10L) catch {
    _ => panic()
  }
  let text = @minivcd_mbt.markdown_snapshot(snapshot)
  assert_true(text.contains("| top.counter | 0001 |"))
}

///|
test "markdown snapshot uses dash for empty value" {
  let snapshot = @minivcd_mbt.snapshot_at(report_vcd(), 10L) catch {
    _ => panic()
  }
  let text = @minivcd_mbt.markdown_snapshot(snapshot)
  assert_true(text.contains("| top.idle | - |"))
}

///|
test "markdown buckets contains timestamp rows" {
  let text = @minivcd_mbt.markdown_buckets(report_vcd())
  assert_true(text.contains("| 0 | 2 |"))
}

///|
test "markdown buckets includes last timestamp" {
  let text = @minivcd_mbt.markdown_buckets(report_vcd())
  assert_true(text.contains("| 20 | 2 |"))
}

///|
test "markdown report combines summary and coverage" {
  let text = @minivcd_mbt.markdown_report(report_vcd()) catch { _ => panic() }
  assert_true(text.contains("# MiniVCD-MBT Report"))
  assert_true(text.contains("## Signal Coverage"))
}

///|
test "manifest line contains counts" {
  let text = @minivcd_mbt.manifest_line(report_vcd())
  assert_true(text.contains("signals=3"))
  assert_true(text.contains("changes=8"))
}

///|
test "manifest line contains time bounds" {
  let text = @minivcd_mbt.manifest_line(report_vcd())
  assert_true(text.contains("start=0"))
  assert_true(text.contains("end=20"))
}

///|
test "signal manifest lists names" {
  let text = @minivcd_mbt.signal_manifest(report_vcd())
  assert_true(text.contains("top.clk"))
  assert_true(text.contains("top.counter"))
}

///|
test "single signal report includes stats" {
  let text = @minivcd_mbt.single_signal_report(report_vcd(), "top.clk") catch {
    _ => panic()
  }
  assert_true(text.contains("## Signal Statistics"))
}

///|
test "single signal report includes value counts" {
  let text = @minivcd_mbt.single_signal_report(report_vcd(), "top.clk") catch {
    _ => panic()
  }
  assert_true(text.contains("## Value Counts: top.clk"))
}

///|
test "single signal report includes change table" {
  let text = @minivcd_mbt.single_signal_report(report_vcd(), "top.clk") catch {
    _ => panic()
  }
  assert_true(text.contains("## Changes: top.clk"))
}

///|
test "manifest line uses dash for missing timescale and times" {
  let vcd : @minivcd_mbt.VcdFile = {
    date: "",
    version: "",
    timescale: "",
    signals: [],
    changes: [],
  }
  let text = @minivcd_mbt.manifest_line(vcd)
  assert_true(text.contains("timescale=-"))
  assert_true(text.contains("start=-"))
  assert_true(text.contains("end=-"))
}

///|
test "signal manifest is empty for no signals" {
  let vcd : @minivcd_mbt.VcdFile = {
    date: "",
    version: "",
    timescale: "1ns",
    signals: [],
    changes: [],
  }
  assert_eq(@minivcd_mbt.signal_manifest(vcd), "")
}
