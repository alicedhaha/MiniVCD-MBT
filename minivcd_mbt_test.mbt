///|
fn parse_ok(text : String) -> @minivcd_mbt.VcdFile {
  @minivcd_mbt.parse_vcd(text) catch {
    @minivcd_mbt.VcdError(message) => {
      println(message)
      panic()
    }
  }
}

///|
fn simple_vcd(changes : String) -> String {
  let header =
    #|$timescale 1ns $end
    #|$scope module top $end
    #|$var wire 1 ! clk $end
    #|$upscope $end
    #|$enddefinitions $end
    #|
  header + changes
}

///|
fn expect_error(text : String, fragment : String) -> Unit raise {
  try @minivcd_mbt.parse_vcd(text) catch {
    @minivcd_mbt.VcdError(message) => assert_true(message.contains(fragment))
  } noraise {
    _ => panic()
  }
}

///|
test "header date" {
  let text =
    #|$date Fri Aug 14 2026 $end
    #|$enddefinitions $end
  let vcd = parse_ok(text)
  assert_eq(vcd.date, "Fri Aug 14 2026")
}

///|
test "header version" {
  let text =
    #|$version Icarus Verilog 12.0 $end
    #|$enddefinitions $end
  let vcd = parse_ok(text)
  assert_eq(vcd.version, "Icarus Verilog 12.0")
}

///|
test "compact timescale" {
  let vcd = parse_ok("$timescale 1ns $end $enddefinitions $end")
  assert_eq(vcd.timescale, "1ns")
}

///|
test "split timescale" {
  let vcd = parse_ok("$timescale 10 ps $end $enddefinitions $end")
  assert_eq(vcd.timescale, "10ps")
}

///|
test "unknown header command is ignored" {
  let vcd = parse_ok(
    "$comment generated for a test $end $timescale 1ns $end $enddefinitions $end",
  )
  assert_eq(vcd.timescale, "1ns")
}

///|
test "single scope produces full name" {
  let vcd = parse_ok(simple_vcd("#0 0!"))
  assert_eq(vcd.signals[0].full_name, "top.clk")
}

///|
test "nested scopes produce hierarchical name" {
  let text =
    #|$scope module top $end
    #|$scope module cpu $end
    #|$var wire 1 ! clk $end
    #|$upscope $end
    #|$upscope $end
    #|$enddefinitions $end
  let vcd = parse_ok(text)
  assert_eq(vcd.signals[0].full_name, "top.cpu.clk")
}

///|
test "upscope allows sibling scopes" {
  let text =
    #|$scope module top $end
    #|$scope module cpu $end
    #|$var wire 1 ! clk $end
    #|$upscope $end
    #|$scope module bus $end
    #|$var wire 1 ? ready $end
    #|$upscope $end
    #|$upscope $end
    #|$enddefinitions $end
  let vcd = parse_ok(text)
  assert_eq(vcd.signals[1].full_name, "top.bus.ready")
}

///|
test "unmatched upscope is rejected" {
  expect_error("$upscope $end $enddefinitions $end", "unmatched $upscope")
}

///|
test "unclosed scope is rejected" {
  expect_error(
    "$scope module top $end $enddefinitions $end", "$scope/$upscope mismatch",
  )
}

///|
test "one bit signal fields" {
  let signal = parse_ok(simple_vcd("#0 0!")).signals[0]
  assert_eq(signal.identifier, "!")
  assert_eq(signal.name, "clk")
  assert_eq(signal.width, 1)
}

///|
test "vector signal declaration" {
  let text =
    #|$scope module top $end
    #|$var wire 8 # counter [7:0] $end
    #|$upscope $end
    #|$enddefinitions $end
    #|#0 b00000000 #
  let vcd = parse_ok(text)
  assert_eq(vcd.signals[0].width, 8)
  assert_eq(vcd.signals[0].name, "counter")
}

///|
test "multiple signal declarations preserve order" {
  let text =
    #|$scope module top $end
    #|$var wire 1 ! clk $end
    #|$var reg 1 ? rst $end
    #|$upscope $end
    #|$enddefinitions $end
  let vcd = parse_ok(text)
  assert_eq(vcd.signals.length(), 2)
  assert_eq(vcd.signals[1].full_name, "top.rst")
}

///|
test "signal type is retained" {
  let vcd = parse_ok("$var reg 1 ! state $end $enddefinitions $end #0 1!")
  assert_eq(vcd.signals[0].signal_type, "reg")
}

///|
test "malformed var is rejected" {
  expect_error("$var wire 1 ! $end $enddefinitions $end", "malformed $var")
}

///|
test "invalid var width is rejected" {
  expect_error(
    "$var wire many ! clk $end $enddefinitions $end", "invalid width",
  )
}

///|
test "zero var width is rejected" {
  expect_error(
    "$var wire 0 ! clk $end $enddefinitions $end", "width must be positive",
  )
}

///|
test "duplicate identifier is rejected" {
  let text =
    #|$var wire 1 ! a $end
    #|$var wire 1 ! b $end
    #|$enddefinitions $end
  expect_error(text, "duplicate signal identifier")
}

///|
test "scalar zero" {
  let vcd = parse_ok(simple_vcd("#0 0!"))
  assert_eq(vcd.changes[0].value, "0")
}

///|
test "scalar one" {
  let vcd = parse_ok(simple_vcd("#0 1!"))
  assert_eq(vcd.changes[0].value, "1")
}

///|
test "uppercase X scalar is normalized" {
  let vcd = parse_ok(simple_vcd("#0 X!"))
  assert_eq(vcd.changes[0].value, "x")
}

///|
test "uppercase Z scalar is normalized" {
  let vcd = parse_ok(simple_vcd("#0 Z!"))
  assert_eq(vcd.changes[0].value, "z")
}

///|
test "binary vector value" {
  let vcd = parse_ok("$var wire 4 # count $end $enddefinitions $end #0 b1010 #")
  assert_eq(vcd.changes[0].value, "1010")
}

///|
test "vector x and z are normalized" {
  let vcd = parse_ok("$var wire 4 # bus $end $enddefinitions $end #0 bXz01 #")
  assert_eq(vcd.changes[0].value, "xz01")
}

///|
test "invalid scalar value is rejected" {
  expect_error(simple_vcd("#0 q!"), "invalid signal value")
}

///|
test "invalid vector value is rejected" {
  expect_error(
    "$var wire 4 # bus $end $enddefinitions $end #0 b1020 #", "invalid vector value",
  )
}

///|
test "timestamp zero" {
  let vcd = parse_ok(simple_vcd("#0 0!"))
  assert_eq(vcd.changes[0].timestamp, 0L)
}

///|
test "multiple timestamps" {
  let vcd = parse_ok(simple_vcd("#0 0! #5 1! #10 0!"))
  assert_eq(vcd.changes.length(), 3)
  assert_eq(vcd.changes[2].timestamp, 10L)
}

///|
test "one timestamp applies to multiple changes" {
  let text =
    #|$var wire 1 ! a $end
    #|$var wire 1 ? b $end
    #|$enddefinitions $end
    #|#7 0! 1?
  let vcd = parse_ok(text)
  assert_eq(vcd.changes[0].timestamp, 7L)
  assert_eq(vcd.changes[1].timestamp, 7L)
}

///|
test "malformed timestamp is rejected" {
  expect_error(simple_vcd("#five 0!"), "invalid timestamp")
}

///|
test "overflow timestamp is rejected" {
  expect_error(simple_vcd("#999999999999999999999 0!"), "value is too large")
}

///|
test "unknown scalar identifier is rejected" {
  expect_error(simple_vcd("#0 0?"), "unknown signal identifier")
}

///|
test "unknown vector identifier is rejected" {
  expect_error(
    "$var wire 4 # bus $end $enddefinitions $end #0 b0000 ?", "unknown signal identifier",
  )
}

///|
test "find signal by full name" {
  let vcd = parse_ok(simple_vcd("#0 0!"))
  assert_true(
    @minivcd_mbt.find_signal(vcd, "top.clk") is Some(signal) &&
    signal.name == "clk",
  )
}

///|
test "find missing signal returns none" {
  let vcd = parse_ok(simple_vcd("#0 0!"))
  assert_true(@minivcd_mbt.find_signal(vcd, "top.missing") is None)
}

///|
test "find signal by identifier" {
  let vcd = parse_ok(simple_vcd("#0 0!"))
  assert_true(
    @minivcd_mbt.find_signal_by_identifier(vcd, "!") is Some(signal) &&
    signal.full_name == "top.clk",
  )
}

///|
test "list signals returns all declarations" {
  let vcd = parse_ok(
    "$var wire 1 ! a $end $var wire 1 ? b $end $enddefinitions $end",
  )
  assert_eq(@minivcd_mbt.list_signals(vcd).length(), 2)
}

///|
test "signal changes filter other identifiers" {
  let text =
    #|$scope module top $end
    #|$var wire 1 ! a $end
    #|$var wire 1 ? b $end
    #|$upscope $end
    #|$enddefinitions $end
    #|#0 0! 1? #5 1!
  let vcd = parse_ok(text)
  let changes = @minivcd_mbt.signal_changes(vcd, "top.a") catch { _ => panic() }
  assert_eq(changes.length(), 2)
  assert_eq(changes[1].value, "1")
}

///|
test "signal changes missing signal raises error" {
  let vcd = parse_ok(simple_vcd("#0 0!"))
  try @minivcd_mbt.signal_changes(vcd, "top.nope") catch {
    @minivcd_mbt.VcdError(message) =>
      assert_true(message.contains("signal not found"))
  } noraise {
    _ => panic()
  }
}

///|
test "signal changes by identifier" {
  let vcd = parse_ok(simple_vcd("#0 0! #5 1!"))
  let changes = @minivcd_mbt.signal_changes_by_identifier(vcd, "!") catch {
    _ => panic()
  }
  assert_eq(changes.length(), 2)
  assert_eq(changes[1].timestamp, 5L)
}

///|
test "signal changes by identifier rejects missing identifier" {
  let vcd = parse_ok(simple_vcd("#0 0!"))
  try @minivcd_mbt.signal_changes_by_identifier(vcd, "?") catch {
    @minivcd_mbt.VcdError(message) =>
      assert_true(message.contains("identifier not found"))
  } noraise {
    _ => panic()
  }
}

///|
test "value at exact timestamp" {
  let vcd = parse_ok(simple_vcd("#0 0! #5 1!"))
  assert_eq(
    @minivcd_mbt.value_at(vcd, "top.clk", 5L) catch {
      _ => panic()
    },
    Some("1"),
  )
}

///|
test "value between timestamps" {
  let vcd = parse_ok(simple_vcd("#0 0! #5 1! #10 0!"))
  assert_eq(
    @minivcd_mbt.value_at(vcd, "top.clk", 7L) catch {
      _ => panic()
    },
    Some("1"),
  )
}

///|
test "value before first change is none" {
  let vcd = parse_ok(simple_vcd("#5 1!"))
  assert_eq(
    @minivcd_mbt.value_at(vcd, "top.clk", 0L) catch {
      _ => panic()
    },
    None,
  )
}

///|
test "negative value query timestamp is rejected" {
  let vcd = parse_ok(simple_vcd("#0 0!"))
  try @minivcd_mbt.value_at(vcd, "top.clk", -1L) catch {
    @minivcd_mbt.VcdError(message) =>
      assert_true(message.contains("non-negative"))
  } noraise {
    _ => panic()
  }
}

///|
test "statistics change count" {
  let vcd = parse_ok(simple_vcd("#0 0! #5 1! #10 0!"))
  let stats = @minivcd_mbt.signal_stats(vcd, "top.clk") catch { _ => panic() }
  assert_eq(stats.change_count, 3)
}

///|
test "statistics first and last time" {
  let vcd = parse_ok(simple_vcd("#2 0! #8 1!"))
  let stats = @minivcd_mbt.signal_stats(vcd, "top.clk") catch { _ => panic() }
  assert_eq(stats.first_change_time, Some(2L))
  assert_eq(stats.last_change_time, Some(8L))
}

///|
test "rising edge count" {
  let vcd = parse_ok(simple_vcd("#0 0! #5 1! #10 0! #15 1!"))
  let stats = @minivcd_mbt.signal_stats(vcd, "top.clk") catch { _ => panic() }
  assert_eq(stats.rising_edges, 2)
}

///|
test "falling edge count" {
  let vcd = parse_ok(simple_vcd("#0 1! #5 0! #10 1! #15 0!"))
  let stats = @minivcd_mbt.signal_stats(vcd, "top.clk") catch { _ => panic() }
  assert_eq(stats.falling_edges, 2)
}

///|
test "vector has no scalar edge statistics" {
  let vcd = parse_ok(
    "$var wire 4 # bus $end $enddefinitions $end #0 b0000 # #5 b1111 #",
  )
  let stats = @minivcd_mbt.signal_stats(vcd, "bus") catch { _ => panic() }
  assert_eq(stats.rising_edges, 0)
  assert_eq(stats.falling_edges, 0)
}

///|
test "csv export" {
  let vcd = parse_ok(simple_vcd("#0 0! #5 1!"))
  let csv = @minivcd_mbt.export_csv(vcd) catch { _ => panic() }
  assert_eq(csv, "timestamp,signal,value\n0,top.clk,0\n5,top.clk,1\n")
}

///|
test "empty input is rejected" {
  expect_error("  \n\t", "empty VCD input")
}

///|
test "missing enddefinitions is rejected" {
  expect_error("$timescale 1ns $end", "missing $enddefinitions")
}

///|
test "dumpvars values are parsed at time zero" {
  let vcd = parse_ok(simple_vcd("$dumpvars 0! $end"))
  assert_eq(vcd.changes.length(), 1)
  assert_eq(vcd.changes[0].timestamp, 0L)
}

///|
test "dumpall values use current timestamp" {
  let vcd = parse_ok(simple_vcd("#12 $dumpall 1! $end"))
  assert_eq(vcd.changes.length(), 1)
  assert_eq(vcd.changes[0].timestamp, 12L)
  assert_eq(vcd.changes[0].value, "1")
}

///|
test "dumpon accepts vector values" {
  let text =
    #|$scope module top $end
    #|$var wire 4 # bus $end
    #|$upscope $end
    #|$enddefinitions $end
    #|#9 $dumpon b10XZ # $end
  let vcd = parse_ok(text)
  assert_eq(vcd.changes.length(), 1)
  assert_eq(vcd.changes[0].timestamp, 9L)
  assert_eq(vcd.changes[0].value, "10xz")
}

///|
test "unterminated dump command is rejected" {
  expect_error(simple_vcd("$dumpall 0!"), "unterminated $dumpall command")
}

///|
test "parse alias" {
  let vcd = @minivcd_mbt.parse(simple_vcd("#0 1!")) catch { _ => panic() }
  assert_eq(vcd.changes[0].value, "1")
}

///|
test "start and end time" {
  let vcd = parse_ok(simple_vcd("#10 0! #25 1!"))
  assert_eq(@minivcd_mbt.start_time(vcd), Some(10L))
  assert_eq(@minivcd_mbt.end_time(vcd), Some(25L))
}

///|
test "summary reports file counts and time bounds" {
  let vcd = parse_ok(simple_vcd("#10 0! #25 1!"))
  let summary = @minivcd_mbt.summary(vcd)
  assert_eq(summary.signal_count, 1)
  assert_eq(summary.change_count, 2)
  assert_eq(summary.start_time, Some(10L))
  assert_eq(summary.end_time, Some(25L))
}

///|
test "empty statistics use none bounds" {
  let vcd = parse_ok(simple_vcd(""))
  let stats = @minivcd_mbt.signal_stats(vcd, "top.clk") catch { _ => panic() }
  assert_eq(stats.change_count, 0)
  assert_eq(stats.first_change_time, None)
  assert_eq(stats.last_change_time, None)
}
