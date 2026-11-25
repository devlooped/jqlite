---
title: "Values"
---

# Values

Inputs, results and variables are all `jqlite.Value`. Go has no standard JSON value that keeps the
order of object keys, so the package exposes the engine's own value type. A `Value` is a small
struct, passed by value; its zero value is `null`.

## Getting values in

There are three ways to make an input:

| From | Function | Notes |
| --- | --- | --- |
| JSON text | `ParseJSON(text)` | exactly one JSON value; object keys keep their order |
| Go values | `FromAny(v)` | `map[string]any` keys are sorted: Go maps have no order |
| scratch | `Null`, `True`, `False`, `Bool`, `Number`, `String`, `NewArray`, `NewObject` | `NewObject` keeps the order of its members |

`ParseJSON` follows the [JSON reader of the spec](../language/spec.md#53-json-reader): it also
reads `NaN`, `Infinity` and their variants, and a repeated key keeps its first position and its last
value. Its errors carry jq's message, for example
`Unfinished JSON term at EOF at line 1, column 5 (while parsing '{"a":')`.

`FromAny` accepts `nil`, `bool`, every integer and floating-point type, `string`, `json.Number`, a
`Value`, any slice or array, any map with string keys, and pointers to these (a nil pointer is
`null`). Anything else, such as a struct, is an error: marshal it with `encoding/json` and use
`ParseJSON` instead.

```go
package main

import (
	"fmt"

	"github.com/devlooped/jqlite/go"
)

func main() {
	order := jqlite.NewObject(
		jqlite.Member{Key: "id", Value: jqlite.Number(42)},
		jqlite.Member{Key: "lines", Value: jqlite.NewArray(jqlite.String("pen"), jqlite.String("ink"))},
		jqlite.Member{Key: "paid", Value: jqlite.False},
	)
	fmt.Println(jqlite.ToJSON(order))

	expression := jqlite.MustParse(`.lines |= length`)
	results, _ := expression.Evaluate(order, nil)
	fmt.Println(jqlite.ToJSON(results[0]))
	fmt.Println(jqlite.ToJSON(order)) // the input is unchanged
}
```

```text
{"id":42,"lines":["pen","ink"],"paid":false}
{"id":42,"lines":2,"paid":false}
{"id":42,"lines":["pen","ink"],"paid":false}
```

## Reading results

`ToJSON` writes a value as compact JSON text ([the canonical writer](../language/spec.md#51-canonical-json-writer)).
`Value` also implements `fmt.Stringer` with the same text. `ToAny` converts a value to `nil`,
`bool`, `float64`, `string`, `[]any` and `map[string]any`; an object's key order is lost there.

To walk a result, switch on `Kind()` and use the accessor of that kind. An accessor called on the
wrong kind panics: check the kind first.

```go
package main

import (
	"fmt"
	"log"
	"math"

	"github.com/devlooped/jqlite/go"
)

func describe(v jqlite.Value) string {
	switch v.Kind() {
	case jqlite.KindNull:
		return "null"
	case jqlite.KindFalse, jqlite.KindTrue:
		return fmt.Sprintf("boolean %v", v.IsTruthy())
	case jqlite.KindNumber:
		n := v.AsNumber()
		if n == math.Trunc(n) && math.Abs(n) <= 1<<53 {
			return fmt.Sprintf("integer %d", int64(n))
		}
		return fmt.Sprintf("number %g", n)
	case jqlite.KindString:
		return fmt.Sprintf("string %q", v.AsString())
	case jqlite.KindArray:
		return fmt.Sprintf("array of %d", v.AsArray().Count())
	default:
		object := v.AsObject()
		keys := make([]string, object.Count())
		for i := range keys {
			keys[i] = object.KeyAt(i)
		}
		return fmt.Sprintf("object with keys %v", keys)
	}
}

func main() {
	input, err := jqlite.FromAny(map[string]any{"id": 7, "tags": []string{"a", "b"}, "price": 2.5})
	if err != nil {
		log.Fatal(err)
	}
	results, err := jqlite.Evaluate(`.id, .price, .tags, {z: 1, a: 2}, .missing, (.id > 5)`, input, nil)
	if err != nil {
		log.Fatal(err)
	}
	for _, r := range results {
		fmt.Println(describe(r))
	}
}
```

```text
integer 7
number 2.5
array of 2
object with keys [z a]
null
boolean true
```

An `*Array` has `Count()` and `At(i)`; an `*Object` has `Count()`, `KeyAt(i)`, `ValueAt(i)` in
insertion order, and `TryGetValue(key)`. The full list is in the [API reference](api.md#values).

## Kinds

| jq type | `Kind()` | Go side |
| --- | --- | --- |
| null | `KindNull` | `Null`, the zero `Value` |
| boolean | `KindFalse`, `KindTrue` | `Bool(b)`, `IsTruthy()` |
| number | `KindNumber` | `Number(f)`, `AsNumber() float64` |
| string | `KindString` | `String(s)`, `AsString() string` |
| array | `KindArray` | `NewArray(...)`, `AsArray() *Array` |
| object | `KindObject` | `NewObject(...)`, `AsObject() *Object` |

The kinds are declared in jq's sort order. `TypeName()` gives the name jq's `type` gives
(`"boolean"` for both booleans).

## Numbers

Every number is an IEEE 754 double (`float64`); there is no separate integer type. An integer comes
out as a `float64` with no fractional part: convert it yourself, as `describe` does above. Integers
beyond 2^53 lose precision on the way in: `9007199254740993` reads as `9007199254740992`.

`ToJSON` prints the shortest text that reads back as the same double: `100000000000000000`,
`1e+21`, `0.30000000000000004`, `1e-7`, `-0`. NaN is written `null` and the infinities
`1.7976931348623157e+308` and `-1.7976931348623157e+308`. Inside the engine, and through
`AsNumber` and `ToAny`, NaN and the infinities stay what they are.

## Strings

Strings are Go strings holding UTF-8; a jqlite string is a sequence of Unicode code points, so
`length`, indexes and `explode` count code points, not bytes. Wherever text enters the engine
(`String`, `ParseJSON`, `FromAny`, object keys, the program text), each ill-formed UTF-8 sequence
becomes U+FFFD, one per maximal subpart, and a lone surrogate escape such as `"\ud800"` becomes
U+FFFD as well ([spec §4.1](../language/spec.md#41-kinds)). Strings that come out are always
well-formed UTF-8.

## Objects and key order

Objects remember the order in which keys were added. `ToJSON`, `keys_unsorted`, `to_entries` and
iteration use that order; `keys` sorts. Setting an existing key keeps its position; a new key goes
last. `FromAny` sorts the keys of a Go map, because a map has no order, and `ToAny` loses the order
again. Use `ParseJSON`, `NewObject` and `ToJSON` when the order matters.

## Ownership and mutability

Values are immutable and safe to share between goroutines. A result never aliases memory you can
change: keep it as long as you need, after the evaluation and across goroutines. An evaluation
never changes its input. The methods of `*Array` and `*Object` that look like changes (`Append`,
`Set`, `Remove`, ...) return a new array or object and leave the receiver as it was. `ToArray`
returns a fresh slice.
