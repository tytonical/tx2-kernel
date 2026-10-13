# Fix policy

This tree is NVIDIA's L4T R32.7.6 kernel (Linux 4.9.337 base) for the Jetson TX2 NX, with
security fixes backported from later Linux releases, built with `configs/tx2nx-anpr.config`.
Linux 4.9 is no longer maintained upstream, so fixes for later CVEs are not available as stable
releases and have to be ported by hand. This document describes which fixes are applied and how.

## What is fixed

The aim is that no CVE is exploitable in this configuration under the threat model the tree is
maintained against (below). That is a target, not a guarantee: it depends on the CVE data
available at the time of each scan, on review judgement, and on how the kernel is configured
and used. `docs/FIXES.md` lists what has actually been applied.

Each CVE published against the 4.9 base is assessed against this configuration:

- **Code not compiled in this configuration.** No fix is applied. These are listed in
  `docs/cve-baseline.tsv` and in the release VEX as `vulnerable_code_not_present`.
- **Already fixed in the NVIDIA sources.** Recorded in `docs/cve-baseline.tsv`.
- **Reachable by an unprivileged local user, or from the network.** Fixed by backporting the
  upstream fix.
- **Reachable only with a capability that a hardened, capability-limited service would hold**
  (for example `CAP_NET_ADMIN` or `CAP_NET_RAW`). Fixed, because a compromised service must not be
  able to escalate further.
- **Reachable only with full privileges** (init-namespace root, `CAP_SYS_ADMIN` in the initial user
  namespace, `CAP_SYS_MODULE`, writing to block devices or loading crafted filesystem images).
  Not fixed as a rule, because such an attacker already controls the system. Small, low-risk fixes
  may still be taken.
- **Reachable only by physical access** (malicious USB devices, access to the board or boot media).
  Not fixed as a rule.
- **Small, low-risk fixes** may be applied even when the bug is not reachable, as hardening.
- **Reachable only through an optional feature** that the configuration does not need. The feature
  may be removed or refused instead of carrying the fix (for example `PACKET_TX_RING` and ext4
  `inline_data`). These local changes are listed separately in `docs/FIXES.md` and appear in the
  VEX as `vulnerable_code_not_in_execute_path`.

CVEs whose code is compiled and that are not fixed here are not listed in the VEX. Whether they
matter depends on how the kernel is deployed: for example, on whether unprivileged user
namespaces are enabled or which users can reach a given interface. Anyone deploying this kernel
should assess them against their own threat model.

## How fixes are applied

- The closest stable backport (4.14.y, 4.19.y, 5.4.y, 5.10.y) is the starting point when one
  exists; otherwise the mainline fix is used. Changes are kept to what the fix needs; adaptations
  to 4.9 are described in an `[ adapted for 4.9 ... ]` note in the commit message.
- Each fix is reviewed against the upstream commit and the surrounding 4.9 code (locking, reference
  counting, RCU and error paths), and later upstream corrections to it are taken as follow-ups.
- Commits carry trailers so the fix list can be generated: `CVE:` for a fix, `Related-to:` for a
  follow-up, `Mitigates:` for a local change that removes the vulnerable path,
  `Prerequisite-for:` for an upstream prerequisite, and `Backported-from:` for the stable commit
  used as the base.
- A fix that upstream stable later reverted, or that stable replaced with a different fix, is not
  applied. The tree should match the final stable state for every hunk it shares with stable.
- Every change must build cleanly with the release toolchain (the CI build) before it is merged.

## Threat model the tree is maintained against

- **In scope:** remote network attackers, attackers on the adjacent network, unprivileged local
  code, and a compromised capability-limited service trying to escalate.
- **Out of scope:** attackers with full privileges (see above), physical access, and hardware or
  drivers this configuration does not include.

## Releases

A release is tagged `release/<kernel version>-<suffix>`, for example `release/4.9.337-tyton-1`.
The kernel is built with that name as its release string (`uname -r`). Each release carries the
kernel image, device trees and modules, the fix list, and an OpenVEX document stating which CVEs
are fixed and which are in code not compiled in this configuration.
