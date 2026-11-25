---
title: "Variables"
---

# Variables

A program can read values that the host gives to each evaluation, as `$name`. This is how you pass
parameters to a parsed expression without building the program text.

## Passing variables

```java
import com.devlooped.jqlite.Jq;
import com.devlooped.jqlite.JqException;
import com.devlooped.jqlite.JqExpression;
import com.devlooped.jqlite.JqJson;
import com.devlooped.jqlite.values.JqValue;
import java.util.List;
import java.util.Map;

public class Expensive {
    public static void main(String[] args) {
        JqExpression expensive = Jq.parse("[.[] | select(.price >= $min) | .name]");
        JqValue products = JqJson.parse("""
            [{"name": "pen", "price": 2}, {"name": "lamp", "price": 40}, {"name": "desk", "price": 250}]
            """);

        for (double min : new double[] {10, 100}) {
            List<JqValue> results = expensive.evaluate(products, Map.of("min", JqValue.fromNumber(min)));
            System.out.println(JqJson.toJson(results.get(0)));
        }

        try {
            expensive.evaluate(products);
        } catch (JqException e) {
            System.out.println(e.getMessage());
        }
    }
}
```

```text
["lamp","desk"]
["desk"]
$min is not defined
```

Variables are a `Map<String, JqValue>`, given to:

- `JqExpression.evaluate(JqValue input, Map<String, JqValue> variables)`;
- `JqExpression.evaluate(JqValue input, Map<String, JqValue> variables, Predicate<JqValue> onResult)`;
- `Jq.evaluate(String expression, JqValue input, Map<String, JqValue> variables)`;
- `Jq.evaluateLines(JqExpression, Reader, Map<String, JqValue>, Predicate<JqValue>)`.

The variables belong to one evaluation: the same `JqExpression` can run at the same time on
several threads with different variables. A `null` map is the same as an empty one. The values are
immutable `JqValue`s, used as they are (see [Values](values.md)).

## Names

A name is a jq identifier without the `$`: an ASCII letter or `_`, then ASCII letters, digits or
`_` (`[A-Za-z_][A-Za-z0-9_]*`). The key `"root"` binds `$root`. The names are checked before the
evaluation starts, and a wrong one throws `IllegalArgumentException`:

| Key | Message |
| --- | --- |
| `"$min"` | `'$min' is not a valid variable name: give a jq identifier without '$'.` |
| `"first-name"` | `'first-name' is not a valid variable name: give a jq identifier without '$'.` |
| `"ENV"` | `$ENV cannot be a host variable: use JqOptions.withEnvironment.` |
| a `null` value | `The variable 'a' has no value: give JqValue.NULL for null.` |

`ENV` is rejected because `$ENV` is the environment, set with
[`JqOptions.withEnvironment`](options.md#environment).

## A variable the host did not give

A `$name` that has no binding in the program is looked up when it is evaluated, not when the
program is parsed. If the host did not give it, the evaluation raises the run-time error
`$name is not defined`. It reaches the host as a `JqException`, and a program can catch it:

```jq
try $min catch "no minimum"
```

On any input, without variables, this program outputs `"no minimum"`. A branch that never
evaluates `$min` needs no value for it. The same holds inside a [module](modules.md): an unbound
`$name` in a module is the same host variable as in the main program.

A qualified name, `$alias::name`, is not a host variable: it must be bound by a data import
(`import "config" as $alias;`), otherwise parsing fails with `$alias::name is not defined`.

## Shadowing

Bindings in the program win over host variables of the same name. With the host variable `x`
set to `1`:

```jq
$x, (2 as $x | $x), (def f($x): $x; f(3))
```

outputs `1`, `2` and `3`: the `as $x` binding and the `$x` parameter hide the host variable inside
their scope ([spec §7.5](../language/spec.md#75-variables-and-bindings)).

## $ENV and $__loc__

Two names are predefined and are never host variables:

- `$ENV` is an object of the environment variables, and `env` returns the same object. By default
  it is the process environment; [`JqOptions.withEnvironment`](options.md#environment) replaces it.
  A program can shadow it (`{} as $ENV | ...`).
- `$__loc__` is `{"file": F, "line": L}`: the line of the `$__loc__` and `"<top-level>"` in the main
  program, or the module's canonical path in a module. `$__loc__` on the first line of a program is
  `{"file":"<top-level>","line":1}`.
