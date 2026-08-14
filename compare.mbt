///|
fn string_array_contains(values : Array[String], target : String) -> Bool {
  for value in values {
    if value == target {
      return true
    }
  }
  false
}

///|
fn int64_array_contains(values : Array[Int64], target : Int64) -> Bool {
  for value in values {
    if value == target {
      return true
    }
  }
  false
}

///|
fn push_unique_string(values : Array[String], value : String) -> Unit {
  if !string_array_contains(values, value) {
    values.push(value)
  }
}

///|
fn push_unique_int64(values : Array[Int64], value : Int64) -> Unit {
  if !int64_array_contains(values, value) {
    values.push(value)
  }
}

///|
fn option_string_equals(left : String?, right : String?) -> Bool {
  match (left, right) {
    (Some(l), Some(r)) => l == r
    (None, None) => true
    _ => false
  }
}

///|
fn option_string_text(value : String?) -> String {
  match value {
    Some(value) => value
    None => "-"
  }
}

///|
fn find_signal_or_none(vcd : VcdFile, full_name : String) -> Signal? {
  find_signal(vcd, full_name)
}

///|
fn same_width(left : Signal, right : Signal) -> Bool {
  left.width == right.width
}

///|
fn same_type(left : Signal, right : Signal) -> Bool {
  left.signal_type == right.signal_type
}

///|
fn names_from_signals(signals : Array[Signal]) -> Array[String] {
  let result : Array[String] = []
  for signal in signals {
    result.push(signal.full_name)
  }
  result
}

///|
fn merged_signal_names(left : VcdFile, right : VcdFile) -> Array[String] {
  let result : Array[String] = []
  for name in names_from_signals(left.signals) {
    push_unique_string(result, name)
  }
  for name in names_from_signals(right.signals) {
    push_unique_string(result, name)
  }
  result
}

///|
fn merged_timestamps(left : VcdFile, right : VcdFile) -> Array[Int64] {
  let result : Array[Int64] = []
  for time in timestamps(left) {
    push_unique_int64(result, time)
  }
  for time in timestamps(right) {
    push_unique_int64(result, time)
  }
  result
}

///|
fn append_signal_list(
  builder : StringBuilder,
  title : String,
  values : Array[String],
) -> Unit {
  builder.write_string(title)
  builder.write_string(": ")
  if values.is_empty() {
    builder.write_string("none\n")
  } else {
    for i = 0; i < values.length(); i = i + 1 {
      if i > 0 {
        builder.write_string(", ")
      }
      builder.write_string(values[i])
    }
    builder.write_char('\n')
  }
}

///|
fn append_time_list(
  builder : StringBuilder,
  title : String,
  values : Array[Int64],
) -> Unit {
  builder.write_string(title)
  builder.write_string(": ")
  if values.is_empty() {
    builder.write_string("none\n")
  } else {
    for i = 0; i < values.length(); i = i + 1 {
      if i > 0 {
        builder.write_string(", ")
      }
      builder.write_string(values[i].to_string())
    }
    builder.write_char('\n')
  }
}

///|
fn markdown_string_list(
  builder : StringBuilder,
  title : String,
  values : Array[String],
) -> Unit {
  builder.write_string("- ")
  builder.write_string(title)
  builder.write_string(": ")
  if values.is_empty() {
    builder.write_string("none\n")
  } else {
    for i = 0; i < values.length(); i = i + 1 {
      if i > 0 {
        builder.write_string(", ")
      }
      builder.write_string(values[i])
    }
    builder.write_char('\n')
  }
}

///|
fn markdown_time_list(
  builder : StringBuilder,
  title : String,
  values : Array[Int64],
) -> Unit {
  builder.write_string("- ")
  builder.write_string(title)
  builder.write_string(": ")
  if values.is_empty() {
    builder.write_string("none\n")
  } else {
    for i = 0; i < values.length(); i = i + 1 {
      if i > 0 {
        builder.write_string(", ")
      }
      builder.write_string(values[i].to_string())
    }
    builder.write_char('\n')
  }
}

///|
pub fn compare_signal_sets(left : VcdFile, right : VcdFile) -> SignalSetDiff {
  let common : Array[String] = []
  let left_only : Array[String] = []
  let right_only : Array[String] = []
  let width_mismatches : Array[String] = []
  let type_mismatches : Array[String] = []
  for left_signal in left.signals {
    match find_signal_or_none(right, left_signal.full_name) {
      Some(right_signal) => {
        common.push(left_signal.full_name)
        if !same_width(left_signal, right_signal) {
          width_mismatches.push(left_signal.full_name)
        }
        if !same_type(left_signal, right_signal) {
          type_mismatches.push(left_signal.full_name)
        }
      }
      None => left_only.push(left_signal.full_name)
    }
  }
  for right_signal in right.signals {
    if find_signal_or_none(left, right_signal.full_name) is None {
      right_only.push(right_signal.full_name)
    }
  }
  { common, left_only, right_only, width_mismatches, type_mismatches }
}

///|
pub fn compare_timestamps(left : VcdFile, right : VcdFile) -> TimestampDiff {
  let common : Array[Int64] = []
  let left_only : Array[Int64] = []
  let right_only : Array[Int64] = []
  let left_times = timestamps(left)
  let right_times = timestamps(right)
  for time in left_times {
    if int64_array_contains(right_times, time) {
      common.push(time)
    } else {
      left_only.push(time)
    }
  }
  for time in right_times {
    if !int64_array_contains(left_times, time) {
      right_only.push(time)
    }
  }
  { common, left_only, right_only }
}

///|
pub fn compare_values_at(
  left : VcdFile,
  right : VcdFile,
  timestamp : Int64,
) -> Array[ValueDiff] raise VcdError {
  if timestamp < 0L {
    raise VcdError("timestamp must be non-negative")
  }
  let result : Array[ValueDiff] = []
  for name in merged_signal_names(left, right) {
    let left_value = if find_signal(left, name) is Some(_) {
      value_at(left, name, timestamp)
    } else {
      None
    }
    let right_value = if find_signal(right, name) is Some(_) {
      value_at(right, name, timestamp)
    } else {
      None
    }
    if !option_string_equals(left_value, right_value) {
      result.push({
        timestamp,
        full_name: name,
        left: left_value,
        right: right_value,
      })
    }
  }
  result
}

///|
pub fn compare_values_on_union_timeline(
  left : VcdFile,
  right : VcdFile,
) -> Array[ValueDiff] raise VcdError {
  let result : Array[ValueDiff] = []
  for time in merged_timestamps(left, right) {
    for diff in compare_values_at(left, right, time) {
      result.push(diff)
    }
  }
  result
}

///|
pub fn compare_vcd(left : VcdFile, right : VcdFile) -> VcdDiff raise VcdError {
  {
    signal_diff: compare_signal_sets(left, right),
    timestamp_diff: compare_timestamps(left, right),
    value_diffs: compare_values_on_union_timeline(left, right),
  }
}

///|
pub fn vcds_have_same_signal_set(left : VcdFile, right : VcdFile) -> Bool {
  let diff = compare_signal_sets(left, right)
  diff.left_only.is_empty() &&
  diff.right_only.is_empty() &&
  diff.width_mismatches.is_empty() &&
  diff.type_mismatches.is_empty()
}

///|
pub fn vcds_have_same_timestamps(left : VcdFile, right : VcdFile) -> Bool {
  let diff = compare_timestamps(left, right)
  diff.left_only.is_empty() && diff.right_only.is_empty()
}

///|
pub fn vcds_have_same_values(
  left : VcdFile,
  right : VcdFile,
) -> Bool raise VcdError {
  compare_values_on_union_timeline(left, right).is_empty()
}

///|
pub fn vcds_are_equivalent(
  left : VcdFile,
  right : VcdFile,
) -> Bool raise VcdError {
  vcds_have_same_signal_set(left, right) &&
  vcds_have_same_timestamps(left, right) &&
  vcds_have_same_values(left, right)
}

///|
pub fn count_value_diffs_at(
  left : VcdFile,
  right : VcdFile,
  timestamp : Int64,
) -> Int raise VcdError {
  compare_values_at(left, right, timestamp).length()
}

///|
pub fn first_value_diff(
  left : VcdFile,
  right : VcdFile,
) -> ValueDiff? raise VcdError {
  let diffs = compare_values_on_union_timeline(left, right)
  if diffs.is_empty() {
    None
  } else {
    Some(diffs[0])
  }
}

///|
pub fn value_diff_count(left : VcdFile, right : VcdFile) -> Int raise VcdError {
  compare_values_on_union_timeline(left, right).length()
}

///|
pub fn signal_value_diff_count(
  left : VcdFile,
  right : VcdFile,
  full_name : String,
) -> Int raise VcdError {
  let mut count = 0
  for diff in compare_values_on_union_timeline(left, right) {
    if diff.full_name == full_name {
      count = count + 1
    }
  }
  count
}

///|
pub fn render_signal_set_diff(diff : SignalSetDiff) -> String {
  let builder = StringBuilder()
  append_signal_list(builder, "Common signals", diff.common)
  append_signal_list(builder, "Left-only signals", diff.left_only)
  append_signal_list(builder, "Right-only signals", diff.right_only)
  append_signal_list(builder, "Width mismatches", diff.width_mismatches)
  append_signal_list(builder, "Type mismatches", diff.type_mismatches)
  builder.to_string()
}

///|
pub fn render_timestamp_diff(diff : TimestampDiff) -> String {
  let builder = StringBuilder()
  append_time_list(builder, "Common timestamps", diff.common)
  append_time_list(builder, "Left-only timestamps", diff.left_only)
  append_time_list(builder, "Right-only timestamps", diff.right_only)
  builder.to_string()
}

///|
pub fn render_value_diff(diff : ValueDiff) -> String {
  "\{diff.timestamp}\t\{diff.full_name}\t\{option_string_text(diff.left)}\t\{option_string_text(diff.right)}"
}

///|
pub fn render_value_diffs(diffs : Array[ValueDiff]) -> String {
  let builder = StringBuilder()
  builder.write_string("timestamp\tsignal\tleft\tright\n")
  for diff in diffs {
    builder.write_string(render_value_diff(diff))
    builder.write_char('\n')
  }
  builder.to_string()
}

///|
pub fn render_vcd_diff(diff : VcdDiff) -> String {
  let builder = StringBuilder()
  builder.write_string("Signal differences\n")
  builder.write_string(render_signal_set_diff(diff.signal_diff))
  builder.write_string("\nTimestamp differences\n")
  builder.write_string(render_timestamp_diff(diff.timestamp_diff))
  builder.write_string("\nValue differences\n")
  builder.write_string(render_value_diffs(diff.value_diffs))
  builder.to_string()
}

///|
pub fn markdown_signal_set_diff(diff : SignalSetDiff) -> String {
  let builder = StringBuilder()
  builder.write_string("## Signal Differences\n\n")
  markdown_string_list(builder, "Common signals", diff.common)
  markdown_string_list(builder, "Left-only signals", diff.left_only)
  markdown_string_list(builder, "Right-only signals", diff.right_only)
  markdown_string_list(builder, "Width mismatches", diff.width_mismatches)
  markdown_string_list(builder, "Type mismatches", diff.type_mismatches)
  builder.to_string()
}

///|
pub fn markdown_timestamp_diff(diff : TimestampDiff) -> String {
  let builder = StringBuilder()
  builder.write_string("## Timestamp Differences\n\n")
  markdown_time_list(builder, "Common timestamps", diff.common)
  markdown_time_list(builder, "Left-only timestamps", diff.left_only)
  markdown_time_list(builder, "Right-only timestamps", diff.right_only)
  builder.to_string()
}

///|
pub fn markdown_value_diffs(diffs : Array[ValueDiff]) -> String {
  let builder = StringBuilder()
  builder.write_string("## Value Differences\n\n")
  builder.write_string("| Timestamp | Signal | Left | Right |\n")
  builder.write_string("| --- | --- | --- | --- |\n")
  for diff in diffs {
    builder.write_string("| ")
    builder.write_string(diff.timestamp.to_string())
    builder.write_string(" | ")
    builder.write_string(diff.full_name)
    builder.write_string(" | ")
    builder.write_string(option_string_text(diff.left))
    builder.write_string(" | ")
    builder.write_string(option_string_text(diff.right))
    builder.write_string(" |\n")
  }
  builder.to_string()
}

///|
pub fn markdown_vcd_diff(diff : VcdDiff) -> String {
  let builder = StringBuilder()
  builder.write_string("# VCD Comparison\n\n")
  builder.write_string(markdown_signal_set_diff(diff.signal_diff))
  builder.write_char('\n')
  builder.write_string(markdown_timestamp_diff(diff.timestamp_diff))
  builder.write_char('\n')
  builder.write_string(markdown_value_diffs(diff.value_diffs))
  builder.to_string()
}

///|
pub fn comparison_manifest(diff : VcdDiff) -> String {
  "common_signals=\{diff.signal_diff.common.length()} left_only_signals=\{diff.signal_diff.left_only.length()} right_only_signals=\{diff.signal_diff.right_only.length()} common_timestamps=\{diff.timestamp_diff.common.length()} value_diffs=\{diff.value_diffs.length()}"
}

///|
pub fn compare_and_render(
  left : VcdFile,
  right : VcdFile,
) -> String raise VcdError {
  render_vcd_diff(compare_vcd(left, right))
}

///|
pub fn compare_and_render_markdown(
  left : VcdFile,
  right : VcdFile,
) -> String raise VcdError {
  markdown_vcd_diff(compare_vcd(left, right))
}
