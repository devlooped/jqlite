<p align="center">
  <img src="assets/img/logo.svg" alt="jqlite" width="256">
</p>

<p align="center">
  <a href="https://www.nuget.org/packages/JQLite"><img src="https://img.shields.io/nuget/vpre/JQLite.svg?label=nuget&color=004880" alt="NuGet"></a>
  <a href="https://www.nuget.org/packages/JQLite"><img src="https://img.shields.io/nuget/dt/JQLite.svg?label=downloads&color=004880" alt="NuGet downloads"></a>
  <a href="https://www.npmjs.com/package/@devlooped/jqlite"><img src="https://img.shields.io/npm/v/@devlooped/jqlite.svg?label=npm&color=CB3837" alt="npm"></a>
  <a href="https://www.npmjs.com/package/@devlooped/jqlite"><img src="https://img.shields.io/npm/dt/@devlooped/jqlite.svg?label=downloads&color=CB3837" alt="npm downloads"></a>
</p>

<p align="center">
  <a href="https://pypi.org/project/devlooped-jqlite"><img src="https://img.shields.io/pypi/v/devlooped-jqlite.svg?label=pypi&color=FFD43B" alt="PyPI"></a>
  <a href="https://pypi.org/project/devlooped-jqlite"><img src="https://img.shields.io/pypi/dm/devlooped-jqlite.svg?label=downloads&color=FFD43B" alt="PyPI downloads"></a>
  <a href="https://crates.io/crates/jqlite"><img src="https://img.shields.io/crates/v/jqlite.svg?label=crates.io&color=DEA584" alt="crates.io"></a>
  <a href="https://crates.io/crates/jqlite"><img src="https://img.shields.io/crates/d/jqlite.svg?label=downloads&color=DEA584" alt="crates.io downloads"></a>
</p>

<p align="center">
  <a href="https://pkg.go.dev/github.com/devlooped/jqlite/go"><img src="https://img.shields.io/github/v/tag/devlooped/jqlite.svg?filter=go/*&label=go&color=00ADD8" alt="Go"></a>
  <a href="https://central.sonatype.com/artifact/com.devlooped/jqlite"><img src="https://img.shields.io/maven-central/v/com.devlooped/jqlite.svg?label=maven&color=B07219" alt="Maven Central"></a>
  <a href="https://github.com/devlooped/jqlite/blob/main/osmfeula.txt"><img src="https://img.shields.io/badge/EULA-OSMF-blue?labelColor=black&color=C9FF30" alt="EULA"></a>
  <a href="https://github.com/devlooped/jqlite/blob/main/license.txt"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License"></a>
</p>


jqlite is a portable profile of the [jq](https://jqlang.org) language: jq as a library, defined so 
that a program gives the same outputs in every language that runs it. It has one 
[specification](spec/jqlite.md), one [conformance corpus](spec/tests) and one engine, written in .NET 
and ported file by file to TypeScript, Python, Java, Go and Rust.

| Implementation | Package | Guide |
| --- | --- | --- |
| .NET (the reference) | [`JQLite`](https://www.nuget.org/packages/JQLite) on NuGet | [devlooped.com/jqlite/dotnet](https://www.devlooped.com/jqlite/dotnet/) |
| TypeScript | [`@devlooped/jqlite`](https://www.npmjs.com/package/@devlooped/jqlite) on npm | [devlooped.com/jqlite/typescript](https://www.devlooped.com/jqlite/typescript/) |
| Python | [`devlooped-jqlite`](https://pypi.org/project/devlooped-jqlite) on PyPI, imported as `jqlite` | [devlooped.com/jqlite/python](https://www.devlooped.com/jqlite/python/) |
| Java | [`com.devlooped:jqlite`](https://central.sonatype.com/artifact/com.devlooped/jqlite) on Maven Central | [devlooped.com/jqlite/java](https://www.devlooped.com/jqlite/java/) |
| Go | module [`github.com/devlooped/jqlite/go`](https://pkg.go.dev/github.com/devlooped/jqlite/go) | [devlooped.com/jqlite/go](https://www.devlooped.com/jqlite/go/) |
| Rust | crate [`jqlite`](https://crates.io/crates/jqlite) | [devlooped.com/jqlite/rust](https://www.devlooped.com/jqlite/rust/) |

## Open Source Maintenance Fee

To ensure the long-term sustainability of this project, use of jqlite requires an 
[Open Source Maintenance Fee](https://opensourcemaintenancefee.org). While the source 
code is freely available under the terms of the [OSMF EULA](./osmfeula.txt), all other 
aspects of the project—including opening or commenting on issues, participating in 
discussions, and downloading releases—require [adherence to the Maintenance Fee](./osmfeula.txt).

In short, if you use this project to generate revenue, the [Maintenance Fee is required](./osmfeula.txt).

To pay the Maintenance Fee, [become a Sponsor](https://github.com/sponsors/devlooped).

## The language

The profile has the jq 1.8 language: paths, pipes, generators, array and object construction, 
string interpolation, variables and destructuring (including `?//`), `def`, `reduce`, `foreach`, 
`label`/`break`, `try`/`catch` and `?`, path expressions and every assignment operator, and modules. 
Its [builtins](spec/jqlite.md#9-builtins) cover types and selection, objects, arrays and collections, 
paths, strings, formats, dates, math and regular expressions: every builtin of jq 1.8 is in, except 
the five that describe jq's command line or read its next input.

jq programs behave as in jq 1.8, except for the [differences](spec/jqlite.md#13-differences-from-jq-18) 
that make the result exact and equal in every language. Those you are most likely to notice:

- Numbers are doubles, written in one canonical form (`1.0` is `1`; `1e-7`, `1e+21`, `-0`).
- Regular expressions use one flavor, common to every implementation, instead of Oniguruma's: no 
  lookaround, backreferences or inline flags, and ASCII character classes.
- A `$name` that the program does not bind is a host variable, given by the caller of the evaluation.
- The call depth is limited by an option of the host, and there are no tail calls.
- An evaluation has one input: `input` and `inputs` are not in the profile.

On the website: [the language](https://www.devlooped.com/jqlite/language/), 
[a tour](https://www.devlooped.com/jqlite/language/tour/), 
[the specification](https://www.devlooped.com/jqlite/language/spec/) and 
[the jq 1.8 manual](https://www.devlooped.com/jqlite/language/manual/).

## Implementations

Every implementation follows the same specification and passes the same corpus, so a program gives 
the same outputs in each. Values go in and come out as the host's own JSON values where it has 
ordered ones, and as the engine's values where it does not. The examples below run the same program 
on the same input.

### .NET

[`JQLite`](https://www.nuget.org/packages/JQLite) is the reference implementation, which the other 
engines are ported from. It runs on .NET 8 or later, takes and returns `System.Text.Json` 
`JsonElement`s, and is trimmable and Native AOT compatible.

```shell
dotnet add package JQLite
```

```csharp
using System.Text.Json;
using JQLite;

using var people = JsonDocument.Parse(
    """[{"name":"Ada","active":true},{"name":"Lin","active":false}]""");

var results = Jq.Evaluate("[.[] | select(.active) | .name]", people.RootElement);

Console.WriteLine(results[0].GetRawText()); // ["Ada"]
```

The [package readme](dotnet/JQLite/readme.md) has more examples, the performance against the jq 
executable and the upgrade notes from `Devlooped.JQSharp` 1.x. Read the 
[.NET guide](https://www.devlooped.com/jqlite/dotnet/) and the 
[API reference](https://www.devlooped.com/jqlite/dotnet/api/).

### TypeScript

[`@devlooped/jqlite`](https://www.npmjs.com/package/@devlooped/jqlite) is an ESM package with no 
run-time dependency and its own type declarations, for Node 20 or later and for browsers.

```shell
npm install @devlooped/jqlite
```

```typescript
import { Jq } from "@devlooped/jqlite";

const people = [{ name: "Ada", active: true }, { name: "Lin", active: false }];

const results = Jq.evaluate("[.[] | select(.active) | .name]", people);

console.log(JSON.stringify(results[0])); // ["Ada"]
```

Read the [TypeScript guide](https://www.devlooped.com/jqlite/typescript/), and the 
[port notes](typescript/README.md) to build and test it.

### Python

[`devlooped-jqlite`](https://pypi.org/project/devlooped-jqlite), imported as `jqlite`, is for 
Python 3.11 or later and uses the standard library only. It takes and returns the values of 
`json.loads`.

```shell
pip install devlooped-jqlite
```

```python
import json
import jqlite

people = [{"name": "Ada", "active": True}, {"name": "Lin", "active": False}]

results = jqlite.evaluate("[.[] | select(.active) | .name]", people)

print(json.dumps(results[0]))  # ["Ada"]
```

Read the [Python guide](https://www.devlooped.com/jqlite/python/), and the 
[port notes](python/README.md) to build and test it.

### Java

[`com.devlooped:jqlite`](https://central.sonatype.com/artifact/com.devlooped/jqlite) is for Java 21 
or later, with no run-time dependency.

```java
import com.devlooped.jqlite.*;
import com.devlooped.jqlite.values.JqValue;
import java.util.List;

JqValue people = JqJson.parse(
    "[{\"name\":\"Ada\",\"active\":true},{\"name\":\"Lin\",\"active\":false}]");

List<JqValue> results = Jq.evaluate("[.[] | select(.active) | .name]", people);

System.out.println(JqJson.toJson(results.get(0))); // ["Ada"]
```

Read the [Java guide](https://www.devlooped.com/jqlite/java/), and the 
[port notes](java/README.md) to build and test it.

### Go

The module [`github.com/devlooped/jqlite/go`](https://pkg.go.dev/github.com/devlooped/jqlite/go), 
package `jqlite`, uses the standard library only.

```shell
go get github.com/devlooped/jqlite/go
```

```go
package main

import (
	"fmt"

	jqlite "github.com/devlooped/jqlite/go"
)

func main() {
	people, _ := jqlite.ParseJSON(`[{"name":"Ada","active":true},{"name":"Lin","active":false}]`)

	results, err := jqlite.Evaluate(`[.[] | select(.active) | .name]`, people, nil)
	if err != nil {
		panic(err)
	}

	fmt.Println(jqlite.ToJSON(results[0])) // ["Ada"]
}
```

Read the [Go guide](https://www.devlooped.com/jqlite/go/), and the 
[port notes](go/README.md) to build and test it.

### Rust

The crate [`jqlite`](https://crates.io/crates/jqlite) uses edition 2024 and has no `unsafe` code.

```shell
cargo add jqlite
```

```rust
use jqlite::{JqError, JqValue};

fn main() -> Result<(), JqError> {
    let people = JqValue::parse(
        r#"[{"name":"Ada","active":true},{"name":"Lin","active":false}]"#)?;

    let results = jqlite::evaluate("[.[] | select(.active) | .name]", people)?;

    println!("{}", results[0].to_json()); // ["Ada"]
    Ok(())
}
```

Read the [Rust guide](https://www.devlooped.com/jqlite/rust/), and the 
[port notes](rust/README.md) to build and test it.

## The project

The behaviour is written down once and tested once, and every implementation runs the same tests. 
A change goes through the parts in this order: the specification, a case in the corpus, the 
reference engine, then every port.

| Part | What it is |
| --- | --- |
| [`spec/jqlite.md`](spec/jqlite.md) | The language: grammar, values, semantics, builtins, errors, limits, the host interface and the differences from jq. It is normative. |
| [`spec/prelude.jq`](spec/prelude.jq) | The builtins written in jqlite itself, embedded unchanged by every implementation. |
| [`spec/tests`](spec/tests) | The conformance corpus: programs, inputs and the outputs of jq 1.8.2, except where the specification lists a difference. |
| [`dotnet`](dotnet) | The reference engine (`dotnet/JQLite/Core`), written without anything another language lacks, and the .NET package around it. |
| [`typescript`](typescript), [`python`](python), [`java`](java), [`go`](go), [`rust`](rust) | The ports, file by file, each with a host API in the idiom of its language. |
| [`bench`](bench) | The cross-language benchmark. |
| [`docs`](docs) | The website. |

On the website: [the project](https://www.devlooped.com/jqlite/project/), 
[the porting guide](https://www.devlooped.com/jqlite/project/porting/), 
[the conformance corpus](https://www.devlooped.com/jqlite/project/corpus/) and 
[the benchmarks](https://www.devlooped.com/jqlite/project/benchmarks/). 
[`AGENTS.md`](AGENTS.md) says where each kind of change goes and which rules the engine's code follows.

## Dogfooding

[![CI Version](https://img.shields.io/endpoint?url=https://shields.kzu.app/vpre/JQLite/main&label=nuget.ci&color=brightgreen)](https://pkg.kzu.app/index.json)
[![Build](https://github.com/devlooped/jqlite/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/devlooped/jqlite/actions/workflows/build.yml)

CI packages are produced from every branch and pull request so you can dogfood builds as 
quickly as they are produced.

The CI feed is `https://pkg.kzu.app/index.json`.

The versioning scheme for packages is:

- PR builds: *42.42.42-pr*`[NUMBER]`
- Branch builds: *42.42.42-*`[BRANCH]`.`[COMMITS]`

<!-- include https://github.com/devlooped/sponsors/raw/main/footer.md -->
# Sponsors 

<!-- sponsors.md -->
[![Clarius Org](https://avatars.githubusercontent.com/u/71888636?v=4&s=39 "Clarius Org")](https://github.com/clarius)
[![MFB Technologies, Inc.](https://avatars.githubusercontent.com/u/87181630?v=4&s=39 "MFB Technologies, Inc.")](https://github.com/MFB-Technologies-Inc)
[![SandRock](https://avatars.githubusercontent.com/u/321868?u=99e50a714276c43ae820632f1da88cb71632ec97&v=4&s=39 "SandRock")](https://github.com/sandrock)
[![DRIVE.NET, Inc.](https://avatars.githubusercontent.com/u/15047123?v=4&s=39 "DRIVE.NET, Inc.")](https://github.com/drivenet)
[![Keith Pickford](https://avatars.githubusercontent.com/u/16598898?u=64416b80caf7092a885f60bb31612270bffc9598&v=4&s=39 "Keith Pickford")](https://github.com/Keflon)
[![Thomas Bolon](https://avatars.githubusercontent.com/u/127185?u=7f50babfc888675e37feb80851a4e9708f573386&v=4&s=39 "Thomas Bolon")](https://github.com/tbolon)
[![Jacob Foshee](https://avatars.githubusercontent.com/u/480334?v=4&s=39 "Jacob Foshee")](https://github.com/jfoshee)
[![](https://avatars.githubusercontent.com/u/33566379?u=bf62e2b46435a267fa246a64537870fd2449410f&v=4&s=39 "")](https://github.com/Mrxx99)
[![Eric Johnson](https://avatars.githubusercontent.com/u/26369281?u=41b560c2bc493149b32d384b960e0948c78767ab&v=4&s=39 "Eric Johnson")](https://github.com/eajhnsn1)
[![Jonathan ](https://avatars.githubusercontent.com/u/5510103?u=98dcfbef3f32de629d30f1f418a095bf09e14891&v=4&s=39 "Jonathan ")](https://github.com/Jonathan-Hickey)
[![Ken Bonny](https://avatars.githubusercontent.com/u/6417376?u=569af445b6f387917029ffb5129e9cf9f6f68421&v=4&s=39 "Ken Bonny")](https://github.com/KenBonny)
[![Simon Cropp](https://avatars.githubusercontent.com/u/122666?v=4&s=39 "Simon Cropp")](https://github.com/SimonCropp)
[![agileworks-eu](https://avatars.githubusercontent.com/u/5989304?v=4&s=39 "agileworks-eu")](https://github.com/agileworks-eu)
[![Zheyu Shen](https://avatars.githubusercontent.com/u/4067473?v=4&s=39 "Zheyu Shen")](https://github.com/arsdragonfly)
[![Vezel](https://avatars.githubusercontent.com/u/87844133?v=4&s=39 "Vezel")](https://github.com/vezel-dev)
[![ChilliCream](https://avatars.githubusercontent.com/u/16239022?v=4&s=39 "ChilliCream")](https://github.com/ChilliCream)
[![4OTC](https://avatars.githubusercontent.com/u/68428092?v=4&s=39 "4OTC")](https://github.com/4OTC)
[![domischell](https://avatars.githubusercontent.com/u/66068846?u=0a5c5e2e7d90f15ea657bc660f175605935c5bea&v=4&s=39 "domischell")](https://github.com/DominicSchell)
[![Adrian Alonso](https://avatars.githubusercontent.com/u/2027083?u=129cf516d99f5cb2fd0f4a0787a069f3446b7522&v=4&s=39 "Adrian Alonso")](https://github.com/adalon)
[![torutek](https://avatars.githubusercontent.com/u/33917059?v=4&s=39 "torutek")](https://github.com/torutek)
[![Ryan McCaffery](https://avatars.githubusercontent.com/u/16667079?u=c0daa64bb5c1b572130e05ae2b6f609ecc912d4d&v=4&s=39 "Ryan McCaffery")](https://github.com/mccaffers)
[![Seika Logiciel](https://avatars.githubusercontent.com/u/2564602?v=4&s=39 "Seika Logiciel")](https://github.com/SeikaLogiciel)
[![Andrew Grant](https://avatars.githubusercontent.com/devlooped-user?s=39 "Andrew Grant")](https://github.com/wizardness)
[![eska-gmbh](https://avatars.githubusercontent.com/devlooped-team?s=39 "eska-gmbh")](https://github.com/eska-gmbh)
[![Geodata AS](https://avatars.githubusercontent.com/u/5946299?v=4&s=39 "Geodata AS")](https://github.com/geodata-no)
[![Röbbek Capital](https://avatars.githubusercontent.com/u/116765313?v=4&s=39 "Röbbek Capital")](https://github.com/Roebbek-Capital)
[![Schüco](https://avatars.githubusercontent.com/u/125355474?v=4&s=39 "Schüco")](https://github.com/schueco)
[![Vertica Open Source Fund](https://avatars.githubusercontent.com/u/359072813?v=4&s=39 "Vertica Open Source Fund")](https://github.com/Vertica-Open-Source-Fund)
[![codefortynine](https://avatars.githubusercontent.com/devlooped-team?s=39 "codefortynine")](https://github.com/codefortynine)


<!-- sponsors.md -->
[![Sponsor this project](https://avatars.githubusercontent.com/devlooped-sponsor?s=118 "Sponsor this project")](https://github.com/sponsors/devlooped)

[Learn more about GitHub Sponsors](https://github.com/sponsors)

<!-- https://github.com/devlooped/sponsors/raw/main/footer.md -->
