---
title: "Values"
---

# Values

Inputs, variables and results are JavaScript's own JSON values: `null`, booleans, numbers, strings,
arrays and objects. The API converts them to jqlite values on the way in and back on the way out.
The types are `JsonInput` (what an evaluation takes) and `JsonValue` (what it returns).

## The kinds

| jqlite | Into jqlite | Out of jqlite |
| --- | --- | --- |
| null | `null` | `null` |
| boolean | `true`, `false` | `true`, `false` |
| number | any `number`, as is | a `number` (see [Numbers](#numbers)) |
| string | a `string`; a lone surrogate becomes U+FFFD | a `string` |
| array | an array; an `undefined` element is `null` | a new array |
| object | a plain object, or a `Map` with string keys; an `undefined` property is left out | a new plain object |

Anything else is a `TypeError` before the evaluation starts: a function, a symbol, a `bigint`,
`undefined` as the whole input, a `Map` with a key that is not a string. Any other object is read as
a plain object, through its own enumerable keys: a `Date` or a `Set` becomes `{}`.

```typescript
import { Jq } from "@devlooped/jqlite";

console.log(Jq.evaluate("[.[] | type]", [1, "s", null, true, [], {}]));
console.log(JSON.stringify(Jq.evaluate(".", { a: undefined, b: [1] })));
```

```text
[ [ 'number', 'string', 'null', 'boolean', 'array', 'object' ] ]
[{"b":[1]}]
```

The `JsonInput` type admits `undefined` only as a property value; an `undefined` array element is
accepted at run time, as `JSON.stringify` accepts it.

## Numbers

Every jqlite number is an IEEE-754 double, as a JavaScript `number` is. There is no separate integer
type: `1.0` and `1` are the same value, and an integer comes out as a `number` whose text has no
fraction. Integers are exact up to 2^53; beyond, they round as doubles do.

Inside a program, NaN, the infinities and `-0` exist. A result is what its canonical text would read
back as:

| Inside jqlite | Result |
| --- | --- |
| NaN | `null` |
| +Infinity, -Infinity | `1.7976931348623157e308`, `-1.7976931348623157e308` (±`Number.MAX_VALUE`) |
| `-0` | `-0` |

```typescript
import { Jq } from "@devlooped/jqlite";

console.log(Jq.evaluate("[nan, infinite, -infinite, 1.0, 3/2]", null));
console.log(Jq.evaluate("[., isnan]", NaN));
```

```text
[ [ null, 1.7976931348623157e+308, -1.7976931348623157e+308, 1, 1.5 ] ]
[ [ null, true ] ]
```

Inputs are taken as they are, NaN and infinities included. `evaluateText` writes numbers in the
canonical layout of [spec §5.2](../language/spec.md#52-number-formatter): `100000000000000000000`,
`1e+21`, `1e-7`.

## Strings

A jqlite string is a sequence of Unicode code points. `length` counts code points, not UTF-16 units:
`"😀é" | length` is `2`. A lone surrogate in a string or a key of the input, of a variable or of the
program becomes U+FFFD, so every result string is well-formed UTF-16.

```typescript
import { Jq } from "@devlooped/jqlite";

console.log(Jq.evaluate("explode", "a\ud800b"));
```

```text
[ [ 97, 65533, 98 ] ]
```

## Key order

A jqlite object keeps its keys in insertion order ([spec §4.1](../language/spec.md#41-kinds)). A
plain JavaScript object does too, except for keys that look like array indexes (`"0"`, `"42"`):
JavaScript always enumerates those first, in numeric order. So the order of such keys is lost at
the boundary, on the way in and on the way out. Every other key keeps its position.

For the exact order:

- give the input as a `Map`: its entries go in, in order;
- take the results with `evaluateText`, which takes JSON text and returns the text the engine writes.

```typescript
import { Jq } from "@devlooped/jqlite";

const input = new Map<string, number>([["b", 1], ["10", 2], ["a", 3]]);
console.log(Jq.evaluate("keys_unsorted", { b: 1, "10": 2, a: 3 }));
console.log(Jq.evaluate("keys_unsorted", input));
console.log(Jq.parse(". + {c: 4}").evaluateText('{"b":1,"10":2,"a":3}'));
```

```text
[ [ '10', 'b', 'a' ] ]
[ [ 'b', '10', 'a' ] ]
[ '{"b":1,"10":2,"a":3,"c":4}' ]
```

`evaluateText` throws a `JqError` when its input is not exactly one JSON value, for example
`Unexpected extra JSON values (while parsing '1 2')`.

A key named `__proto__` is an ordinary own property of a result, not its prototype.

## Ownership and lifetime

- The input and the variables are converted once, at the start of the evaluation. Changing them
  afterwards, even from a callback, does not affect the evaluation.
- Every result is a new value of its own: plain arrays and objects, not frozen, that the caller owns
  and may change. They share nothing with the input, with other results or with later evaluations.
- Values of any depth convert without recursion: an array nested 5,000 levels deep goes in and comes
  out without a stack overflow.
