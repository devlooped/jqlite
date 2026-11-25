---
title: "A tour"
---

# A tour

A jqlite program is a *filter*: it takes one input value and produces zero or more outputs. This page builds programs up from the smallest ones, all on the same input. It is the same in every implementation; how you pass the input and read the outputs is in the section of your [language](readme.md#implementations).

Every example below runs on this document:

```json
{
  "store": "Lakeside",
  "open": true,
  "orders": [
    { "id": 1, "customer": "Ada", "items": [ { "sku": "tea", "qty": 2, "price": 4.5 }, { "sku": "cup", "qty": 1, "price": 12 } ] },
    { "id": 2, "customer": "Lin", "items": [ { "sku": "tea", "qty": 1, "price": 4.5 } ] },
    { "id": 3, "customer": "Ada", "items": [] }
  ]
}
```

In the tables, several outputs are separated by a comma.

## Paths

`.` is the input itself. `.name` takes a field, `.[n]` an element, and `.[]` every element, one output each.

| Program | Outputs |
| --- | --- |
| `.store` | `"Lakeside"` |
| `.orders[0].customer` | `"Ada"` |
| `.orders[1].items[0]` | `{"sku":"tea","qty":1,"price":4.5}` |
| `.orders[].id` | `1`, `2`, `3` |
| `.missing.deeper` | `null` |

A field that is not there is `null`, not an error. Indexing a value of the wrong type is an error; `?` after a path drops it.

## Pipes and commas

`a | b` runs `b` on each output of `a`. `a, b` gives the outputs of `a`, then those of `b`.

| Program | Outputs |
| --- | --- |
| `.orders[] \| .customer` | `"Ada"`, `"Lin"`, `"Ada"` |
| `.store, .open` | `"Lakeside"`, `true` |
| `.orders \| length` | `3` |

## Building values

`[...]` collects every output of the filter inside it into one array. `{...}` builds an object, and `{id}` is short for `{id: .id}`. A string can hold filters between `\(` and `)`.

| Program | Outputs |
| --- | --- |
| `[.orders[].customer]` | `["Ada","Lin","Ada"]` |
| `[.orders[].customer] \| unique` | `["Ada","Lin"]` |
| `.orders[] \| {id, lines: (.items \| length)}` | `{"id":1,"lines":2}`, `{"id":2,"lines":1}`, `{"id":3,"lines":0}` |
| `.orders[] \| "\(.customer) ordered \(.items \| length) line(s)"` | `"Ada ordered 2 line(s)"`, `"Lin ordered 1 line(s)"`, `"Ada ordered 0 line(s)"` |

## Selecting and transforming

`select(f)` keeps its input when `f` is true and gives nothing otherwise. `map(f)` applies `f` to each element of an array.

| Program | Outputs |
| --- | --- |
| `.orders[] \| select(.items \| length > 0) \| .id` | `1`, `2` |
| `.orders \| map(.customer)` | `["Ada","Lin","Ada"]` |
| `[.orders[].items[] \| .qty * .price] \| add` | `25.5` |
| `.orders \| group_by(.customer) \| map({customer: .[0].customer, orders: length})` | `[{"customer":"Ada","orders":2},{"customer":"Lin","orders":1}]` |
| `first(.orders[] \| select(.customer == "Lin")) \| .id` | `2` |

Filters are lazy: `first` stops the search at the first match, and `[limit(3; range(1; infinite))]` is `[1,2,3]`.

## Defaults

`add` of an empty array is `null`. `a // b` gives `b` when `a` gives nothing but `null` or `false`.

| Program | Outputs |
| --- | --- |
| `.orders[] \| {id, total: (.items \| map(.qty * .price) \| add)}` | `{"id":1,"total":21}`, `{"id":2,"total":4.5}`, `{"id":3,"total":null}` |
| `.orders[] \| {id, total: ((.items \| map(.qty * .price) \| add) // 0)}` | `{"id":1,"total":21}`, `{"id":2,"total":4.5}`, `{"id":3,"total":0}` |

## Variables, functions and folds

`f as $x | g` runs `g` once for each output of `f`, with `$x` bound to it. `def` names a filter. `reduce` folds a stream into one value.

| Program | Outputs |
| --- | --- |
| `.orders[] \| .id as $id \| .items[] \| [$id, .sku]` | `[1,"tea"]`, `[1,"cup"]`, `[2,"tea"]` |
| `def total: map(.qty * .price) \| add // 0; .orders[] \| {id, total: (.items \| total)}` | `{"id":1,"total":21}`, `{"id":2,"total":4.5}`, `{"id":3,"total":0}` |
| `reduce .orders[].items[] as $i (0; . + $i.qty)` | `4` |

A `$name` that the program does not bind is a variable of the host: with `who` given as `"Ada"`, `.orders[] | select(.customer == $who) | .id` gives `1`, `3`.

## Updates

A path on the left of an assignment operator says where; the result is the whole input with that place changed. Nothing is modified: values are immutable.

| Program | Outputs |
| --- | --- |
| `.orders[0].items[0].price \|= . * 2 \| .orders[0].items[0]` | `{"sku":"tea","qty":2,"price":9}` |
| `del(.orders[2]) \| .orders \| length` | `2` |
| `[paths(type == "number")] \| length` | `9` |

## Errors

An error stops the program unless a `try` catches it. `try f catch g` runs `g` on the error value; `f?` is `try f` without a `catch`.

| Program | Outputs |
| --- | --- |
| `try error("no stock") catch .` | `"no stock"` |
| `try (.store \| .[0]) catch .` | `"Cannot index string with number (0)"` |
| `[.store, .orders \| .[0]? \| .id]` | `[1]` |

In the last one, indexing the string is an error that `?` drops, so only the first order goes on. Without a `try`, an error ends the evaluation and the host receives it as an [error of its language](readme.md#what-an-implementation-gives-its-host).

## Text

`@csv`, `@tsv`, `@json`, `@base64`, `@uri`, `@html`, `@sh` and `@text` format their input as a string.

| Program | Outputs |
| --- | --- |
| `.orders[].items[] \| [.sku, .qty] \| @csv` | `"\"tea\",2"`, `"\"cup\",1"`, `"\"tea\",1"` |
| `.orders \| map(.id) \| @json` | `"[1,2,3]"` |

## Where to go next

- The [jq 1.8 manual](manual.md) describes every construct and builtin with examples.
- The [specification](spec.md) is exact about each of them: [§7](spec.md#7-constructs) for the constructs, [§9](spec.md#9-builtins) for the builtins, [§10](spec.md#10-errors) for the errors.
- The [differences from jq](readme.md#differences-from-jq) say where jqlite and jq part.
