///|
fn md_bool(value : Bool) -> String {
  if value {
    "yes"
  } else {
    "no"
  }
}

///|
fn md_optional_time(value : Int64?) -> String {
  match value {
    Some(time) => time.to_string()
    None => "-"
  }
}

///|
fn md_optional_value(value : String?) -> String {
  match value {
    Some(value) => value
    None => "-"
  }
}

///|
fn markdown_escape_cell(text : String) -> String {
  let builder = StringBuilder()
  for ch in text {
    match ch {
      '|' => builder.write_string("\\|")
      '\n' | '\r' | '\t' => builder.write_char(' ')
      _ => builder.write_char(ch)
    }
  }
  builder.to_string()
}

///|
fn write_markdown_row(builder : StringBuilder, cells : Array[String]) -> Unit {
  builder.write_char('|')
  for cell in cells {
    builder.write_char(' ')
    builder.write_string(markdown_escape_cell(cell))
    builder.write_char(' ')
    builder.write_char('|')
  }
  builder.write_char('\n')
}

///|
fn write_markdown_separator(builder : StringBuilder, columns : Int) -> Unit {
  builder.write_char('|')
  for i = 0; i < columns; i = i + 1 {
    builder.write_string(" --- |")
  }
  builder.write_char('\n')
}

///|
fn write_heading(builder : StringBuilder, level : Int, title : String) -> Unit {
  for i = 0; i < level; i = i + 1 {
    builder.write_char('#')
  }
  builder.write_char(' ')
  builder.write_string(title)
  builder.write_string("\n\n")
}

///|
fn write_key_value(
  builder : StringBuilder,
  key : String,
  value : String,
) -> Unit {
  builder.write_string("- ")
  builder.write_string(key)
  builder.write_string(": ")
  builder.write_string(value)
  builder.write_char('\n')
}

///|
fn signal_markdown_row(signal : Signal) -> Array[String] {
  [
    signal.full_name,
    signal.signal_type,
    signal.width.to_string(),
    signal.identifier,
  ]
}

///|
fn coverage_markdown_row(coverage : SignalCoverage) -> Array[String] {
  [
    coverage.full_name,
    md_bool(coverage.has_value),
    coverage.change_count.to_string(),
    coverage.transition_count.to_string(),
    coverage.unknown_change_count.to_string(),
    coverage.high_impedance_change_count.to_string(),
    md_optional_time(coverage.first_change_time),
    md_optional_time(coverage.last_change_time),
  ]
}

///|
fn issue_markdown_row(issue : VcdIssue) -> Array[String] {
  [
    issue.code,
    md_optional_time(issue.timestamp),
    md_optional_value(issue.signal),
    issue.message,
  ]
}

///|
fn change_markdown_row(vcd : VcdFile, change : SignalChange) -> Array[String] {
  [
    change.timestamp.to_string(),
    signal_name_for_identifier(vcd, change.identifier),
    change.value,
  ]
}

///|
fn value_count_markdown_row(item : ValueCount) -> Array[String] {
  [item.value, item.count.to_string()]
}

///|
/// Render a Markdown summary section for the parsed file.
pub fn markdown_summary(vcd : VcdFile) -> String {
  let sum = summary(vcd)
  let h = health(vcd)
  let builder = StringBuilder()
  write_heading(builder, 2, "VCD Summary")
  write_key_value(
    builder,
    "Timescale",
    if vcd.timescale.is_empty() {
      "-"
    } else {
      vcd.timescale
    },
  )
  write_key_value(builder, "Signals", sum.signal_count.to_string())
  write_key_value(builder, "Scalar signals", h.scalar_signal_count.to_string())
  write_key_value(builder, "Vector signals", h.vector_signal_count.to_string())
  write_key_value(builder, "Changes", sum.change_count.to_string())
  write_key_value(builder, "Start time", md_optional_time(sum.start_time))
  write_key_value(builder, "End time", md_optional_time(sum.end_time))
  write_key_value(builder, "Validation issues", h.issue_count.to_string())
  builder.to_string()
}

///|
/// Render all signal declarations as a Markdown table.
pub fn markdown_signals(vcd : VcdFile) -> String {
  let builder = StringBuilder()
  write_heading(builder, 2, "Signals")
  write_markdown_row(builder, ["Signal", "Type", "Width", "Identifier"])
  write_markdown_separator(builder, 4)
  for signal in vcd.signals {
    write_markdown_row(builder, signal_markdown_row(signal))
  }
  builder.to_string()
}

///|
/// Render one signal's changes as a Markdown table.
pub fn markdown_signal_changes(
  vcd : VcdFile,
  full_name : String,
) -> String raise VcdError {
  let builder = StringBuilder()
  write_heading(builder, 2, "Changes: \{full_name}")
  write_markdown_row(builder, ["Timestamp", "Value"])
  write_markdown_separator(builder, 2)
  for change in signal_changes(vcd, full_name) {
    write_markdown_row(builder, [change.timestamp.to_string(), change.value])
  }
  builder.to_string()
}

///|
/// Render all parsed changes as a Markdown table.
pub fn markdown_changes(vcd : VcdFile) -> String {
  let builder = StringBuilder()
  write_heading(builder, 2, "Changes")
  write_markdown_row(builder, ["Timestamp", "Signal", "Value"])
  write_markdown_separator(builder, 3)
  for change in vcd.changes {
    write_markdown_row(builder, change_markdown_row(vcd, change))
  }
  builder.to_string()
}

///|
/// Render basic statistics for one signal as Markdown.
pub fn markdown_signal_stats(
  vcd : VcdFile,
  full_name : String,
) -> String raise VcdError {
  let signal = match find_signal(vcd, full_name) {
    Some(signal) => signal
    None => raise VcdError("signal not found: \{full_name}")
  }
  let stats = signal_stats(vcd, full_name)
  let builder = StringBuilder()
  write_heading(builder, 2, "Signal Statistics")
  write_key_value(builder, "Signal", signal.full_name)
  write_key_value(builder, "Type", signal.signal_type)
  write_key_value(builder, "Width", signal.width.to_string())
  write_key_value(builder, "Changes", stats.change_count.to_string())
  write_key_value(
    builder,
    "First change",
    md_optional_time(stats.first_change_time),
  )
  write_key_value(
    builder,
    "Last change",
    md_optional_time(stats.last_change_time),
  )
  if signal.width == 1 {
    write_key_value(builder, "Rising edges", stats.rising_edges.to_string())
    write_key_value(builder, "Falling edges", stats.falling_edges.to_string())
  }
  builder.to_string()
}

///|
/// Render one signal's value-count table as Markdown.
pub fn markdown_value_counts(
  vcd : VcdFile,
  full_name : String,
) -> String raise VcdError {
  let builder = StringBuilder()
  write_heading(builder, 2, "Value Counts: \{full_name}")
  write_markdown_row(builder, ["Value", "Count"])
  write_markdown_separator(builder, 2)
  for item in value_counts(vcd, full_name) {
    write_markdown_row(builder, value_count_markdown_row(item))
  }
  builder.to_string()
}

///|
/// Render coverage summaries for all signals as Markdown.
pub fn markdown_coverage(vcd : VcdFile) -> String raise VcdError {
  let builder = StringBuilder()
  write_heading(builder, 2, "Signal Coverage")
  write_markdown_row(builder, [
    "Signal", "Has value", "Changes", "Transitions", "X changes", "Z changes", "First",
    "Last",
  ])
  write_markdown_separator(builder, 8)
  for coverage in all_signal_coverage(vcd) {
    write_markdown_row(builder, coverage_markdown_row(coverage))
  }
  builder.to_string()
}

///|
/// Render validation issues as Markdown.
pub fn markdown_issues(vcd : VcdFile) -> String {
  let builder = StringBuilder()
  write_heading(builder, 2, "Validation")
  let issues = validate_vcd(vcd)
  if issues.is_empty() {
    builder.write_string("No validation issues found.\n")
  } else {
    write_markdown_row(builder, ["Code", "Timestamp", "Signal", "Message"])
    write_markdown_separator(builder, 4)
    for item in issues {
      write_markdown_row(builder, issue_markdown_row(item))
    }
  }
  builder.to_string()
}

///|
/// Render a snapshot as a Markdown table.
pub fn markdown_snapshot(snapshot : VcdSnapshot) -> String {
  let builder = StringBuilder()
  write_heading(builder, 2, "Snapshot @ \{snapshot.timestamp}")
  write_markdown_row(builder, ["Signal", "Value"])
  write_markdown_separator(builder, 2)
  for item in snapshot.values {
    write_markdown_row(builder, [
      item.signal.full_name,
      md_optional_value(item.value),
    ])
  }
  builder.to_string()
}

///|
/// Render a timestamp-bucket overview as Markdown.
pub fn markdown_buckets(vcd : VcdFile) -> String {
  let builder = StringBuilder()
  write_heading(builder, 2, "Timestamp Buckets")
  write_markdown_row(builder, ["Timestamp", "Changes"])
  write_markdown_separator(builder, 2)
  for bucket in timestamp_buckets(vcd) {
    write_markdown_row(builder, [
      bucket.timestamp.to_string(),
      bucket.changes.length().to_string(),
    ])
  }
  builder.to_string()
}

///|
/// Render a compact Markdown report covering the most useful library outputs.
pub fn markdown_report(vcd : VcdFile) -> String raise VcdError {
  let builder = StringBuilder()
  write_heading(builder, 1, "MiniVCD-MBT Report")
  builder.write_string(markdown_summary(vcd))
  builder.write_char('\n')
  builder.write_string(markdown_signals(vcd))
  builder.write_char('\n')
  builder.write_string(markdown_coverage(vcd))
  builder.write_char('\n')
  builder.write_string(markdown_issues(vcd))
  builder.to_string()
}

///|
/// Render a plain one-line manifest useful for logs.
pub fn manifest_line(vcd : VcdFile) -> String {
  let sum = summary(vcd)
  "timescale=\{if vcd.timescale.is_empty() { "-" } else { vcd.timescale }} signals=\{sum.signal_count} changes=\{sum.change_count} start=\{md_optional_time(sum.start_time)} end=\{md_optional_time(sum.end_time)}"
}

///|
/// Render signal names as a newline-delimited manifest.
pub fn signal_manifest(vcd : VcdFile) -> String {
  let builder = StringBuilder()
  for signal in vcd.signals {
    builder.write_string(signal.full_name)
    builder.write_char('\n')
  }
  builder.to_string()
}

///|
/// Render a lightweight report for one signal.
pub fn single_signal_report(
  vcd : VcdFile,
  full_name : String,
) -> String raise VcdError {
  let builder = StringBuilder()
  builder.write_string(markdown_signal_stats(vcd, full_name))
  builder.write_char('\n')
  builder.write_string(markdown_value_counts(vcd, full_name))
  builder.write_char('\n')
  builder.write_string(markdown_signal_changes(vcd, full_name))
  builder.to_string()
}
