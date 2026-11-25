---
title: "Tidy what the website work found around the repository: prelude line endings, Jekyll leftovers, Lunet workarounds"
kind: improvement
status: pending
created: 2026-11-25
summary: "The TypeScript build leaves a generated file modified on Windows, the old Jekyll configuration is dead weight, and the site works around two Lunet bugs and an unpinned theme."
---

## Why
- **`typescript/src/binding/preludeSource.ts` shows as modified after every build on Windows.** `typescript/scripts/generate-prelude.mjs` (run by `npm run build`, `npm test`, `prepack`) writes it with LF; with `* text=auto` and `core.autocrlf` the checkout has CRLF (`git ls-files --eol`: `i/lf w/crlf`). `git status` lists it, `git diff` is empty. Seen twice on 2026-11-25.
- **`_config.yml` and `assets/css/style.scss`** are the Jekyll setup GitHub Pages used to build from the root. Once Settings > Pages > Source is "GitHub Actions" (needed by `.github/workflows/site.yml`) Jekyll no longer runs. Both are synced from `devlooped/oss` (`.netconfig`), so deleting them alone does not last. `assets/img/logo.svg` stays: `docs/import.ps1` copies it into the site.
- **Lunet 1.0.14**, found while building `docs/`:
  - A script added to the bundle with `js "/js/x.js"` is silently left out of `site-defer.js` when the file is in a content folder; the same file under `.lunet/js/` is bundled. That is why `jqlite.js` is in `docs/.lunet/js/`.
  - `list_item_class` on a `menu.yml` item with `folder: true` is not rendered, and where it is, the class is appended without a space after `active` (`src/Lunet.Menus/MenuObject.cs`, `RenderItem`).
  - `lunet-io/templates` has no tag, so the theme follows `main`, and `docs/.lunet/layouts/base.sbn-html` and `default.sbn-html` are copies of its layouts that break silently if it changes them.

## What to do
- [ ] Pin the generated file to LF (`typescript/src/binding/preludeSource.ts text eol=lf` in `.gitattributes`) and renormalize; check `go/internal/binding/prelude.jq` and `rust/src/binding/prelude.jq` for the same.
- [ ] After the first deployment by the workflow, delete `_config.yml` and `assets/css/style.scss` and mark their `.netconfig` entries with `skip`.
- [ ] Open issues at https://github.com/lunet-io/lunet (the two bugs) and https://github.com/lunet-io/templates (a tagged release; a hook for extra navigation items and a configurable API menu depth would remove both layout copies). When fixed: move `jqlite.js` beside `css/jqlite.scss`, pin the theme, drop the layout copies.

## Where
`.gitattributes`, `_config.yml`, `assets/css/style.scss`, `.netconfig`, `docs/config.scriban`, `docs/.lunet/`
