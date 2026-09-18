# UBI9 build base

A Linux AMD64 system base for application build environments. It contains Java
11, 17 and 21 development kits, font and graphics libraries, OpenSSL, ICU,
localization data and common archive/build utilities from UBI9 and EPEL9.

The image contains no Mendix binaries, Gradle distribution, application or
organization-specific configuration. It is not a complete application builder:
obtain the required licensed build tools separately and add them in a derived
image. This base starts a shell as root; derived images should select an
appropriate user for their workload.

## Pull and verify

```sh
docker pull --platform linux/amd64 docker.io/smilchsack/mendix-ubi-buildbase:ubi9-2026-09
```

From a checkout of the corresponding repository release, verify the local image:

```sh
./verify.sh --image docker.io/smilchsack/mendix-ubi-buildbase:ubi9-2026-09
```

The verifier checks the public file/build-context allowlists, installed packages,
Java versions, shared-library dependencies and absence of known build-tool,
application and credential files. Container checks run without network access.
An optional `--denylist /path/to/private-patterns.txt` scans sources, metadata,
history, saved layers and the final filesystem for known text. Keep the denylist
outside the repository; see `./verify.sh --help` for coverage limits.

Release images include an SBOM and build provenance. To verify the keyless
signature, replace the placeholder with the digest recorded by the release:

```sh
IMAGE='docker.io/smilchsack/mendix-ubi-buildbase@sha256:<release-digest>'
cosign verify "$IMAGE" \
  --certificate-identity https://github.com/smilchsack/mendix-ubi-buildbase/.github/workflows/publish.yml@refs/heads/main \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
docker pull --platform linux/amd64 "$IMAGE"
```

Use the verified digest in derived images to select an exact release. See
[SECURITY.md](SECURITY.md) for release checks and their limits.

## Build locally

```sh
BUILDX_GIT_INFO=false docker buildx build --platform linux/amd64 \
  --provenance=false --load \
  -t docker.io/smilchsack/mendix-ubi-buildbase:ubi9-2026-09 .
./verify.sh
```

The UBI input and Dockerfile frontend are pinned by digest. RPM signatures are
checked, but package repositories are live: a rebuild may select newer packages.
ARM hosts require AMD64 emulation. Only `Dockerfile` and `.dockerignore` enter the
build context. A local build does not create the release workflow's signature or
attestations.

## Licenses and corresponding sources

Repository code uses the [MIT license](LICENSE). Third-party software retains
its original licenses; see [LICENSES.md](LICENSES.md), `packages.tsv`,
`sources-manifest.json` and `release-manifest.json`.

The [ubi9-2026-09 release](https://github.com/smilchsack/mendix-ubi-buildbase/releases/tag/ubi9-2026-09)
provides `sources.tar.gz`, `notices.tar.gz` and the matching manifests. These cover
packages from both the original base and the final image, including packages
replaced in later image layers.

Organizations may mirror or import this image into their internal container registry.

## Publishing an update

Configure a Docker Hub Read/Write token as `DOCKERHUB_TOKEN` in the GitHub
`release` environment and restrict that environment to the `main` branch.
Start the `Publish verified UBI build base` workflow manually from `main`.
Remove temporary release credentials after use.

For each new release, refresh the package inventory, source RPMs, notices and
checksummed release manifests together. Upload the source and notice archives
to the corresponding GitHub release before running the publication workflow.
The workflow rejects package versions not covered by that reviewed inventory.
