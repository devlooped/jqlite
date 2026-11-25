---
title: "Evaluating"
---

# Evaluating

A program runs on one input value and produces zero or more output values. The crate gives three ways to run it: `jqlite::evaluate` for a single run, a parsed `JqExpression` for many runs, and `JqExpression::for_each` to receive the outputs one at a time.

## One-shot evaluation

```rust
let results: Vec<JqValue> = jqlite::evaluate(".a + 1", JqValue::parse(r#"{"a": 41}"#)?)?;
assert_eq!(results[0].to_json(), "42");
```

`jqlite::evaluate(expression, input)` parses the program with the default options, evaluates it once and returns all the outputs. It cannot take variables or options: use `parse_with` and `evaluate_with` for those.

## Parse once, evaluate many times

```rust
use jqlite::{JqError, JqValue};

fn main() -> Result<(), JqError> {
    // Parse and bind once: syntax errors and unknown functions are reported here.
    let total = jqlite::parse(".items | map(.price * .qty) | add")?;

    for order in [
        r#"{"items":[{"price":2.5,"qty":4}]}"#,
        r#"{"items":[{"price":1,"qty":1},{"price":3,"qty":2}]}"#,
    ] {
        let results = total.evaluate(JqValue::parse(order)?)?;
        println!("{}", results[0]);
    }
    Ok(())
}
```

```text
10
7
```

`jqlite::parse(text)` and `jqlite::parse_with(text, &options)` return a `JqExpression`. Parsing does all the work that does not depend on the input, and reports its errors as `JqError::Parse` with a line and a column:

- syntax errors, including a program nested deeper than 1000 levels (`Program too deeply nested`);
- calls of unknown functions or of a known name with the wrong number of arguments (`foo/0 is not defined`);
- `break $name` without its `label`, and `$alias::name` without its data import;
- every `import` and `include`: the modules are resolved, read and bound now (see [Modules](modules.md)).

A `$name` with no binding is not a parse error: it is a [host variable](variables.md), looked up when it is evaluated. The [options](options.md) are read at parse time and apply to every evaluation of the expression.

## All the results, or a stream

`evaluate(input)` and `evaluate_with(input, &variables)` collect every output in a `Vec`. When the program fails, they return the error and drop the outputs produced before it. A program with infinitely many outputs never returns from them.

`for_each(input, variables, on_result)` gives each output to the closure as soon as it is produced. The closure returns `true` to go on or `false` to stop; stopping is not an error.

```rust
use jqlite::{JqError, JqValue};

fn main() -> Result<(), JqError> {
    let expression = jqlite::parse("range(1; infinite) | select(. % 7 == 0)")?;

    let mut found = Vec::new();
    expression.for_each(JqValue::Null, None, |result| {
        found.push(result.as_number());
        found.len() < 3 // false stops the evaluation
    })?;
    println!("{found:?}");
    Ok(())
}
```

```text
[7.0, 14.0, 21.0]
```

The second argument is `Option<&HashMap<String, JqValue>>`: `None`, or the variables. If an error reaches the top of the program, `for_each` returns it after the outputs produced before it have been given to the closure:

```rust
let expression = jqlite::parse(r#"1, 2, error("late"), 3"#)?;
let result = expression.for_each(JqValue::Null, None, |value| {
    println!("got {value}");
    true
});
// got 1, got 2, then result is Err with the message "late"
```

## One input per evaluation

An evaluation has exactly one input value. jqlite has no `input` or `inputs`: a program that uses them fails to parse with `input/0 is not defined`. To process a sequence of values, evaluate the expression once per value (see [JSON Lines](jsonl.md)); nothing of one evaluation reaches the next.

The empty program, or one made only of whitespace and comments, is the identity `.`: `jqlite::evaluate("", input)` returns the input.

## Threads

A `JqExpression` is immutable, `Send` and `Sync`. Many threads may evaluate the same expression at once, each with its own input and variables. Cloning it is cheap: the clones share the parsed program.

```rust
use std::collections::HashMap;
use std::thread;

use jqlite::{JqError, JqValue};

fn main() -> Result<(), JqError> {
    let expression = jqlite::parse("[.[] * $factor] | add")?;
    let input = JqValue::parse("[1, 2, 3]")?;

    let totals: Vec<String> = thread::scope(|scope| {
        let handles: Vec<_> = (1..=4)
            .map(|factor| {
                let (expression, input) = (&expression, input.clone());
                scope.spawn(move || {
                    let variables = HashMap::from([("factor".to_owned(), JqValue::from(factor))]);
                    expression.evaluate_with(input, &variables).map(|results| results[0].to_json())
                })
            })
            .collect();
        handles.into_iter().map(|handle| handle.join().expect("the thread ends")).collect::<Result<_, _>>()
    })?;
    println!("{totals:?}");
    Ok(())
}
```

```text
["6", "12", "18", "24"]
```

What runs during an evaluation follows from this:

- the `debug` and `stderr` handlers and the clock of the [options](options.md) may be called from any thread that evaluates the expression;
- the resolver of [modules](modules.md) is called while parsing, and again by `modulemeta` during evaluations;
- an evaluation runs on the calling thread. Deep recursion does not overflow its stack: the engine continues on a new stack segment when the stack runs short, and the only recursion limit a program meets is the [depth limit](options.md#the-depth-limit).

An evaluation cannot be cancelled from another thread. To bound one, stream it with `for_each` and return `false` when you want it to stop; that works only when the program produces outputs.
