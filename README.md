# Wings of Fury (custom Bluefin via the `finpilot` template)

My customized Bluefin build. Chickens are the present-day dinosaurs,
and I once named a chicken Wings of Fury. She was a tough little
creature who outlasted every other hen in her flock.

## What makes this raptor different?

This image is based on Fedora Silverblue and Bluefin. It includes these customizations:

### Added packages (Build-time)

- **Tailscale**, from Tailscale's RPM repository, with `tailscaled` enabled
  ([build/30-tailscale.sh](build/30-tailscale.sh))
- **1Password and 1Password CLI**, from 1Password's RPM repository
  ([build/32-1password.sh](build/32-1password.sh))
- **Vicinae and Zed**, from the Terra repository
  ([build/35-terra-installs.sh](build/35-terra-installs.sh))
- **NVIDIA (open) support** ([build/50-nvidia.sh](build/50-nvidia.sh))

### Added applications (Runtime)

**CLI tools (Homebrew)** — installed on demand via `ujust install-default-apps`
([custom/brew/default.Brewfile](custom/brew/default.Brewfile)):

- Shell tools: `bat`, `bat-extras`, `eza`, `fd`, `fzf`, `procs`, `ripgrep`,
  `dust`, `duf`, `tre-command`, `zoxide`, `zsh`, `starship`, `tmux`
- Development: `neovim`, `just`, `kanata`, `nmap`, `restic`, `ast-grep`,
  `bats-core`, `fnm`, `gcc`, `git-delta`, `git-pkgs-brief`, `go`, `rust`,
  `tree-sitter-cli`, `uv`, `crush` (charmbracelet/tap), `terraform`
  (hashicorp/tap)
- CLIs and TUIs: `fastfetch`, `gh`, `kew`
- Libraries: `libtiff`, `imagemagick`, `pdftk-java`
- Fonts: 0xProto Nerd Font, Atkinson Hyperlegible Mono/Next, B612 Mono

**GUI apps (Flatpak)** — installed on first boot
([custom/flatpaks/default.preinstall](custom/flatpaks/default.preinstall)):

- Communication and email: Thunderbird
- Browsers: Zen Browser
- Writing and notes: Obsidian
- Images: GIMP, Pinta, Eyedropper, Gradia
- Media: VLC, Amberol, Shortwave
- Files and backup: Pika Backup, LocalSend, Nautilus Previewer
- Reading and feeds: NewsFlash
- Development: Gitte
- Desktop tooling: Flatseal, Extension Manager, Warehouse, Keypunch

### Removed or disabled

- Nothing beyond the base template's cleanup (third-party RPM repositories are
  used at build time only and removed or disabled before the image ships).

### Configuration changes

- The `tailscaled` service is enabled at build time.
- Systemd update timers (`uupd`) and the Brew/Flatpak first-boot units come
  from the base template and stay on.

_Last updated: 2026-11-07_

## Quick start

1. **Create your repository** — "Use this template" on GitHub.
2. **Rename the project.** The published name is your repository name. Three
   files carry it as a literal, and `just test-contract` fails if they disagree:

   - `Containerfile` — the `# Name:` comment and `ARG IMAGE_NAME`
   - `Justfile` — the `IMAGE_NAME` default
   - `artifacthub-repo.yml` — `repositoryID`

   Grep for `finpilot` afterwards to catch the prose and the examples.
3. **Finish setup.** [The `onboarding` skill](.agents/skills/onboarding/SKILL.md)
   carries the rest — enabling Actions, auto-merge and workflow permissions, the
   Renovate token, the `stable` branch, branch protection on both branches, and
   the labels. Every step has a `gh` command and a GitHub-website route, and the
   skill ends by auditing that each setting matches.

## What's included

**Build system**

- A build on every push to `main`, publishing `:stable-testing`
- Renovate through `projectbluefin/actions`, updating pinned actions and image
  digests every six hours
- Images older than 90 days pruned automatically
- Pull requests validated for shellcheck, hadolint, Brewfiles, Flatpaks,
  Justfiles, and Renovate config
- Keyless OIDC signing on every published image, enforced at promotion
  ([where the signature is checked](#where-the-signature-is-checked))

**Runtime**

- Homebrew, pre-staged at build time and unpacked on first boot
- Flatpaks declared in `custom/flatpaks/`, installed on first boot
- `ujust` shortcuts for the Brewfiles and for re-applying configuration
- `uupd` for scheduled system updates

## Customize

Pick your base image on the `Containerfile`'s `FROM` line; the template defaults
to Fedora Silverblue. That line is the only place the base is chosen: `just build`
reads the image name and the tag from it, and the Fedora major comes from the
base image itself during the build.

Then add to your image:

- **System packages** — `build/20-packages-and-services.sh` ([guide](build/README.md))
- **CLI tools** — `custom/brew/` ([guide](custom/brew/README.md))
- **GUI apps** — `custom/flatpaks/` ([guide](custom/flatpaks/README.md))
- **Commands** — `custom/ujust/` ([guide](custom/ujust/README.md))

[The `customize` skill](.agents/skills/customize/SKILL.md) decides which of
those a given package belongs in.

## Releases

| Branch   | Image tag         | Audience                       |
| -------- | ----------------- | ------------------------------ |
| `main`   | `:stable-testing` | Testers and release candidates |
| `stable` | `:stable`         | Production                     |

Merging to `main` publishes `:stable-testing`; the promotion PR that follows
publishes `:stable` when merged. Promotion verifies the cosign signature on the
testing image before it reports ready, and refuses to promote at all once `main`
has moved past the commit the promotion PR was built from.

> **Known gap:** the promotion gate checks the digest and the signature only. It
> runs no end-to-end tests, so `release/ready` means "signed and unmodified",
> not "functionally validated".

## Image signing

Images are signed with keyless OIDC via Cosign and GitHub Actions. There is no
key to generate or store.

```bash
cosign verify \
  --certificate-identity-regexp="https://github.com/your-username/your-repo-name/.github/workflows/" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ghcr.io/your-username/your-repo-name:stable
```

Unsigned images fail the promotion gate, so `main → stable` reports
`release/blocked` until signing is restored.

### Where the signature is checked

**In CI, on the way to `:stable` — and not verified on the device.** The
promotion gate is the only enforcement point. An installed system pulls its
updates over an unverified transport (`image-info.json`'s `image-ref` is
`ostree-unverified-image:docker://…`), so `bootc upgrade` does not check the
cosign signature.

That is a deliberate statement of what the image can actually do, not an
oversight. Device-side verification runs through
`/etc/containers/policy.json`, which matches a keyless Fulcio certificate on
`subjectEmail` only — mandatory and exact. A GitHub Actions certificate
identifies its workflow in a URI SAN and carries no email, so no policy entry
can match it, and the inherited policy's `""` catch-all
(`insecureAcceptAnything`) would accept the image regardless. A signed-looking
`image-ref` here would verify nothing while implying it verified something.

Making updates verify on the device means signing with a key the policy can
name: publish with a cosign keypair, merge a `sigstoreSigned` scope for your
namespace into the inherited policy (with `jq`, during
[`build/10-overlay.sh`](build/10-overlay.sh) — never by shipping a whole
`policy.json` through `custom/files/`, which freezes every scope you inherited),
add a `registries.d` entry with `use-sigstore-attachments: true` for it, and
flip `IMAGE_REF` back to `ostree-image-signed:`. Validate that on a real
install before shipping it: a scope that does not match turns `bootc upgrade`
into a hard refusal. `tests/contract/image-signing_test.bats` holds the two
sides together, so changing one without the other fails the suite.

## Using your image

Switch to a built image:

```bash
sudo bootc switch --transport registry ghcr.io/your-username/your-repo-name:stable-testing
sudo systemctl reboot
```

Then, as your user:

```bash
ujust install-default-apps    # Homebrew: the default Brewfile
ujust install-dev-tools       # Homebrew: the development Brewfile
ujust configure-dev-groups    # add yourself to docker and libvirt
ujust install-config          # re-apply the image defaults, backing up yours
```

First boot unpacks Homebrew and installs the declared Flatpaks; both need a
network connection. Check them with `systemctl status brew-setup.service` and
`systemctl status flatpak-preinstall.service`.

## Local testing

```bash
just build            # build the container image
just build-qcow2      # build a QCOW2 disk image
just run-vm-qcow2     # boot it in a browser-based VM
just build-iso        # build an installer ISO
just test-unit        # run the test suite
```

## Troubleshooting

[The `troubleshooting` skill](.agents/skills/troubleshooting/SKILL.md) covers
build, CI, and runtime failures symptom-first. The two most common first-boot
surprises:

- **No Flatpaks.** `flatpak-preinstall.service` needs a network connection and
  reports success even when it cannot reach Flathub, so a first boot before
  Wi-Fi is configured installs nothing. Reboot once you are online.
- **No `brew`.** `brew-setup.service` unpacks Homebrew on first boot; check its
  status before reaching for a reinstall.

## Community

- [Universal Blue Discord](https://discord.gg/WEu6BdFEtp)
- [bootc discussions](https://github.com/bootc-dev/bootc/discussions)

## Learn more

- [Universal Blue](https://universal-blue.org/)
- [bootc](https://containers.github.io/bootc/)
- [Project Bluefin contributing guide](https://docs.projectbluefin.io/contributing/)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
