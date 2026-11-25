---
title: Home
layout: simple
og_type: website
---

<section class="jqlite-hero">
  <div>
    <p class="jqlite-eyebrow">jq, as a library</p>
    <h1>One jq program, the same result in six languages.</h1>
    <p class="lead">
      jqlite is a portable profile of the <a href="https://jqlang.org">jq</a> language: one specification,
      one conformance corpus, and an engine ported file by file to .NET, TypeScript, Python, Java, Go and Rust.
    </p>
    <div class="d-flex gap-3 mt-4 flex-wrap">
      <a href="#pick-your-language" class="btn btn-primary btn-lg"><i class="bi bi-code-slash" aria-hidden="true"></i> Pick your language</a>
      <a href="{{site.basepath}}/language/" class="btn btn-outline-secondary btn-lg"><i class="bi bi-braces-asterisk" aria-hidden="true"></i> The language</a>
    </div>
  </div>
  <div class="jqlite-run" aria-label="A jqlite program, its input and its output">
    <div class="jqlite-run-program"><span class="jqlite-run-label">Program</span><pre>[.[] | select(.active) | .name]</pre></div>
    <div><span class="jqlite-run-label">Input</span><pre>[
  { "name": "Ada", "active": true },
  { "name": "Lin", "active": false }
]</pre></div>
    <div><span class="jqlite-run-label">Output</span><pre>["Ada"]</pre></div>
  </div>
</section>

<h2 id="pick-your-language" class="jqlite-section-title">Pick your language</h2>
<p class="jqlite-section-lead">
  Each implementation has its own guide, with the same topics under the same names: evaluating, values,
  variables, options, modules, errors, JSON Lines and the API. The language switcher at the top of a page
  shows the same topic in another language.
</p>
<div class="jqlite-cards">
  {{~ for language in site.jqlite_languages ~}}
  <a class="jqlite-card" href="{{site.basepath}}/{{language.id}}/">
    <span class="jqlite-card-title"><span class="jqlite-language-tag" aria-hidden="true">{{language.tag}}</span>{{language.name}}</span>
    <span class="jqlite-card-package">{{language.package}}</span>
    <span class="jqlite-card-note">{{language.note}}</span>
  </a>
  {{~ end ~}}
</div>

<h2 class="jqlite-section-title">The same call, six ways</h2>
<p class="jqlite-section-lead">
  The program above, run from each language. Values go in and come out as the host's own JSON values
  where it has ordered ones, and as the engine's values where it does not.
</p>
<div class="jqlite-samples">
  <ul class="nav nav-tabs" role="tablist">
    {{~ for language in site.jqlite_languages ~}}
    <li class="nav-item" role="presentation">
      <button class="nav-link{{ for.first ? " active" : "" }}" id="sample-tab-{{language.id}}" data-bs-toggle="tab" data-bs-target="#sample-{{language.id}}" type="button" role="tab" aria-controls="sample-{{language.id}}" aria-selected="{{ for.first }}">{{language.name}}</button>
    </li>
    {{~ end ~}}
  </ul>
  <div class="tab-content">
    <div class="tab-pane show active" id="sample-dotnet" role="tabpanel" aria-labelledby="sample-tab-dotnet" tabindex="0">

```csharp
using System.Text.Json;
using JQLite;

using var people = JsonDocument.Parse(
    """[{"name":"Ada","active":true},{"name":"Lin","active":false}]""");

var results = Jq.Evaluate("[.[] | select(.active) | .name]", people.RootElement);

Console.WriteLine(results[0].GetRawText()); // ["Ada"]
```

</div>
    <div class="tab-pane" id="sample-typescript" role="tabpanel" aria-labelledby="sample-tab-typescript" tabindex="0">

```typescript
import { Jq } from "jqlite";

const people = [{ name: "Ada", active: true }, { name: "Lin", active: false }];

const results = Jq.evaluate("[.[] | select(.active) | .name]", people);

console.log(JSON.stringify(results[0])); // ["Ada"]
```

</div>
    <div class="tab-pane" id="sample-python" role="tabpanel" aria-labelledby="sample-tab-python" tabindex="0">

```python
import json
import jqlite

people = [{"name": "Ada", "active": True}, {"name": "Lin", "active": False}]

results = jqlite.evaluate("[.[] | select(.active) | .name]", people)

print(json.dumps(results[0]))  # ["Ada"]
```

</div>
    <div class="tab-pane" id="sample-java" role="tabpanel" aria-labelledby="sample-tab-java" tabindex="0">

```java
import com.devlooped.jqlite.*;
import com.devlooped.jqlite.values.JqValue;
import java.util.List;

JqValue people = JqJson.parse(
    "[{\"name\":\"Ada\",\"active\":true},{\"name\":\"Lin\",\"active\":false}]");

List<JqValue> results = Jq.evaluate("[.[] | select(.active) | .name]", people);

System.out.println(JqJson.toJson(results.get(0))); // ["Ada"]
```

</div>
    <div class="tab-pane" id="sample-go" role="tabpanel" aria-labelledby="sample-tab-go" tabindex="0">

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

</div>
    <div class="tab-pane" id="sample-rust" role="tabpanel" aria-labelledby="sample-tab-rust" tabindex="0">

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

</div>
  </div>
</div>

<h2 class="jqlite-section-title">What every implementation shares</h2>
<p class="jqlite-section-lead">
  The language is defined once. These pages hold for every implementation, whichever language you call it from.
</p>
<div class="jqlite-cards">
  <a class="jqlite-card" href="{{site.basepath}}/language/">
    <span class="jqlite-card-title"><i class="bi bi-braces-asterisk" aria-hidden="true"></i>The language</span>
    <span class="jqlite-card-note">What is in the profile, and the differences from jq 1.8 you are most likely to meet.</span>
  </a>
  <a class="jqlite-card" href="{{site.basepath}}/language/tour/">
    <span class="jqlite-card-title"><i class="bi bi-signpost-2" aria-hidden="true"></i>A tour</span>
    <span class="jqlite-card-note">Paths, pipes, construction, functions, updates and errors, on one small document.</span>
  </a>
  <a class="jqlite-card" href="{{site.basepath}}/language/spec/">
    <span class="jqlite-card-title"><i class="bi bi-file-earmark-ruled" aria-hidden="true"></i>Specification</span>
    <span class="jqlite-card-note">The normative text: grammar, values, semantics, every builtin, errors and limits.</span>
  </a>
  <a class="jqlite-card" href="{{site.basepath}}/project/">
    <span class="jqlite-card-title"><i class="bi bi-diagram-3" aria-hidden="true"></i>The project</span>
    <span class="jqlite-card-note">How the reference is built and ported, the conformance corpus, and the cross-language benchmark.</span>
  </a>
</div>

<p class="jqlite-section-lead mt-5">
  jqlite is open source under the <a href="https://github.com/devlooped/jqlite/blob/main/license.txt">MIT license</a>.
  Its use is subject to the <a href="https://github.com/devlooped/jqlite/blob/main/osmfeula.txt">Open Source Maintenance Fee EULA</a>:
  if you use it to generate revenue, <a href="https://github.com/sponsors/devlooped">sponsoring</a> is required.
</p>
