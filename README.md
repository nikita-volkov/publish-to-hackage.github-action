# Summary

GitHub action for publishing packages and documentation to Hackage.

It is a fork of [haskell-actions/hackage-publish](https://github.com/haskell-actions/hackage-publish). In difference to the original it:

- Fixes the issue of the original action not failing on errors such as unsuccessful publishing.
- Fails fast with a clear message when the `token` input is empty.
- Uses `https` as the default `server`, rather than plain `http`.
- Works around a known Hackage bug where the documentation-upload response gets truncated: curl reports exit code 56 (`Illegal or missing hexadecimal sequence in chunked-encoding`) even though the documentation was uploaded successfully. This action detects that specific case from the response body and treats it as success instead of failing the job.

## Usage

This action does not build the tarball itself — build it in a prior step, then point this action at the tarball file. It publishes exactly **one** package per invocation; for multi-package Cabal projects, invoke it once per package (e.g. via a build matrix).

```yaml
- name: Build package tarball
  run: cabal sdist

- name: Build documentation tarball
  run: cabal haddock --haddock-for-hackage

- name: Publish to Hackage
  id: publish
  uses: nikita-volkov/publish-to-hackage@v2
  with:
    token: ${{ secrets.HACKAGE_TOKEN }}
    publish: true
    package-path: dist-newstyle/sdist/my-package-1.0.0.tar.gz
    doc-path: dist-newstyle/sdist/my-package-1.0.0-docs.tar.gz

- name: Report outcome
  run: echo "Already published: ${{ steps.publish.outputs.already-published }}"
```

## Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `token` | yes | | Authentication token for Hackage |
| `server` | no | `https://hackage.haskell.org` | URL to the Hackage server |
| `publish` | no | `false` | Whether to publish the release on Hackage. Uploads a release candidate if `false` |
| `package-path` | yes | | Path to the package tarball produced by `cabal sdist` |
| `doc-path` | no | (empty, disabled) | Path to the documentation tarball produced by `cabal haddock --haddock-for-hackage`. Leave empty to skip documentation upload |

## Outputs

| Name | Description |
|---|---|
| `already-published` | `"true"` if the package was already published on Hackage prior to this run (an idempotent no-op — the run still succeeds); `"false"` if this run performed the publish. Only meaningful when `publish` is `true`; candidate uploads always report `"false"` |

## Idempotency

When `publish: true`, if the package version was already published on Hackage, the action does **not** fail. It reports this via the `already-published` output instead, so retried or re-run workflows stay idempotent. Any other upload failure (bad token, permission error, server error) still fails the action normally.

## Migrating from v1

`v2` is a breaking change:

- `packagesPath` (a directory, globbed for all `*.tar.gz` files) is replaced by `package-path` (the path to a single tarball file).
- `docsPath` (a directory) is replaced by `doc-path` (the path to a single doc tarball file).
- Multi-package projects that relied on `packagesPath` uploading every tarball in a directory must now call this action once per package (e.g. in a build matrix), passing the specific `package-path`/`doc-path` for each.
- A package that's already published on Hackage no longer fails the job — check the new `already-published` output if your workflow needs to branch on that.
