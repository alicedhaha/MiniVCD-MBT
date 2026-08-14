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
/// One signal value observed at a selected timestamp.
pub(all) struct SignalValue {
  signal : Signal
  value : String?
} derive(Eq, @debug.Debug)

///|
/// A point-in-time view of every declared signal.
pub(all) struct VcdSnapshot {
  timestamp : Int64
  values : Array[SignalValue]
} derive(Eq, @debug.Debug)

///|
/// A compact report of one timestamp and the changes that happened there.
pub(all) struct TimestampBucket {
  timestamp : Int64
  changes : Array[SignalChange]
} derive(Eq, @debug.Debug)

///|
/// A normalized signal declaration summary suitable for reports.
pub(all) struct SignalDescriptor {
  identifier : String
  name : String
  full_name : String
  width : Int
  signal_type : String
  scope : String
  is_scalar : Bool
  is_vector : Bool
} derive(Eq, @debug.Debug)

///|
/// A validation issue discovered after parsing a VCD file.
pub(all) struct VcdIssue {
  code : String
  message : String
  timestamp : Int64?
  signal : String?
} derive(Eq, @debug.Debug)

///|
/// Counts of scalar/vector/unknown-state signals and changes.
pub(all) struct VcdHealth {
  signal_count : Int
  scalar_signal_count : Int
  vector_signal_count : Int
  change_count : Int
  unknown_value_change_count : Int
  high_impedance_change_count : Int
  issue_count : Int
} derive(Eq, @debug.Debug)

///|
/// A search result produced by name, scope, type, or identifier queries.
pub(all) struct SignalMatch {
  signal : Signal
  reason : String
} derive(Eq, @debug.Debug)

///|
/// A transition between two consecutive known values of one signal.
pub(all) struct SignalTransition {
  timestamp : Int64
  previous : String
  current : String
} derive(Eq, @debug.Debug)

///|
/// A half-open time interval over which a signal keeps the same value.
pub(all) struct ValueSpan {
  start_time : Int64
  end_time : Int64?
  value : String
} derive(Eq, @debug.Debug)

///|
/// Count of a concrete value in a signal change history.
pub(all) struct ValueCount {
  value : String
  count : Int
} derive(Eq, @debug.Debug)

///|
/// Per-character counts for a scalar or vector logic value.
pub(all) struct LogicCounts {
  zeros : Int
  ones : Int
  unknowns : Int
  high_impedances : Int
  width : Int
} derive(Eq, @debug.Debug)

///|
/// A per-signal coverage summary for review and diagnostics.
pub(all) struct SignalCoverage {
  full_name : String
  has_value : Bool
  first_change_time : Int64?
  last_change_time : Int64?
  change_count : Int
  transition_count : Int
  unknown_change_count : Int
  high_impedance_change_count : Int
} derive(Eq, @debug.Debug)

///|
/// A query window over VCD timestamps.
pub(all) struct TimeWindow {
  start_time : Int64
  end_time : Int64
} derive(Eq, @debug.Debug)

///|
/// Difference between the signal declarations of two parsed VCD files.
pub(all) struct SignalSetDiff {
  common : Array[String]
  left_only : Array[String]
  right_only : Array[String]
  width_mismatches : Array[String]
  type_mismatches : Array[String]
} derive(Eq, @debug.Debug)

///|
/// Value difference for one signal at one timestamp.
pub(all) struct ValueDiff {
  timestamp : Int64
  full_name : String
  left : String?
  right : String?
} derive(Eq, @debug.Debug)

///|
/// Timestamp presence difference between two parsed VCD files.
pub(all) struct TimestampDiff {
  common : Array[Int64]
  left_only : Array[Int64]
  right_only : Array[Int64]
} derive(Eq, @debug.Debug)

///|
/// Compact comparison between two parsed VCD files.
pub(all) struct VcdDiff {
  signal_diff : SignalSetDiff
  timestamp_diff : TimestampDiff
  value_diffs : Array[ValueDiff]
} derive(Eq, @debug.Debug)

///|
/// A text rendering option bundle for CLI-style library reports.
pub(all) struct RenderOptions {
  include_header : Bool
  include_empty_values : Bool
  separator : String
} derive(Eq, @debug.Debug)

///|
/// A readable parse or query error. The library raises this instead of
/// panicking on malformed VCD input or an invalid query.
pub(all) suberror VcdError {
  VcdError(String)
} derive(@debug.Debug)
