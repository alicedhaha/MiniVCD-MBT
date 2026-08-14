///|
fn print_help() -> Unit {
  let help =
    #|MiniVCD-MBT - lightweight VCD waveform viewer
    #|
    #|Usage:
    #|  minivcd info <file.vcd>
    #|  minivcd signals <file.vcd>
    #|  minivcd changes <file.vcd> <full.signal.name>
    #|  minivcd stats <file.vcd> <full.signal.name>
    #|  minivcd value <file.vcd> <full.signal.name> <timestamp>
    #|  minivcd export <file.vcd> <output.csv>
  println(help)
}

///|
fn read_vcd(path : String) -> @vcdlib.VcdFile raise @vcdlib.VcdError {
  let text = @fs.read_file_to_string(path) catch {
    @fs.IOError(message) =>
      raise @vcdlib.VcdError("cannot read '\{path}': \{message}")
  }
  @vcdlib.parse_vcd(text)
}

///|
fn show_time(value : Int64?) -> String {
  match value {
    Some(time) => time.to_string()
    None => "n/a"
  }
}

///|
fn run(args : Array[String]) -> Unit raise @vcdlib.VcdError {
  if args.length() < 2 {
    print_help()
    return
  }
  let command = args[1]
  match command {
    "info" => {
      if args.length() != 3 {
        raise @vcdlib.VcdError("usage: minivcd info <file.vcd>")
      }
      let vcd = read_vcd(args[2])
      let summary = @vcdlib.summary(vcd)
      println("VCD File")
      println("Timescale: \{vcd.timescale}")
      println("Signals: \{summary.signal_count}")
      println("Changes: \{summary.change_count}")
      println("Start time: \{show_time(summary.start_time)}")
      println("End time: \{show_time(summary.end_time)}")
    }
    "signals" => {
      if args.length() != 3 {
        raise @vcdlib.VcdError("usage: minivcd signals <file.vcd>")
      }
      let vcd = read_vcd(args[2])
      for signal in @vcdlib.list_signals(vcd) {
        println("\{signal.full_name}\t\{signal.signal_type}\t\{signal.width}")
      }
    }
    "changes" => {
      if args.length() != 4 {
        raise @vcdlib.VcdError(
          "usage: minivcd changes <file.vcd> <full.signal.name>",
        )
      }
      let vcd = read_vcd(args[2])
      for change in @vcdlib.signal_changes(vcd, args[3]) {
        println("\{change.timestamp}\t\{change.value}")
      }
    }
    "stats" => {
      if args.length() != 4 {
        raise @vcdlib.VcdError(
          "usage: minivcd stats <file.vcd> <full.signal.name>",
        )
      }
      let vcd = read_vcd(args[2])
      let signal = match @vcdlib.find_signal(vcd, args[3]) {
        Some(signal) => signal
        None => raise @vcdlib.VcdError("signal not found: \{args[3]}")
      }
      let stats = @vcdlib.signal_stats(vcd, args[3])
      println("Signal: \{signal.full_name}")
      println("Type: \{signal.signal_type}")
      println("Width: \{signal.width}")
      println("Changes: \{stats.change_count}")
      println("First change: \{show_time(stats.first_change_time)}")
      println("Last change: \{show_time(stats.last_change_time)}")
      if signal.width == 1 {
        println("Rising edges: \{stats.rising_edges}")
        println("Falling edges: \{stats.falling_edges}")
      }
    }
    "value" => {
      if args.length() != 5 {
        raise @vcdlib.VcdError(
          "usage: minivcd value <file.vcd> <full.signal.name> <timestamp>",
        )
      }
      let timestamp = @string.parse_int64(args[4]) catch {
        _ => raise @vcdlib.VcdError("invalid timestamp '\{args[4]}'")
      }
      let vcd = read_vcd(args[2])
      match @vcdlib.value_at(vcd, args[3], timestamp) {
        Some(value) => println("\{args[3]} @ \{timestamp} = \{value}")
        None =>
          raise @vcdlib.VcdError(
            "no value for \{args[3]} at or before \{timestamp}",
          )
      }
    }
    "export" => {
      if args.length() != 4 {
        raise @vcdlib.VcdError("usage: minivcd export <file.vcd> <output.csv>")
      }
      let vcd = read_vcd(args[2])
      let csv = @vcdlib.export_csv(vcd)
      @fs.write_string_to_file(args[3], csv) catch {
        @fs.IOError(message) =>
          raise @vcdlib.VcdError("cannot write '\{args[3]}': \{message}")
      }
      println("Exported \{vcd.changes.length()} changes to \{args[3]}")
    }
    "help" | "--help" | "-h" => print_help()
    _ => raise @vcdlib.VcdError("unknown command '\{command}'")
  }
}

///|
fn main {
  try run(@env.args()) catch {
    @vcdlib.VcdError(message) => println("Error: \{message}")
  } noraise {
    _ => ()
  }
}
