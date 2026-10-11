# OPNsense setup guide for the JengaSec gateway — DRAFT v0.1

Scope: the `net` VM on Server 3 (2 vCPU, 4 GB per the architecture draft). Menu names vary slightly between OPNsense versions, so treat the paths as guides.
**First ask Network what already exists** (VM created? ISO installed? interfaces assigned?). Skip any step they have already done, and agree who does what: Network builds, SEC owns the rules.

## 0. Before you touch anything
- Snapshot the VM in Proxmox before each major change (baseline, after interfaces, after WireGuard, after rules).
- Keep Proxmox console access open the whole time. A bad rule can lock you out of the GUI; the console cannot be locked out.
- Never type or paste real credentials into chat. Put them straight into the password manager.

## 1. Proxmox side (Network or Platform)
1. `vmbr1` must be VLAN-aware (Proxmox host > System > Network: tick "VLAN aware"). It carries VLANs 101-109 to the MikroTik switch.
2. Create the VM: amd64, CPU type `host`, 2 vCPU, 4 GB RAM, 20-30 GB disk, VirtIO NICs, QEMU guest agent off (not needed).
3. NICs (confirm the uplink design with Network):
   - `net0`: uplink / backbone leg (VLAN 32 backbone 10.10.32.0/24 per the draft; Network decides how it reaches the VM).
   - `net1`: on `vmbr1`, **no VLAN tag** (trunk). Allow VLANs 101-109 only: in the VM config `net1: virtio=<mac>,bridge=vmbr1,trunks=101;102;103;104;105;106;107;108;109`.
4. **Untick "Firewall" on every VM NIC.** Proxmox's own firewall in front of OPNsense causes confusing drops.
5. Download the OPNsense amd64 DVD ISO from the official site and **verify its SHA256 checksum** against the published value before use.

## 2. Install
1. Boot the ISO, log in as the installer user (documented in the OPNsense docs), run the guided install onto the VM disk (UFS or ZFS, either is fine).
2. Reboot, remove the ISO.
3. On the console menu: **Assign interfaces** (net0 = WAN/uplink, net1 = trunk parent, no VLANs yet).
4. Set the temporary management address on the console, then **immediately change the root password** (default is documented publicly) and store the new one in the password manager.

## 3. Base configuration (GUI)
- System > Settings > General: hostname `gw`, domain `jengasec.local` (or agreed), timezone, DNS.
- **Time sync:** System > Settings > General / Services > Network Time: confirm NTP works. Correct time matters because all evidence and scoring depend on timestamps.
- System > Firmware: update to the latest stable release, reboot, **then freeze the version** (no surprise upgrades during the event). Take a snapshot.
- Interfaces > Settings: **disable hardware checksum, TSO and LRO offloading** (common cause of VirtIO packet problems), then reboot.

## 4. Interfaces and VLANs
Interfaces > Devices > VLAN: create VLANs 101-109 with parent = the trunk NIC. Then Interfaces > Assignments: add each, enable, set static IPv4:

| VLAN | Name | Gateway address |
|---|---|---|
| 101 | MGMT | 10.101.0.1/24 |
| 102 | STAFF | 10.102.0.1/24 |
| 103 | JUDGES | 10.103.0.1/24 |
| 104 | RED_AI | 10.104.0.1/24 |
| 105 | RED_APP | 10.105.0.1/22 |
| 106 | BLUE_AI | 10.106.0.1/24 |
| 107 | BLUE_APP | 10.107.0.1/23 |
| 108 | APPS | 10.108.0.1/24 |
| 109 | FUNCTIONS | 10.109.0.1/24 (draft: net = .1) |

Note: the draft recommends merging 104-107 into one "Teams" VLAN on Wi-Fi. If that is confirmed (open question 10), Network decides the Teams subnet; adjust this table and the DHCP step.
Do not enable DHCP on 101, 108 or 109. Servers get static addresses (web .10, shared .20, obs .30, k8s-blue .50).

## 5. DHCP
- Use the DHCP service your version provides (Kea in recent releases) on the people-facing VLANs only: staff, judges and the participant/Teams VLAN(s).
- Laptops get ordinary DHCP addresses. The fixed identity is the WireGuard address, not the Wi-Fi one.

## 6. Admin access hardening (do this early)
1. System > Access > Users: create **named admin accounts** (one per person), add SSH public keys, give only the privileges each role needs.
2. System > Settings > Administration:
   - SSH on, **permit root login off, password login off** (keys only), listen on MGMT/STAFF interfaces only.
   - Web GUI: listen on MGMT/STAFF interfaces only.
3. Test a named admin login (GUI and SSH key) in a **second session** before disabling the root login.
4. Retire the shared bootstrap login (or schedule it with a date).
5. Create a dedicated API user `provisioning` for the scripts. Give it only the privileges for aliases and WireGuard peers. Create its key and secret, store them in the vault, and add a firewall rule so the API/GUI port is reachable only from the shared VM (10.109.0.20).
6. Another API credential for the kill switch, held only by the two named owners, with privileges limited to toggling the kill rule and killing states.

## 7. WireGuard
1. VPN > WireGuard (core in recent versions; the `os-wireguard` plugin on older ones).
2. Create one instance: listen port **51820**, generate the server keypair (the private key stays on the gateway and is never exported), tunnel addresses covering the team ranges: 10.60.0.0/16 (Red App), 10.61.0.0/16 (Blue App), 10.62.0.0/16 (Blue AI), 10.63.0.0/24 (staff/judges remote), 10.64.0.0/16 (Red AI). Network may prefer one instance per class; either works.
3. Add peers. For every peer: its public key and **allowed IPs = exactly its own /32** (this is the anti-spoofing control). Prefer participants generating their own keypairs and submitting the public key.
4. Assign the WireGuard interface (Interfaces > Assignments) and enable it, so rules can be written on it. Confirm with Network which interface or group the rules go on.
5. Client configs: client AllowedIPs lists only the networks they should route into the tunnel (e.g. 10.108.0.0/24, website IP), not 0.0.0.0/0. The firewall, not the client config, is the security control.
6. Confirm UDP 51820 is reachable from the participant VLANs and nothing else is.

## 8. NAT
- Firewall > NAT > Outbound: team ranges must not be translated when going to apps (the draft's no-NAT rule). Internal VLAN-to-VLAN routing is not NATed by default; check there are no rules matching 10.60-10.64 or 10.108.
- Allow outbound NAT only on the uplink for staff and the few allowed egress cases.

## 9. Aliases and rules
1. Create the aliases in `opnsense-ruleset-spec.md` section 2 (hand-create a few for tomorrow; make-scope.py generates the rest).
2. Delete or disable the default allow-all rules on every interface.
3. Add the rules in the spec's section 3. Log every block rule.
4. Keep the anti-lockout rule until the management allow rule works and you've tested it, then decide whether to remove it.

## 10. Kill switch
- Create the kill rule as a **floating, quick** block rule at the top for the alias `RED_ALL`, normally disabled.
- Create it in the new rules UI (the toggle API applies to those rules). Note its UUID.
- Cut: toggle on, apply, then kill states.
  - `POST /api/firewall/filter/toggle_rule/<uuid>/1` then `POST /api/firewall/filter/apply`
  - `POST /api/diagnostics/firewall/kill_states/` with body `{"filter": "<ip>"}`
- Restore: `POST /api/firewall/filter/toggle_rule/<uuid>/0`, then apply.
- Authenticate with the kill-switch API key and secret (HTTP Basic). These endpoint names are from public client code; **verify them against your OPNsense version's API docs and test before relying on them**, and test whether `filter` accepts a subnet or needs one call per IP.

## 11. Logging, telemetry, IDS
- System > Settings > Logging > Targets (remote syslog): obs VM `10.109.0.30:514`.
- Reporting > NetFlow: collector `10.109.0.30:2055`, capture on the participant-facing and WireGuard interfaces.
- Services > Intrusion Detection (Suricata): start in **IDS mode only**, on the WireGuard and APPS interfaces, and watch the 2 vCPU. Only enable what the CPU can handle.
- Turn on logging for the block rules (rules 2, 3, 10, 14, 16).

## 12. Backups
- System > Configuration > Backups: download the config **encrypted with a password** after every significant change.
- The config contains the WireGuard private key and password hashes. Store backups off-repo with Tier 0 access; the encryption password goes in the password manager.
- Also keep the Proxmox snapshots.

## 13. Minimum viable set for the test run
If time is short, do this much: sections 2-4 (install, VLANs, interfaces), section 6 steps 1-3 (named admin, key-only SSH), section 7 with three test peers (Red, Blue, Blue), the aliases for those three, rules 0-3, 4, 8, 10 and 16, then run tests A1-A13 and K1-K5 from `test-run-plan.md`.
