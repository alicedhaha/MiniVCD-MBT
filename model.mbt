///|
/// A signal declared in the VCD header.
pub(all) struct Signal {
  identifier : String
  name : String
  full_name : String
  width : Int
  signal_type : String
} derive(Eq, @debug.Debug)

///|
/// One value change associated with a VCD identifier.
pub(all) struct SignalChange {
  timestamp : Int64
  identifier : String
  value : String
} derive(Eq, @debug.Debug)

///|
/// Parsed VCD metadata, declarations, and value changes.
pub(all) struct VcdFile {
  date : String
  version : String
  timescale : String
  signals : Array[Signal]
  changes : Array[SignalChange]
} derive(Eq, @debug.Debug)

///|
/// Basic activity statistics for one signal.
pub(all) struct SignalStats {
  change_count : Int
  first_change_time : Int64?
  last_change_time : Int64?
  rising_edges : Int
  falling_edges : Int
} derive(Eq, @debug.Debug)

///|
/// File-level counts and time bounds.
pub(all) struct VcdSummary {
  signal_count : Int
  change_count : Int
  start_time : Int64?
  end_time : Int64?
} derive(Eq, @debug.Debug)

///|
/// A readable parse or query error. The library raises this instead of
/// panicking on malformed VCD input or an invalid query.
pub(all) suberror VcdError {
  VcdError(String)
} derive(@debug.Debug)
