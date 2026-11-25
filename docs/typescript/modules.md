---
title: "Modules"
---

# Modules

A program can load jq definitions and JSON data from modules:

```jq
include "utils";          # the definitions of utils, callable as they are
import "math" as m;       # the definitions of math, called as m::name
import "config" as $cfg;  # the JSON values of config, as an array in $cfg
```

jqlite has no search path of its own: the host finds modules through a resolver, the `resolver`
[option](options.md). Without one, no module exists and every directive is a parse error.

## The file resolver

`JqFileResolver`, from the `@devlooped/jqlite/node` entry, reads modules from the file system:

```typescript
import { mkdirSync, writeFileSync } from "node:fs";
import { Jq } from "@devlooped/jqlite";
import { JqFileResolver } from "@devlooped/jqlite/node";

mkdirSync("modules/lib", { recursive: true });
writeFileSync("modules/lib/text.jq", 'def shout: ascii_upcase + "!";');
writeFileSync("modules/config.json", '{"greeting": "hello"}');

const resolver = new JqFileResolver("modules");
const expression = Jq.parse('import "lib/text" as t; import "config" as $cfg; $cfg[0].greeting | t::shout', { resolver });
console.log(expression.evaluate(null));
```

```text
[ 'HELLO!' ]
```

- A path is relative to the directory of the module that imports it, or to `baseDirectory` (the
  constructor's argument, made absolute) for the program itself.
- A path without an extension gets `.jq` for a code module and `.json` for a data module. A path
  with an extension keeps it.
- The canonical path, the module's identity, is the full path of the file. A path that is not an
  existing file resolves to nothing.
- Files are read as UTF-8.

The `jqlite` entry has no resolver: it runs in a browser too. There is no resolver over embedded
resources, as the .NET reference has.

## Writing a resolver

A resolver implements `JqResolver`, two methods:

```typescript
import { Jq, type JqModuleKind, type JqResolver } from "@devlooped/jqlite";

const sources = new Map([
  ["mem:greet.jq", 'def greet: "hello " + .;'],
  ["mem:numbers.json", "1 2 3"],
]);

const memory: JqResolver = {
  getCanonicalPath(path: string, kind: JqModuleKind): string | null {
    const name = `mem:${path}${kind === "data" ? ".json" : ".jq"}`;
    return sources.has(name) ? name : null;
  },
  open(canonicalPath: string): string {
    return sources.get(canonicalPath)!;
  },
};

const expression = Jq.parse('include "greet"; import "numbers" as $n; greet, $n', { resolver: memory });
console.log(expression.evaluate("world"));
```

```text
[ 'hello world', [ 1, 2, 3 ] ]
```

`getCanonicalPath(path, kind, metadata, fromPath)` maps a directive to a module identity:

| Argument | Value |
| --- | --- |
| `path` | the path as the directive writes it |
| `kind` | `"code"` for `import … as name` and `include`, `"data"` for `import … as $name` |
| `metadata` | the directive's metadata object (`include "p" {"search": "./"};`), or `undefined` |
| `fromPath` | the canonical path of the importing module, or `null` for the program itself |

It returns the canonical path, or `null` (or an empty string) when there is no such module. The
same canonical path means the same module: while one expression is parsed, each module is read once
per canonical path, however many directives name it. `open(canonicalPath)` returns the module's
text.

## What a module sees

- A code module holds definitions, optionally after `module {...};` and its own directives. It sees
  the builtins, its own imports and its own definitions, nothing of the importer. It exports only
  the definitions at its top level.
- A data module is a sequence of JSON values separated by whitespace. `import "p" as $name;` binds
  them as an array to both `$name` and `$name::name`; an empty file binds `[]`.
- An unbound `$name` inside a module is the same [host variable](variables.md) as in the program.

## Failures

Resolution happens in `Jq.parse`, so its failures are `JqParseError`s. The position is that of the
directive: ` at line L, column C` in the program, ` at <identity>, line L, column C` in a module.

| Failure | Message |
| --- | --- |
| no resolver, or the resolver returns `null` | `module not found: <path> at line L, column C` |
| the resolver throws | the message of what it threw, then the position of the directive |
| a module imports itself, directly or not | `circular import of <identity>`, then the position of the directive |
| a syntax or binding error in a module | the error, then ` at <identity>, line L, column C`, the position in the module |
| a data module that is not JSON values | `error loading data file <identity>: ` and the reason |

## modulemeta

`modulemeta` takes a module path and outputs its metadata, its dependencies and its definitions. It
calls the resolver during the evaluation, so its failures are run-time errors that `try` catches:

```typescript
import { Jq, type JqResolver } from "@devlooped/jqlite";

const resolver: JqResolver = {
  getCanonicalPath: (path) => (path === "meta" ? path : null),
  open: () => 'module {"version": "1.0"}; def double: . * 2;',
};
const expression = Jq.parse('modulemeta, (try ("nosuch" | modulemeta) catch .)', { resolver });
console.log(JSON.stringify(expression.evaluate("meta")));
```

```text
[{"version":"1.0","deps":[],"defs":["double/0"]},"module not found: nosuch"]
```

The full rules of modules are in [spec §9.11](../language/spec.md#911-modules-optional-group).
