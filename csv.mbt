///|
/// Export all parsed changes in `timestamp,signal,value` form.
pub fn export_csv(vcd : VcdFile) -> String raise VcdError {
  let builder = StringBuilder()
  builder.write_string("timestamp,signal,value\n")
  for change in vcd.changes {
    let full_name = match signal_by_identifier(vcd.signals, change.identifier) {
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
