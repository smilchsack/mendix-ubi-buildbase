# Third-party licenses and corresponding sources

The [MIT license](LICENSE) covers this repository's original Dockerfile, scripts
and documentation. It does not relicense UBI9, EPEL packages, Java or any other
third-party component in the image. Those components remain subject to their
respective license terms and copyright notices.

The [Red Hat Universal Base Image EULA](https://www.redhat.com/en/about/red-hat-end-user-license-agreements#UBI)
also applies to the UBI distribution.

Package-provided notices remain in the image, including `/usr/share/licenses`
and applicable `/usr/share/doc` directories. The notice archive supplements
license files omitted by the base image's package documentation settings.
`packages.tsv` records package and
license metadata. Package metadata is an inventory aid; the original license
texts govern each component.

The [ubi9-2026-09 release](https://github.com/smilchsack/mendix-ubi-buildbase/releases/tag/ubi9-2026-09)
provides:

- `sources.tar.gz`: matching source RPMs, including their upstream sources,
  patches and packaging/build specifications.
- `notices.tar.gz`: collected original package license and notice files.
- `sources-manifest.json`: the source inventory and its recorded provenance.
- `release-manifest.json`: the image and release artifact inventory.
- `packages.tsv`: package versions and license metadata.

The source and notice collections cover the original pinned base as well as the
final image. This includes original package versions retained in lower image
layers after an upgrade. Use the manifests accompanying the exact image release
when locating its corresponding sources; sources for a later rebuild may differ.

Retain the applicable notices and corresponding-source materials when
redistributing the image, as required by the individual component licenses.
No application or proprietary build-tool distribution is included in this base.
