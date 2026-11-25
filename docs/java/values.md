---
title: "Values"
---

# Values

Java has no standard ordered JSON value, so the host works with the engine's own values: the
sealed interface `JqValue` of the package `com.devlooped.jqlite.values`. Inputs, variables and
results are all `JqValue`, and they are immutable.

## Making values

Read JSON text with `JqJson.parse`, or build values directly:

```java
import com.devlooped.jqlite.Jq;
import com.devlooped.jqlite.JqJson;
import com.devlooped.jqlite.values.JqArray;
import com.devlooped.jqlite.values.JqObject;
import com.devlooped.jqlite.values.JqObjectBuilder;
import com.devlooped.jqlite.values.JqValue;

public class Values {
    public static void main(String[] args) {
        JqObjectBuilder user = new JqObjectBuilder();
        user.set("name", JqValue.fromString("Ada"));
        user.set("born", JqValue.fromNumber(1815));
        user.set("active", JqValue.TRUE);
        user.set("tags", JqArray.of(JqValue.fromString("math"), JqValue.fromString("poetry")));
        user.set("manager", JqValue.NULL);
        JqObject input = user.toObject();

        JqValue result = Jq.evaluate("{name, tags: (.tags | length)}", input).get(0);
        System.out.println(JqJson.toJson(result));
    }
}
```

```text
{"name":"Ada","tags":2}
```

| JSON | Java |
| --- | --- |
| `null` | `JqValue.NULL` |
| `false`, `true` | `JqValue.FALSE`, `JqValue.TRUE`, `JqValue.fromBool(boolean)` |
| number | `JqValue.fromNumber(double)` |
| string | `JqValue.fromString(String)` |
| array | `JqArray.of(JqValue...)`, `JqArray.EMPTY` |
| object | `new JqObjectBuilder()`, `set(key, value)`, then `toObject()`; `JqObject.EMPTY` |

A `JqObjectBuilder` must not be used after `toObject()`: its storage becomes the object's. Setting
a key that is already there replaces its value at its position; a new key goes last.

> [!WARNING]
> `JqObjectBuilder.set` takes its key as it is. A key with a lone surrogate is not replaced by
> U+FFFD, and a program cannot then look it up: give well-formed keys, or read the object from JSON
> text with `JqJson.parse`, which cleans them.

`JqJson.parse` reads exactly one JSON value with jqlite's reader ([spec §5.3](../language/spec.md#53-json-reader)):
object keys keep their order, a duplicate key replaces the earlier value at the earlier position,
and invalid text throws `JqException` (see [Errors](errors.md)).

## Reading results

Switch on `kind()`, then use the accessor of that kind:

```java
static String describe(JqValue value) {
    return switch (value.kind()) {
        case NULL -> "null";
        case FALSE, TRUE -> "boolean " + value.isTruthy();
        case NUMBER -> "number " + value.asNumber();
        case STRING -> "string " + value.asString();
        case ARRAY -> {
            JqArray array = value.asArray();
            yield "array of " + array.count();
        }
        case OBJECT -> {
            JqObject object = value.asObject();
            yield "object with keys " + String.join(", ", object.sortedKeys());
        }
    };
}
```

`JqKind` has seven members: `NULL`, `FALSE`, `TRUE`, `NUMBER`, `STRING`, `ARRAY`, `OBJECT`.
`typeName()` gives jq's name of the type (`"boolean"` for both `FALSE` and `TRUE`). An accessor of
the wrong kind (`asString()` on a number) throws `IllegalStateException`.

A string result is not always the same class: a long string built by `+` is a `JqString`, others are
a record nested in `JqValue`. Use `kind()` and `asString()`, never `instanceof`, to read strings.

`equals` on values is not jq's `==`. To compare results, compare their JSON text, or compute the
comparison in the program.

## Numbers

Numbers are IEEE-754 doubles, inside the engine and on the way out. `asNumber()` returns a
`double`; cast it when you need an integer (`(long) value.asNumber()`). Integers are exact up to
2^53; beyond it they round:

| Program | Input | `JqJson.toJson` of the result | `asNumber()` |
| --- | --- | --- | --- |
| `.id` | `{"id": 42}` | `42` | `42.0` |
| `.` | `9007199254740993` | `9007199254740992` | `9.007199254740992E15` |
| `.` | `100000000000000000000000000001` | `1e+29` | `1.0E29` |
| `.` | `1E400` | `1.7976931348623157e+308` | `Infinity` |
| `.id / 5` | `{"id": 42}` | `8.4` | `8.4` |
| `0 \| -.` | `null` | `-0` | `-0.0` |

The JSON text of a number is the shortest that reads back as the same double
([spec §5.2](../language/spec.md#52-number-formatter)): `42`, `1e-7`, `1e+29`.

NaN and the infinities exist inside the engine, and `JqValue.fromNumber` accepts them. JSON has no
text for them, so `JqJson.toJson` writes NaN as `null` and the infinities as
`1.7976931348623157e+308` and `-1.7976931348623157e+308`; `asNumber()` still returns NaN or the
infinity.

## Strings

Strings are sequences of Unicode code points. A lone surrogate in a Java string becomes U+FFFD on
the way in: `JqValue.fromString("a\uD800b")`, a JSON escape `"\ud800"` read by `JqJson.parse`, and
the environment of `$ENV` are all cleaned this way, so `explode` of `"a\uD800b"` is
`[97,65533,98]`. Strings that come out of an evaluation are always well formed. `length` and the
string builtins count code points, not UTF-16 units.

## Arrays and objects

| `JqArray` | `JqObject` |
| --- | --- |
| `count()` | `count()` |
| `get(index)` | `get(key)`: the value, or Java `null` when the key is absent |
| `toArray()`: a new `JqValue[]` | `keyAt(i)`, `valueAt(i)`: by position, in insertion order |
| | `containsKey(key)`, `indexOf(key)`, `sortedKeys()` |

Objects keep the insertion order of their keys: iteration, `keys_unsorted`, `to_entries` and the
JSON text use it, and `keys` sorts. On the input `{"b":1,"a":2,"b":3}`, `keys` is `["a","b"]`,
`keys_unsorted` is `["b","a"]` and `tojson` is `"{\"b\":3,\"a\":2}"`. The array returned by
`sortedKeys()` is shared: do not write it.

`JqArray` and `JqObject` also have methods that return a modified copy (`append`, `concat`,
`slice`, `setItem`; `set`, `remove`, `merge`): see the [API reference](api.md#values).

## Ownership and lifetime

Every value is immutable, and results share structure with the input and with each other: `.a`
returns the very object stored in the input, without a copy. That is safe because nothing can
change it. A result does not depend on the expression or on the evaluation that produced it: keep
it as long as you need, pass it to other threads, or use it as the input of another evaluation.
