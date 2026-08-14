///|
fn empty_render_options() -> RenderOptions {
  { include_header: true, include_empty_values: true, separator: "\t" }
}

///|
fn option_time_to_string(value : Int64?) -> String {
  match value {
    Some(time) => time.to_string()
    None => "n/a"
  }
}

///|
fn option_value_to_string(value : String?) -> String {
  match value {
    Some(value) => value
    None => ""
  }
}

///|
fn signal_scope(full_name : String) -> String {
  let mut last_dot = -1
  let mut index = 0
  for ch in full_name {
    if ch == '.' {
      last_dot = index
    }
    index = index + 1
  }
  if last_dot < 0 {
    ""
  } else {
    full_name[:last_dot].to_owned()
  }
}

///|
fn issue(
  code : String,
  message : String,
  timestamp : Int64?,
  signal : String?,
) -> VcdIssue {
  { code, message, timestamp, signal }
}

///|
fn is_valid_logic_char(ch : Char) -> Bool {
  match ch {
    '0' | '1' | 'x' | 'z' => true
    _ => false
  }
}

///|
fn value_contains_char(value : String, target : Char) -> Bool {
  for ch in value {
    if ch == target {
      return true
    }
  }
  false
}

///|
fn signal_name_for_identifier(vcd : VcdFile, identifier : String) -> String {
  match find_signal_by_identifier(vcd, identifier) {
    Some(signal) => signal.full_name
    None => identifier
  }
}

///|
fn unique_push(values : Array[String], value : String) -> Unit {
  for existing in values {
    if existing == value {
      return
    }
  }
  values.push(value)
}

///|
fn unique_time_push(values : Array[Int64], value : Int64) -> Unit {
  for existing in values {
    if existing == value {
      return
    }
  }
  values.push(value)
}

///|
/// Return the default text-rendering options used by the report helpers.
pub fn default_render_options() -> RenderOptions {
  empty_render_options()
}

///|
/// Build a normalized descriptor for one signal declaration.
pub fn describe_signal(signal : Signal) -> SignalDescriptor {
  {
    identifier: signal.identifier,
    name: signal.name,
    full_name: signal.full_name,
    width: signal.width,
    signal_type: signal.signal_type,
    scope: signal_scope(signal.full_name),
    is_scalar: signal.width == 1,
    is_vector: signal.width > 1,
  }
}

///|
/// Build descriptors for every declared signal in source order.
pub fn describe_signals(vcd : VcdFile) -> Array[SignalDescriptor] {
  let result : Array[SignalDescriptor] = []
  for signal in vcd.signals {
    result.push(describe_signal(signal))
  }
  result
}

///|
/// Return every unique signal type seen in declarations.
pub fn signal_types(vcd : VcdFile) -> Array[String] {
  let result : Array[String] = []
  for signal in vcd.signals {
    unique_push(result, signal.signal_type)
  }
  result
}

///|
/// Count declarations of a given VCD signal type such as `wire` or `reg`.
pub fn count_signals_by_type(vcd : VcdFile, signal_type : String) -> Int {
  let mut count = 0
  for signal in vcd.signals {
    if signal.signal_type == signal_type {
      count = count + 1
    }
  }
  count
}

///|
/// Return declarations whose VCD type matches `signal_type`.
pub fn signals_by_type(vcd : VcdFile, signal_type : String) -> Array[Signal] {
  let result : Array[Signal] = []
  for signal in vcd.signals {
    if signal.signal_type == signal_type {
      result.push(signal)
    }
  }
  result
}

///|
/// Return one-bit signals.
pub fn scalar_signals(vcd : VcdFile) -> Array[Signal] {
  let result : Array[Signal] = []
  for signal in vcd.signals {
    if signal.width == 1 {
      result.push(signal)
    }
  }
  result
}

///|
/// Return multi-bit signals.
pub fn vector_signals(vcd : VcdFile) -> Array[Signal] {
  let result : Array[Signal] = []
  for signal in vcd.signals {
    if signal.width > 1 {
      result.push(signal)
    }
  }
  result
}

///|
/// Return signals whose full hierarchical name starts with `scope_prefix`.
pub fn signals_under_scope(
  vcd : VcdFile,
  scope_prefix : String,
) -> Array[Signal] {
  let result : Array[Signal] = []
  let prefix = if scope_prefix.is_empty() { "" } else { "\{scope_prefix}." }
  for signal in vcd.signals {
    if signal.full_name == scope_prefix || signal.full_name.has_prefix(prefix) {
      result.push(signal)
    }
  }
  result
}

///|
/// Return full hierarchical names in declaration order.
pub fn signal_full_names(vcd : VcdFile) -> Array[String] {
  let result : Array[String] = []
  for signal in vcd.signals {
    result.push(signal.full_name)
  }
  result
}

///|
/// Return raw VCD identifiers in declaration order.
pub fn signal_identifiers(vcd : VcdFile) -> Array[String] {
  let result : Array[String] = []
  for signal in vcd.signals {
    result.push(signal.identifier)
  }
  result
}

///|
/// Search signals by a text fragment in full name, short name, identifier, or type.
pub fn search_signals(vcd : VcdFile, text : String) -> Array[SignalMatch] {
  let result : Array[SignalMatch] = []
  for signal in vcd.signals {
    if signal.full_name.contains(text) {
      result.push({ signal, reason: "full-name" })
    } else if signal.name.contains(text) {
      result.push({ signal, reason: "name" })
    } else if signal.identifier.contains(text) {
      result.push({ signal, reason: "identifier" })
    } else if signal.signal_type.contains(text) {
      result.push({ signal, reason: "type" })
    }
  }
  result
}

///|
/// Return all unique timestamps seen in change order.
pub fn timestamps(vcd : VcdFile) -> Array[Int64] {
  let result : Array[Int64] = []
  for change in vcd.changes {
    unique_time_push(result, change.timestamp)
  }
  result
}

///|
/// Count unique timestamps.
pub fn timestamp_count(vcd : VcdFile) -> Int {
  timestamps(vcd).length()
}

///|
/// Return changes that occurred at one timestamp.
pub fn changes_at_timestamp(
  vcd : VcdFile,
  timestamp : Int64,
) -> Array[SignalChange] {
  let result : Array[SignalChange] = []
  for change in vcd.changes {
    if change.timestamp == timestamp {
      result.push(change)
    }
  }
  result
}

///|
/// Group all changes into timestamp buckets.
pub fn timestamp_buckets(vcd : VcdFile) -> Array[TimestampBucket] {
  let result : Array[TimestampBucket] = []
  for time in timestamps(vcd) {
    result.push({ timestamp: time, changes: changes_at_timestamp(vcd, time) })
  }
  result
}

///|
/// Count changes that happened at one timestamp.
pub fn change_count_at_timestamp(vcd : VcdFile, timestamp : Int64) -> Int {
  let mut count = 0
  for change in vcd.changes {
    if change.timestamp == timestamp {
      count = count + 1
    }
  }
  count
}

///|
/// Return true when a signal has at least one value change.
pub fn signal_has_changes(
  vcd : VcdFile,
  full_name : String,
) -> Bool raise VcdError {
  signal_changes(vcd, full_name).length() > 0
}

///|
/// Return the first parsed value of a signal.
pub fn first_value(vcd : VcdFile, full_name : String) -> String? raise VcdError {
  let changes = signal_changes(vcd, full_name)
  if changes.is_empty() {
    None
  } else {
    Some(changes[0].value)
  }
}

///|
/// Return the last parsed value of a signal.
pub fn last_value(vcd : VcdFile, full_name : String) -> String? raise VcdError {
  let changes = signal_changes(vcd, full_name)
  if changes.is_empty() {
    None
  } else {
    Some(changes[changes.length() - 1].value)
  }
}

///|
/// Return true when the signal ever contains an `x` value.
pub fn signal_has_unknown(
  vcd : VcdFile,
  full_name : String,
) -> Bool raise VcdError {
  for change in signal_changes(vcd, full_name) {
    if value_contains_char(change.value, 'x') {
      return true
    }
  }
  false
}

///|
/// Return true when the signal ever contains a `z` value.
pub fn signal_has_high_impedance(
  vcd : VcdFile,
  full_name : String,
) -> Bool raise VcdError {
  for change in signal_changes(vcd, full_name) {
    if value_contains_char(change.value, 'z') {
      return true
    }
  }
  false
}

///|
/// Count changes for a signal whose value contains `x`.
pub fn unknown_change_count(
  vcd : VcdFile,
  full_name : String,
) -> Int raise VcdError {
  let mut count = 0
  for change in signal_changes(vcd, full_name) {
    if value_contains_char(change.value, 'x') {
      count = count + 1
    }
  }
  count
}

///|
/// Count changes for a signal whose value contains `z`.
pub fn high_impedance_change_count(
  vcd : VcdFile,
  full_name : String,
) -> Int raise VcdError {
  let mut count = 0
  for change in signal_changes(vcd, full_name) {
    if value_contains_char(change.value, 'z') {
      count = count + 1
    }
  }
  count
}

///|
/// Return transitions between consecutive known parsed values of one signal.
pub fn signal_transitions(
  vcd : VcdFile,
  full_name : String,
) -> Array[SignalTransition] raise VcdError {
  let changes = signal_changes(vcd, full_name)
  let result : Array[SignalTransition] = []
  let mut previous : String? = None
  for change in changes {
    match previous {
      Some(prev) =>
        if prev != change.value {
          result.push({
            timestamp: change.timestamp,
            previous: prev,
            current: change.value,
          })
        }
      None => ()
    }
    previous = Some(change.value)
  }
  result
}

///|
/// Count value transitions, ignoring repeated writes of the same value.
pub fn transition_count(
  vcd : VcdFile,
  full_name : String,
) -> Int raise VcdError {
  signal_transitions(vcd, full_name).length()
}

///|
/// Return value spans from each change until the next change.
pub fn value_spans(
  vcd : VcdFile,
  full_name : String,
) -> Array[ValueSpan] raise VcdError {
  let changes = signal_changes(vcd, full_name)
  let result : Array[ValueSpan] = []
  for i = 0; i < changes.length(); i = i + 1 {
    let end_time = if i + 1 < changes.length() {
      Some(changes[i + 1].timestamp)
    } else {
      None
    }
    result.push({
      start_time: changes[i].timestamp,
      end_time,
      value: changes[i].value,
    })
  }
  result
}

///|
/// Build a point-in-time snapshot for every declared signal.
pub fn snapshot_at(
  vcd : VcdFile,
  timestamp : Int64,
) -> VcdSnapshot raise VcdError {
  if timestamp < 0L {
    raise VcdError("timestamp must be non-negative")
  }
  let values : Array[SignalValue] = []
  for signal in vcd.signals {
    let value = value_at(vcd, signal.full_name, timestamp)
    values.push({ signal, value })
  }
  { timestamp, values }
}

///|
/// Build snapshots for every timestamp present in the VCD.
pub fn snapshots(vcd : VcdFile) -> Array[VcdSnapshot] raise VcdError {
  let result : Array[VcdSnapshot] = []
  for time in timestamps(vcd) {
    result.push(snapshot_at(vcd, time))
  }
  result
}

///|
/// Return the value for a signal inside a snapshot.
pub fn snapshot_value(snapshot : VcdSnapshot, full_name : String) -> String? {
  for item in snapshot.values {
    if item.signal.full_name == full_name {
      return item.value
    }
  }
  None
}

///|
/// Return true when every declared signal has a value at `timestamp`.
pub fn snapshot_is_complete(
  vcd : VcdFile,
  timestamp : Int64,
) -> Bool raise VcdError {
  for item in snapshot_at(vcd, timestamp).values {
    if item.value is None {
      return false
    }
  }
  true
}

///|
/// Return signals that have no value at `timestamp`.
pub fn undefined_signals_at(
  vcd : VcdFile,
  timestamp : Int64,
) -> Array[Signal] raise VcdError {
  let result : Array[Signal] = []
  for item in snapshot_at(vcd, timestamp).values {
    if item.value is None {
      result.push(item.signal)
    }
  }
  result
}

///|
/// Return signals that never receive a value change.
pub fn unchanged_signals(vcd : VcdFile) -> Array[Signal] {
  let result : Array[Signal] = []
  for signal in vcd.signals {
    let mut found = false
    for change in vcd.changes {
      if change.identifier == signal.identifier {
        found = true
        break
      }
    }
    if !found {
      result.push(signal)
    }
  }
  result
}

///|
/// Count all changes whose value contains `x`.
pub fn file_unknown_change_count(vcd : VcdFile) -> Int {
  let mut count = 0
  for change in vcd.changes {
    if value_contains_char(change.value, 'x') {
      count = count + 1
    }
  }
  count
}

///|
/// Count all changes whose value contains `z`.
pub fn file_high_impedance_change_count(vcd : VcdFile) -> Int {
  let mut count = 0
  for change in vcd.changes {
    if value_contains_char(change.value, 'z') {
      count = count + 1
    }
  }
  count
}

///|
/// Validate parsed invariants that should hold after `parse_vcd`.
pub fn validate_vcd(vcd : VcdFile) -> Array[VcdIssue] {
  let issues : Array[VcdIssue] = []
  for signal in vcd.signals {
    if signal.identifier.is_empty() {
      issues.push(
        issue(
          "empty-identifier",
          "signal identifier is empty",
          None,
          Some(signal.full_name),
        ),
      )
    }
    if signal.name.is_empty() {
      issues.push(
        issue(
          "empty-name",
          "signal name is empty",
          None,
          Some(signal.full_name),
        ),
      )
    }
    if signal.full_name.is_empty() {
      issues.push(
        issue(
          "empty-full-name",
          "signal full name is empty",
          None,
          Some(signal.identifier),
        ),
      )
    }
    if signal.width <= 0 {
      issues.push(
        issue(
          "invalid-width",
          "signal width must be positive",
          None,
          Some(signal.full_name),
        ),
      )
    }
    for other in vcd.signals {
      if signal.full_name != other.full_name &&
        signal.identifier == other.identifier {
        issues.push(
          issue(
            "duplicate-identifier",
            "duplicate signal identifier",
            None,
            Some(signal.identifier),
          ),
        )
      }
    }
  }
  let mut previous_time : Int64? = None
  for change in vcd.changes {
    let signal = find_signal_by_identifier(vcd, change.identifier)
    match signal {
      Some(sig) => {
        if sig.width == 1 && change.value.length() != 1 {
          issues.push(
            issue(
              "scalar-width",
              "scalar signal received a non-scalar value",
              Some(change.timestamp),
              Some(sig.full_name),
            ),
          )
        }
        if sig.width > 1 && change.value.length() != sig.width {
          issues.push(
            issue(
              "vector-width",
              "vector value width differs from declaration",
              Some(change.timestamp),
              Some(sig.full_name),
            ),
          )
        }
      }
      None =>
        issues.push(
          issue(
            "unknown-identifier",
            "change references an unknown identifier",
            Some(change.timestamp),
            Some(change.identifier),
          ),
        )
    }
    for ch in change.value {
      if !is_valid_logic_char(ch) {
        issues.push(
          issue(
            "invalid-value",
            "change contains a non logic value",
            Some(change.timestamp),
            Some(change.identifier),
          ),
        )
      }
    }
    match previous_time {
      Some(time) =>
        if change.timestamp < time {
          issues.push(
            issue(
              "time-order",
              "change timestamp moved backwards",
              Some(change.timestamp),
              Some(change.identifier),
            ),
          )
        }
      None => ()
    }
    previous_time = Some(change.timestamp)
  }
  issues
}

///|
/// Return true when `validate_vcd` finds no issues.
pub fn is_valid_vcd(vcd : VcdFile) -> Bool {
  validate_vcd(vcd).is_empty()
}

///|
/// Build a compact health summary from declarations, changes, and validation.
pub fn health(vcd : VcdFile) -> VcdHealth {
  {
    signal_count: vcd.signals.length(),
    scalar_signal_count: scalar_signals(vcd).length(),
    vector_signal_count: vector_signals(vcd).length(),
    change_count: vcd.changes.length(),
    unknown_value_change_count: file_unknown_change_count(vcd),
    high_impedance_change_count: file_high_impedance_change_count(vcd),
    issue_count: validate_vcd(vcd).length(),
  }
}

///|
/// Render one signal declaration as a compact text line.
pub fn render_signal(signal : Signal) -> String {
  "\{signal.full_name}\t\{signal.signal_type}\t\{signal.width}\t\{signal.identifier}"
}

///|
/// Render one value change using the signal full name when possible.
pub fn render_change(vcd : VcdFile, change : SignalChange) -> String {
  "\{change.timestamp}\t\{signal_name_for_identifier(vcd, change.identifier)}\t\{change.value}"
}

///|
/// Render file summary in the same style as the CLI info command.
pub fn render_info(vcd : VcdFile) -> String {
  let sum = summary(vcd)
  let builder = StringBuilder()
  builder.write_string("VCD File\n")
  builder.write_string("Timescale: \{vcd.timescale}\n")
  builder.write_string("Signals: \{sum.signal_count}\n")
  builder.write_string("Changes: \{sum.change_count}\n")
  builder.write_string("Start time: \{option_time_to_string(sum.start_time)}\n")
  builder.write_string("End time: \{option_time_to_string(sum.end_time)}\n")
  builder.to_string()
}

///|
/// Render the declared signal table.
pub fn render_signals(vcd : VcdFile) -> String {
  let builder = StringBuilder()
  for signal in vcd.signals {
    builder.write_string(render_signal(signal))
    builder.write_char('\n')
  }
  builder.to_string()
}

///|
/// Render one signal's change history.
pub fn render_signal_changes(
  vcd : VcdFile,
  full_name : String,
) -> String raise VcdError {
  let builder = StringBuilder()
  for change in signal_changes(vcd, full_name) {
    builder.write_string(change.timestamp.to_string())
    builder.write_char('\t')
    builder.write_string(change.value)
    builder.write_char('\n')
  }
  builder.to_string()
}

///|
/// Render timestamp buckets.
pub fn render_buckets(vcd : VcdFile) -> String {
  let builder = StringBuilder()
  for bucket in timestamp_buckets(vcd) {
    builder.write_string("#")
    builder.write_string(bucket.timestamp.to_string())
    builder.write_string(" changes=")
    builder.write_string(bucket.changes.length().to_string())
    builder.write_char('\n')
    for change in bucket.changes {
      builder.write_string("  ")
      builder.write_string(signal_name_for_identifier(vcd, change.identifier))
      builder.write_string(" = ")
      builder.write_string(change.value)
      builder.write_char('\n')
    }
  }
  builder.to_string()
}

///|
/// Render one snapshot as text.
pub fn render_snapshot(
  snapshot : VcdSnapshot,
  options : RenderOptions,
) -> String {
  let builder = StringBuilder()
  if options.include_header {
    builder.write_string("timestamp")
    builder.write_string(options.separator)
    builder.write_string("signal")
    builder.write_string(options.separator)
    builder.write_string("value\n")
  }
  for item in snapshot.values {
    match item.value {
      Some(value) => {
        builder.write_string(snapshot.timestamp.to_string())
        builder.write_string(options.separator)
        builder.write_string(item.signal.full_name)
        builder.write_string(options.separator)
        builder.write_string(value)
        builder.write_char('\n')
      }
      None =>
        if options.include_empty_values {
          builder.write_string(snapshot.timestamp.to_string())
          builder.write_string(options.separator)
          builder.write_string(item.signal.full_name)
          builder.write_string(options.separator)
          builder.write_char('\n')
        }
    }
  }
  builder.to_string()
}

///|
/// Render all snapshots at recorded timestamps.
pub fn render_timeline(
  vcd : VcdFile,
  options : RenderOptions,
) -> String raise VcdError {
  let builder = StringBuilder()
  let mut first = true
  for snapshot in snapshots(vcd) {
    let local_options = if first {
      options
    } else {
      {
        include_header: false,
        include_empty_values: options.include_empty_values,
        separator: options.separator,
      }
    }
    builder.write_string(render_snapshot(snapshot, local_options))
    first = false
  }
  builder.to_string()
}

///|
/// Render validation issues, one per line.
pub fn render_issues(issues : Array[VcdIssue]) -> String {
  let builder = StringBuilder()
  for item in issues {
    builder.write_string(item.code)
    builder.write_char('\t')
    builder.write_string(option_time_to_string(item.timestamp))
    builder.write_char('\t')
    builder.write_string(option_value_to_string(item.signal))
    builder.write_char('\t')
    builder.write_string(item.message)
    builder.write_char('\n')
  }
  builder.to_string()
}

///|
/// Render a health summary intended for human-readable diagnostics.
pub fn render_health(vcd : VcdFile) -> String {
  let h = health(vcd)
  let builder = StringBuilder()
  builder.write_string("Signals: \{h.signal_count}\n")
  builder.write_string("Scalar signals: \{h.scalar_signal_count}\n")
  builder.write_string("Vector signals: \{h.vector_signal_count}\n")
  builder.write_string("Changes: \{h.change_count}\n")
  builder.write_string(
    "Unknown-value changes: \{h.unknown_value_change_count}\n",
  )
  builder.write_string(
    "High-impedance changes: \{h.high_impedance_change_count}\n",
  )
  builder.write_string("Validation issues: \{h.issue_count}\n")
  builder.to_string()
}
