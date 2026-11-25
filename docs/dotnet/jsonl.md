---
title: "JSON Lines"
---

# JSON Lines

A [JSON Lines](https://jsonlines.org) file holds one JSON value per line. To run a program on each
value, `Jq.EvaluateAsync` takes an `IAsyncEnumerable<JsonElement>` and returns the results of every
value, in order, as an `IAsyncEnumerable<JsonElement>`:

```csharp
public static IAsyncEnumerable<JsonElement> EvaluateAsync(string expression,
    IAsyncEnumerable<JsonElement> input,
    IReadOnlyDictionary<string, JsonElement>? variables = null,
    CancellationToken cancellationToken = default);

public static IAsyncEnumerable<JsonElement> EvaluateAsync(JqExpression expression,
    IAsyncEnumerable<JsonElement> input,
    IReadOnlyDictionary<string, JsonElement>? variables = null,
    CancellationToken cancellationToken = default);
```

There is no synchronous helper: for an `IEnumerable<JsonElement>`, call
`JqExpression.Evaluate` on each value (see [below](#without-the-helpers)).

## Reading a file

`JsonSerializer.DeserializeAsyncEnumerable<JsonElement>` with `topLevelValues: true` reads a
stream of whitespace-separated JSON values as they arrive. It needs System.Text.Json 9 or later:
on .NET 8, add the `System.Text.Json` package.

With this `users.jsonl`:

```json
{"id":1,"name":"Alice","dept":"Engineering"}
{"id":2,"name":"Bob","dept":"Marketing"}
{"id":3,"name":"Charlie","dept":"Engineering"}
```

```csharp
using System.Text.Json;
using JQLite;

using var stream = File.OpenRead("users.jsonl");
var users = JsonSerializer.DeserializeAsyncEnumerable<JsonElement>(stream, topLevelValues: true);

await foreach (var name in Jq.EvaluateAsync("""select(.dept == "Engineering") | .name""", users))
    Console.WriteLine(name);
// Alice
// Charlie
```

The file is not loaded whole: each value is evaluated when it has been read, and its results are
yielded before the next value is read.

`DeserializeAsyncEnumerable` uses the reflection-based serializer, which Native AOT and trimmed
applications may disable. The next example reads the lines itself and works everywhere.

## Reusing a parsed expression

The overload that takes a string parses it when the enumeration starts: a
[JqParseException](xref:JQLite.JqParseException) surfaces at the first step of the `await foreach`,
and the program is parsed again by each call. Parse it once with `Jq.Parse` to share it between
streams, or to give it [options](options.md):

```csharp
using System.Runtime.CompilerServices;
using System.Text.Json;
using JQLite;

JqExpression errors = Jq.Parse("""select(.level == "error") | "\(.time) \(.message)" """);

Directory.CreateDirectory("logs");
File.WriteAllText("logs/a.jsonl", """
    {"time":"10:00","level":"info","message":"started"}
    {"time":"10:05","level":"error","message":"disk full"}

    """);

foreach (var file in Directory.GetFiles("logs", "*.jsonl"))
{
    await foreach (var line in Jq.EvaluateAsync(errors, ReadJsonLines(file)))
        Console.WriteLine(line); // 10:05 disk full
}

// One JsonElement per non-blank line.
static async IAsyncEnumerable<JsonElement> ReadJsonLines(string path,
    [EnumeratorCancellation] CancellationToken cancellationToken = default)
{
    await foreach (var line in File.ReadLinesAsync(path, cancellationToken))
    {
        if (string.IsNullOrWhiteSpace(line))
            continue;
        using var doc = JsonDocument.Parse(line);
        yield return doc.RootElement.Clone();
    }
}
```

## Each value alone

Every value of the stream is a separate evaluation, as if you called `JqExpression.Evaluate` on
it: nothing of one evaluation reaches the next. jqlite has no `input` or `inputs` to read the next
value, and `halt` ends only the evaluation of its own value:

```csharp
using System.Runtime.CompilerServices;
using System.Text.Json;
using JQLite;

await foreach (var result in Jq.EvaluateAsync("if . == 2 then halt else . * 10 end", Values("1", "2", "3")))
    Console.WriteLine(result);
// 10
// 30

static async IAsyncEnumerable<JsonElement> Values(params string[] texts)
{
    foreach (var text in texts)
    {
        await Task.Yield();
        using var doc = JsonDocument.Parse(text);
        yield return doc.RootElement.Clone();
    }
}
```

To combine values, as `jq -s` (slurp) or `reduce inputs` do, collect them first into one array and
evaluate the program once on it.

## Errors and cancellation

- An error that no `try` caught, for any value, ends the enumeration with a `JqException`
  (or a `JqHaltException` for `halt_error`). The results of the earlier values have been yielded;
  those of the failing value are not, since the results of one value are computed before they are
  yielded. To skip bad values instead, catch the error in the program: `try (…) catch empty`.
- The `variables` apply to every value; invalid names throw `ArgumentException` when the first
  value is evaluated.
- The `cancellationToken` stops reading the input: it is passed to the source with
  `WithCancellation`, and cancelling it throws `OperationCanceledException` from the source. The
  evaluation of one value is not interrupted. `WithCancellation` on the returned sequence works too.

## Without the helpers

For values you already have in memory, or a synchronous source, evaluate each one:

```csharp
using System.Text.Json;
using JQLite;

var total = Jq.Parse(".qty * .price");

foreach (var line in new[] { """{"qty":2,"price":1.5}""", """{"qty":1,"price":4}""" })
{
    using var doc = JsonDocument.Parse(line);
    foreach (var result in total.Evaluate(doc.RootElement))
        Console.WriteLine(result); // 3, then 4
}
```
