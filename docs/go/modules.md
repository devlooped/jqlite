---
title: "Modules"
---

# Modules

A program can load jq definitions and JSON data from modules: `import "path" as name;`,
`include "path";` and the data import `import "path" as $name;`. jqlite does not search the file
system by itself: the host supplies modules through a `jqlite.Resolver`, given in
`Options.Resolver` or to `ParseWithResolver`. Without a resolver, no module exists and every import
fails with `module not found: <path>`.

## What the directives do

| Directive | Effect |
| --- | --- |
| `import "p" as name;` | the definitions of code module `p` are callable as `name::f` |
| `include "p";` | the definitions of `p` are callable unqualified, as if written there |
| `import "p" as $name;` | data module `p`, a sequence of JSON values, is bound as an array to `$name` and `$name::name` |
| `"p" \| modulemeta` | the metadata of module `p`, its imports (`deps`) and its definitions (`defs`) |

A code module is a file of jq definitions, optionally starting with `module {...};` metadata; it
exports only the definitions written at its top level ([the rules](../language/spec.md#911-modules-optional-group)).
Modules are read and bound once per canonical path when the program is parsed. Only `modulemeta`
calls the resolver while the program runs; a module the program already loaded is not read again.

## Resolving from an fs.FS

`FSResolver` reads modules from any `fs.FS`: an `embed.FS` for modules built into your binary, an
`os.DirFS`, or a `fstest.MapFS` as here:

```go
package main

import (
	"fmt"
	"log"
	"testing/fstest"

	"github.com/devlooped/jqlite/go"
)

func main() {
	files := fstest.MapFS{
		"lib/text.jq":         &fstest.MapFile{Data: []byte(`import "util/case" as c; def shout: c::upper + "!";`)},
		"lib/util/case.jq":    &fstest.MapFile{Data: []byte(`def upper: ascii_upcase;`)},
		"lib/currencies.json": &fstest.MapFile{Data: []byte(`{"code":"EUR"} {"code":"USD"}`)},
	}
	resolver := &jqlite.FSResolver{FS: files, Root: "lib"}

	program := `import "text" as t; import "currencies" as $cur;
(.name | t::shout), [$cur[].code], ("text" | modulemeta)`
	expression, err := jqlite.ParseWithResolver(program, resolver)
	if err != nil {
		log.Fatal(err)
	}
	input, _ := jqlite.ParseJSON(`{"name":"hello"}`)
	results, err := expression.Evaluate(input, nil)
	if err != nil {
		log.Fatal(err)
	}
	for _, r := range results {
		fmt.Println(jqlite.ToJSON(r))
	}
}
```

```text
"HELLO!"
["EUR","USD"]
{"deps":[{"as":"c","is_data":false,"relpath":"util/case"}],"defs":["shout/0"]}
```

## Resolving from files

`NewFileResolver(baseDirectory)` reads modules from the file system (`baseDirectory` made absolute).

```go
package main

import (
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/devlooped/jqlite/go"
)

func main() {
	directory, err := os.MkdirTemp("", "modules")
	if err != nil {
		log.Fatal(err)
	}
	defer os.RemoveAll(directory)
	os.WriteFile(filepath.Join(directory, "math.jq"), []byte("def double: . * 2;\n"), 0o644)

	resolver := jqlite.NewFileResolver(directory)
	expression, err := jqlite.ParseWithResolver(`include "math"; map(double)`, resolver)
	if err != nil {
		log.Fatal(err)
	}
	results, _ := expression.Evaluate(jqlite.NewArray(jqlite.Number(1), jqlite.Number(2)), nil)
	fmt.Println(jqlite.ToJSON(results[0]))

	_, err = jqlite.ParseWithResolver(`import "missing" as m; 1`, resolver)
	fmt.Println(err)
}
```

```text
[2,4]
module not found: missing at line 1, column 1
```

## How paths are resolved

Both built-in resolvers work the same way:

- A path is relative to the directory of the importing module. For the main program, it is relative
  to `BaseDirectory` (`FileResolver`) or `Root` (`FSResolver`).
- A path without an extension gets `.jq` for a code import and `.json` for a data import.
- The canonical path, the module's identity, is the absolute file path (`FileResolver`) or the path
  inside the `fs.FS` (`FSResolver`). It is what `$__loc__.file` and error messages show.
- A path that does not name an existing file is "not found". Neither resolver uses the metadata of
  the directive (such as `{"search": "..."}`).

## Writing your own resolver

A resolver has two methods. `CanonicalPath` maps a path, as written in the directive, to a canonical
path; it returns `""` with a `nil` error when there is no such module. `Open` reads the module at a
canonical path. The same canonical path means the same module.

```go
package main

import (
	"fmt"
	"io"
	"log"
	"strings"

	"github.com/devlooped/jqlite/go"
)

// mapResolver serves modules from memory; a canonical path is a key of the map.
type mapResolver map[string]string

func (m mapResolver) CanonicalPath(path string, kind jqlite.ModuleKind, metadata *jqlite.Value, fromPath string) (string, error) {
	name := path + ".jq"
	if kind == jqlite.ModuleData {
		name = path + ".json"
	}
	if _, ok := m[name]; !ok {
		return "", nil // no such module
	}
	return name, nil
}

func (m mapResolver) Open(canonicalPath string) (io.ReadCloser, error) {
	return io.NopCloser(strings.NewReader(m[canonicalPath])), nil
}

func main() {
	resolver := mapResolver{
		"greet.jq":    `def greet: "hello, " + .;`,
		"limits.json": `{"max": 3}`,
	}
	expression, err := jqlite.ParseWithResolver(`import "greet" as g; import "limits" as $l; g::greet, $l[0].max`, resolver)
	if err != nil {
		log.Fatal(err)
	}
	results, _ := expression.Evaluate(jqlite.String("world"), nil)
	for _, r := range results {
		fmt.Println(jqlite.ToJSON(r))
	}
}
```

```text
"hello, world"
3
```

`metadata` is the directive's metadata object, or `nil`; `fromPath` is the canonical path of the
importing module, or `""` for the main program. Because `modulemeta` calls the resolver during
evaluations, possibly from several goroutines at once, a resolver must be safe for concurrent use.

## When resolution fails

| Failure | Result |
| --- | --- |
| `CanonicalPath` returns `""` | `module not found: <path>` |
| `CanonicalPath` or `Open` returns an error, or reading fails | the error's text is the message |
| a syntax or binding error inside a module | the message names the module: `... at <canonical path>, line L, column C` |
| a module that imports itself, directly or not | `circular import of <canonical path>` |

When parsing, these are a `*jqlite.ParseError` (its `Module` field names the module of an error
inside one). In `modulemeta`, they are run-time errors: `try ("nosuch" | modulemeta) catch .`
outputs `"module not found: nosuch"`.
