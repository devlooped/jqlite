---
title: "Variables"
---

# Variables

A program can use variables that your code supplies, as the jq command line does with `--arg` and
`--argjson`. Pass them to an evaluation as an `IReadOnlyDictionary<string, JsonElement>`, by name
without the `$`:

```csharp
using System.Text.Json;
using JQLite;

using var doc = JsonDocument.Parse("""{"name":"Alice"}""");
using var root = JsonDocument.Parse("""{"id":42,"role":"admin"}""");

var variables = new Dictionary<string, JsonElement>
{
    ["root"] = root.RootElement, // $root
};

var results = Jq.Evaluate("{name, id: $root.id, role: $root.role}", doc.RootElement, variables);

Console.WriteLine(results[0].GetRawText()); // {"name":"Alice","id":42,"role":"admin"}
```

Every evaluation method takes the dictionary as an optional last argument (before the
cancellation token of the async ones):

- `Jq.Evaluate(expression, input, variables)`;
- `JqExpression.Evaluate(input, variables)` and `JqExpression.Evaluate(input, onResult, variables)`;
- `Jq.EvaluateAsync(expression, input, variables, cancellationToken)`, where the same variables
  apply to every value of the stream (see [JSON Lines](jsonl.md)).

Variables belong to one evaluation, not to the parsed expression: the same
[JqExpression](xref:JQLite.JqExpression) can run with different variables, concurrently. The
values are converted once per evaluation, so you may dispose their documents when `Evaluate`
returns.

## Names

A name is a jq identifier without the `$`: a letter or `_`, then letters, digits or `_`
(`[A-Za-z_][A-Za-z0-9_]*`). The key `"root"` binds `$root`.

`ENV` is not allowed: `$ENV` is the environment, set with
[`JqOptions.Environment`](options.md#environment).

Any other key, such as `"$root"`, `"a-b"`, `"1x"` or `""`, throws an `ArgumentException` (its
`ParamName` is `variables`) before the evaluation starts:

```text
'$root' is not a valid variable name: give a jq identifier without '$'. (Parameter 'variables')
$ENV cannot be a host variable: use JqOptions.Environment. (Parameter 'variables')
```

## Variables that are not supplied

A `$name` that the program does not bind itself is a host variable. It is not checked when the
program is parsed: it is looked up when it is evaluated. If the dictionary does not have it, the
lookup is the run-time error `$name is not defined`, which `try` can catch like any other error:

```csharp
using System.Text.Json;
using JQLite;

var greet = Jq.Parse("""("hello " + $who), (try $missing catch ("caught: " + .))""");
using var doc = JsonDocument.Parse("null");
using var who = JsonDocument.Parse("\"world\"");

foreach (var result in greet.Evaluate(doc.RootElement, new Dictionary<string, JsonElement> { ["who"] = who.RootElement }))
    Console.WriteLine(result);
// hello world
// caught: $missing is not defined

try
{
    greet.Evaluate(doc.RootElement); // no variables at all
}
catch (JqException ex)
{
    Console.WriteLine(ex.Message); // $who is not defined
}
```

Since the lookup happens only when evaluated, a branch that does not run needs no variable:
`false and $verbose` never looks `$verbose` up. For a default, write `try $x catch 1` or `$x? // 1`;
`$x // 1` is not enough, because `//` lets the errors of its left side through.

Code [modules](modules.md) see the same host variables as the main program: an unbound `$name` in a
module is the host variable of that name. A qualified `$alias::name` is different: it must be bound
by a data import (`import "file" as $alias;`), otherwise the program fails to parse.

## Shadowing

A binding in the program hides a host variable of the same name, wherever it is visible. Both
`as $name` and a `$name` parameter of a function do:

```csharp
using System.Text.Json;
using JQLite;

using var doc = JsonDocument.Parse("null");
using var one = JsonDocument.Parse("1");
var variables = new Dictionary<string, JsonElement> { ["x"] = one.RootElement };

var program = "$x, (2 as $x | $x), (def f($x): $x; f(3))";
foreach (var result in Jq.Evaluate(program, doc.RootElement, variables))
    Console.Write(result.GetRawText() + " ");
// 1 2 3
```

## $ENV and $__loc__

Two names are not host variables:

- `$ENV` is the object of environment variables, the same as the builtin `env`. It comes from
  [`JqOptions.Environment`](options.md#environment), or from the process environment when that
  option is `null`. A program may shadow it (`{} as $ENV | $ENV` is `{}`).
- `$__loc__` is the object `{"file": "<top-level>", "line": L}`, where `L` is the line of its `$` in
  the program; in a module, `file` is the module's canonical path. It is not a variable: it cannot
  be bound or used as a parameter.

```csharp
using System.Text.Json;
using JQLite;

using var doc = JsonDocument.Parse("null");
Console.WriteLine(Jq.Evaluate("1 |\n$__loc__", doc.RootElement)[0].GetRawText());
// {"file":"<top-level>","line":2}
```

The rules are in spec [§7.5](../language/spec.md#75-variables-and-bindings) and
[§12](../language/spec.md#12-host-interface).
