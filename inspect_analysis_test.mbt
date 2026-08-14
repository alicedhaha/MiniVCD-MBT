///|
fn parse_extended(text : String) -> @minivcd_mbt.VcdFile {
  @minivcd_mbt.parse_vcd(text) catch {
    @minivcd_mbt.VcdError(message) => {
      println(message)
      panic()
    }
  }
}

///|
fn rich_vcd() -> @minivcd_mbt.VcdFile {
  parse_extended(
    (
      #|$date Fri Aug 14 2026 $end
      #|$version MiniVCD test writer $end
      #|$timescale 1ns $end
      #|$scope module top $end
      #|$scope module cpu $end
      #|$var wire 1 ! clk $end
      #|$var wire 1 ? rst $end
      #|$var wire 4 # counter $end
      #|$var reg 2 $ state $end
      #|$upscope $end
      #|$scope module bus $end
      #|$var wire 1 % valid $end
      #|$var wire 8 & data $end
      #|$upscope $end
      #|$upscope $end
      #|$enddefinitions $end
      #|#0 0! 1? b0000 # bxx $ 0% b00000000 &
      #|#5 1!
      #|#10 0! 0? b0001 # b01 $ 1% b00000001 &
      #|#15 1!
      #|#20 0! b0010 # b10 $ bzzzzzzzz &
      #|#25 1!
      #|#30 0! b0011 # b11 $ 0% b00000011 &
      #|#35 1!
      #|#40 0! b0100 # b00 $ 1% b00000100 &
    ),
  )
}

///|
fn sparse_vcd() -> @minivcd_mbt.VcdFile {
  parse_extended(
    (
      #|$timescale 1ns $end
      #|$scope module top $end
      #|$var wire 1 ! clk $end
      #|$var wire 1 ? never $end
      #|$upscope $end
      #|$enddefinitions $end
      #|#10 1!
    ),
  )
}

///|
fn expect_vcd_error(
  fn_body : () -> Unit raise,
  fragment : String,
) -> Unit raise {
  try fn_body() catch {
    @minivcd_mbt.VcdError(message) => assert_true(message.contains(fragment))
    _ => panic()
  } noraise {
    _ => panic()
  }
}

///|
test "describe signal extracts scope and scalar flags" {
  let signal = rich_vcd().signals[0]
  let desc = @minivcd_mbt.describe_signal(signal)
  assert_eq(desc.scope, "top.cpu")
  assert_eq(desc.is_scalar, true)
  assert_eq(desc.is_vector, false)
}

///|
test "describe vector signal sets vector flag" {
  let signal = rich_vcd().signals[2]
  let desc = @minivcd_mbt.describe_signal(signal)
  assert_eq(desc.full_name, "top.cpu.counter")
  assert_eq(desc.is_scalar, false)
  assert_eq(desc.is_vector, true)
}

///|
test "describe signals preserves declaration count" {
  let descriptions = @minivcd_mbt.describe_signals(rich_vcd())
  assert_eq(descriptions.length(), 6)
}

///|
test "signal types are unique" {
  let types = @minivcd_mbt.signal_types(rich_vcd())
  assert_eq(types.length(), 2)
  assert_eq(types[0], "wire")
  assert_eq(types[1], "reg")
}

///|
test "count signals by type counts wires" {
  assert_eq(@minivcd_mbt.count_signals_by_type(rich_vcd(), "wire"), 5)
}

///|
test "count signals by type counts regs" {
  assert_eq(@minivcd_mbt.count_signals_by_type(rich_vcd(), "reg"), 1)
}

///|
test "signals by type returns state register" {
  let regs = @minivcd_mbt.signals_by_type(rich_vcd(), "reg")
  assert_eq(regs.length(), 1)
  assert_eq(regs[0].full_name, "top.cpu.state")
}

///|
test "scalar signals include clk rst and valid" {
  let scalars = @minivcd_mbt.scalar_signals(rich_vcd())
  assert_eq(scalars.length(), 3)
}

///|
test "vector signals include counter state and data" {
  let vectors = @minivcd_mbt.vector_signals(rich_vcd())
  assert_eq(vectors.length(), 3)
}

///|
test "signals under cpu scope" {
  let signals = @minivcd_mbt.signals_under_scope(rich_vcd(), "top.cpu")
  assert_eq(signals.length(), 4)
}

///|
test "signals under bus scope" {
  let signals = @minivcd_mbt.signals_under_scope(rich_vcd(), "top.bus")
  assert_eq(signals.length(), 2)
}

///|
test "signal full names preserve order" {
  let names = @minivcd_mbt.signal_full_names(rich_vcd())
  assert_eq(names[0], "top.cpu.clk")
  assert_eq(names[5], "top.bus.data")
}

///|
test "signal identifiers preserve order" {
  let ids = @minivcd_mbt.signal_identifiers(rich_vcd())
  assert_eq(ids[0], "!")
  assert_eq(ids[5], "&")
}

///|
test "search signals by full name" {
  let matches = @minivcd_mbt.search_signals(rich_vcd(), "counter")
  assert_eq(matches.length(), 1)
  assert_eq(matches[0].reason, "full-name")
}

///|
test "search signals by identifier" {
  let matches = @minivcd_mbt.search_signals(rich_vcd(), "&")
  assert_eq(matches.length(), 1)
  assert_eq(matches[0].signal.full_name, "top.bus.data")
}

///|
test "search signals by type" {
  let matches = @minivcd_mbt.search_signals(rich_vcd(), "reg")
  assert_eq(matches.length(), 1)
  assert_eq(matches[0].signal.full_name, "top.cpu.state")
}

///|
test "timestamps are unique and ordered" {
  let times = @minivcd_mbt.timestamps(rich_vcd())
  assert_eq(times.length(), 9)
  assert_eq(times[0], 0L)
  assert_eq(times[8], 40L)
}

///|
test "timestamp count reports nine points" {
  assert_eq(@minivcd_mbt.timestamp_count(rich_vcd()), 9)
}

///|
test "changes at timestamp zero include six changes" {
  let changes = @minivcd_mbt.changes_at_timestamp(rich_vcd(), 0L)
  assert_eq(changes.length(), 6)
}

///|
test "changes at timestamp five include clk only" {
  let changes = @minivcd_mbt.changes_at_timestamp(rich_vcd(), 5L)
  assert_eq(changes.length(), 1)
  assert_eq(changes[0].identifier, "!")
}

///|
test "timestamp buckets match timestamps" {
  let buckets = @minivcd_mbt.timestamp_buckets(rich_vcd())
  assert_eq(buckets.length(), 9)
  assert_eq(buckets[0].changes.length(), 6)
}

///|
test "change count at timestamp ten" {
  assert_eq(@minivcd_mbt.change_count_at_timestamp(rich_vcd(), 10L), 6)
}

///|
test "signal has changes true" {
  let result = @minivcd_mbt.signal_has_changes(rich_vcd(), "top.cpu.clk") catch {
    _ => panic()
  }
  assert_eq(result, true)
}

///|
test "signal has changes false for sparse signal" {
  let result = @minivcd_mbt.signal_has_changes(sparse_vcd(), "top.never") catch {
    _ => panic()
  }
  assert_eq(result, false)
}

///|
test "first value of clk is zero" {
  let value = @minivcd_mbt.first_value(rich_vcd(), "top.cpu.clk") catch {
    _ => panic()
  }
  assert_eq(value, Some("0"))
}

///|
test "last value of counter is 0100" {
  let value = @minivcd_mbt.last_value(rich_vcd(), "top.cpu.counter") catch {
    _ => panic()
  }
  assert_eq(value, Some("0100"))
}

///|
test "first value is none for unchanged signal" {
  let value = @minivcd_mbt.first_value(sparse_vcd(), "top.never") catch {
    _ => panic()
  }
  assert_eq(value, None)
}

///|
test "state has unknown values" {
  let result = @minivcd_mbt.signal_has_unknown(rich_vcd(), "top.cpu.state") catch {
    _ => panic()
  }
  assert_eq(result, true)
}

///|
test "data has high impedance values" {
  let result = @minivcd_mbt.signal_has_high_impedance(
    rich_vcd(),
    "top.bus.data",
  ) catch {
    _ => panic()
  }
  assert_eq(result, true)
}

///|
test "unknown change count for state" {
  let count = @minivcd_mbt.unknown_change_count(rich_vcd(), "top.cpu.state") catch {
    _ => panic()
  }
  assert_eq(count, 1)
}

///|
test "high impedance change count for data" {
  let count = @minivcd_mbt.high_impedance_change_count(
    rich_vcd(),
    "top.bus.data",
  ) catch {
    _ => panic()
  }
  assert_eq(count, 1)
}

///|
test "file unknown change count" {
  assert_eq(@minivcd_mbt.file_unknown_change_count(rich_vcd()), 1)
}

///|
test "file high impedance change count" {
  assert_eq(@minivcd_mbt.file_high_impedance_change_count(rich_vcd()), 1)
}

///|
test "signal transitions for clk" {
  let transitions = @minivcd_mbt.signal_transitions(rich_vcd(), "top.cpu.clk") catch {
    _ => panic()
  }
  assert_eq(transitions.length(), 8)
  assert_eq(transitions[0].previous, "0")
  assert_eq(transitions[0].current, "1")
}

///|
test "transition count ignores repeated values" {
  let text =
    #|$var wire 1 ! a $end
    #|$enddefinitions $end
    #|#0 0!
    #|#5 0!
    #|#10 1!
  let count = @minivcd_mbt.transition_count(parse_extended(text), "a") catch {
    _ => panic()
  }
  assert_eq(count, 1)
}

///|
test "value spans include open ended last span" {
  let spans = @minivcd_mbt.value_spans(rich_vcd(), "top.cpu.clk") catch {
    _ => panic()
  }
  assert_eq(spans.length(), 9)
  assert_eq(spans[0].start_time, 0L)
  assert_eq(spans[0].end_time, Some(5L))
  assert_eq(spans[8].end_time, None)
}

///|
test "snapshot at twenty has counter value" {
  let snapshot = @minivcd_mbt.snapshot_at(rich_vcd(), 20L) catch {
    _ => panic()
  }
  let value = @minivcd_mbt.snapshot_value(snapshot, "top.cpu.counter")
  assert_eq(value, Some("0010"))
}

///|
test "snapshot at zero has all values" {
  let snapshot = @minivcd_mbt.snapshot_at(rich_vcd(), 0L) catch { _ => panic() }
  assert_eq(snapshot.values.length(), 6)
  assert_eq(@minivcd_mbt.snapshot_value(snapshot, "top.bus.valid"), Some("0"))
}

///|
test "snapshots cover all timestamps" {
  let snapshots = @minivcd_mbt.snapshots(rich_vcd()) catch { _ => panic() }
  assert_eq(snapshots.length(), 9)
  assert_eq(snapshots[8].timestamp, 40L)
}

///|
test "snapshot completeness true for rich vcd" {
  let complete = @minivcd_mbt.snapshot_is_complete(rich_vcd(), 40L) catch {
    _ => panic()
  }
  assert_eq(complete, true)
}

///|
test "snapshot completeness false for sparse vcd before never value" {
  let complete = @minivcd_mbt.snapshot_is_complete(sparse_vcd(), 10L) catch {
    _ => panic()
  }
  assert_eq(complete, false)
}

///|
test "undefined signals at sparse timestamp" {
  let signals = @minivcd_mbt.undefined_signals_at(sparse_vcd(), 10L) catch {
    _ => panic()
  }
  assert_eq(signals.length(), 1)
  assert_eq(signals[0].full_name, "top.never")
}

///|
test "unchanged signals returns never" {
  let signals = @minivcd_mbt.unchanged_signals(sparse_vcd())
  assert_eq(signals.length(), 1)
  assert_eq(signals[0].full_name, "top.never")
}

///|
test "validate rich vcd has no issues" {
  assert_eq(@minivcd_mbt.validate_vcd(rich_vcd()).length(), 0)
}

///|
test "is valid vcd returns true" {
  assert_eq(@minivcd_mbt.is_valid_vcd(rich_vcd()), true)
}

///|
test "validate detects unknown identifier in constructed value" {
  let signals : Array[@minivcd_mbt.Signal] = []
  let changes : Array[@minivcd_mbt.SignalChange] = [
    { timestamp: 0L, identifier: "!", value: "0" },
  ]
  let vcd : @minivcd_mbt.VcdFile = {
    date: "",
    version: "",
    timescale: "1ns",
    signals,
    changes,
  }
  let issues = @minivcd_mbt.validate_vcd(vcd)
  assert_eq(issues.length(), 1)
  assert_eq(issues[0].code, "unknown-identifier")
}

///|
test "validate detects vector width mismatch" {
  let signal : @minivcd_mbt.Signal = {
    identifier: "#",
    name: "bus",
    full_name: "top.bus",
    width: 4,
    signal_type: "wire",
  }
  let changes : Array[@minivcd_mbt.SignalChange] = [
    { timestamp: 0L, identifier: "#", value: "10" },
  ]
  let vcd : @minivcd_mbt.VcdFile = {
    date: "",
    version: "",
    timescale: "1ns",
    signals: [signal],
    changes,
  }
  let issues = @minivcd_mbt.validate_vcd(vcd)
  assert_eq(issues[0].code, "vector-width")
}

///|
test "validate detects scalar width mismatch" {
  let signal : @minivcd_mbt.Signal = {
    identifier: "!",
    name: "a",
    full_name: "a",
    width: 1,
    signal_type: "wire",
  }
  let changes : Array[@minivcd_mbt.SignalChange] = [
    { timestamp: 0L, identifier: "!", value: "10" },
  ]
  let vcd : @minivcd_mbt.VcdFile = {
    date: "",
    version: "",
    timescale: "1ns",
    signals: [signal],
    changes,
  }
  let issues = @minivcd_mbt.validate_vcd(vcd)
  assert_eq(issues[0].code, "scalar-width")
}

///|
test "validate detects invalid value character" {
  let signal : @minivcd_mbt.Signal = {
    identifier: "!",
    name: "a",
    full_name: "a",
    width: 1,
    signal_type: "wire",
  }
  let changes : Array[@minivcd_mbt.SignalChange] = [
    { timestamp: 0L, identifier: "!", value: "q" },
  ]
  let vcd : @minivcd_mbt.VcdFile = {
    date: "",
    version: "",
    timescale: "1ns",
    signals: [signal],
    changes,
  }
  let issues = @minivcd_mbt.validate_vcd(vcd)
  assert_eq(issues[0].code, "invalid-value")
}

///|
test "validate detects time order issue" {
  let signal : @minivcd_mbt.Signal = {
    identifier: "!",
    name: "a",
    full_name: "a",
    width: 1,
    signal_type: "wire",
  }
  let changes : Array[@minivcd_mbt.SignalChange] = [
    { timestamp: 10L, identifier: "!", value: "0" },
    { timestamp: 5L, identifier: "!", value: "1" },
  ]
  let vcd : @minivcd_mbt.VcdFile = {
    date: "",
    version: "",
    timescale: "1ns",
    signals: [signal],
    changes,
  }
  let issues = @minivcd_mbt.validate_vcd(vcd)
  assert_true(issues.length() > 0)
}

///|
test "health summarizes rich vcd" {
  let health = @minivcd_mbt.health(rich_vcd())
  assert_eq(health.signal_count, 6)
  assert_eq(health.scalar_signal_count, 3)
  assert_eq(health.vector_signal_count, 3)
  assert_eq(health.issue_count, 0)
}

///|
test "render signal includes identifier" {
  let line = @minivcd_mbt.render_signal(rich_vcd().signals[0])
  assert_true(line.contains("top.cpu.clk"))
  assert_true(line.contains("!"))
}

///|
test "render change uses full name" {
  let vcd = rich_vcd()
  let line = @minivcd_mbt.render_change(vcd, vcd.changes[0])
  assert_true(line.contains("top.cpu.clk"))
}

///|
test "render info contains counts" {
  let text = @minivcd_mbt.render_info(rich_vcd())
  assert_true(text.contains("Signals: 6"))
  assert_true(text.contains("Changes: 30"))
}

///|
test "render signals contains bus data" {
  let text = @minivcd_mbt.render_signals(rich_vcd())
  assert_true(text.contains("top.bus.data"))
}

///|
test "render signal changes contains values" {
  let text = @minivcd_mbt.render_signal_changes(rich_vcd(), "top.cpu.clk") catch {
    _ => panic()
  }
  assert_true(text.contains("5\t1"))
}

///|
test "render buckets labels timestamps" {
  let text = @minivcd_mbt.render_buckets(rich_vcd())
  assert_true(text.contains("#0 changes=6"))
}

///|
test "render snapshot includes header and values" {
  let snapshot = @minivcd_mbt.snapshot_at(rich_vcd(), 20L) catch {
    _ => panic()
  }
  let text = @minivcd_mbt.render_snapshot(
    snapshot,
    @minivcd_mbt.default_render_options(),
  )
  assert_true(text.contains("timestamp"))
  assert_true(text.contains("top.cpu.counter"))
}

///|
test "render timeline includes only one header" {
  let text = @minivcd_mbt.render_timeline(
    rich_vcd(),
    @minivcd_mbt.default_render_options(),
  ) catch {
    _ => panic()
  }
  assert_true(text.contains("timestamp"))
  assert_true(text.contains("40\ttop.cpu.counter\t0100"))
}

///|
test "render issues prints code and message" {
  let issues : Array[@minivcd_mbt.VcdIssue] = [
    {
      code: "demo",
      message: "example issue",
      timestamp: Some(1L),
      signal: Some("top.a"),
    },
  ]
  let text = @minivcd_mbt.render_issues(issues)
  assert_true(text.contains("demo"))
  assert_true(text.contains("example issue"))
}

///|
test "render health includes issue count" {
  let text = @minivcd_mbt.render_health(rich_vcd())
  assert_true(text.contains("Validation issues: 0"))
}

///|
test "scalar logic value accepts zero" {
  assert_eq(@minivcd_mbt.is_scalar_logic_value("0"), true)
}

///|
test "scalar logic value rejects vector" {
  assert_eq(@minivcd_mbt.is_scalar_logic_value("01"), false)
}

///|
test "vector logic value accepts four bits" {
  assert_eq(@minivcd_mbt.is_vector_logic_value("01xz"), true)
}

///|
test "vector logic value rejects scalar" {
  assert_eq(@minivcd_mbt.is_vector_logic_value("1"), false)
}

///|
test "known binary accepts 1010" {
  assert_eq(@minivcd_mbt.is_known_binary("1010"), true)
}

///|
test "known binary rejects unknown" {
  assert_eq(@minivcd_mbt.is_known_binary("10x0"), false)
}

///|
test "has unknown bit" {
  assert_eq(@minivcd_mbt.has_unknown_bit("10x0"), true)
}

///|
test "has high impedance bit" {
  assert_eq(@minivcd_mbt.has_high_impedance_bit("10z0"), true)
}

///|
test "zero bit count" {
  assert_eq(@minivcd_mbt.zero_bit_count("001xz"), 2)
}

///|
test "one bit count" {
  assert_eq(@minivcd_mbt.one_bit_count("101xz"), 2)
}

///|
test "unknown bit count" {
  assert_eq(@minivcd_mbt.unknown_bit_count("xx10"), 2)
}

///|
test "high impedance bit count" {
  assert_eq(@minivcd_mbt.high_impedance_bit_count("zz10"), 2)
}

///|
test "logic counts summarizes value" {
  let counts = @minivcd_mbt.logic_counts("01xz")
  assert_eq(counts.zeros, 1)
  assert_eq(counts.ones, 1)
  assert_eq(counts.unknowns, 1)
  assert_eq(counts.high_impedances, 1)
  assert_eq(counts.width, 4)
}

///|
test "classify zero value" {
  assert_eq(@minivcd_mbt.classify_value("0000"), "zero")
}

///|
test "classify one value" {
  assert_eq(@minivcd_mbt.classify_value("1111"), "one")
}

///|
test "classify known binary mixed value" {
  assert_eq(@minivcd_mbt.classify_value("1010"), "known-binary")
}

///|
test "classify unknown value" {
  assert_eq(@minivcd_mbt.classify_value("10x0"), "unknown")
}

///|
test "classify high impedance value" {
  assert_eq(@minivcd_mbt.classify_value("10z0"), "high-impedance")
}

///|
test "classify mixed unknown and high impedance value" {
  assert_eq(@minivcd_mbt.classify_value("xz"), "mixed-unknown-high-impedance")
}

///|
test "binary value to int converts ten" {
  assert_eq(@minivcd_mbt.binary_value_to_int64("1010"), Some(10L))
}

///|
test "binary value to int rejects x" {
  assert_eq(@minivcd_mbt.binary_value_to_int64("10x0"), None)
}

///|
test "hamming distance equal width" {
  assert_eq(@minivcd_mbt.hamming_distance("1010", "1001"), Some(2))
}

///|
test "hamming distance rejects unequal width" {
  assert_eq(@minivcd_mbt.hamming_distance("10", "100"), None)
}

///|
test "distinct values for valid" {
  let values = @minivcd_mbt.distinct_values(rich_vcd(), "top.bus.valid") catch {
    _ => panic()
  }
  assert_eq(values.length(), 2)
}

///|
test "value counts for clk" {
  let counts = @minivcd_mbt.value_counts(rich_vcd(), "top.cpu.clk") catch {
    _ => panic()
  }
  assert_eq(counts.length(), 2)
}

///|
test "count value for clk zeros" {
  let count = @minivcd_mbt.count_value(rich_vcd(), "top.cpu.clk", "0") catch {
    _ => panic()
  }
  assert_eq(count, 5)
}

///|
test "first change at or after returns exact hit" {
  let change = @minivcd_mbt.first_change_at_or_after(
    rich_vcd(),
    "top.cpu.clk",
    10L,
  ) catch {
    _ => panic()
  }
  match change {
    Some(change) => assert_eq(change.timestamp, 10L)
    None => panic()
  }
}

///|
test "first change at or after skips to next" {
  let change = @minivcd_mbt.first_change_at_or_after(
    rich_vcd(),
    "top.cpu.clk",
    12L,
  ) catch {
    _ => panic()
  }
  match change {
    Some(change) => assert_eq(change.timestamp, 15L)
    None => panic()
  }
}

///|
test "first change at or after returns none after end" {
  let change = @minivcd_mbt.first_change_at_or_after(
    rich_vcd(),
    "top.cpu.clk",
    50L,
  ) catch {
    _ => panic()
  }
  assert_eq(change, None)
}

///|
test "last change at or before returns exact hit" {
  let change = @minivcd_mbt.last_change_at_or_before(
    rich_vcd(),
    "top.cpu.clk",
    10L,
  ) catch {
    _ => panic()
  }
  match change {
    Some(change) => assert_eq(change.timestamp, 10L)
    None => panic()
  }
}

///|
test "last change at or before returns previous" {
  let change = @minivcd_mbt.last_change_at_or_before(
    rich_vcd(),
    "top.cpu.clk",
    12L,
  ) catch {
    _ => panic()
  }
  match change {
    Some(change) => assert_eq(change.timestamp, 10L)
    None => panic()
  }
}

///|
test "last change at or before none before start" {
  let change = @minivcd_mbt.last_change_at_or_before(
    rich_vcd(),
    "top.cpu.clk",
    0L,
  ) catch {
    _ => panic()
  }
  match change {
    Some(change) => assert_eq(change.timestamp, 0L)
    None => panic()
  }
}

///|
test "signal changes in window" {
  let changes = @minivcd_mbt.signal_changes_in_window(
    rich_vcd(),
    "top.cpu.clk",
    { start_time: 10L, end_time: 20L },
  ) catch {
    _ => panic()
  }
  assert_eq(changes.length(), 3)
}

///|
test "all changes in window" {
  let changes = @minivcd_mbt.changes_in_window(rich_vcd(), {
    start_time: 20L,
    end_time: 20L,
  }) catch {
    _ => panic()
  }
  assert_eq(changes.length(), 4)
}

///|
test "change count in window" {
  let count = @minivcd_mbt.change_count_in_window(rich_vcd(), {
    start_time: 0L,
    end_time: 5L,
  }) catch {
    _ => panic()
  }
  assert_eq(count, 7)
}

///|
test "signal changes inside window true" {
  let result = @minivcd_mbt.signal_changes_inside_window(
    rich_vcd(),
    "top.cpu.clk",
    { start_time: 5L, end_time: 5L },
  ) catch {
    _ => panic()
  }
  assert_eq(result, true)
}

///|
test "signal changes inside window false" {
  let result = @minivcd_mbt.signal_changes_inside_window(
    rich_vcd(),
    "top.cpu.rst",
    { start_time: 20L, end_time: 30L },
  ) catch {
    _ => panic()
  }
  assert_eq(result, false)
}

///|
test "first time in window" {
  let time = @minivcd_mbt.first_time_in_window(rich_vcd(), {
    start_time: 12L,
    end_time: 18L,
  }) catch {
    _ => panic()
  }
  assert_eq(time, Some(15L))
}

///|
test "last time in window" {
  let time = @minivcd_mbt.last_time_in_window(rich_vcd(), {
    start_time: 12L,
    end_time: 22L,
  }) catch {
    _ => panic()
  }
  assert_eq(time, Some(20L))
}

///|
test "window rejects negative start" {
  expect_vcd_error(
    fn() raise {
      let _ = @minivcd_mbt.changes_in_window(rich_vcd(), {
        start_time: -1L,
        end_time: 2L,
      })
    },
    "non-negative",
  )
}

///|
test "window rejects reversed bounds" {
  expect_vcd_error(
    fn() raise {
      let _ = @minivcd_mbt.changes_in_window(rich_vcd(), {
        start_time: 5L,
        end_time: 2L,
      })
    },
    "end must not be before start",
  )
}

///|
test "signal coverage summarizes clk" {
  let coverage = @minivcd_mbt.signal_coverage(rich_vcd(), "top.cpu.clk") catch {
    _ => panic()
  }
  assert_eq(coverage.has_value, true)
  assert_eq(coverage.change_count, 9)
  assert_eq(coverage.transition_count, 8)
}

///|
test "all signal coverage includes six signals" {
  let coverage = @minivcd_mbt.all_signal_coverage(rich_vcd()) catch {
    _ => panic()
  }
  assert_eq(coverage.length(), 6)
}

///|
test "covered signal count rich vcd" {
  let count = @minivcd_mbt.covered_signal_count(rich_vcd()) catch {
    _ => panic()
  }
  assert_eq(count, 6)
}

///|
test "uncovered signal count sparse vcd" {
  assert_eq(@minivcd_mbt.uncovered_signal_count(sparse_vcd()), 1)
}

///|
test "render value counts includes header" {
  let text = @minivcd_mbt.render_value_counts(rich_vcd(), "top.cpu.clk") catch {
    _ => panic()
  }
  assert_true(text.contains("value\tcount"))
}

///|
test "render coverage includes signal name" {
  let text = @minivcd_mbt.render_coverage(rich_vcd()) catch { _ => panic() }
  assert_true(text.contains("top.cpu.clk"))
  assert_true(text.contains("signal\thas_value"))
}
