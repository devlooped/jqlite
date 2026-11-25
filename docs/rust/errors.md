---
title: "Errors"
---

# Errors

Every fallible function of the crate returns `Result<_, JqError>`: errors of programs, of inputs and of variables are values, never panics. What panics is a misuse of the value accessors, such as `as_number` on a string (see [Invalid arguments](#invalid-arguments)).

```rust
pub enum JqError {
    Parse { message: String, line: u32, column: u32 },
    Runtime { message: String, value: JqValue },
    Halt { message: String, value: JqValue, exit_code: i32 },
    Variable { message: String },
    Json { message: String },
}
```

`JqError` implements `Display` (the message), `Debug`, `Clone` and `std::error::Error`, so `?` converts it into `Box<dyn Error>`. `message()` returns the message of any variant; `value()` returns the error value of `Runtime` and `Halt`, and `None` for the others.

## An example of each

```rust
use jqlite::{JqError, JqValue};

fn run(program: &str, input: &str) {
    let outcome = jqlite::parse(program).and_then(|expression| expression.evaluate(JqValue::parse(input)?));
    match outcome {
        Ok(results) => println!("ok: {results:?}"),
        Err(JqError::Parse { message, line, column }) => println!("parse error at {line}:{column}: {message}"),
        Err(JqError::Runtime { message, value }) => println!("runtime error: {message} (value {value})"),
        Err(JqError::Halt { value, exit_code, .. }) => println!("halt_error: exit code {exit_code}, value {value}"),
        Err(other) => println!("{other:?}"),
    }
}

fn main() {
    run(".a |\n  frob", "null");
    run(".a + 1", r#"{"a":"x"}"#);
    run("error({code: 42})", "null");
    run(r#""bye\n" | halt_error(2)"#, "null");
    run("1, halt, 2", "null");
    run(".", "[1,");
}
```

```text
parse error at 2:3: frob/0 is not defined at line 2, column 3
runtime error: string ("x") and number (1) cannot be added (value "string (\"x\") and number (1) cannot be added")
runtime error: {"code":42} (not a string) (value {"code":42})
halt_error: exit code 2, value "bye\n"
ok: [1]
Json { message: "Unfinished JSON term at EOF at line 1, column 3 (while parsing '[1,')" }
```

## Syntax and binding errors

`JqError::Parse` comes from `parse` and `parse_with`, before any evaluation: a syntax error, a call of an unknown function (`frob/0 is not defined`), a `break` without its label, a missing data import, or a failed module (see [Modules](modules.md#failed-resolutions)). `line` and `column` are 1-based and count code points. The message ends with the place: ` at line L, column C`, or ` at <module>, line L, column C` when the error is inside a module; then `line` and `column` are positions in that module. The fixed texts are listed in [spec §10.2](../language/spec.md#102-binding-and-syntax-errors).

## Run-time errors

`JqError::Runtime` is an error that reached the top of the program uncaught: one raised by `error(v)` or by a builtin (`Cannot index number with string ("a")`, `Maximum call depth exceeded`, `$x is not defined`…).

- `value` is the error value as the program raised it: any JSON value. A builtin's error value is its message string.
- `message` is the value itself when it is a string, else its JSON text followed by ` (not a string)` (NaN is written `null`).

`evaluate` and `evaluate_with` drop the outputs produced before the error; `for_each` has already given them to its closure ([Evaluating](evaluate.md#all-the-results-or-a-stream)). The messages of the builtins are in [spec §10](../language/spec.md#10-errors).

## Halting

`halt` ends the evaluation normally: the outputs produced so far are the result, and there is no error. `1, halt, 2` gives `[1]`.

`halt_error` and `halt_error(code)` end it with `JqError::Halt`:

- `value` is the input of `halt_error`; `message` follows the rule of run-time errors (a string is its own message, newline included);
- `exit_code` is the code given, or `5` for `halt_error` without one. The crate does not exit the process: what to do with the code is the host's choice.

`try` does not catch a halt.

## Catching errors in the program

A program handles its own errors with `try … catch` or `?`; they then never reach the host.

```rust
let program = r#"
    .[] | try (if . < 0 then error({negative: .}) else sqrt end)
          catch "skipped \(.negative)"
"#;
for result in jqlite::evaluate(program, JqValue::parse("[4, -1, 9]")?)? {
    println!("{result}");   // 2, "skipped -1", 3
}
let numbers = jqlite::evaluate("[.[] | tonumber?]", JqValue::parse(r#"["1", "x", "3"]"#)?)?;
// [[1,3]]
```

`catch` receives the error value unchanged. Every run-time error is catchable, including `Maximum call depth exceeded` and `$name is not defined`; `break` is not an error and `try` does not catch it ([spec §13](../language/spec.md#13-differences-from-jq-18)).

## Invalid arguments

Errors of what the host gives:

- `JqError::Variable`: a variable name that is not a jq identifier, or `ENV`, rejected before the evaluation starts ([Variables](variables.md#names)).
- `JqError::Json`: `JqValue::parse` was given text that is not exactly one JSON value. The message is the reason, a position when there is one, and the text: `Unexpected extra JSON values (while parsing '1 2')`.

These are panics, not errors, because they are programming mistakes:

- `as_number`, `as_string`, `as_array`, `as_object` on a value of another kind;
- `JqArray::get` with an index past the end, `JqArray::slice` with bounds out of order or past the end, `JqObject::key_at` and `value_at` past the end.
