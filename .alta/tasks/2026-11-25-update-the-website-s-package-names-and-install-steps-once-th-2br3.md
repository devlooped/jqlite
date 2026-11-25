---
title: "Point the website at PyPI, Maven Central, NuGet and Go module tags once the packages are there"
kind: gap
status: pending
created: 2026-11-25
summary: "The guides already install TypeScript from npm and Rust from crates.io; Python, Java, Go and .NET still describe a build from a clone or a release that is not out."
---

## Why
On 2026-11-25 `@devlooped/jqlite` was on npm and `jqlite` on crates.io, and the guides say so. The other four were not published (checked against each registry):

- **Python**: `devlooped-jqlite` is not on PyPI. `docs/python/readme.md` ("Getting it") installs from a clone.
- **Java**: `com.devlooped:jqlite` 1.0.0 is not on Maven Central. `docs/java/readme.md` builds with `mvnw`.
- **Go**: the module has no `go/vX.Y.Z` tag (`proxy.golang.org` lists no version). `docs/go/readme.md` uses a `replace` directive on a clone.
- **.NET**: `JQLite` is not on nuget.org (only `Devlooped.JQSharp` 1.0.x). `docs/dotnet/readme.md` shows `dotnet add package JQLite` with a note pointing to the CI feed.

## What to do
As each one is published:
- [ ] Python: `pip install devlooped-jqlite` in `docs/python/readme.md`.
- [ ] Java: the Maven and Gradle coordinates in `docs/java/readme.md`, without the build steps.
- [ ] Go: `go get github.com/devlooped/jqlite/go` in `docs/go/readme.md`, without the `replace` directive.
- [ ] .NET: remove the note about nuget.org in `docs/dotnet/readme.md`.
- [ ] The `package` shown on the cards (`jqlite_languages` in `docs/config.scriban`), if a name changes.
- [ ] Build with `pwsh docs/build.ps1`.

## Where
`docs/python/readme.md`, `docs/java/readme.md`, `docs/go/readme.md`, `docs/dotnet/readme.md`, `docs/config.scriban`
