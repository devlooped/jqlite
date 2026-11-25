---
title: "Errors"
---

# Errors

The engine itself never raises: errors are values inside it, and they become Python exceptions only at the host boundary. There are three exception types, all in the package, and one base class:

| Exception | Base | Raised by | When |
| --- | --- | --- | --- |
| `jqlite.JqParseError` | `JqError` | `parse`, `evaluate` | a syntax or binding error, in the program or in a module |
| `jqlite.JqError` | `Exception` | `evaluate`, `stream`, `evaluate_each` | a run-time error that no `try` caught |
| `jqlite.JqHaltError` | `JqError` | `evaluate`, `stream`, `evaluate_each` | `halt_error` |

Catch the subclasses before `JqError`:

```python
import jqlite

def run(program, input=None):
    try:
        return jqlite.evaluate(program, input)
    except jqlite.JqHaltError as e:
        return f"halted with {e.exit_code}: {e.value!r}"
    except jqlite.JqParseError as e:
        return f"bad program at {e.line}:{e.column}: {e}"
    except jqlite.JqError as e:
        return f"failed: {e.value!r}"

print(run("1 +"))                       # bad program at 1:4: Unexpected end of program at line 1, column 4
print(run(". + 1", "a"))                # failed: 'string ("a") and number (1) cannot be added'
print(run('"bye" | halt_error(2)'))     # halted with 2: 'bye'
```

## Syntax and binding errors

`JqParseError` is raised before any evaluation. Its attributes:

- `line` and `column`: the position, starting at 1; columns count code points;
- `module`: the canonical path of the module that holds the error, or `None` for the main program;
- `message` (also `str(e)`): the description followed by the position, as in `foo/0 is not defined at line 2, column 3`, or `... at <module>, line 1, column 10` in a module;
- `value`: always `None`.

The errors include a syntax error, a call of an unknown function (`name/arity is not defined`), a `break` without its `label`, a `$alias::name` without its data import, a program nested more than 1000 levels deep, and the module errors of [Modules](modules.md#when-resolution-fails). The fixed texts are in [spec §10.2](../language/spec.md#102-binding-and-syntax-errors).

## Run-time errors

A run-time error that reaches the top of the program raises `JqError`. Its attributes:

- `value`: the error value as a Python JSON value. It is what `error(v)` raised, or the message string of a builtin's error. Any value can be an error value.
- `message` (also `str(e)`): the value itself when it is a string; otherwise its compact JSON text followed by ` (not a string)` ([spec §10.1](../language/spec.md#101-message-rules)).

```python
import jqlite

try:
    jqlite.evaluate("error({code: 1})", None)
except jqlite.JqError as e:
    print(e.value)  # {'code': 1}
    print(e)        # {"code":1} (not a string)
```

With `stream`, every output produced before the error has already been given to the callback when the exception is raised. With `evaluate`, those outputs are lost with the list.

The depth limit (`Maximum call depth exceeded`, [Options](options.md#the-depth-limit)) and an unsupplied variable (`$name is not defined`, [Variables](variables.md)) are run-time errors like any other.

## Catching errors in the program

`try` catches run-time errors inside the program, so they never reach Python. `try E catch H` gives the error value to `H`; `try E` and `E?` drop it:

```python
import jqlite

print(jqlite.evaluate('[.[] | try (. + 1) catch "bad"]', [1, "a", 2]))  # [[2, 'bad', 3]]
print(jqlite.evaluate("[.[] | .a?]", [{"a": 1}, 5]))                    # [[1]]
print(jqlite.evaluate("try error({code: 1}) catch .code", None))        # [1]
```

`try` does not catch `break`, `halt` or `halt_error` ([spec §7.14](../language/spec.md#714-errors-and-halting)).

## Halting

`halt` stops the program at once with no error: the evaluation ends normally, and the outputs produced before it are the results.

```python
import jqlite

print(jqlite.evaluate("1, halt, 2", None))  # [1]
```

`halt_error(code)` stops the program and raises `JqHaltError`. `value` is the input of `halt_error`, `exit_code` the code truncated to an integer, and `message` follows the rule of run-time errors. `halt_error` without an argument uses the code 5.

```python
import jqlite

try:
    jqlite.evaluate('{a: 1} | halt_error(3)', None)
except jqlite.JqHaltError as e:
    print(e.exit_code, e.value, e)  # 3 {'a': 1} {"a":1} (not a string)
```

`JqHaltError` is a `JqError`: catch it first if you treat it differently. An exit code of 0 still raises it.

## Invalid arguments

Mistakes in the arguments of the API raise the standard Python exceptions, before anything is evaluated:

| Exception | When |
| --- | --- |
| `TypeError` | the expression is not a `str`; an input or a variable value is not a JSON value ([Values](values.md)) |
| `ValueError` | a variable name is not an identifier, or is `ENV` ([Variables](variables.md)) |
| `ValueError` | `max_depth` is not an `int` from 0 to 100,000 (raised by `Options`) |

An exception raised by your own callbacks (`stream`'s `on_result`, the `debug` and `stderr` handlers) propagates unchanged. So does one raised by a resolver, unless it is a `JqError` or an `OSError` ([Modules](modules.md#when-resolution-fails)).
