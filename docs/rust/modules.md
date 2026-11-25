---
title: "Modules"
---

# Modules

A program can use definitions and data from modules: `import "path" as name;` (definitions called as `name::f`), `include "path";` (definitions called unqualified), `import "path" as $name;` (a data module: its JSON values as an array) and `modulemeta` (a module's metadata, dependencies and definitions). The crate finds no module by itself: the host gives a resolver in [`JqOptions::resolver`](options.md). Without one, every `import` and `include` is a parse error, `module not found: <path>`.

## Files on disk

`JqFileResolver` reads modules from a directory:

```rust
use std::sync::Arc;

use jqlite::{JqError, JqFileResolver, JqOptions, JqValue};

fn main() -> Result<(), JqError> {
    // lib/math.jq:    def double: . * 2;
    // lib/units.json: {"km": 1000} {"mi": 1609.344}
    let dir = std::env::temp_dir().join("jqlite-modules-example");
    std::fs::create_dir_all(dir.join("lib")).expect("the folder is created");
    std::fs::write(dir.join("lib/math.jq"), "def double: . * 2;").expect("the file is written");
    std::fs::write(dir.join("lib/units.json"), r#"{"km": 1000} {"mi": 1609.344}"#).expect("the file is written");

    let options = JqOptions { resolver: Some(Arc::new(JqFileResolver::new(&dir))), ..JqOptions::default() };
    let program = r#"import "lib/math" as m; import "lib/units" as $units; [m::double, $units[1].mi]"#;
    println!("{}", jqlite::parse_with(program, &options)?.evaluate(JqValue::from(21))?[0]);

    let meta = jqlite::parse_with("modulemeta", &options)?;
    println!("{}", meta.evaluate(JqValue::from("lib/math"))?[0]);

    match jqlite::parse_with(r#"import "lib/nope" as n; 1"#, &options) {
        Err(error) => println!("{error}"),
        Ok(_) => unreachable!(),
    }
    std::fs::remove_dir_all(&dir).expect("the folder is removed");
    Ok(())
}
```

```text
[42,1609.344]
{"deps":[],"defs":["double/0"]}
module not found: lib/nope at line 1, column 1
```

How `JqFileResolver` resolves a path:

- A directive of the main program is relative to the base directory given to `JqFileResolver::new` (made absolute; `base_directory()` returns it). A directive inside a module is relative to that module's directory.
- A path without an extension gets `.jq` for a code module and `.json` for a data module; a path with an extension is taken as it is (`import "a.jq" as a;`).
- The canonical path, the module's identity, is the absolute file path. The file must exist, or the module is not found.
- The directive's metadata (`import "a" as a {search: "./"};`) is ignored: there is no search path.

A data module is a sequence of JSON values separated by whitespace, bound as an array to `$name` (and to `$name::name`); an empty file binds `[]`.

## Writing a resolver

Implement `JqResolver` to take modules from anywhere else: resources compiled into the binary, a database, the network. The crate has no resolver of embedded resources; `include_str!` and a map do it:

```rust
use std::collections::HashMap;
use std::sync::Arc;

use jqlite::{JqError, JqModuleKind, JqOptions, JqResolver, JqValue};

/// Modules compiled into the binary, by name.
struct Embedded {
    modules: HashMap<&'static str, &'static str>,
}

impl JqResolver for Embedded {
    fn canonical_path(&self, path: &str, kind: JqModuleKind, _metadata: Option<&JqValue>, _from_path: Option<&str>) -> Option<String> {
        let name = match kind {
            JqModuleKind::Code => format!("{path}.jq"),
            JqModuleKind::Data => format!("{path}.json"),
        };
        self.modules.contains_key(name.as_str()).then_some(name)
    }

    fn read(&self, canonical_path: &str) -> std::io::Result<String> {
        self.modules
            .get(canonical_path)
            .map(|text| (*text).to_owned())
            .ok_or_else(|| std::io::Error::new(std::io::ErrorKind::NotFound, canonical_path.to_owned()))
    }
}

fn main() -> Result<(), JqError> {
    let resolver = Embedded {
        modules: HashMap::from([
            ("greet.jq", r#"import "names" as $names; def hello: "hello, \($names[0][.])";"#),
            ("names.json", r#"{"en": "world", "es": "mundo"}"#),
        ]),
    };
    let options = JqOptions { resolver: Some(Arc::new(resolver)), ..JqOptions::default() };
    let expression = jqlite::parse_with(r#"include "greet"; hello"#, &options)?;
    for language in ["en", "es"] {
        println!("{}", expression.evaluate(JqValue::from(language))?[0]);
    }
    Ok(())
}
```

```text
"hello, world"
"hello, mundo"
```

In practice the map's texts would be `include_str!("jq/greet.jq")` and so on. The two methods:

- `canonical_path(path, kind, metadata, from_path)` maps a directive to the module's identity, or `None` when there is no such module. `path` is the text of the directive; `kind` is `JqModuleKind::Code` or `JqModuleKind::Data`; `metadata` is the directive's metadata object, if any; `from_path` is the canonical path of the importing module, or `None` for the main program and for `modulemeta`. Equal canonical paths are the same module.
- `read(canonical_path)` returns the module's text.

A module is read and bound once per canonical path while an expression is parsed, however many directives name it. `modulemeta` calls the resolver again during evaluations, possibly from several threads at once: a resolver is `Send + Sync`.

## Failed resolutions

Errors in directives are found when the program is parsed, as `JqError::Parse`. An error inside a module names the module, with a line and a column in that module.

| Cause | Message |
| --- | --- |
| no resolver, or `canonical_path` returns `None` | `module not found: <path> at line L, column C` |
| `read` returns an `Err` | the I/O error's text, then ` at line L, column C` |
| a module imports itself, directly or through others | `circular import of <canonical path>` |
| a syntax or binding error in a module | its message, ` at <canonical path>, line L, column C` |
| a data module that is not JSON | `error loading data file <canonical path>: <reason>` |

`modulemeta` raises the same errors as run-time errors, which `try` catches: `try ("nosuch" | modulemeta) catch .` is `"module not found: nosuch"`. Its input must be a string. The module rules in full are in [spec §9.11](../language/spec.md#911-modules-optional-group).
