---
title: "Modules"
---

# Modules

A program can use definitions and data from other files with `import` and `include`, and read a
module's description with `modulemeta`. jqlite does not read files by itself: the host supplies
modules through a resolver, set with `JqOptions.withResolver` or passed to
`Jq.parse(String, JqResolver)`. Without a resolver no module exists.

## An example

Take a directory `modules` with four files. `modules/utils.jq`:

```jq
def inc: . + 1;
```

`modules/lib/tax.jq`:

```jq
module {"version": "1.0"};
include "math";
def gross: . * (1 + rate);
```

`modules/lib/math.jq`:

```jq
def rate: 0.21;
```

`modules/config.json`:

```json
{"rate": 0.21}
```

This program uses the three kinds of directive:

```java
JqFileResolver resolver = new JqFileResolver(Path.of("modules"));
JqExpression expression = Jq.parse("""
    include "utils";
    import "lib/tax" as tax;
    import "config" as $config;
    [inc, tax::gross, $config[0].rate, $config::config]
    """, resolver);

System.out.println(JqJson.toJson(expression.evaluate(JqValue.fromNumber(100)).get(0)));
```

```text
[101,121,0.21,[{"rate":0.21}]]
```

- `include "utils";` makes the definitions of `utils.jq` callable without a prefix.
- `import "lib/tax" as tax;` makes them callable as `tax::gross`. `lib/tax.jq` includes `math`,
  which is found next to it, in `lib/`. A module exports only the definitions written at its own
  top level, not those it includes.
- `import "config" as $config;` reads a data module: a sequence of JSON values, bound as an array to
  both `$config` and `$config::config`. A data file with no value binds `[]`.

The modules are read and bound by `Jq.parse`, once per canonical path however many directives
name it. Evaluations do not read them again. The rules are those of
[spec §9.11](../language/spec.md#911-modules-optional-group).

## modulemeta

`modulemeta` takes a module path as input and outputs the module's metadata, its dependencies and
its definitions. It calls the resolver when it is evaluated, possibly from several threads at once.

```java
JqExpression meta = Jq.parse("modulemeta", JqOptions.defaults().withResolver(resolver));
meta.evaluate(JqValue.fromString("lib/tax"));
// {"version":"1.0","deps":[{"is_data":false,"relpath":"math"}],"defs":["gross/0"]}
```

## Built-in resolvers

`JqFileResolver(Path baseDirectory)` reads files:

- a path in the main program is relative to `baseDirectory`; a path in a module is relative to the
  directory of that module;
- a path whose file name has no extension gets `.jq` for code and `.json` for data; a path with an
  extension (`include "ext.jq";`) is kept as written;
- the canonical path is the full, normalized file path; files are read as UTF-8.

`JqResourceResolver(ClassLoader loader, String prefix)` reads resources of a class loader, for
modules packaged in your jar:

```java
JqResourceResolver resolver = new JqResourceResolver(MyApp.class.getClassLoader(), "myapp/filters");
Jq.parse("include \"greet\"; greet", resolver).evaluate(JqValue.fromString("world"));
// with myapp/filters/greet.jq holding: def greet: "hello " + .;
// ["hello world"]
```

The resource name is the prefix, a slash and the path, plus `.jq` (code) or `.json` (data) unless
the path already ends with it. A directive in a module is relative to that module's directory:
`include "sub/helper"` in `myapp/filters/greet.jq` is `myapp/filters/sub/helper.jq`. The prefix
is slash-separated, without a final slash, and may be empty.

Both resolvers are safe to use from several threads.

## Writing a resolver

Extend the abstract class `JqResolver` and implement two methods:

| Method | Returns |
| --- | --- |
| `String getCanonicalPath(String path, JqModuleKind kind, JqValue metadata, String fromPath)` | the module's identity, or `null` when there is no such module |
| `Reader open(String canonicalPath)` | the text of the module with that identity |

`path` is the directive's path as written, `kind` is `JqModuleKind.CODE` or `JqModuleKind.DATA`,
`metadata` is the directive's metadata object (`include "b" {"search": "./"};`) or `null`, and
`fromPath` is the canonical path of the importing module, or `null` for the main program. Two
directives that get the same canonical path name the same module. This resolver keeps modules in
a map:

```java
import com.devlooped.jqlite.Jq;
import com.devlooped.jqlite.JqJson;
import com.devlooped.jqlite.JqModuleKind;
import com.devlooped.jqlite.JqResolver;
import com.devlooped.jqlite.values.JqValue;
import java.io.Reader;
import java.io.StringReader;
import java.util.Map;

public class MapModules {
    static final class MapResolver extends JqResolver {
        private final Map<String, String> modules;

        MapResolver(Map<String, String> modules) {
            this.modules = Map.copyOf(modules);
        }

        @Override
        public String getCanonicalPath(String path, JqModuleKind kind, JqValue metadata, String fromPath) {
            String name = "mem:" + path + (kind == JqModuleKind.CODE ? ".jq" : ".json");
            return modules.containsKey(name) ? name : null;
        }

        @Override
        public Reader open(String canonicalPath) {
            return new StringReader(modules.get(canonicalPath));
        }
    }

    public static void main(String[] args) {
        MapResolver resolver = new MapResolver(Map.of(
            "mem:greet.jq", "include \"punctuation\"; def greet: \"hello \" + . + mark;",
            "mem:punctuation.jq", "def mark: \"!\";",
            "mem:colors.json", "\"red\" \"green\""));

        Jq.parse("include \"greet\"; import \"colors\" as $colors; greet, $colors", resolver)
            .evaluate(JqValue.fromString("world"))
            .forEach(v -> System.out.println(JqJson.toJson(v)));
    }
}
```

```text
"hello world!"
["red","green"]
```

Both methods may throw `IOException`. Because `modulemeta` calls the resolver during evaluations,
a resolver must allow calls from several threads at once.

## When resolution fails

| Case | Result |
| --- | --- |
| `getCanonicalPath` returns `null` or `""` | `JqParseException`: `module not found: nosuch at line 1, column 1` |
| no resolver | the same `module not found` error |
| the resolver throws `IOException`, `UncheckedIOException`, `SecurityException` or `JqException` | `JqParseException` with the exception's message |
| a syntax error in a module | `JqParseException` naming the module: `Expected ')' but found ';' at /full/path/bad.jq, line 2, column 15` |
| a module that imports itself, directly or not | `JqParseException`: `circular import of <canonical path>` |
| a data module that is not a sequence of JSON values | `JqParseException` naming the module |

The `line()` and `column()` of the exception are those of the directive in the main program, or of
the error in the module that the message names. In `modulemeta` the same failures are run-time
errors that a program can catch: `try ("nosuch" | modulemeta) catch .` outputs
`"module not found: nosuch"`.
