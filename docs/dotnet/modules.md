---
title: "Modules"
---

# Modules

A program can load jqlite definitions and JSON data from modules:

| Directive | Effect |
| --- | --- |
| `import "path" as name;` | the definitions of a code module, called as `name::f` |
| `include "path";` | the definitions of a code module, called as if written here |
| `import "path" as $name;` | a data module: its JSON values, bound as an array to `$name` and `$name::name` |
| `"path" \| modulemeta` | the metadata, imports and definitions of a code module |

jqlite has no module search path of its own: the host finds modules. In .NET, you give a
[JqResolver](xref:JQLite.JqResolver) in the `Resolver` of the [options](options.md). Without one,
no module exists. What modules mean is in spec
[§9.11](../language/spec.md#911-modules-optional-group).

## When modules are read

Modules are found and read while the expression is parsed, by `Jq.Parse`: each module once per
canonical path, however many directives name it. An evaluation reads nothing, except
`modulemeta`, which calls the resolver when it runs, possibly from several threads at once.

## Files

[JqFileResolver](xref:JQLite.JqFileResolver) reads modules from the file system. A path is
relative to the directory of the module that names it, or to the resolver's base directory for the
expression itself. A path with no extension gets `.jq` (code) or `.json` (data). The canonical
path of a module is its full file path.

With these two files in a `filters` directory:

```jq
# filters/common.jq
def cents: . * 100 | round / 100;
```

```json
{"usd": 1, "eur": 0.92}
```

the second saved as `filters/rates.json`, this program uses both:

```csharp
using System.Text.Json;
using JQLite;

var options = new JqOptions { Resolver = new JqFileResolver("filters") };

var toEuros = Jq.Parse(
    """
    include "common"; import "rates" as $rates;
    .amount * $rates[0].eur | cents
    """,
    options);

using var doc = JsonDocument.Parse("""{"amount": 12.345}""");
Console.WriteLine(toEuros.Evaluate(doc.RootElement)[0]); // 11.36
```

A data module is a sequence of JSON values separated by whitespace, so `$rates` is an array:
`$rates[0]` is the object of the file. A file with no value binds `[]`.

The base directory is made absolute when the resolver is created, from the current directory at
that time. `Jq.Parse(expression, resolver)` is a shortcut for
`Jq.Parse(expression, new JqOptions { Resolver = resolver })`.

## Embedded resources

[JqResourceResolver](xref:JQLite.JqResourceResolver) reads the embedded resources of an assembly.
A resource name is the prefix, a dot, then the path with `/` and `\` turned into dots, then `.jq`
or `.json` unless the path already ends with it. A directive in a module is relative to that
module's name without its last segment.

```xml
<ItemGroup>
  <EmbeddedResource Include="Filters\**\*.jq" />
</ItemGroup>
```

With the default namespace `MyApp`, the files `Filters/utils.jq` and `Filters/sub/helper.jq`
become the resources `MyApp.Filters.utils.jq` and `MyApp.Filters.sub.helper.jq`:

```jq
# Filters/utils.jq
include "sub/helper"; def shout: twice | ascii_upcase;
```

```jq
# Filters/sub/helper.jq
def twice: . + " " + .;
```

```csharp
using System.Text.Json;
using JQLite;

var options = new JqOptions { Resolver = new JqResourceResolver(typeof(Program).Assembly, "MyApp.Filters") };

using var doc = JsonDocument.Parse("\"hey\"");
Console.WriteLine(Jq.Parse("""include "utils"; shout""", options).Evaluate(doc.RootElement)[0]); // HEY HEY
```

The prefix may be empty or `null`; it has no final dot.

## Your own resolver

Derive from `JqResolver` to keep modules anywhere else: a database, a dictionary, a remote store.
It has two methods:

- `GetCanonicalPath(path, kind, metadata, fromPath)` maps a path, as written in the directive, to
  the module's identity, its canonical path, or to `null` when there is no such module. `kind` is
  `JqModuleKind.Code` or `JqModuleKind.Data`; `metadata` is the metadata object written after the
  directive (`import "a" as a {"search": "./"};`), or `null`; `fromPath` is the canonical path of
  the importing module, or `null` for the expression itself. The same canonical path means the
  same module.
- `Open(canonicalPath)` returns a `TextReader` over the text of a module that `GetCanonicalPath`
  returned. The reader is disposed after the text is read.

```csharp
using System.Text.Json;
using JQLite;

var options = new JqOptions
{
    Resolver = new DictionaryResolver(new Dictionary<string, string>
    {
        ["greet.jq"] = """def greet: "hello " + .;""",
        ["names.json"] = "\"world\" \"moon\"",
    }),
};

using var doc = JsonDocument.Parse("null");
var program = """import "greet" as g; import "names" as $names; $names[] | g::greet""";
foreach (var result in Jq.Parse(program, options).Evaluate(doc.RootElement))
    Console.WriteLine(result); // hello world, then hello moon

class DictionaryResolver(IReadOnlyDictionary<string, string> modules) : JqResolver
{
    public override string? GetCanonicalPath(string path, JqModuleKind kind, JsonElement? metadata, string? fromPath)
    {
        var name = path + (kind == JqModuleKind.Code ? ".jq" : ".json");
        return modules.ContainsKey(name) ? name : null;
    }

    public override TextReader Open(string canonicalPath) => new StringReader(modules[canonicalPath]);
}
```

Since `modulemeta` may call it from several evaluations at once, a resolver must be safe to call
from several threads. Both built-in resolvers are.

## When resolution fails

| What happens | At parse time (`import`, `include`) | In `modulemeta` |
| --- | --- | --- |
| `GetCanonicalPath` returns `null` | `JqParseException`: `module not found: path` | the run-time error `module not found: path` |
| the resolver throws `JqException`, `IOException` or `UnauthorizedAccessException` | `JqParseException` with the exception's message | a run-time error with that message |
| the resolver throws any other exception | it propagates unchanged | it propagates unchanged |
| a syntax error in a module | `JqParseException` naming the module | a run-time error |
| a module imports itself, directly or not | `JqParseException`: `circular import of …` | no error: `modulemeta` reads only the module it names |

The messages of a `JqParseException` end with the position. For `include "nonexistent"; .` with a
resolver that does not know it, and for a module `a.jq` with a syntax error:

```text
module not found: nonexistent at line 1, column 1
Expected ')' but found ';' at a.jq, line 1, column 10
```

An error inside a module names its canonical path, and `Line` and `Column` are positions in that
module. See [Errors](errors.md).

The errors of `modulemeta` are ordinary run-time errors, so `try` catches them:

```jq
try ("nonexistent" | modulemeta) catch .
```

```text
"module not found: nonexistent"
```

A data module whose text is not a sequence of JSON values is a parse error naming the module.
