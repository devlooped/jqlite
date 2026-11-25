---
title: "jqlite for TypeScript"
---

# jqlite for TypeScript

The TypeScript port of jqlite runs jq programs on JavaScript values. It is a file-by-file port of the
.NET reference engine: it follows the same [spec](../language/spec.md) and passes the same
conformance corpus. The engine and the main entry have no run-time dependency and run in a browser
as well as in Node; only the file resolver of `jqlite/node` needs Node.

## Requirements

- Node 20 or later (the package declares `"engines": { "node": ">=20" }`), or a browser for the main entry.
- An ESM project: the package is `"type": "module"` and has no CommonJS build.
- The package ships its own type declarations.

## Getting it

The package is `jqlite`, version `1.0.0`, with two entry points:

| Import | What |
| --- | --- |
| `jqlite` | `Jq`, `JqExpression`, the errors and the types; no Node API |
| `jqlite/node` | `JqFileResolver`, which reads modules from the file system |

The repository does not publish it to a registry. Build it from a clone of
[devlooped/jqlite](https://github.com/devlooped/jqlite), then install the folder in your project:

```shell-session
$ git clone https://github.com/devlooped/jqlite.git
$ cd jqlite/typescript
$ npm ci
$ npm run build
$ cd /path/to/your/project
$ npm install /path/to/jqlite/typescript
```

`npm run build` writes the compiled package to `typescript/dist/`. [Port notes](port.md) has the
test and benchmark commands.

## A first example

```typescript
import { Jq } from "jqlite";

const orders = {
  items: [
    { name: "pen", price: 3, count: 2 },
    { name: "ink", price: 1, count: 9 },
  ],
};

const results = Jq.evaluate(
  ".items[] | select(.price > $min) | {name, total: (.price * .count)}",
  orders,
  { min: 2 },
);

for (const result of results) console.log(JSON.stringify(result));
```

```text
{"name":"pen","total":6}
```

`Jq.evaluate` parses the program, runs it on one input value and returns every result as a plain
JavaScript value. `$min` is a host variable, given by name without `$`. To run the same program many
times, parse it once with `Jq.parse` (see [Evaluating](evaluate.md)).

## In this section

| Page | What |
| --- | --- |
| [Evaluating](evaluate.md) | one-shot evaluation, parse once and evaluate many times, streaming, concurrency |
| [Values](values.md) | how JavaScript values go in and come out: numbers, strings, key order |
| [Variables](variables.md) | host variables (`$name`), `$ENV`, `$__loc__` |
| [Options](options.md) | environment, clock and time zone, depth limit, `debug` and `stderr` |
| [Modules](modules.md) | `import`, `include`, data modules, resolvers |
| [Errors](errors.md) | parse errors, run-time errors, `halt` and `halt_error` |
| [JSON Lines](jsonl.md) | one evaluation per value of a stream |
| [API reference](api.md) | every exported symbol |
| [Port notes](port.md) | build, tests, layout, differences from the reference |

The language itself is described in [the language guide](../language/readme.md) and, exactly, in
[the spec](../language/spec.md).
