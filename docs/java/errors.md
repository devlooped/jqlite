---
title: "Errors"
---

# Errors

Inside the engine, jqlite errors are values. They become Java exceptions only at the host API, as
three classes of the package `com.devlooped.jqlite`, all unchecked:

| Exception | Thrown by | When |
| --- | --- | --- |
| `JqParseException` | `Jq.parse`, `Jq.evaluate` | a syntax or binding error, before any evaluation |
| `JqException` | `evaluate`, `Jq.evaluateLines`, `JqJson.parse` | an error reached the top of the program; invalid JSON text |
| `JqHaltException` | `evaluate`, `Jq.evaluateLines` | `halt_error` ended the program |

`JqParseException` and `JqHaltException` extend `JqException`, so catch them first.

```java
import com.devlooped.jqlite.Jq;
import com.devlooped.jqlite.JqException;
import com.devlooped.jqlite.JqHaltException;
import com.devlooped.jqlite.JqJson;
import com.devlooped.jqlite.JqParseException;

public class Errors {
    static void run(String program, String input) {
        try {
            Jq.parse(program).evaluate(JqJson.parse(input), result -> {
                System.out.println("result: " + JqJson.toJson(result));
                return true;
            });
            System.out.println("ended normally");
        } catch (JqParseException e) {
            System.out.println("parse error at " + e.line() + ":" + e.column() + ": " + e.getMessage());
        } catch (JqHaltException e) {
            System.out.println("halted with code " + e.exitCode() + ": " + JqJson.toJson(e.value()));
        } catch (JqException e) {
            System.out.println("error: " + e.getMessage());
        }
    }

    public static void main(String[] args) {
        run(".a +", "null");
        run(".[] | .name", "[{\"name\": \"x\"}, 5]");
        run("1, halt, 2", "null");
        run("{code: 2} | halt_error", "null");
    }
}
```

```text
parse error at 1:5: Unexpected end of program at line 1, column 5
result: "x"
error: Cannot index number with string ("name")
result: 1
ended normally
halted with code 5: {"code":2}
```

## Syntax and binding errors

`JqParseException` reports an error found while the program is parsed and bound: a syntax error,
an unknown function (`foo/0 is not defined`), a `break` without its label
(`$*label-x is not defined`), a qualified variable without its data import, a module that cannot
be found or read, a cycle of imports. The message ends with the position:
`foo/0 is not defined at line 2, column 3`.

- `line()` and `column()` are 1-based; the column counts code points.
- When the error is inside a module, the message names the module's canonical path before the line:
  `Expected ')' but found ';' at /full/path/bad.jq, line 2, column 15`, and `line()` and `column()`
  are positions in that module.
- `value()` is `null`.

## Uncaught run-time errors

When an error reaches the top of the program, `evaluate` throws `JqException`.

- `value()` is the error value: what `error(v)` raised, or the message string of a builtin's error.
  Any value can be an error value.
- `getMessage()` is the value itself when it is a string. Otherwise it is the value's JSON text
  followed by ` (not a string)`: `error({code: 404})` gives `{"code":404} (not a string)`, and
  `error(null)` gives `null (not a string)` with `value()` equal to `JqValue.NULL`.

The list-returning `evaluate` returns nothing when it throws. The streaming `evaluate` has already
given the results produced before the error to its callback.

The messages of the builtins are those of jq 1.8 ([spec §10](../language/spec.md#10-errors)), for
example `string ("a") and number (1) cannot be added` or `Maximum call depth exceeded` (see
[the depth limit](options.md#the-depth-limit)).

## halt and halt_error

`halt` ends the program normally: no exception, and the results before it are kept (`1, halt, 2`
outputs `1`).

`halt_error` ends the program with `JqHaltException`, even with the exit code 0:

- `value()` is the input of `halt_error`; `getMessage()` follows the rule above (`"bye"` gives the
  message `bye`);
- `exitCode()` is the code: `halt_error(1)` gives 1, and `halt_error` without an argument gives 5.

jqlite writes nothing to standard error and does not end the process: what to do with the value
and the code is the host's choice.

## Catching errors in the program

A program handles its own errors with `try`, before they reach the host:

```jq
[.[] | try .name catch "bad"]
```

On `[{"name": "x"}, 5]` this outputs `["x","bad"]`. `try E` without `catch` drops the error, and
`E?` is the same: `[.[] | .name?]` outputs `["x"]`. The handler receives the error value as it is:
`try error({code: 404}) catch .code` outputs `404`. `try` does not catch `halt`, `halt_error` or
`break` ([spec §7.13](../language/spec.md#713-try-catch-and-)).

## Invalid arguments

Mistakes in the calls of the API are ordinary Java exceptions, thrown before any evaluation:

| Call | Exception |
| --- | --- |
| a `null` program, options, resolver, input or callback | `NullPointerException` |
| a variable name that is not an identifier, starts with `$`, or is `ENV`; a `null` variable value | `IllegalArgumentException` (see [Variables](variables.md#names)) |
| `withMaxDepth` outside 1 to 100,000 | `IllegalArgumentException` |
| `withClock(null)` | `NullPointerException` |
| `JqJson.parse` of invalid JSON | `JqException`: `Unfinished JSON term at EOF at line 1, column 8 (while parsing '{"a": 1,')` |

An exception thrown by your own callback (`onResult`, a `debug` or `stderr` handler) ends the
evaluation and propagates to the caller unchanged.
