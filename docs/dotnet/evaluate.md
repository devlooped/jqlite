---
title: "Evaluating"
---

# Evaluating

A jqlite program runs on one input value and produces a stream of results: none, one or many.
The [Jq](xref:JQLite.Jq) class parses programs and evaluates them; a parsed program is a
[JqExpression](xref:JQLite.JqExpression) that you can evaluate any number of times.

## One-shot evaluation

`Jq.Evaluate(expression, input)` parses the program with the default options, runs it and
returns all its results as an `IReadOnlyList<JsonElement>`:

```csharp
using System.Text.Json;
using JQLite;

using var doc = JsonDocument.Parse("""{"items":[3,1,2]}""");

var results = Jq.Evaluate(".items | sort | .[]", doc.RootElement);

Console.WriteLine(results.Count);                                   // 3
Console.WriteLine(string.Join(",", results.Select(r => r.GetRawText()))); // 1,2,3
```

The list is complete when it is returned: the whole program has run. A third, optional argument
passes [variables](variables.md).

## Parse once, evaluate many times

Parsing is the expensive step. When a program runs on many inputs, parse it once with
`Jq.Parse` and keep the `JqExpression`:

```csharp
using System.Text.Json;
using JQLite;

JqExpression activeNames = Jq.Parse(".users[] | select(.active) | .name");

string[] payloads =
[
    """{"users":[{"name":"Alice","active":true},{"name":"Bob","active":false}]}""",
    """{"users":[{"name":"Carol","active":true}]}""",
];

foreach (var json in payloads)
{
    using var doc = JsonDocument.Parse(json);
    foreach (var name in activeNames.Evaluate(doc.RootElement))
        Console.WriteLine(name);
}
// Alice
// Carol
```

`Jq.Parse` checks everything that does not depend on the input, before any evaluation:

- the syntax, including the nesting limit (`Program too deeply nested`);
- that every function and label is defined (`shout/0 is not defined`);
- the modules of `import` and `include`, which are found and read through the resolver of the
  [options](options.md) (see [Modules](modules.md)).

A failure is a [JqParseException](xref:JQLite.JqParseException) with a line and a column (see
[Errors](errors.md)). A `$name` that the program does not bind is not checked: it is a host
variable, looked up when evaluated (see [Variables](variables.md)).

`Jq.Parse` has three overloads: `Parse(expression)` with the default options,
`Parse(expression, options)` with a [JqOptions](xref:JQLite.JqOptions), and
`Parse(expression, resolver)`, the same as `new JqOptions { Resolver = resolver }`. None of the
arguments may be `null`. The options are read when the expression is parsed and apply to every
evaluation of it.

## Streaming results

The overload of `JqExpression.Evaluate` that takes a callback gives each result as soon as it is
produced. The callback returns `true` to go on and `false` to stop; stopping is not an error:

```csharp
using System.Text.Json;
using JQLite;

using var doc = JsonDocument.Parse("""{"limit": 1000000}""");
var multiples = new List<int>();

Jq.Parse("range(.limit) | select(. % 7 == 0)").Evaluate(doc.RootElement, result =>
{
    multiples.Add(result.GetInt32());
    return multiples.Count < 3; // false stops the evaluation
});

Console.WriteLine(string.Join(", ", multiples)); // 0, 7, 14
```

Only the work needed for the first three results is done: `range` is lazy. Use the callback when
a program can produce many or endless results, when you need only the first few, or when you want
to handle results while the rest are computed.

The two overloads differ when an error ends the evaluation:

| Overload | Results produced before the error |
| --- | --- |
| `Evaluate(input, variables)`, returns a list | lost: the exception is thrown and no list is returned |
| `Evaluate(input, onResult, variables)` | already given to the callback |

An exception thrown by the callback is not caught: it ends the evaluation and reaches the caller
of `Evaluate`.

## One input per evaluation

An evaluation has exactly one input value. jqlite has no `input` or `inputs` builtins (spec
[§13](../language/spec.md#13-differences-from-jq-18)); a program that uses them fails to parse with
`input/0 is not defined`. To process several values, evaluate the expression on each one, or use
the [JSON Lines](jsonl.md) helpers, which do that for you.

`halt` ends the evaluation normally: the results produced before it are kept, and no exception is
thrown. `halt_error` throws (see [Errors](errors.md)).

## The empty program

An empty program, or one with only whitespace and comments, is the identity `.`:

```csharp
using System.Text.Json;
using JQLite;

using var doc = JsonDocument.Parse("[1,2]");
Console.WriteLine(Jq.Evaluate("", doc.RootElement)[0].GetRawText()); // [1,2]
```

## Threads

A `JqExpression` is immutable. You can evaluate the same instance from many threads at once, each
evaluation with its own input and variables; one evaluation owns all its state.

```csharp
using System.Text.Json;
using JQLite;

var scale = Jq.Parse("[.[] | . * $k] | add");
using var doc = JsonDocument.Parse("[1,2,3]");
var input = doc.RootElement;
var totals = new string[8];

Parallel.For(0, totals.Length, i =>
{
    using var k = JsonDocument.Parse(i.ToString());
    var variables = new Dictionary<string, JsonElement> { ["k"] = k.RootElement };
    totals[i] = scale.Evaluate(input, variables)[0].GetRawText();
});

Console.WriteLine(string.Join(" ", totals)); // 0 6 12 18 24 30 36 42
```

An evaluation runs on the calling thread, from start to end; there is no asynchronous evaluation.
What you share between evaluations must be safe to share: the input element, the
[resolver](modules.md), which `modulemeta` may call from several evaluations at once, and the
[Debug and Stderr handlers](options.md#debug-and-stderr), which run on the thread of each
evaluation.

Deep recursion never overflows the .NET stack, whatever the size of the thread's stack: the
recursion limit is [`MaxDepth`](options.md#the-depth-limit).
