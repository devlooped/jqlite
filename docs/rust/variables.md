---
title: "Variables"
---

# Variables

A program reads values from its host through variables: `$min` in the program is the value the host gives under the name `min`. Variables are given per evaluation, so one parsed expression can run with different values on every call.

```rust
use std::collections::HashMap;

use jqlite::{JqError, JqValue};

fn main() -> Result<(), JqError> {
    let expression = jqlite::parse(".[] | select(.age >= $min) | .name")?;
    let input = JqValue::parse(r#"[{"name":"Ada","age":36},{"name":"Linus","age":28}]"#)?;

    let variables = HashMap::from([("min".to_owned(), JqValue::from(30))]);
    for result in expression.evaluate_with(input.clone(), &variables)? {
        println!("{result}");
    }

    // Without the variable, the program fails when it reads $min.
    match expression.evaluate(input) {
        Err(error) => println!("{error}"),
        Ok(results) => println!("{results:?}"),
    }
    Ok(())
}
```

```text
"Ada"
$min is not defined
```

## The API

| Method | Variables |
| --- | --- |
| `JqExpression::evaluate_with(input, &variables)` | `&HashMap<String, JqValue>` |
| `JqExpression::for_each(input, Some(&variables), on_result)` | `Option<&HashMap<String, JqValue>>` |
| `JqExpression::evaluate(input)`, `jqlite::evaluate(text, input)` | none |

The map is borrowed for the evaluation only; the values in it are shared, not copied.

## Names

- A name is a jq identifier without the `$`: an ASCII letter or `_`, then ASCII letters, digits or `_` (`[A-Za-z_][A-Za-z0-9_]*`).
- `root` is an ordinary name: it binds `$root`.
- `ENV` is refused: `$ENV` is the environment, set with [`JqOptions::environment`](options.md#environment).

Every name is checked before the evaluation starts, even names the program does not use. A wrong one is `JqError::Variable`, and the program does not run:

```text
Variable { message: "$ENV cannot be a host variable: use JqOptions::environment." }
Variable { message: "'$x' is not a valid variable name: give a jq identifier without '$'." }
Variable { message: "'my-var' is not a valid variable name: give a jq identifier without '$'." }
```

## Variables the host does not give

A `$name` that the program does not bind is a host variable, looked up when it is evaluated. If the host did not give it, reading it raises the run-time error `$name is not defined`. It is an ordinary error: `try` catches it, and a program that never reaches the variable runs normally.

```rust
let given = HashMap::from([
    ("root".to_owned(), JqValue::parse(r#"{"a":1}"#)?),
    ("x".to_owned(), JqValue::from("host")),
]);
for program in ["$root.a", "try $missing catch .", "$missing // 0", "2 as $x | $x", "def f($x): $x; f(3)", "[$x, $__loc__]"] {
    match jqlite::parse(program)?.evaluate_with(JqValue::Null, &given) {
        Ok(results) => println!("{program:<24} {results:?}"),
        Err(error) => println!("{program:<24} error: {error}"),
    }
}
```

```text
$root.a                  [1]
try $missing catch .     ["$missing is not defined"]
$missing // 0            error: $missing is not defined
2 as $x | $x             [2]
def f($x): $x; f(3)      [3]
[$x, $__loc__]           [["host",{"file":"<top-level>","line":1}]]
```

`//` does not catch errors, so `$missing // 0` fails: use `try $missing catch 0` for a default.

This differs from jq, where an unbound `$name` is a compile error and variables are declared with `--arg` ([spec §13](../language/spec.md#13-differences-from-jq-18)).

## Shadowing

Bindings in the program win over host variables of the same name, wherever they are visible:

- `E as $x | ...`, destructuring patterns, and the variables of `reduce` and `foreach`;
- `$x` parameters of functions (`def f($x): ...`).

Outside those scopes, `$x` is the host variable again: with `x` given as `"A"`, `reduce 4 as $x (0; $x), $x` outputs `4` and `"A"`.

A module's unbound `$name` is the same host variable as in the main program. A qualified `$alias::name` is never a host variable: it must come from a data import (see [Modules](modules.md)), or the program fails to parse.

## Predefined names

- `$ENV` is an object of the environment variables: the process environment, or the map set in [`JqOptions::environment`](options.md#environment). A program may shadow it with its own binding.
- `$__loc__` is `{"file": "<top-level>", "line": N}`, with the line of the `$`; in a module, `file` is the module's canonical path. It is not a variable and cannot be given by the host.

The binding rules in full are in [spec §7.5](../language/spec.md#75-variables-and-bindings).
