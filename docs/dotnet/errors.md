---
title: "Errors"
---

# Errors

The errors of a program reach your code as exceptions. They all derive from
[JqException](xref:JQLite.JqException):

| Exception | Thrown by | When |
| --- | --- | --- |
| [JqParseException](xref:JQLite.JqParseException) | `Jq.Parse`, and so `Jq.Evaluate` | a syntax or binding error, before any evaluation |
| `JqException` | `Evaluate` | an error that no `try` caught |
| [JqHaltException](xref:JQLite.JqHaltException) | `Evaluate` | `halt_error` |

Invalid arguments are the usual .NET exceptions: `ArgumentNullException` for a `null` expression,
options, resolver or callback, and `ArgumentException` for an invalid [variable](variables.md)
name. An exception thrown by your own code (the result callback, a `Debug` or `Stderr` handler, a
resolver) propagates unchanged, except the resolver exceptions that [Modules](modules.md#when-resolution-fails)
lists.

## Syntax and binding errors

`Jq.Parse` checks the whole program, and the modules it loads, before anything runs. A
`JqParseException` has the 1-based `Line` and `Column` of the error (the column counts code points),
and its message ends with the position. Its `Value` is `null`.

```csharp
using JQLite;

try
{
    Jq.Parse(".name |\n  shout");
}
catch (JqParseException ex)
{
    Console.WriteLine(ex.Message);              // shout/0 is not defined at line 2, column 3
    Console.WriteLine($"{ex.Line}:{ex.Column}"); // 2:3
}
```

Besides syntax errors, parsing fails for a function, label or module that is not defined, a
circular import, and a program nested more than 1000 levels deep. When the error is in a module,
the message names the module's canonical path before the line
(`… at a.jq, line 1, column 10`), and `Line` and `Column` are positions in that module.

An undefined `$name` is not a parse error: it is a [host variable](variables.md), and a missing
one fails when evaluated.

## Run-time errors

An error that reaches the top of the program, uncaught, ends the evaluation with a `JqException`:

- `Value` is the error value: what `error(v)` raised, or the message string of a builtin's error.
  Any JSON value can be an error value.
- `Message` is that value when it is a string; otherwise its JSON text followed by
  ` (not a string)`.

```csharp
using System.Text.Json;
using JQLite;

using var doc = JsonDocument.Parse("""{"name":"Bob","age":12}""");

try
{
    Jq.Evaluate("""if .age < 18 then error({reason: "minor", age}) else . end""", doc.RootElement);
}
catch (JqException ex)
{
    Console.WriteLine(ex.Message);                      // {"reason":"minor","age":12} (not a string)
    Console.WriteLine(ex.Value?.GetProperty("reason")); // minor
}

try
{
    Jq.Evaluate(". + 1", JsonDocument.Parse("\"a\"").RootElement);
}
catch (JqException ex)
{
    Console.WriteLine(ex.Message); // string ("a") and number (1) cannot be added
}
```

`error(null)` gives a `Value` whose `ValueKind` is `Null`, and the message `null (not a string)`.
The messages of the builtins are listed in spec [§10](../language/spec.md#10-errors).

The list-returning `Evaluate` returns no results when it throws. The callback overload has already
given the results produced before the error (see [Evaluating](evaluate.md#streaming-results)).

## halt and halt_error

`halt` ends the evaluation normally: no exception, and the results produced before it are kept.

`halt_error` and `halt_error(code)` end it with a `JqHaltException`: `Value` is the input of
`halt_error`, `ExitCode` the code (5 when none is given), and `Message` follows the same rule as
above. `try` does not catch either.

```csharp
using System.Text.Json;
using JQLite;

using var doc = JsonDocument.Parse("null");

Console.WriteLine(Jq.Evaluate("1, halt, 2", doc.RootElement).Count); // 1

try
{
    Jq.Evaluate("""{status: "rejected"} | halt_error(3)""", doc.RootElement);
}
catch (JqHaltException ex)
{
    Console.WriteLine($"{ex.ExitCode}: {ex.Value}"); // 3: {"status":"rejected"}
}
```

A tool that mimics the jq command line would write `Message` to standard error and exit with
`ExitCode`. Since `JqHaltException` derives from `JqException`, catch it first when you handle
both.

## Catching errors in the program

Inside a program, `try` catches run-time errors, including `Maximum call depth exceeded` and
`$name is not defined`; `?` is `try` without a handler:

```csharp
using System.Text.Json;
using JQLite;

using var doc = JsonDocument.Parse("""[{"a":1}, "text", {"a":2}]""");

foreach (var result in Jq.Evaluate("""[.[] | try .a catch "bad"], [.[] | .a?]""", doc.RootElement))
    Console.WriteLine(result.GetRawText());
// [1,"bad",2]
// [1,2]
```

`catch` receives the error value unchanged. The outputs produced before the error are kept:
`[try (1, error("x"), 3) catch .]` is `[1,"x"]`. `try` does not catch `halt`, `halt_error` or
`break`.
