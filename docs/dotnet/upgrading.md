---
title: "Upgrading from 1.x"
---

# Upgrading from 1.x

This version of JQLite replaces JQSharp 1.x (the `Devlooped.JQSharp` package). The engine was rewritten as the
reference implementation of jqlite, so the API changed in a few places and some programs give
different results, closer to jq 1.8. This page lists what you need to change.

## Package and namespace

| 1.x | Now |
| --- | --- |
| package `Devlooped.JQSharp` | package `JQLite` |
| `using Devlooped;` | `using JQLite;` |

The type names `Jq`, `JqExpression`, `JqException`, `JqResolver`, `JqFileResolver` and
`JqResourceResolver` are unchanged.

## API changes

- `Jq.Evaluate` and `JqExpression.Evaluate` return an `IReadOnlyList<JsonElement>` instead of an
  `IEnumerable<JsonElement>`. The program runs when `Evaluate` is called, not when the results are
  first enumerated, so an error is thrown by the call itself. A new overload takes a callback and
  streams the results (see [Evaluating](evaluate.md#streaming-results)).
- `Jq.Parse(expression, JqResolver? resolver = null)` became three overloads:
  `Parse(expression)`, `Parse(expression, resolver)` and `Parse(expression, options)`, taking a
  [JqOptions](xref:JQLite.JqOptions). None accepts `null`: replace `Jq.Parse(text, null)` with
  `Jq.Parse(text)`.
- The `Jq.EvaluateAsync` overloads that took a `CancellationToken` as the third argument are gone:
  the variables come third. Name the token, `Jq.EvaluateAsync(expression, input, cancellationToken: token)`.
- `JqException` is no longer sealed. [JqParseException](xref:JQLite.JqParseException) (with `Line`
  and `Column`) and [JqHaltException](xref:JQLite.JqHaltException) (with `ExitCode`) derive from it.
  Its constructors are `JqException(string)` and `JqException(string, JsonElement)`; the
  `JqException(JsonElement)` constructor is gone. See [Errors](errors.md).
- [JqResolver](xref:JQLite.JqResolver) has a new contract. `Resolve(path, fromPath)` and the virtual
  `GetCanonicalPath(path, fromPath)` are replaced by two abstract methods:
  `GetCanonicalPath(path, kind, metadata, fromPath)`, which returns `null` when there is no such
  module, and `Open(canonicalPath)`. See [Modules](modules.md#your-own-resolver).

## Behaviour changes

- An empty expression is `.`; 1.x threw `Filter expression cannot be empty.`.
- Unknown functions, labels and modules fail in `Jq.Parse` with a `JqParseException`, rather than
  when evaluated.
- `halt` ends the evaluation normally and keeps the results produced before it. `halt_error`
  throws a `JqHaltException` with the value and the exit code. In 1.x, both ended the evaluation
  without results and without an exception.
- Data imports (`import "file" as $name;`) bind an array of the values of the file.
- `$ENV` and `env` come from `JqOptions.Environment` (the process environment by default), and
  `now` and the local time zone from `JqOptions.TimeProvider`. See [Options](options.md).
- Deep recursion fails with the catchable error `Maximum call depth exceeded`, at
  [`JqOptions.MaxDepth`](options.md#the-depth-limit) calls (1000 by default), instead of
  overflowing the stack.
- `debug` and `stderr` hand their values to `JqOptions.Debug` and `JqOptions.Stderr`.

## Different results

- Numbers are written in one canonical form: `1.0` is `1`, and `1e-7`, `1e+21`, `-0` are written
  so (see [Values](values.md#numbers)).
- Lone surrogates in strings become U+FFFD.
- Semantic fixes: lexical scoping of functions and variables, the precedence of `as` and `//`,
  `try` keeping the outputs produced before an error, object construction over generators,
  short-circuit `and` and `or`, stable sorts, and string slices by code point.
- Regular expressions follow the jqlite flavor: no lookaround, backreferences or inline flags;
  `\d`, `\w`, `\s` and `\b` are ASCII; the `i` flag folds ASCII letters only.

The complete list of differences from jq is in spec
[§13](../language/spec.md#13-differences-from-jq-18).
