---
title: "Values"
---

# Values

The host values of the .NET API are `System.Text.Json.JsonElement`s: the input, the
[variables](variables.md) and every result. On the way in, each element is converted once into a
jqlite value (spec [§4](../language/spec.md#4-values)); on the way out, each result is written in
its canonical JSON text and read back as a new `JsonElement`.

| JSON | Inside the program | Result |
| --- | --- | --- |
| `null`, `true`, `false` | the same | the same |
| number | an IEEE 754 double | the shortest text that reads back as that double |
| string | a sequence of code points | a JSON string; a lone surrogate is U+FFFD |
| array | an array | an array |
| object | an object, keys in their order | an object, keys in their order |

A `default(JsonElement)` (value kind `Undefined`) is read as `null`.

## Numbers

Every number is a double. Integers are exact up to 2^53; larger ones are rounded, and a number
beyond the range of a double becomes an infinity. A result is written in one canonical form
(spec [§5.2](../language/spec.md#52-number-formatter)): an integral value has no fraction or
exponent, whatever the input text was.

```csharp
using System.Text.Json;
using JQLite;

using var doc = JsonDocument.Parse("[1.0, 1.5e3, 0.10, 12345678901234567890, 1E400]");

foreach (var result in Jq.Evaluate(".[], 0.1 + 0.2, 6 / 2, 1e21, 1e-7, -0", doc.RootElement))
    Console.Write(result.GetRawText() + " ");
// 1 1500 0.1 12345678901234567000 1.7976931348623157e+308 0.30000000000000004 3 1e+21 1e-7 -0
```

Read a result with the `JsonElement` method that fits: `GetInt32()` and `GetInt64()` work on
integral results such as `6 / 2` (written `3`), `GetDouble()` on any number.

### NaN and infinities

NaN and the infinities exist inside a program, but JSON has no text for them. A result is written
the way jq writes them: NaN as `null`, infinities as the largest double.

```csharp
using System.Text.Json;
using JQLite;

using var doc = JsonDocument.Parse("null");

foreach (var result in Jq.Evaluate("[nan, infinite, -infinite], (nan | isnan)", doc.RootElement))
    Console.WriteLine(result.GetRawText());
// [null,1.7976931348623157e+308,-1.7976931348623157e+308]
// true
```

Inside the program NaN is still a number: test it with `isnan` before the value leaves the
program if the difference matters.

## Strings

A jqlite string is a sequence of Unicode code points: `length`, slices and `explode` count code
points, not UTF-16 chars. A lone surrogate escape in the JSON text (`"\ud800"`) cannot be a code
point: it becomes U+FFFD, in strings and in object keys alike.

```csharp
using System.Text.Json;
using JQLite;

using var doc = JsonDocument.Parse("""["a\ud800b", "𝄞"]""");

foreach (var result in Jq.Evaluate("(.[0] | explode), (.[1] | length)", doc.RootElement))
    Console.WriteLine(result.GetRawText());
// [97,65533,98]
// 1
```

`GetString()` on a result returns an ordinary .NET string, with U+FFFD where the input had a lone
surrogate.

## Arrays and objects

Objects keep their keys in insertion order: the order of the input text, then the order in which
the program adds keys. `keys` sorts; `keys_unsorted`, `to_entries` and iteration keep the order.
When the input text repeats a key, the last value wins, at the position of the first:

```csharp
using System.Text.Json;
using JQLite;

using var doc = JsonDocument.Parse("""{"b":1,"a":2,"b":3}""");

foreach (var result in Jq.Evaluate(". , keys, (. + {c: 4, a: 0})", doc.RootElement))
    Console.WriteLine(result.GetRawText());
// {"b":3,"a":2}
// ["a","b"]
// {"b":3,"a":0,"c":4}
```

Containers of any depth are converted with loops, not recursion. Results are compact JSON: no
whitespace.

## Lifetime and ownership of results

Each result is a `JsonElement` of its own, detached from the input and from the evaluation. It
stays valid after the input's `JsonDocument` is disposed, and there is nothing to dispose:

```csharp
using System.Text.Json;
using JQLite;

IReadOnlyList<JsonElement> results;
using (var doc = JsonDocument.Parse("""{"a": {"b": [1,2]} }"""))
    results = Jq.Evaluate(".a, .a.b[]", doc.RootElement);

foreach (var result in results)
    Console.WriteLine(result.GetRawText());
// {"b":[1,2]}
// 1
// 2
```

A `JsonElement` is read-only, so results cannot be changed in place; jqlite values are immutable
too. To change a result, run another program on it, or convert it to a `JsonNode`
(`JsonNode.Parse(result.GetRawText())`).

The input is read once, when the evaluation starts; the evaluation keeps no reference to it, so
you may dispose the input's document as soon as `Evaluate` returns.
