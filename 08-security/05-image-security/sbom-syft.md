# SBOM with Syft

A **Software Bill of Materials** lists every package in an artifact (image, filesystem, source tree). Required by SLSA, US Executive Order 14028, and most enterprise procurement processes today.

[Anchore Syft](https://github.com/anchore/syft) is the de-facto SBOM generator. Output formats: SPDX, CycloneDX, syft-native JSON.

## Install

```bash
brew install syft
# or curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin
```

## Generate

```bash
# Image (any registry)
syft ghcr.io/myorg/app:1.2.3 -o spdx-json > sbom.spdx.json
syft ghcr.io/myorg/app:1.2.3 -o cyclonedx-json > sbom.cdx.json

# Local Docker image
syft myapp:dev -o spdx-json > sbom.json

# Source tree (npm, pip, go.mod, cargo, etc.)
syft dir:./ -o cyclonedx-json > sbom.json

# OCI tarball
syft oci-archive:./image.tar -o spdx-json
```

## Why two formats?

| Format | Maintainer | Strengths |
|--------|-----------|-----------|
| SPDX | Linux Foundation | License focus, ISO standard |
| CycloneDX | OWASP | Vulnerability + VEX + supply-chain focus |

Generate both — costs nothing, makes downstream tooling happy.

## Attach SBOM to image (signed)

```bash
syft ghcr.io/myorg/app:1.2.3 -o spdx-json > sbom.json
cosign attest --predicate sbom.json --type spdxjson \
  ghcr.io/myorg/app@sha256:...
```

Now the SBOM travels with the image and is verifiable.

## Scan an SBOM with grype

[Grype](https://github.com/anchore/grype) is the matching vuln scanner — pairs naturally with syft.

```bash
brew install grype
grype sbom:./sbom.spdx.json --fail-on high
```

This is faster than re-scanning the image because the package list is already extracted.

## CI snippet

```yaml
- uses: anchore/sbom-action@v0
  with:
    image: ghcr.io/${{ github.repository }}:${{ github.sha }}
    format: spdx-json
    output-file: sbom.spdx.json
- uses: anchore/scan-action@v3
  with:
    sbom: sbom.spdx.json
    fail-build: true
    severity-cutoff: high
```

## VEX (Vulnerability Exploitability eXchange)

A separate document that says "yes the SBOM lists CVE-X but it doesn't apply because Y". OpenVEX format. Without VEX, every consumer re-asks you about the same false positives.
