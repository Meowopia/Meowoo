# Upstream and licensing

Meowoo's Miru-based development edition derives from
[Miru Alpha](https://github.com/miru-project/miru-alpha), version 2.0.3-alpha,
commit `148b1e16969b00a600bbfcef94dde9b061c4647a`.

The embedded [miru-core](https://github.com/miru-project/miru-core) submodule is
pinned to `13c46223230162871f7eb7757bd8c29d15ec5f1a`.
Machine-readable baseline and toolchain requirements are in
[`tool/meowoo/upstream.lock.json`](tool/meowoo/upstream.lock.json).

## Licenses

- Client: retain the upstream GNU GPL version 3 license in [`LICENSE`](LICENSE).
- Core: retain its separate GNU AGPL version 3 license in
  [`src/miru_core/miru-core/LICENSE`](src/miru_core/miru-core/LICENSE).
- Vendored code, media libraries, packages and artwork retain their respective
  licenses and notices. The project is not an MIT-only distribution.
- These identifiers describe the checked-in license texts, not a complete
  audit of every dependency or permission to reuse upstream trademarks.
- Distributing a build requires the applicable license notices and corresponding
  source, including the relevant core and native components. Release packaging
  and dependency-license review must be completed before publishing binaries.

The original client documentation is preserved in
[`docs/upstream/`](docs/upstream/README.miru.md). Descriptions there concern
upstream Miru and do not establish that a Meowoo release has passed validation.
