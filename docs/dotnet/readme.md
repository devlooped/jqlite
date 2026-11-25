---
title: "jqlite for .NET"
---

# jqlite for .NET

JQLite is the .NET reference implementation of jqlite, the portable profile of the
[jq](https://jqlang.org) language. It follows the same [spec](../language/spec.md) and passes the
same conformance corpus as the other implementations; the Go, Java, Python, Rust and TypeScript
engines are ported from it file by file (see the [porting guide](../project/porting.md)).

Programs read and produce `System.Text.Json` values: you give a `JsonElement` and get
`JsonElement`s back.

## Requirements

- .NET 8 or later: the package targets `net8.0`.
- No package dependencies besides the framework.
- The library is marked trimmable and Native AOT compatible: it uses no reflection and no
  JSON serializer.

## Get the package

The package is `JQLite`, released to nuget.org:

```shell-session
dotnet add package JQLite
```

> [!NOTE]
> Versions 1.x were published as `Devlooped.JQSharp` ([Upgrading from 1.x](upgrading.md)). Until the
> first release named `JQLite` is on nuget.org, take a build from the CI feed below.

Builds of every branch and pull request are published to the CI feed
`https://pkg.kzu.app/index.json`, with versions such as `42.42.42-main.123`. To build from source
instead, clone [devlooped/jqlite](https://github.com/devlooped/jqlite) and reference the project:

```shell-session
dotnet add reference path/to/jqlite/dotnet/JQLite/JQLite.csproj
```

The package is distributed under the
[OSMF EULA](https://github.com/devlooped/jqlite/blob/main/osmfeula.txt).

## A first program

```csharp
using System.Text.Json;
using JQLite;

using var doc = JsonDocument.Parse(
    """
    {
      "users": [
        { "name": "Alice", "age": 30 },
        { "name": "Bob", "age": 17 },
        { "name": "Carol", "age": 42 }
      ]
    }
    """);

IReadOnlyList<JsonElement> results = Jq.Evaluate(
    ".users[] | select(.age >= 18) | {name, adult: true}",
    doc.RootElement);

foreach (var result in results)
    Console.WriteLine(result.GetRawText());
```

```text
{"name":"Alice","adult":true}
{"name":"Carol","adult":true}
```

[Jq](xref:JQLite.Jq) is the entry point: `Jq.Evaluate` parses the program, runs it on one input
value and returns every result. A program can produce zero, one or many results; here `.users[]`
produces one value per user and `select` drops the minors.

`GetRawText()` gives the JSON text of a result. `ToString()`, which `Console.WriteLine(result)`
uses, gives the same text for numbers, arrays and objects, but a string without its quotes.

## In this section

| Page | What it covers |
| --- | --- |
| [Evaluating](evaluate.md) | One-shot evaluation, parsing once, streaming results, threads |
| [Values](values.md) | How JSON values go in and come out: numbers, strings, key order |
| [Variables](variables.md) | Passing `$name` variables from your code |
| [Options](options.md) | Environment, clock and time zone, depth limit, `debug` and `stderr` |
| [Modules](modules.md) | `import`, `include`, data modules and resolvers |
| [Errors](errors.md) | The exceptions, and catching errors inside a program |
| [JSON Lines](jsonl.md) | Running a program on each value of a stream |
| [Upgrading from 1.x](upgrading.md) | What changed since JQSharp 1.x |

The API reference is generated from the XML documentation: see [the API](/dotnet/api/). For the
language itself, start with [the jqlite language](../language/readme.md).
