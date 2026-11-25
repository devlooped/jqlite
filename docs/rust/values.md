---
title: "Values"
---

# Values

Inputs, variables and results are all `JqValue`, the engine's own value type. There is no conversion layer to a JSON library: you build values from JSON text or from Rust values, and read results by matching on the enum.

```rust
pub enum JqValue {
    Null,
    False,
    True,
    Number(f64),
    String(JqString),   // Arc<String>
    Array(JqArray),
    Object(JqObject),
}
```

## Values on the way in

```rust
use jqlite::{JqError, JqValue};

fn main() -> Result<(), JqError> {
    // From JSON text.
    let parsed: JqValue = r#"{"id": 7, "tags": ["a", "b"]}"#.parse()?;

    // From Rust values.
    let built: JqValue = [
        ("id", JqValue::from(7)),
        ("tags", JqValue::from(vec![JqValue::from("a"), JqValue::from("b")])),
        ("owner", JqValue::from(None::<&str>)),
    ]
    .into_iter()
    .collect();

    println!("{parsed}");
    println!("{built}");
    println!("{}", jqlite::evaluate(".tags | length", built)?[0]);
    Ok(())
}
```

```text
{"id":7,"tags":["a","b"]}
{"id":7,"tags":["a","b"],"owner":null}
2
```

- `JqValue::parse(text)` (also `text.parse::<JqValue>()`) reads exactly one JSON value, as RFC 8259 with the rules of [spec §5.3](../language/spec.md#53-json-reader): the words `nan` and `infinity` are accepted, a key given twice keeps its first position and its last value, and nesting deeper than 10,000 levels is the error `Exceeds depth limit for parsing`. Any error is `JqError::Json`.
- `From` exists for `bool`, `f64`, `i32`, `&str`, `String`, `Vec<JqValue>`, `JqArray`, `JqObject`, and `Option<T>` (`None` is `null`). Other integer types go through `f64`: `JqValue::from(n as f64)`.
- Collecting `(key, value)` pairs gives an object in that order; a key given twice keeps its first position and its last value.

## Values on the way out

The results are a `Vec<JqValue>`. Match on the variants to read them:

```rust
fn describe(value: &JqValue) -> String {
    match value {
        JqValue::Null => "null".to_owned(),
        JqValue::False | JqValue::True => format!("boolean {}", value.is_truthy()),
        JqValue::Number(n) if n.fract() == 0.0 && n.abs() < 9007199254740992.0 => format!("integer {}", *n as i64),
        JqValue::Number(n) => format!("number {n}"),
        JqValue::String(text) => format!("string of {} code points", text.chars().count()),
        JqValue::Array(array) => format!("array of {}", array.count()),
        JqValue::Object(object) => {
            let keys: Vec<&str> = object.entries().iter().map(|(key, _)| key.as_str()).collect();
            format!("object with keys {keys:?}")
        }
    }
}
```

The accessors `as_number`, `as_string`, `as_array` and `as_object` return the payload directly, and **panic** when the value is of another kind: check `kind()` or match first. `type_name()` gives the name jq's `type` prints (`"boolean"` for both `True` and `False`).

`to_json()` and `Display` (and `Debug`) write the canonical compact JSON text of [spec §5.1](../language/spec.md#51-canonical-json-writer). `JqValue` does not implement `PartialEq`: compare the `to_json()` texts, or compare in the program with `==`.

## Numbers

Every number is an IEEE 754 double (`f64`); there are no separate integers.

| Program output | `to_json()` | `as_number()` |
| --- | --- | --- |
| `1.0` | `1` | `1.0` |
| `1e3` | `1000` | `1000.0` |
| `1e21` | `1e+21` | `1e21` |
| `0.1 + 0.2` | `0.30000000000000004` | `0.30000000000000004` |
| `-0` | `-0` | `-0.0` |
| `100000000000000000001` | `100000000000000000000` | `1e20` |
| `nan` | `null` | `NaN` |
| `infinite`, `-infinite` | `1.7976931348623157e+308`, `-1.7976931348623157e+308` | `inf`, `-inf` |

- An integral number prints without a fraction or exponent up to 21 digits ([spec §5.2](../language/spec.md#52-number-formatter)). Integers are exact up to 2^53; larger ones are rounded to the nearest double when read.
- NaN and the infinities exist inside the engine and in `JqValue::Number`; only their text changes: NaN is written as `null`, the infinities as the largest finite double.
- To get an `i64`, check that the number is finite, integral and in range, as `describe` does above.

## Strings

A string is a sequence of Unicode code points, held as `Arc<String>` (`JqString`). A Rust string is always well formed. A JSON text can still name a lone surrogate with an escape: it becomes U+FFFD when the text is read.

```rust
let input = JqValue::parse(r#""a\ud800b""#)?;
assert_eq!(input.as_string(), "a\u{FFFD}b");
assert_eq!(jqlite::evaluate("explode", input)?[0].to_json(), "[97,65533,98]");
```

Lengths, indexes and slices count code points, not bytes: `"aé😀" | length` is `3`.

## Arrays and objects

`JqArray` holds a `Vec<JqValue>`: `count()`, `get(index)`, `as_slice()`, `iter()`, and `&JqArray` is `IntoIterator`.

`JqObject` keeps its keys in insertion order. Iteration (`entries()`, `key_at`, `value_at`), `to_json()`, and the program's `.[]`, `keys_unsorted` and `to_entries` use that order; jq's `keys` sorts. `get(key)` looks a key up. A program's `+` keeps the keys of the left object in place and appends new ones: `{"z":1,"a":2} | . + {b: 0}` is `{"z":1,"a":2,"b":0}`.

## Ownership and lifetime

A result is an owned `JqValue`, independent of the input and of the expression: you may drop the input, the expression or the options and keep the results. Values are `Send` and `Sync`, and `clone()` is cheap: strings, arrays and objects are shared behind `Arc`, so a result often shares parts with the input.

No value a program can see ever changes. You can still change your own copy: `JqArray::make_mut`, `JqObject::insert` and the methods that take the container by value (`append`, `set_item`, `set`, `remove`, `merge`…) change it in place when it is the only owner, and copy it first when it is shared.

```rust
let input = JqValue::parse(r#"{"items": [1, 2]}"#)?;
let results = jqlite::evaluate(".items", input.clone())?;

let JqValue::Array(mut items) = results.into_iter().next().expect("one result") else {
    unreachable!("the result is an array");
};
items.make_mut().push(JqValue::from(3)); // copies: the elements are shared with `input`
assert_eq!(JqValue::from(items).to_json(), "[1,2,3]");
assert_eq!(input.to_json(), r#"{"items":[1,2]}"#);
```

Values nested very deeply (10,000 levels) are read, compared, written and dropped without recursion on the host stack. A value nested deeper than 10,001 levels is written by `to_json()` with `<skipped: too deep>` in place of its deepest parts.
