///|
fn tokenize(text : String) -> Array[String] {
  let normalized = text
    .replace_all(old="\r", new=" ")
    .replace_all(old="\n", new=" ")
    .replace_all(old="\t", new=" ")
  let tokens : Array[String] = []
  for token in normalized.split(" ") {
    let trimmed = token.trim()
    if !trimmed.is_empty() {
      tokens.push(trimmed.to_owned())
    }
  }
  tokens
}

///|
fn join_tokens(parts : Array[String], separator : String) -> String {
  let builder = StringBuilder()
  for i = 0; i < parts.length(); i = i + 1 {
    if i > 0 {
      builder.write_string(separator)
    }
    builder.write_string(parts[i])
  }
  builder.to_string()
}

///|
fn command_body(
  tokens : Array[String],
  start : Int,
  command : String,
) -> (Array[String], Int) raise VcdError {
  let body : Array[String] = []
  let mut i = start
  while i < tokens.length() && tokens[i] != "$end" {
    body.push(tokens[i])
    i = i + 1
  }
  if i >= tokens.length() {
    raise VcdError("unterminated \{command} command")
  }
  (body, i + 1)
}

///|
fn parse_positive_width(text : String) -> Int raise VcdError {
  if text.is_empty() {
    raise VcdError("malformed $var: missing width")
  }
  let mut value = 0
  for ch in text {
    if ch < '0' || ch > '9' {
      raise VcdError("malformed $var: invalid width '\{text}'")
    }
    value = value * 10 + (ch.to_int() - '0'.to_int())
  }
  if value <= 0 {
    raise VcdError("malformed $var: width must be positive")
  }
  value
}

///|
fn parse_nonnegative_int64(
  text : String,
  context : String,
) -> Int64 raise VcdError {
  if text.is_empty() {
    raise VcdError("invalid \{context}: expected a non-negative integer")
  }
  let mut value = 0L
  for ch in text {
    if ch < '0' || ch > '9' {
      raise VcdError("invalid \{context} '\{text}'")
    }
    let digit = Int64::from_int(ch.to_int() - '0'.to_int())
    if value > (9223372036854775807L - digit) / 10L {
      raise VcdError("invalid \{context} '\{text}': value is too large")
    }
    value = value * 10L + digit
  }
  value
}

///|
fn identifier_exists(signals : Array[Signal], identifier : String) -> Bool {
  for signal in signals {
    if signal.identifier == identifier {
      return true
    }
  }
  false
}

///|
fn signal_by_identifier(
  signals : Array[Signal],
  identifier : String,
) -> Signal? {
  for signal in signals {
    if signal.identifier == identifier {
      return Some(signal)
    }
  }
  None
}

///|
fn full_signal_name(scopes : Array[String], name : String) -> String {
  if scopes.is_empty() {
    name
  } else {
    "\{join_tokens(scopes, ".")}.\{name}"
  }
}

///|
fn normalize_scalar(value : Char) -> String? {
  match value {
    '0' => Some("0")
    '1' => Some("1")
    'x' | 'X' => Some("x")
    'z' | 'Z' => Some("z")
    _ => None
  }
}

///|
fn normalize_vector(bits : String) -> String raise VcdError {
  if bits.is_empty() {
    raise VcdError("invalid vector value: binary digits are missing")
  }
  let builder = StringBuilder(size_hint=bits.length())
  for ch in bits {
    match ch {
      '0' => builder.write_char('0')
      '1' => builder.write_char('1')
      'x' | 'X' => builder.write_char('x')
      'z' | 'Z' => builder.write_char('z')
      _ => raise VcdError("invalid vector value 'b\{bits}'")
    }
  }
  builder.to_string()
}

///|
fn parse_change_token(
  tokens : Array[String],
  i : Int,
  current_time : Int64,
  signals : Array[Signal],
  changes : Array[SignalChange],
) -> Int raise VcdError {
  let token = tokens[i]
  let first = match token.get_char(0) {
    Some(ch) => ch
    None => return i + 1
  }
  if first == 'b' || first == 'B' {
    if i + 1 >= tokens.length() {
      raise VcdError("invalid vector change: missing signal identifier")
    }
    let value = normalize_vector(token[1:].to_owned())
    let identifier = tokens[i + 1]
    if !identifier_exists(signals, identifier) {
      raise VcdError("unknown signal identifier '\{identifier}'")
    }
    changes.push({ timestamp: current_time, identifier, value })
    return i + 2
  }
  match normalize_scalar(first) {
    Some(value) => {
      let identifier = token[1:].to_owned()
      if identifier.is_empty() {
        raise VcdError("invalid scalar change: missing signal identifier")
      }
      let signal = match signal_by_identifier(signals, identifier) {
        Some(signal) => signal
        None => raise VcdError("unknown signal identifier '\{identifier}'")
      }
      if signal.width != 1 {
        raise VcdError(
          "invalid scalar change for \{signal.full_name}: width is \{signal.width}",
        )
      }
      changes.push({ timestamp: current_time, identifier, value })
      i + 1
    }
    None => raise VcdError("invalid signal value '\{token}'")
  }
}

///|
/// Parse a complete VCD document held in memory.
pub fn parse_vcd(text : String) -> VcdFile raise VcdError {
  if text.trim().is_empty() {
    raise VcdError("empty VCD input")
  }
  let tokens = tokenize(text)
  let mut date = ""
  let mut version = ""
  let mut timescale = ""
  let scopes : Array[String] = []
  let signals : Array[Signal] = []
  let changes : Array[SignalChange] = []
  let mut i = 0
  let mut definitions_ended = false
  while i < tokens.length() && !definitions_ended {
    let token = tokens[i]
    match token {
      "$date" => {
        let (body, next) = command_body(tokens, i + 1, "$date")
        date = join_tokens(body, " ")
        i = next
      }
      "$version" => {
        let (body, next) = command_body(tokens, i + 1, "$version")
        version = join_tokens(body, " ")
        i = next
      }
      "$timescale" => {
        let (body, next) = command_body(tokens, i + 1, "$timescale")
        if body.is_empty() {
          raise VcdError("malformed $timescale command")
        }
        timescale = join_tokens(body, "")
        i = next
      }
      "$scope" => {
        let (body, next) = command_body(tokens, i + 1, "$scope")
        if body.length() < 2 || body[1].is_empty() {
          raise VcdError("malformed $scope command")
        }
        scopes.push(body[1])
        i = next
      }
      "$upscope" => {
        let (_, next) = command_body(tokens, i + 1, "$upscope")
        if scopes.pop() is None {
          raise VcdError("unmatched $upscope command")
        }
        i = next
      }
      "$var" => {
        let (body, next) = command_body(tokens, i + 1, "$var")
        if body.length() < 4 {
          raise VcdError("malformed $var command")
        }
        let width = parse_positive_width(body[1])
        let identifier = body[2]
        let name = body[3]
        if identifier.is_empty() || name.is_empty() {
          raise VcdError("malformed $var command")
        }
        if identifier_exists(signals, identifier) {
          raise VcdError("duplicate signal identifier '\{identifier}'")
        }
        signals.push({
          identifier,
          name,
          full_name: full_signal_name(scopes, name),
          width,
          signal_type: body[0],
        })
        i = next
      }
      "$enddefinitions" => {
        let (_, next) = command_body(tokens, i + 1, "$enddefinitions")
        if !scopes.is_empty() {
          raise VcdError("$scope/$upscope mismatch at $enddefinitions")
        }
        definitions_ended = true
        i = next
      }
      _ =>
        if token.has_prefix("$") {
          let (_, next) = command_body(tokens, i + 1, token)
          i = next
        } else {
          i = i + 1
        }
    }
  }
  if !definitions_ended {
    raise VcdError("missing $enddefinitions command")
  }
  let mut current_time = 0L
  while i < tokens.length() {
    let token = tokens[i]
    if token.has_prefix("#") {
      current_time = parse_nonnegative_int64(token[1:].to_owned(), "timestamp")
      i = i + 1
      continue
    }
    if token == "$end" {
      i = i + 1
      continue
    }
    if token == "$dumpvars" ||
      token == "$dumpall" ||
      token == "$dumpon" ||
      token == "$dumpoff" {
      i = i + 1
      while i < tokens.length() && tokens[i] != "$end" {
        i = parse_change_token(tokens, i, current_time, signals, changes)
      }
      if i >= tokens.length() {
        raise VcdError("unterminated \{token} command")
      }
      i = i + 1
      continue
    }
    if token.has_prefix("$") {
      let (_, next) = command_body(tokens, i + 1, token)
      i = next
      continue
    }
    i = parse_change_token(tokens, i, current_time, signals, changes)
  }
  { date, version, timescale, signals, changes }
}

///|
/// Short alias for `parse_vcd`.
pub fn parse(text : String) -> VcdFile raise VcdError {
  parse_vcd(text)
}
