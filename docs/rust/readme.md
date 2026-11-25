---
title: "jqlite for Rust"
---

# jqlite for Rust

The crate `jqlite` is the Rust port of jqlite, a portable profile of the [jq](https://jqlang.org) language. It is a file-by-file port of the .NET reference engine: it follows the same [specification](../language/spec.md) and passes the same conformance corpus (`spec/tests`), so a program gives the same results here as in every other implementation.

You parse a jq program once into a `JqExpression`, then evaluate it on `JqValue` inputs, from as many threads as you like.

## Requirements

- Rust 1.85 or later (the crate uses edition 2024; it is built and tested with 1.96).
- Two dependencies, fetched by Cargo: `regex` and `stacker`. The crate has no `unsafe` code and no build script.

## Getting it

The crate is not published on crates.io. Take it from the Git repository:

```toml
[dependencies]
jqlite = { git = "https://github.com/devlooped/jqlite" }
```

Or, with a clone of the repository, as a path dependency on its `rust` folder:

```toml
[dependencies]
jqlite = { path = "../jqlite/rust" }
```

## A first program

```rust
use jqlite::{JqError, JqValue};

fn main() -> Result<(), JqError> {
    let input = JqValue::parse(r#"{"users":[{"name":"Ada","age":36},{"name":"Linus","age":28}]}"#)?;

    for result in jqlite::evaluate(".users[] | select(.age > 30) | .name", input)? {
        println!("{result}");
    }
    Ok(())
}
```

```text
"Ada"
```

`JqValue::parse` reads one JSON value. `jqlite::evaluate` parses the program and runs it on that input, returning every output in a `Vec<JqValue>`. A `JqValue` prints as compact JSON with `{}` (`Display`) or with `to_json()`.

To run a program on many inputs, parse it once and keep the expression:

```rust
let names = jqlite::parse(".users[] | .name")?;
let results = names.evaluate(input)?;
```

## In this section

| Page | What it covers |
| --- | --- |
| [Evaluating](evaluate.md) | One-shot evaluation, parse once and evaluate many times, streaming results, threads |
| [Values](values.md) | `JqValue`: building inputs, reading results, numbers, strings, key order, ownership |
| [Variables](variables.md) | Passing `$name` variables to an evaluation |
| [Options](options.md) | `JqOptions`: `$ENV`, the clock and time zone, the depth limit, `debug` and `stderr` |
| [Modules](modules.md) | `import`, `include`, data modules, `modulemeta`, resolvers |
| [Errors](errors.md) | `JqError`: parse, run-time, `halt_error`, invalid arguments |
| [JSON Lines](jsonl.md) | Running a program on each value of a JSON Lines file |
| [API reference](api.md) | Every public item of the crate |
| [The port](port.md) | Building, testing and the differences from the .NET reference |

The language itself is described in [the language guide](../language/readme.md); what jqlite changes from jq 1.8 is in [the spec, §13](../language/spec.md#13-differences-from-jq-18).
