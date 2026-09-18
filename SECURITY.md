# Image integrity and security

## Release identity

Official releases use the `main` branch of `smilchsack/mendix-ubi-buildbase` and
its `.github/workflows/publish.yml` workflow. The Docker Hub repository is
`docker.io/smilchsack/mendix-ubi-buildbase`.

Release images include a software bill of materials (SBOM) and build provenance.
Cosign signs the published image digest through GitHub OIDC. Verify both the
exact workflow identity and issuer shown in [README.md](README.md), then consume
the verified digest. Signature verification identifies the signer; it does not
establish that every dependency is safe or that the SBOM is complete.

## Inputs and release checks

The UBI base, Dockerfile frontend and release helper images are pinned by digest;
GitHub Actions are pinned by commit SHA. Dependabot checks Docker and Actions
updates weekly. Review proposed updates and repeat verification before release;
updates are not automatically approved.

RPM signatures are checked. The package repositories are live, so later builds
can contain newer package versions. An image digest identifies an exact artifact;
it does not make future rebuilds byte-for-byte reproducible.

The publication workflow scans the image before registry publication. HIGH or
CRITICAL findings with an available fix block release. Reports retain findings
without fixes for review. A successful scan does not mean there are no known
vulnerabilities, and newly published advisories may change the result. Inspect
the report associated with the specific release.

The release contains corresponding sources and notices for the original base
and final image. See [LICENSES.md](LICENSES.md) and the release manifests for the
matching source artifacts.

## Repository and workload boundaries

Only the Dockerfile and `.dockerignore` enter the image build context. Keep
applications, credentials, private infrastructure references, scanner output
and locally generated archives outside this repository. Build provenance is
public metadata: never pass secrets or private service addresses as build
arguments or labels.

`verify.sh` checks known paths and optionally supplied text patterns. It cannot
identify every encoded secret or inspect all compressed content. Git history
requires separate review. The base has no application entrypoint and defaults
to root; a derived image must choose the user, filesystem permissions and runtime
configuration appropriate to its workload.

For a sensitive vulnerability report, use the repository's private vulnerability
reporting facility if enabled. Do not post credentials or exploit details in a
public issue.
