---
name: build
description: >-
  The Containerfile, Justfile, build phases, image pinning, and the example
  scripts. Use when changing how the image is assembled or activating an
  example.
---

# Build

## The Containerfile

It is the source of truth for image assembly, and it is written to be read. Its
structure, in order:

1. **Identity** — `ARG IMAGE_NAME`, `IMAGE_VENDOR`, `UBLUE_IMAGE_TAG`, and the
   `# Name:` comment. The name actually published is the repository name; these
   are the local fallback and the image metadata.
2. **Context stage** — `COPY build /build`, `COPY custom /custom`, then the two
   OCI images into `/oci/common` and `/oci/brew`.
3. **Base** — the `FROM` line. The only place the base is chosen; the Fedora
   major, the image name, and the digest all follow from it.
4. **Phases** — one `RUN` block per script, in the order they are named.
   [build/README.md](../../../build/README.md) lists them.
5. **Metadata** — the `LABEL` block, fed by ARGs declared late so a new version
   or commit only invalidates the label layer.

Order matters for cache: volatile values go after the expensive layers.

## The `/opt` and `/var` rules

At build time `/opt` is a symlink to `var/opt` and `/var/opt` does not exist,
so an RPM installing under `/opt` fails its cpio unpack until the script runs
`mkdir -p /var/opt`. It is still not safe to leave the payload there: `/var`
in the image behaves like a Docker volume, seeded from the initial image at
first boot and never touched by later image updates. Payloads therefore move
into `/usr` and a `tmpfiles.d` entry recreates `/opt/<pkg>` at boot; this repo
has no blue-build CLI "one true optfix" to do it generically. The worked
example is `build/32-1password.sh`.

That script also shows the group rule: any group that ends up in `/etc/group`
at build time — from a script's `groupadd` or an RPM `%post` — must also be
declared in `/usr/lib/sysusers.d` or `bootc container lint` fails, because
sysusers is how the deployed system reproduces that state. Declare the groups
with fixed GIDs above the per-user range (1000+) and run `systemd-sysusers`
to materialize them; the scriptlets' `getent` checks then skip their own
`groupadd`, so the setgid bits land on the declared GIDs.

## The Justfile

```bash
just build            # build the image
just build-qcow2      # build a QCOW2 disk image
just build-iso        # build an installer ISO
just run-vm-qcow2     # boot the image in a VM
just test-unit        # run the suite
just lint             # shellcheck every tracked script
just check            # verify Justfile syntax
```

`just --list` has the rest. `IMAGE_NAME` defaults to the value in the Justfile
and is overridable by the `IMAGE_NAME` environment variable; CI sets that from
the repository name.

`build-iso` gives installed machines a `bootc` origin built from the image's
`image-info.json` `image-ref` plus the tag you pass, e.g. `just build-iso
ghcr.io/projectbluefin/finpilot stable`. Never read the channel from the baked
`image-tag`: CI builds only as `stable-testing` and `:stable` is a digest copy,
so that value is `stable-testing` even in the stable image.

## Pinning

Every OCI reference is pinned by digest and updated by Renovate: the base image,
`projectbluefin/common`, `ublue-os/brew`, `bootc-image-builder`, and the GitHub
Actions. Do not hand-edit a digest; let Renovate propose it.

Exception: the base image's Fedora major (the final `FROM
quay.io/fedora-ostree-desktops/silverblue:N` in `Containerfile`) is *not*
updated by Renovate. The `packageRules` entry in `.github/renovate.json` that
matches `matchDepNames: ["quay.io/fedora-ostree-desktops/*"]` with
`matchUpdateTypes: ["major"]` sets `enabled: false`, so *no* major update is
proposed for that namespace — including an already-released one such as
44 -> 45. That is deliberate: the namespace also tags unreleased branches, and
every major rebase is a manual step tied to a known-good validation. Bump the
tag in `Containerfile` by hand when the next major is released and validated.

The base image's `FROM` line is the only place the base is chosen, so the Fedora
major cannot desync the way a hand-maintained `FEDORA_MAJOR_VERSION` ARG could.
Two readers derive it from that base: `just build` parses the tag for the version
string, and `00-image-info.sh` reads the base's `os-release` for the image
metadata.

`BASE_IMAGE_NAME` has no default in the Containerfile on purpose: a stale default
like `silverblue` would silently mislabel a CentOS or Hummingbird fork. `just
build` fills it from the `FROM` line and `00-image-info.sh` hard-fails on an empty
value, so build through `just`; a bare `podman build .` is unsupported.

## Examples

`build/*.sh.example` are inactive until you activate them: rename the file off
`.example` and add a `RUN` block after the package phase.
[build/README.md](../../../build/README.md) has the block to copy. This fork
has already activated `30-tailscale.sh` and `50-nvidia.sh`; what follows
describes the scripts by the name they now carry.

A script's promises span files. `30-tailscale.sh` says `90-cleanup.sh`
disables `tailscale.repo` as a backstop, and
`tests/template/build-examples_test.bats` resolves the script by either name
so the promise keeps being checked across activation. When you activate an
example, drop the other paths that name it as inactive —
`build/README.md`'s list, and any test that pins the `.example` path.

`50-nvidia.sh` pulls `ghcr.io/ublue-os/akmods-nvidia-open` through a
`skopeo` policy that accepts only images signed by `build/akmods-cosign.pub`, a
copy of [ublue-os/akmods `cosign.pub`](https://github.com/ublue-os/akmods/blob/main/cosign.pub).
If upstream rotates that key, update the copy; do not weaken the policy to
`insecureAcceptAnything` to get a build through.
