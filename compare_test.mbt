///|
fn left_compare_vcd() -> @minivcd_mbt.VcdFile {
  parse_extended(
    (
      #|$timescale 1ns $end
      #|$scope module top $end
      #|$var wire 1 ! clk $end
      #|$var wire 4 " counter $end
      #|$var wire 1 # only_left $end
      #|$upscope $end
      #|$enddefinitions $end
      #|#0 0! b0000 " 1#
      #|#5 1!
      #|#10 0! b0001 "
      #|#20 1#
    ),
  )
}

///|
fn right_compare_vcd() -> @minivcd_mbt.VcdFile {
  parse_extended(
    (
      #|$timescale 1ns $end
      #|$scope module top $end
      #|$var wire 1 ! clk $end
      #|$var wire 4 " counter $end
      #|$var wire 1 $ only_right $end
      #|$upscope $end
      #|$enddefinitions $end
      #|#0 0! b0000 " 0$
      #|#5 1!
      #|#10 0! b0010 "
      #|#15 1$
    ),
  )
}

///|
fn right_width_mismatch_vcd() -> @minivcd_mbt.VcdFile {
  parse_extended(
    (
      #|$timescale 1ns $end
      #|$scope module top $end
      #|$var wire 1 ! clk $end
      #|$var wire 8 " counter $end
      #|$upscope $end
      #|$enddefinitions $end
      #|#0 0! b00000000 "
    ),
  )
}

///|
fn right_type_mismatch_vcd() -> @minivcd_mbt.VcdFile {
  parse_extended(
    (
      #|$timescale 1ns $end
      #|$scope module top $end
      #|$var reg 1 ! clk $end
      #|$var wire 4 " counter $end
      #|$upscope $end
      #|$enddefinitions $end
      #|#0 0! b0000 "
    ),
  )
}

///|
test "compare signal sets finds common signals" {
  let diff = @minivcd_mbt.compare_signal_sets(
    left_compare_vcd(),
    right_compare_vcd(),
  )
  assert_eq(diff.common.length(), 2)
  assert_eq(diff.common[0], "top.clk")
}

///|
test "compare signal sets finds left only signal" {
  let diff = @minivcd_mbt.compare_signal_sets(
    left_compare_vcd(),
    right_compare_vcd(),
  )
  assert_eq(diff.left_only.length(), 1)
  assert_eq(diff.left_only[0], "top.only_left")
}

///|
test "compare signal sets finds right only signal" {
  let diff = @minivcd_mbt.compare_signal_sets(
    left_compare_vcd(),
    right_compare_vcd(),
  )
  assert_eq(diff.right_only.length(), 1)
  assert_eq(diff.right_only[0], "top.only_right")
}

///|
test "compare signal sets finds width mismatch" {
  let diff = @minivcd_mbt.compare_signal_sets(
    left_compare_vcd(),
    right_width_mismatch_vcd(),
  )
  assert_eq(diff.width_mismatches.length(), 1)
  assert_eq(diff.width_mismatches[0], "top.counter")
}

///|
test "compare signal sets finds type mismatch" {
  let diff = @minivcd_mbt.compare_signal_sets(
    left_compare_vcd(),
    right_type_mismatch_vcd(),
  )
  assert_eq(diff.type_mismatches.length(), 1)
  assert_eq(diff.type_mismatches[0], "top.clk")
}

///|
test "compare timestamps finds common timestamps" {
  let diff = @minivcd_mbt.compare_timestamps(
    left_compare_vcd(),
    right_compare_vcd(),
  )
  assert_eq(diff.common.length(), 3)
  assert_eq(diff.common[2], 10L)
}

///|
test "compare timestamps finds left only timestamp" {
  let diff = @minivcd_mbt.compare_timestamps(
    left_compare_vcd(),
    right_compare_vcd(),
  )
  assert_eq(diff.left_only.length(), 1)
  assert_eq(diff.left_only[0], 20L)
}

///|
test "compare timestamps finds right only timestamp" {
  let diff = @minivcd_mbt.compare_timestamps(
    left_compare_vcd(),
    right_compare_vcd(),
  )
  assert_eq(diff.right_only.length(), 1)
  assert_eq(diff.right_only[0], 15L)
}

///|
test "compare values at equal timestamp finds counter diff" {
  let diffs = @minivcd_mbt.compare_values_at(
    left_compare_vcd(),
    right_compare_vcd(),
    10L,
  ) catch {
    _ => panic()
  }
  assert_true(diffs.length() >= 1)
  assert_eq(diffs[0].full_name, "top.counter")
}

///|
test "compare values at zero includes missing side signals" {
  let diffs = @minivcd_mbt.compare_values_at(
    left_compare_vcd(),
    right_compare_vcd(),
    0L,
  ) catch {
    _ => panic()
  }
  assert_eq(diffs.length(), 2)
}

///|
test "compare values rejects negative timestamp" {
  try
    @minivcd_mbt.compare_values_at(left_compare_vcd(), right_compare_vcd(), -1L)
  catch {
    @minivcd_mbt.VcdError(message) =>
      assert_true(message.contains("non-negative"))
  } noraise {
    _ => panic()
  }
}

///|
test "compare values on union timeline includes several diffs" {
  let diffs = @minivcd_mbt.compare_values_on_union_timeline(
    left_compare_vcd(),
    right_compare_vcd(),
  ) catch {
    _ => panic()
  }
  assert_true(diffs.length() > 3)
}

///|
test "compare vcd returns nested diff" {
  let diff = @minivcd_mbt.compare_vcd(left_compare_vcd(), right_compare_vcd()) catch {
    _ => panic()
  }
  assert_eq(diff.signal_diff.left_only.length(), 1)
  assert_true(diff.value_diffs.length() > 0)
}

///|
test "same signal set false when names differ" {
  assert_eq(
    @minivcd_mbt.vcds_have_same_signal_set(
      left_compare_vcd(),
      right_compare_vcd(),
    ),
    false,
  )
}

///|
test "same signal set true for identical file" {
  assert_eq(
    @minivcd_mbt.vcds_have_same_signal_set(
      left_compare_vcd(),
      left_compare_vcd(),
    ),
    true,
  )
}

///|
test "same timestamps false when one side has extra time" {
  assert_eq(
    @minivcd_mbt.vcds_have_same_timestamps(
      left_compare_vcd(),
      right_compare_vcd(),
    ),
    false,
  )
}

///|
test "same timestamps true for identical file" {
  assert_eq(
    @minivcd_mbt.vcds_have_same_timestamps(
      left_compare_vcd(),
      left_compare_vcd(),
    ),
    true,
  )
}

///|
test "same values false for changed counter" {
  let same = @minivcd_mbt.vcds_have_same_values(
    left_compare_vcd(),
    right_compare_vcd(),
  ) catch {
    _ => panic()
  }
  assert_eq(same, false)
}

///|
test "same values true for identical file" {
  let same = @minivcd_mbt.vcds_have_same_values(
    left_compare_vcd(),
    left_compare_vcd(),
  ) catch {
    _ => panic()
  }
  assert_eq(same, true)
}

///|
test "vcds equivalent false for changed files" {
  let same = @minivcd_mbt.vcds_are_equivalent(
    left_compare_vcd(),
    right_compare_vcd(),
  ) catch {
    _ => panic()
  }
  assert_eq(same, false)
}

///|
test "vcds equivalent true for identical files" {
  let same = @minivcd_mbt.vcds_are_equivalent(
    left_compare_vcd(),
    left_compare_vcd(),
  ) catch {
    _ => panic()
  }
  assert_eq(same, true)
}

///|
test "count value diffs at ten" {
  let count = @minivcd_mbt.count_value_diffs_at(
    left_compare_vcd(),
    right_compare_vcd(),
    10L,
  ) catch {
    _ => panic()
  }
  assert_true(count >= 1)
}

///|
test "first value diff returns earliest diff" {
  let diff = @minivcd_mbt.first_value_diff(
    left_compare_vcd(),
    right_compare_vcd(),
  ) catch {
    _ => panic()
  }
  match diff {
    Some(diff) => assert_eq(diff.timestamp, 0L)
    None => panic()
  }
}

///|
test "first value diff none for identical files" {
  let diff = @minivcd_mbt.first_value_diff(
    left_compare_vcd(),
    left_compare_vcd(),
  ) catch {
    _ => panic()
  }
  assert_eq(diff, None)
}

///|
test "value diff count is positive" {
  let count = @minivcd_mbt.value_diff_count(
    left_compare_vcd(),
    right_compare_vcd(),
  ) catch {
    _ => panic()
  }
  assert_true(count > 0)
}

///|
test "signal value diff count filters by signal" {
  let count = @minivcd_mbt.signal_value_diff_count(
    left_compare_vcd(),
    right_compare_vcd(),
    "top.counter",
  ) catch {
    _ => panic()
  }
  assert_true(count >= 1)
}

///|
test "render signal set diff mentions left only" {
  let text = @minivcd_mbt.render_signal_set_diff(
    @minivcd_mbt.compare_signal_sets(left_compare_vcd(), right_compare_vcd()),
  )
  assert_true(text.contains("Left-only signals"))
}

///|
test "render timestamp diff mentions right only" {
  let text = @minivcd_mbt.render_timestamp_diff(
    @minivcd_mbt.compare_timestamps(left_compare_vcd(), right_compare_vcd()),
  )
  assert_true(text.contains("Right-only timestamps"))
}

///|
test "render value diff contains signal name" {
  let diff : @minivcd_mbt.ValueDiff = {
    timestamp: 10L,
    full_name: "top.counter",
    left: Some("0001"),
    right: Some("0010"),
  }
  let text = @minivcd_mbt.render_value_diff(diff)
  assert_true(text.contains("top.counter"))
}

///|
test "render value diffs contains header" {
  let diffs = @minivcd_mbt.compare_values_at(
    left_compare_vcd(),
    right_compare_vcd(),
    10L,
  ) catch {
    _ => panic()
  }
  let text = @minivcd_mbt.render_value_diffs(diffs)
  assert_true(text.contains("timestamp\tsignal\tleft\tright"))
}

///|
test "render vcd diff contains sections" {
  let diff = @minivcd_mbt.compare_vcd(left_compare_vcd(), right_compare_vcd()) catch {
    _ => panic()
  }
  let text = @minivcd_mbt.render_vcd_diff(diff)
  assert_true(text.contains("Signal differences"))
  assert_true(text.contains("Value differences"))
}

///|
test "markdown signal set diff contains heading" {
  let text = @minivcd_mbt.markdown_signal_set_diff(
    @minivcd_mbt.compare_signal_sets(left_compare_vcd(), right_compare_vcd()),
  )
  assert_true(text.contains("## Signal Differences"))
}

///|
test "markdown timestamp diff contains heading" {
  let text = @minivcd_mbt.markdown_timestamp_diff(
    @minivcd_mbt.compare_timestamps(left_compare_vcd(), right_compare_vcd()),
  )
  assert_true(text.contains("## Timestamp Differences"))
}

///|
test "markdown value diffs contains table header" {
  let diffs = @minivcd_mbt.compare_values_at(
    left_compare_vcd(),
    right_compare_vcd(),
    10L,
  ) catch {
    _ => panic()
  }
  let text = @minivcd_mbt.markdown_value_diffs(diffs)
  assert_true(text.contains("| Timestamp | Signal | Left | Right |"))
}

///|
test "markdown vcd diff contains title" {
  let diff = @minivcd_mbt.compare_vcd(left_compare_vcd(), right_compare_vcd()) catch {
    _ => panic()
  }
  let text = @minivcd_mbt.markdown_vcd_diff(diff)
  assert_true(text.contains("# VCD Comparison"))
}

///|
test "comparison manifest contains counts" {
  let diff = @minivcd_mbt.compare_vcd(left_compare_vcd(), right_compare_vcd()) catch {
    _ => panic()
  }
  let text = @minivcd_mbt.comparison_manifest(diff)
  assert_true(text.contains("common_signals=2"))
  assert_true(text.contains("value_diffs="))
}

///|
test "compare and render returns plain text" {
  let text = @minivcd_mbt.compare_and_render(
    left_compare_vcd(),
    right_compare_vcd(),
  ) catch {
    _ => panic()
  }
  assert_true(text.contains("Timestamp differences"))
}

///|
test "compare and render markdown returns markdown" {
  let text = @minivcd_mbt.compare_and_render_markdown(
    left_compare_vcd(),
    right_compare_vcd(),
  ) catch {
    _ => panic()
  }
  assert_true(text.contains("# VCD Comparison"))
}

///|
test "comparison manifest for identical files has zero value diffs" {
  let diff = @minivcd_mbt.compare_vcd(left_compare_vcd(), left_compare_vcd()) catch {
    _ => panic()
  }
  let text = @minivcd_mbt.comparison_manifest(diff)
  assert_true(text.contains("value_diffs=0"))
}
