///|
fn write_csv_rows(
  builder : StringBuilder,
  full_name : String,
  changes : Array[SignalChange],
) -> Unit {
  for change in changes {
    builder.write_string(change.timestamp.to_string())
    builder.write_char(',')
    builder.write_string(full_name)
    builder.write_char(',')
    builder.write_string(change.value)
    builder.write_char('\n')
  }
}

///|
/// Export one signal in `timestamp,signal,value` form.
pub fn export_signal_csv(
  vcd : VcdFile,
  full_name : String,
) -> String raise VcdError {
  let changes = signal_changes(vcd, full_name)
  let builder = StringBuilder()
  builder.write_string("timestamp,signal,value\n")
  write_csv_rows(builder, full_name, changes)
  builder.to_string()
}

///|
/// Export all parsed changes in `timestamp,signal,value` form.
pub fn export_csv(vcd : VcdFile) -> String raise VcdError {
  let builder = StringBuilder()
  builder.write_string("timestamp,signal,value\n")
  for change in vcd.changes {
    let full_name = match find_signal_by_identifier(vcd, change.identifier) {
      Some(signal) => signal.full_name
      None => raise VcdError("unknown signal identifier '\{change.identifier}'")
    }
    builder.write_string(change.timestamp.to_string())
    builder.write_char(',')
    builder.write_string(full_name)
    builder.write_char(',')
    builder.write_string(change.value)
    builder.write_char('\n')
  }
  builder.to_string()
}
