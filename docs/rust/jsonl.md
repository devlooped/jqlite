---
title: "JSON Lines"
---

# JSON Lines

The Rust crate has no JSON Lines helpers, neither synchronous nor asynchronous: the .NET reference's `EvaluateAsync` has no counterpart here (see [the port's README](port.md)). The pieces it needs are in the API, and a loop over the lines of a reader does the same work: parse the program once, read each line with `JqValue::parse`, and evaluate the expression on it.

## Reading a .jsonl file

```rust
use std::fs::File;
use std::io::{BufRead, BufReader};

use jqlite::JqValue;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let path = std::env::args().nth(1).unwrap_or_else(|| "events.jsonl".to_owned());
    let expression = jqlite::parse(r#"select(.level == "error") | "\(.time) \(.message)""#)?;

    for (number, line) in BufReader::new(File::open(&path)?).lines().enumerate() {
        let line = line?;
        if line.trim().is_empty() {
            continue;
        }
        let input = JqValue::parse(&line).map_err(|error| format!("line {}: {error}", number + 1))?;
        for result in expression.evaluate(input)? {
            println!("{}", result.as_string());
        }
    }
    Ok(())
}
```

With this `events.jsonl`:

```json
{"time":"10:00","level":"info","message":"started"}
{"time":"10:02","level":"error","message":"disk full"}

{"time":"10:05","level":"error","message":"retry failed"}
```

```shell-session
$ cargo run -- events.jsonl
10:02 disk full
10:05 retry failed
```

- **One evaluation per value.** Each line is the input of its own evaluation, and nothing of one evaluation reaches the next. jqlite has no `input` or `inputs` to read further values ([spec §13](../language/spec.md#13-differences-from-jq-18)); to combine values across lines, collect the results in Rust, or build an array of the values and run one program on it.
- **One value per line.** `JqValue::parse` reads exactly one JSON value: a line with two values fails with `Unexpected extra JSON values`. The loop skips blank lines; decide yourself whether a bad line stops the run (as above) or is reported and skipped.
- **Parse once.** The expression is parsed before the loop and reused for every line; parsing is the expensive part ([Evaluating](evaluate.md#parse-once-evaluate-many-times)).

## Streaming the results

`evaluate` collects the outputs of one line in a `Vec`. To write them as they come, use `for_each`:

```rust
let stdout = std::io::stdout();
let mut out = stdout.lock();
expression.for_each(input, None, |result| {
    writeln!(out, "{result}").is_ok() // stop this line's evaluation when the output is closed
})?;
```

This needs `use std::io::Write;`. Writing each result with `Display` gives compact JSON, one value per line: the output is JSON Lines too.

## Variables and options

Host variables and options work as for any evaluation: pass the same `HashMap` to `evaluate_with` for every line, and give the options to `parse_with` once ([Variables](variables.md), [Options](options.md)).

## In parallel or in async code

Evaluations are synchronous and run on the calling thread. The expression is `Send + Sync`, so lines can be evaluated on several threads at once (see [Threads](evaluate.md#threads)) when the order of the output does not matter or is restored afterwards. In an asynchronous program, read the lines with your runtime's reader and run each evaluation where your runtime puts blocking, CPU-bound work: an evaluation never awaits anything, and a long one would hold up the executor's thread.
