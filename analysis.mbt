///|
fn push_value_count(counts : Array[ValueCount], value : String) -> Unit {
  for i = 0; i < counts.length(); i = i + 1 {
    if counts[i].value == value {
      counts[i] = { value: counts[i].value, count: counts[i].count + 1 }
      return
    }
  }
  counts.push({ value, count: 1 })
}

///|
fn signal_or_raise(vcd : VcdFile, full_name : String) -> Signal raise VcdError {
  match find_signal(vcd, full_name) {
    Some(signal) => signal
    None => raise VcdError("signal not found: \{full_name}")
  }
}

///|
fn check_window(window : TimeWindow) -> Unit raise VcdError {
  if window.start_time < 0L || window.end_time < 0L {
    raise VcdError("time window must be non-negative")
  }
  if window.end_time < window.start_time {
    raise VcdError("time window end must not be before start")
  }
}

///|
fn char_count(value : String, target : Char) -> Int {
  let mut count = 0
  for ch in value {
    if ch == target {
      count = count + 1
    }
  }
  count
}

///|
fn all_chars(value : String, target : Char) -> Bool {
  if value.is_empty() {
    return false
  }
  for ch in value {
    if ch != target {
      return false
    }
  }
  true
}

///|
fn contains_only_known_binary(value : String) -> Bool {
  if value.is_empty() {
    return false
  }
  for ch in value {
    if ch != '0' && ch != '1' {
      return false
    }
  }
  true
}

///|
fn value_kind(value : String) -> String {
  if value.is_empty() {
    "empty"
  } else if all_chars(value, '0') {
    "zero"
  } else if all_chars(value, '1') {
    "one"
  } else if contains_only_known_binary(value) {
    "known-binary"
  } else if char_count(value, 'x') > 0 && char_count(value, 'z') > 0 {
    "mixed-unknown-high-impedance"
  } else if char_count(value, 'x') > 0 {
    "unknown"
  } else if char_count(value, 'z') > 0 {
    "high-impedance"
  } else {
    "mixed"
  }
}

///|
/// Return true when the value is exactly one scalar logic character.
pub fn is_scalar_logic_value(value : String) -> Bool {
  value.length() == 1 &&
  (value == "0" || value == "1" || value == "x" || value == "z")
}

///|
/// Return true when the value has more than one valid logic character.
pub fn is_vector_logic_value(value : String) -> Bool {
  if value.length() <= 1 {
    return false
  }
  for ch in value {
    match ch {
      '0' | '1' | 'x' | 'z' => ()
      _ => return false
    }
  }
  true
}

///|
/// Return true when a value contains only known binary bits.
pub fn is_known_binary(value : String) -> Bool {
  contains_only_known_binary(value)
}

///|
/// Return true when a value has any unknown bit.
pub fn has_unknown_bit(value : String) -> Bool {
  char_count(value, 'x') > 0
}

///|
/// Return true when a value has any high-impedance bit.
pub fn has_high_impedance_bit(value : String) -> Bool {
  char_count(value, 'z') > 0
}

///|
/// Count zeros in a scalar or vector value.
pub fn zero_bit_count(value : String) -> Int {
  char_count(value, '0')
}

///|
/// Count ones in a scalar or vector value.
pub fn one_bit_count(value : String) -> Int {
  char_count(value, '1')
}

///|
/// Count unknown bits in a scalar or vector value.
pub fn unknown_bit_count(value : String) -> Int {
  char_count(value, 'x')
}

///|
/// Count high-impedance bits in a scalar or vector value.
pub fn high_impedance_bit_count(value : String) -> Int {
  char_count(value, 'z')
}

///|
/// Return per-character counts for one value.
pub fn logic_counts(value : String) -> LogicCounts {
  {
    zeros: zero_bit_count(value),
    ones: one_bit_count(value),
    unknowns: unknown_bit_count(value),
    high_impedances: high_impedance_bit_count(value),
    width: value.length(),
  }
}

///|
/// Return a compact textual classification of a parsed value.
pub fn classify_value(value : String) -> String {
  value_kind(value)
}

///|
/// Convert a known binary value to Int64 when it fits.
pub fn binary_value_to_int64(value : String) -> Int64? {
  if !contains_only_known_binary(value) {
    return None
  }
  let mut result = 0L
  for ch in value {
    let bit = if ch == '1' { 1L } else { 0L }
    if result > (9223372036854775807L - bit) / 2L {
      return None
    }
    result = result * 2L + bit
  }
  Some(result)
}

///|
/// Count bit positions that differ between two equal-width known or four-state values.
pub fn hamming_distance(left : String, right : String) -> Int? {
  if left.length() != right.length() {
    return None
  }
  let mut distance = 0
  for i = 0; i < left.length(); i = i + 1 {
    if left[i] != right[i] {
      distance = distance + 1
    }
  }
  Some(distance)
}

///|
/// Return all distinct values written to a signal.
pub fn distinct_values(
  vcd : VcdFile,
  full_name : String,
) -> Array[String] raise VcdError {
  let result : Array[String] = []
  for change in signal_changes(vcd, full_name) {
    let mut found = false
    for value in result {
      if value == change.value {
        found = true
        break
      }
    }
    if !found {
      result.push(change.value)
    }
  }
  result
}

///|
/// Count occurrences of each value in a signal change history.
pub fn value_counts(
  vcd : VcdFile,
  full_name : String,
) -> Array[ValueCount] raise VcdError {
  let counts : Array[ValueCount] = []
  for change in signal_changes(vcd, full_name) {
    push_value_count(counts, change.value)
  }
  counts
}

///|
/// Count writes of a concrete value for a signal.
pub fn count_value(
  vcd : VcdFile,
  full_name : String,
  value : String,
) -> Int raise VcdError {
  let mut count = 0
  for change in signal_changes(vcd, full_name) {
    if change.value == value {
      count = count + 1
    }
  }
  count
}

///|
/// Return the first change at or after a timestamp.
pub fn first_change_at_or_after(
  vcd : VcdFile,
  full_name : String,
  timestamp : Int64,
) -> SignalChange? raise VcdError {
  if timestamp < 0L {
    raise VcdError("timestamp must be non-negative")
  }
  for change in signal_changes(vcd, full_name) {
    if change.timestamp >= timestamp {
      return Some(change)
    }
  }
  None
}

///|
/// Return the last change at or before a timestamp.
pub fn last_change_at_or_before(
  vcd : VcdFile,
  full_name : String,
  timestamp : Int64,
) -> SignalChange? raise VcdError {
  if timestamp < 0L {
    raise VcdError("timestamp must be non-negative")
  }
  let mut result : SignalChange? = None
  for change in signal_changes(vcd, full_name) {
    if change.timestamp <= timestamp {
      result = Some(change)
    } else {
      break
    }
  }
  result
}

///|
/// Return changes inside an inclusive time window.
pub fn signal_changes_in_window(
  vcd : VcdFile,
  full_name : String,
  window : TimeWindow,
) -> Array[SignalChange] raise VcdError {
  check_window(window)
  let result : Array[SignalChange] = []
  for change in signal_changes(vcd, full_name) {
    if change.timestamp >= window.start_time &&
      change.timestamp <= window.end_time {
      result.push(change)
    }
  }
  result
}

///|
/// Return all changes in an inclusive time window.
pub fn changes_in_window(
  vcd : VcdFile,
  window : TimeWindow,
) -> Array[SignalChange] raise VcdError {
  check_window(window)
  let result : Array[SignalChange] = []
  for change in vcd.changes {
    if change.timestamp >= window.start_time &&
      change.timestamp <= window.end_time {
      result.push(change)
    }
  }
  result
}

///|
/// Count all changes inside an inclusive time window.
pub fn change_count_in_window(
  vcd : VcdFile,
  window : TimeWindow,
) -> Int raise VcdError {
  changes_in_window(vcd, window).length()
}

///|
/// Return true if a signal changes inside an inclusive time window.
pub fn signal_changes_inside_window(
  vcd : VcdFile,
  full_name : String,
  window : TimeWindow,
) -> Bool raise VcdError {
  signal_changes_in_window(vcd, full_name, window).length() > 0
}

///|
/// Return the first timestamp in a window, if the file has any matching change.
pub fn first_time_in_window(
  vcd : VcdFile,
  window : TimeWindow,
) -> Int64? raise VcdError {
  let changes = changes_in_window(vcd, window)
  if changes.is_empty() {
    None
  } else {
    Some(changes[0].timestamp)
  }
}

///|
/// Return the last timestamp in a window, if the file has any matching change.
pub fn last_time_in_window(
  vcd : VcdFile,
  window : TimeWindow,
) -> Int64? raise VcdError {
  let changes = changes_in_window(vcd, window)
  if changes.is_empty() {
    None
  } else {
    Some(changes[changes.length() - 1].timestamp)
  }
}

///|
/// Summarize how completely one signal is covered by changes.
pub fn signal_coverage(
  vcd : VcdFile,
  full_name : String,
) -> SignalCoverage raise VcdError {
  let _signal = signal_or_raise(vcd, full_name)
  let stats = signal_stats(vcd, full_name)
  {
    full_name,
    has_value: stats.change_count > 0,
    first_change_time: stats.first_change_time,
    last_change_time: stats.last_change_time,
    change_count: stats.change_count,
    transition_count: transition_count(vcd, full_name),
    unknown_change_count: unknown_change_count(vcd, full_name),
    high_impedance_change_count: high_impedance_change_count(vcd, full_name),
  }
}

///|
/// Return coverage summaries for all declared signals.
pub fn all_signal_coverage(
  vcd : VcdFile,
) -> Array[SignalCoverage] raise VcdError {
  let result : Array[SignalCoverage] = []
  for signal in vcd.signals {
    result.push(signal_coverage(vcd, signal.full_name))
  }
  result
}

///|
/// Count signals with at least one value.
pub fn covered_signal_count(vcd : VcdFile) -> Int raise VcdError {
  let mut count = 0
  for coverage in all_signal_coverage(vcd) {
    if coverage.has_value {
      count = count + 1
    }
  }
  count
}

///|
/// Count signals that never receive a value.
pub fn uncovered_signal_count(vcd : VcdFile) -> Int {
  unchanged_signals(vcd).length()
}

///|
/// Render value counts for one signal.
pub fn render_value_counts(
  vcd : VcdFile,
  full_name : String,
) -> String raise VcdError {
  let builder = StringBuilder()
  builder.write_string("value\tcount\n")
  for item in value_counts(vcd, full_name) {
    builder.write_string(item.value)
    builder.write_char('\t')
    builder.write_string(item.count.to_string())
    builder.write_char('\n')
  }
  builder.to_string()
}

///|
/// Render signal coverage summaries.
pub fn render_coverage(vcd : VcdFile) -> String raise VcdError {
  let builder = StringBuilder()
  builder.write_string(
    "signal\thas_value\tchanges\ttransitions\tunknown\tz\tfirst\tlast\n",
  )
  for item in all_signal_coverage(vcd) {
    builder.write_string(item.full_name)
    builder.write_char('\t')
    builder.write_string(item.has_value.to_string())
    builder.write_char('\t')
    builder.write_string(item.change_count.to_string())
    builder.write_char('\t')
    builder.write_string(item.transition_count.to_string())
    builder.write_char('\t')
    builder.write_string(item.unknown_change_count.to_string())
    builder.write_char('\t')
    builder.write_string(item.high_impedance_change_count.to_string())
    builder.write_char('\t')
    builder.write_string(option_time_to_string(item.first_change_time))
    builder.write_char('\t')
    builder.write_string(option_time_to_string(item.last_change_time))
    builder.write_char('\n')
  }
  builder.to_string()
}
