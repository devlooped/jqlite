---
title: "Options"
---

# Options

`JqOptions` holds what an expression takes from its host besides its input and variables. You pass it to `jqlite::parse_with`; it is read once, when the expression is parsed, and applies to every evaluation of that expression. `jqlite::parse` and `jqlite::evaluate` use `JqOptions::default()`.

| Field | Type | Default | Effect |
| --- | --- | --- | --- |
| `resolver` | `Option<Arc<dyn JqResolver>>` | `None`: no module exists | `import`, `include`, `modulemeta` ([Modules](modules.md)) |
| `environment` | `Option<Vec<(String, String)>>` | `None`: the process environment | `$ENV` and `env` |
| `clock` | `Arc<dyn JqClock>` | `Arc::new(SystemClock)`: system time, zone UTC | `now`, `localtime`, `strflocaltime`, `%z`, `%Z` |
| `max_depth` | `usize` | `1000` | calls of jq-defined functions active at once |
| `debug` | `Option<Arc<dyn Fn(&JqValue) + Send + Sync>>` | `None`: dropped | receives the values of `debug` |
| `stderr` | `Option<Arc<dyn Fn(&JqValue) + Send + Sync>>` | `None`: dropped | receives the values of `stderr` |

Set the fields you need and take the rest from the default:

```rust
let options = JqOptions { max_depth: 200, ..JqOptions::default() };
let expression = jqlite::parse_with(program, &options)?;
```

`JqOptions` is `Clone` and `Send + Sync`. The expression keeps what it needs, so the options may be dropped after parsing.

## Environment

```rust
use jqlite::{JqError, JqOptions, JqValue};

fn main() -> Result<(), JqError> {
    let options = JqOptions {
        environment: Some(vec![
            ("HOME".to_owned(), "/home/ada".to_owned()),
            ("LANG".to_owned(), "C".to_owned()),
        ]),
        ..JqOptions::default()
    };
    let expression = jqlite::parse_with("$ENV, env.HOME", &options)?;
    for result in expression.evaluate(JqValue::Null)? {
        println!("{result}");
    }
    Ok(())
}
```

```text
{"HOME":"/home/ada","LANG":"C"}
"/home/ada"
```

- `Some(pairs)`: `$ENV` and `env` are an object of these pairs, in this order. `Some(Vec::new())` hides the environment entirely.
- `None`: the process environment, read by each evaluation the first time it uses `$ENV` or `env`, in the order the operating system gives. Names and values that are not valid Unicode are converted with U+FFFD replacements.

## Clock and time zone

`clock` is the source of `now` and of the local time zone. It implements the trait `JqClock`:

```rust
pub trait JqClock: Send + Sync {
    fn now(&self) -> f64;                  // seconds since the Unix epoch
    fn offset(&self, seconds: f64) -> i32; // seconds east of UTC at that instant
    fn abbreviation(&self, _seconds: f64) -> Option<String> {
        None
    }
}
```

Two clocks are built in:

- `SystemClock`, the default: the system time, with UTC as the local zone. The standard library cannot read the host's time zone, so `localtime` equals `gmtime` and `strflocaltime` prints `%z` as `+0000` and `%Z` as `+00`.
- `FixedOffsetClock { offset_seconds }`: the system time, with a zone at a fixed offset from UTC and no abbreviation.

For a real zone with daylight saving time, or a frozen time in tests, implement `JqClock`. `offset` receives the instant, so it can follow the zone's rules:

```rust
use std::sync::Arc;

use jqlite::{FixedOffsetClock, JqClock, JqError, JqOptions, JqValue};

// A frozen clock in Central European Time, for tests.
struct Frozen;

impl JqClock for Frozen {
    fn now(&self) -> f64 {
        1425599507.0 // 2015-03-05T23:51:47Z
    }

    fn offset(&self, seconds: f64) -> i32 {
        // Summer time from 2015-03-29T01:00Z to 2015-10-25T01:00Z.
        if (1427590800.0..1445734800.0).contains(&seconds) { 7200 } else { 3600 }
    }

    fn abbreviation(&self, seconds: f64) -> Option<String> {
        Some(if self.offset(seconds) == 7200 { "CEST" } else { "CET" }.to_owned())
    }
}

fn main() -> Result<(), JqError> {
    let program = r#"now, (now | strflocaltime("%Y-%m-%d %H:%M %z %Z")), (now | strftime("%H:%M %Z"))"#;

    let frozen = JqOptions { clock: Arc::new(Frozen), ..JqOptions::default() };
    for result in jqlite::parse_with(program, &frozen)?.evaluate(JqValue::Null)? {
        println!("{result}");
    }

    let fixed = JqOptions { clock: Arc::new(FixedOffsetClock { offset_seconds: -3 * 3600 }), ..JqOptions::default() };
    println!("{}", jqlite::parse_with(r#"0 | strflocaltime("%H:%M %z %Z")"#, &fixed)?.evaluate(JqValue::Null)?[0]);

    println!("{}", jqlite::evaluate(r#"0 | strflocaltime("%H:%M %z %Z")"#, JqValue::Null)?[0]);
    Ok(())
}
```

```text
1425599507
"2015-03-06 00:51 +0100 CET"
"23:51 UTC"
"21:00 -0300 -03"
"00:00 +0000 +00"
```

Without an abbreviation, `%Z` prints the offset (`+hh`, or `+hhmm` when the minutes are not zero). UTC functions (`gmtime`, `strftime`, `mktime`, `todate`) do not use the zone. The clock may be called from any thread that evaluates the expression. Dates follow [spec §9.12](../language/spec.md#912-broken-down-time-and-directives): English names, no locale.

## The depth limit

`max_depth` is the largest number of calls of jq-defined functions active at once: functions of the program and of its modules, and the builtins written in jq (`map`, `select`, `limit`…). Past it, the evaluation raises `Maximum call depth exceeded`, an ordinary error that `try` catches.

```rust
let options = JqOptions { max_depth: 100, ..JqOptions::default() };
let count = jqlite::parse_with("def count: if . == 0 then 0 else (. - 1 | count) + 1 end; count", &options)?;
let deep_enough = count.evaluate(JqValue::from(99))?; // [99]
let too_deep = count.evaluate(JqValue::from(100)); // Err: Maximum call depth exceeded

let caught = jqlite::parse_with("def f: 1 + f; try f catch .", &options)?;
let message = caught.evaluate(JqValue::Null)?; // ["Maximum call depth exceeded"]
```

- The default is 1000. Any `usize` is accepted. With `0`, no jq-defined function can be called at all, not even `map`.
- There are no tail calls: every active call counts ([spec §11](../language/spec.md#11-limits)).
- Recursion up to the limit never exhausts the host stack, whatever the limit and the thread's stack size: the engine continues on a new stack segment. A high limit costs memory, not a crash.
- Programs whose results depend on the exact depth at which the limit triggers are not portable between implementations.

## Debug and stderr handlers

`debug` and `stderr` output their input unchanged and give a value to the host. The handlers receive these values as they are; without a handler the values are dropped, and nothing is written to the process's standard error.

```rust
use std::sync::{Arc, Mutex};

use jqlite::{JqError, JqOptions, JqValue};

fn main() -> Result<(), JqError> {
    let log = Arc::new(Mutex::new(Vec::new()));
    let sink = log.clone();
    let options = JqOptions {
        debug: Some(Arc::new(move |value: &JqValue| sink.lock().expect("not poisoned").push(format!("debug: {value}")))),
        stderr: Some(Arc::new(|value: &JqValue| eprintln!("stderr: {value}"))),
        ..JqOptions::default()
    };

    let expression = jqlite::parse_with(r#".a | debug | debug("twice", . * 2) | stderr | . + 1"#, &options)?;
    println!("{:?}", expression.evaluate(JqValue::parse(r#"{"a": 20}"#)?)?);
    println!("{:?}", log.lock().expect("not poisoned"));
    Ok(())
}
```

```text
[21]
["debug: 20", "debug: \"twice\"", "debug: 40"]
```

and `stderr: 20` on standard error. `debug` gives its input; `debug(msgs)` gives each output of `msgs`, not jq's `["DEBUG:", value]` array. A handler may be called from any thread that evaluates the expression, hence `Send + Sync`.