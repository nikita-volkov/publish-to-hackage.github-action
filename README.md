# Summary

GitHub action for publishing packages and documentation to Hackage.

It is a fork of [haskell-actions/hackage-publish](https://github.com/haskell-actions/hackage-publish). In difference to the original it:

- Fixes the issue of the original action not failing on errors such as unsuccessful publishing.
- Fails fast with a clear message when the `token` input is empty.
- Uses `https` as the default `server`, rather than plain `http`.
- Works around a known Hackage bug where the documentation-upload response gets truncated: curl reports exit code 56 (`Illegal or missing hexadecimal sequence in chunked-encoding`) even though the documentation was uploaded successfully. This action detects that specific case from the response body and treats it as success instead of failing the job.

## Usage

This action does not build the tarballs itself — build them in a prior step, then point this action at the directory containing them:

```yaml
- name: Build package tarball
  run: cabal sdist all

- name: Build documentation tarball
  run: cabal haddock --haddock-for-hackage all

- name: Publish to Hackage
  uses: nikita-volkov/publish-to-hackage@v1
  with:
    token: ${{ secrets.HACKAGE_TOKEN }}
    publish: true
    docsPath: dist-newstyle/sdist
```

## Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `token` | yes | | Authentication token for Hackage |
| `server` | no | `https://hackage.haskell.org` | URL to the Hackage server |
| `publish` | no | `false` | Whether to publish the release on Hackage. Uploads a release candidate if `false` |
| `packagesPath` | no | `dist-newstyle/sdist/` | Directory containing the package tarballs produced by `cabal sdist` |
| `docsPath` | no | (empty, disabled) | Directory containing the documentation tarballs produced by `cabal haddock --haddock-for-hackage`. Leave empty to skip documentation upload |

## Multiple packages

Every `*.tar.gz` found directly under `packagesPath` is uploaded, so multi-package Cabal projects are supported without any extra configuration — just make sure `cabal sdist all` (and, if using `docsPath`, `cabal haddock --haddock-for-hackage all`) is run beforehand.
