# Publishing `aurasuisui/bimap` to mooncakes.io

The package is **fully release-ready** (v0.1.0): all five CI steps are green locally, the
`src/pkg.generated.mbti` interface is committed, and `moon.mod` / `README.md` / `LICENSE` /
`CHANGELOG.md` are all present. The only remaining step is the authenticated publish itself,
which requires an interactive login that cannot run in an unattended environment.

## Steps

1. **Log in to mooncakes.io** (interactive — opens a browser for OAuth):

   ```bash
   moon login
   ```

   This creates `~/.moon/credentials.json`. (If you don't have an account yet, register at
   <https://mooncakes.io> first; the package name `aurasuisui/bimap` must be available under
   your account/namespace.)

2. **Publish** from the project root:

   ```bash
   cd moonbit-bimap
   moon publish
   ```

   `moon publish` packages `src/` + `moon.mod` + `README.md` + `LICENSE` (and `CHANGELOG.md`)
   and uploads version `0.1.0`. The `cmd/` examples, `docs/`, and `reference/` directories are
   not part of the published artifact.

3. **Verify** the package is live:

   ```bash
   # from a fresh scratch project
   moon add aurasuisui/bimap     # or add "aurasuisui/bimap@0.1.0" to a moon.mod
   ```

   and check <https://mooncakes.io> for `aurasuisui/bimap`.

4. **(Optional) Run the examples against the published package.** Now that
   `aurasuisui/bimap@0.1.0` resolves, the standalone example modules build:

   ```bash
   moon run cmd/username_email
   moon run cmd/country_code
   ```

## Why this was not done automatically

`moon publish` aborts with:

```
failed to open credentials file: ~/.moon/credentials.json, please login first
```

`moon login` is interactive (browser OAuth) and therefore cannot be performed by the
unattended execution session that built this package. Everything short of the authenticated
upload is complete and verified.

## Pre-publish checklist (already satisfied)

- [x] `moon.mod` has `name`, `version = "0.1.0"`, `license = "Apache-2.0"`, `readme`,
      `repository`, `description`, `keywords`, `source = "src"`.
- [x] `README.md`, `LICENSE` (Apache-2.0), `CHANGELOG.md` present at the root.
- [x] `src/pkg.generated.mbti` generated via `moon info` and committed (so the CI
      `moon info && git diff --exit-code` step stays clean).
- [x] Five-step CI green locally: `moon fmt --check` → `moon check` →
      `moon info && git diff --exit-code` → `moon test` (203 passing) → `moon build`.
- [x] Working tree clean (`git status` empty).
