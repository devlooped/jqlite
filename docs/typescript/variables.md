---
title: "Variables"
---

# Variables

A host variable is a value the host gives an evaluation under a name, which the program reads as
`$name`. It is how a program gets parameters without building them into its text.

## Passing variables

```typescript
import { Jq } from "jqlite";

const greet = Jq.parse('"\\($greeting), \\(.name)!"');

console.log(greet.evaluate({ name: "Ada" }, { greeting: "Hello" }));
console.log(greet.evaluate({ name: "Alan" }, new Map([["greeting", "Hi"]])));
```

```text
[ 'Hello, Ada!' ]
[ 'Hi, Alan!' ]
```

Variables are the last argument of `Jq.evaluate`, `JqExpression.evaluate`, `evaluateEach`,
`evaluateText` and `Jq.evaluateAsync`. Their type is `JqVariables`: a plain object or a `Map`, from
names to [values](values.md). They belong to one evaluation: the same parsed expression can run with
different variables each time. The values are converted once per evaluation.

## Names

A name is given without `$` and must be a jq identifier: a letter or `_`, then letters, digits or
`_` (`[A-Za-z_][A-Za-z0-9_]*`). `root` binds `$root`.

Two kinds of names are rejected with a `TypeError` before anything is evaluated:

| Name | Error message |
| --- | --- |
| not an identifier (`"$x"`, `"1x"`, `"a-b"`, `""`) | `'$x' is not a valid variable name: give a jq identifier without '$'.` |
| `ENV` | `$ENV cannot be a host variable: use the environment option.` |

`$ENV` comes from the [environment option](options.md#environment) instead.

## A variable the host does not give

A `$name` that the program does not bind is a host variable, looked up when it is evaluated. If the
host did not give it, that is the run-time error `$name is not defined`. The program parses; only
the evaluation that reaches the variable fails, and `try` catches the error:

```typescript
import { Jq, JqError } from "jqlite";

const expression = Jq.parse("$x + 1");
console.log(expression.evaluate(null, { x: 1 }));

try {
  expression.evaluate(null);
} catch (e) {
  if (e instanceof JqError) console.log(e.message);
}

console.log(Jq.evaluate("try $x catch .", null));
console.log(Jq.evaluate("$x // 0", null, { x: null }));
```

```text
[ 2 ]
$x is not defined
[ '$x is not defined' ]
[ 0 ]
```

The same holds inside a [module](modules.md): an unbound `$name` there is the same host variable as
in the main program. A qualified `$alias::name` is different: it must be bound by a data import, and
without one it is a parse error (`$a::b is not defined`).

## Shadowing

A binding in the program hides a host variable of the same name, as an inner binding hides an
outer one. Both `as $name` and a `$name` parameter do:

```typescript
import { Jq } from "jqlite";

console.log(Jq.evaluate("1 as $x | $x", null, { x: 99 }));
console.log(Jq.evaluate("def f($x): $x; f(5)", null, { x: 99 }));
console.log(Jq.evaluate("[$x, (2 as $x | $x), $x]", null, { x: 1 }));
```

```text
[ 1 ]
[ 5 ]
[ [ 1, 2, 1 ] ]
```

## Predefined names

| Name | Value |
| --- | --- |
| `$ENV` | an object of the environment variables, from the [environment option](options.md#environment); `env` gives the same object. A program may shadow it (`{} as $ENV`) |
| `$__loc__` | `{"file": F, "line": L}`: the line of the `$`, and `"<top-level>"` in the main program or the module's identity in a module. It is not a variable: it cannot be bound or passed |

```typescript
import { Jq } from "jqlite";

console.log(Jq.evaluate("1 |\n$__loc__", null));
console.log(Jq.parse("$ENV.HOME, env.HOME", { environment: { HOME: "/home/ada" } }).evaluate(null));
```

```text
[ { file: '<top-level>', line: 2 } ]
[ '/home/ada', '/home/ada' ]
```

The rules are in [spec §7.5](../language/spec.md#75-variables-and-bindings).
