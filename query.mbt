///|
/// Return the declared signals in source order.
pub fn list_signals(vcd : VcdFile) -> Array[Signal] {
  vcd.signals.copy()
}

///|
/// Find a signal by hierarchical full name.
pub fn find_signal(vcd : VcdFile, full_name : String) -> Signal? {
  for signal in vcd.signals {
    if signal.full_name == full_name {
      return Some(signal)
    }
  }
  None
}

///|
/// Find a signal by raw VCD identifier.
pub fn find_signal_by_identifier(vcd : VcdFile, identifier : String) -> Signal? {
  for signal in vcd.signals {
    if signal.identifier == identifier {
      return Some(signal)
    }
  }
  None
}

///|
/// Get every change for a signal selected by full name.
pub fn signal_changes(
  vcd : VcdFile,
  full_name : String,
) -> Array[SignalChange] raise VcdError {
  let signal = match find_signal(vcd, full_name) {
    Some(signal) => signal
    None => raise VcdError("signal not found: \{full_name}")
  }
  let result : Array[SignalChange] = []
  for change in vcd.changes {
    if change.identifier == signal.identifier {
      result.push(change)
    }
  }
  result
}

///|
/// Get every change for a signal selected by VCD identifier.
pub fn signal_changes_by_identifier(
  vcd : VcdFile,
  identifier : String,
) -> Array[SignalChange] raise VcdError {
  let signal = match find_signal_by_identifier(vcd, identifier) {
    Some(signal) => signal
    None => raise VcdError("signal identifier not found: \{identifier}")
  }
  let result : Array[SignalChange] = []
  for change in vcd.changes {
    if change.identifier == signal.identifier {
      result.push(change)
    }
  }
  result
}

///|
/// Return the most recent value at or before `timestamp`.
pub fn value_at(
  vcd : VcdFile,
  full_name : String,
  timestamp : Int64,
) -> String? raise VcdError {
  if timestamp < 0L {
    raise VcdError("timestamp must be non-negative")
  }
  let changes = signal_changes(vcd, full_name)
  let mut result : String? = None
  for change in changes {
    if change.timestamp <= timestamp {
      result = Some(change.value)
    } else {
      break
    }
  }
  result
}

///|
/// Summarize file-wide counts and time bounds.
pub fn summary(vcd : VcdFile) -> VcdSummary {
  {
    signal_count: vcd.signals.length(),
    change_count: vcd.changes.length(),
    start_time: start_time(vcd),
    end_time: end_time(vcd),
  }
}

///|
/// Compute change count, time bounds, and 1-bit rising/falling edges.
pub fn signal_stats(
  vcd : VcdFile,
  full_name : String,
) -> SignalStats raise VcdError {
  let signal = match find_signal(vcd, full_name) {
    Some(signal) => signal
    None => raise VcdError("signal not found: \{full_name}")
  }
  let changes = signal_changes(vcd, full_name)
  let mut first_change_time : Int64? = None
  let mut last_change_time : Int64? = None
  let mut rising_edges = 0
  let mut falling_edges = 0
  let mut previous : String? = None
  for change in changes {
    if first_change_time is None {
      first_change_time = Some(change.timestamp)
    }
    last_change_time = Some(change.timestamp)
    if signal.width == 1 {
      match previous {
        Some("0") if change.value == "1" => rising_edges = rising_edges + 1
        Some("1") if change.value == "0" => falling_edges = falling_edges + 1
        _ => ()
      }
    }
    previous = Some(change.value)
  }
  {
    change_count: changes.length(),
    first_change_time,
    last_change_time,
    rising_edges,
    falling_edges,
  }
}

///|
/// Earliest timestamp in the file, if any changes exist.
pub fn start_time(vcd : VcdFile) -> Int64? {
  if vcd.changes.is_empty() {
    None
  } else {
    let mut value = vcd.changes[0].timestamp
    for change in vcd.changes {
      if change.timestamp < value {
        value = change.timestamp
      }
    }
    Some(value)
  }
}

///|
/// Latest timestamp in the file, if any changes exist.
pub fn end_time(vcd : VcdFile) -> Int64? {
  if vcd.changes.is_empty() {
    None
  } else {
    let mut value = vcd.changes[0].timestamp
    for change in vcd.changes {
      if change.timestamp > value {
        value = change.timestamp
      }
    }
    Some(value)
  }
}
