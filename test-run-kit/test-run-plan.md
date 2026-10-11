# Test run plan — firewall and secrets (SEC)

Fill in Result with PASS / FAIL / NOTES. Everything marked "expect" is from the architecture draft.
Test from: (T1) laptop on Teams Wi-Fi, no tunnel; (T2) Red team 2 peer, e.g. 10.60.2.14; (T3) Blue team 1 peer, e.g. 10.61.1.10; (T4) Blue team 2 peer; (T5) staff.
Replace IPs with whatever test peers Network actually creates.

## A. Firewall

| # | Test | From | Command | Expect | Result |
|---|---|---|---|---|---|
| A1 | Only WG port open | T1 | `nmap -Pn -sU -p 51820 <gw-ip>`; `nmap -Pn -p- --min-rate 1000 <gw-ip>` | UDP 51820 open|filtered; no TCP ports open | |
| A2 | Can't see Mgmt | T1 | `nmap -Pn -sn 10.101.0.0/24` ; `ping 10.101.0.1` | No replies | |
| A3 | Can't see apps without tunnel | T1 | `curl -m5 http://10.108.0.11` | Timeout | |
| A4 | Red reaches its one app | T2 | `curl -m5 -i http://10.108.0.11:<port>` | Response | |
| A5 | Red can't reach another app (same enterprise) | T2 | `curl -m5 http://10.108.0.12:<port>` | Timeout; **scope violation logged** | |
| A6 | Red can't reach the same app in the other enterprise | T2 | `curl -m5 http://10.108.0.21:<port>` | Timeout, logged | |
| A7 | Red can't reach Mgmt, Functions, school LAN | T2 | `nmap -Pn -p 22,443,3000 10.101.0.1 10.109.0.30 <school-host>` | All filtered | |
| A8 | Red can reach website | T2 | `curl -m5 -k https://<web-ip>` | Response | |
| A9 | Blue reaches its own app only | T3 | `curl` own IP vs. another app IP | Own: OK. Other: timeout | |
| A10 | No Blue to Blue | T3 to T4 | `ping 10.61.2.10` from T3; `nc -vz -w3 10.61.2.10 22` | No reply | |
| A11 | No Blue to Red | T3 | `ping 10.60.2.14` | No reply | |
| A12 | No NAT: real source seen | T2 | On k8s-blue: `sudo tcpdump -ni any host 10.108.0.11 and port <port>` while curling | Source shows 10.60.2.x, not the gateway address | |
| A13 | Source spoofing blocked | T2 | `sudo ip addr add 10.60.2.99/24 dev wg0` then `curl --interface 10.60.2.99 -m5 http://10.108.0.11` | Fails (not in the peer's AllowedIPs) | |
| A14 | Blocks reach the collector | T2 | After A5-A7, check OPNsense Live View, then Loki/Grafana on obs | Blocks logged and visible with src label | |
| A15 | AI API reachable by AI teams only | AI test peer | `curl -m5 -k https://10.109.0.30:8443` | Reachable from AI Blue/Red; **not** from App Blue or App Red | |
| A16 | Egress allow-list | AI peer | `curl -m5 https://<declared-model-host>` vs `curl -m5 https://example.com` | Declared: OK. Other: blocked | |
| A17 | Rate limit | T2 | `hping3` is not needed: run a burst, e.g. `for i in $(seq 1 500); do curl -s -o /dev/null -m2 http://10.108.0.11:<port>; done` | Rate-limited as configured; gateway CPU stays sane | |

### Kill switch
| # | Test | Steps | Expect | Result |
|---|---|---|---|---|
| K1 | Cuts new traffic | T2 loops `curl` every second. Enable rule 0. | New requests fail within 10 s | |
| K2 | Cuts established sessions | T2 holds a long-lived connection (`nc 10.108.0.11 <port>` or `ssh`-style stream). Enable rule 0 **and** kill states. | Connection dies within 10 s. Check it also dies if you skip the state kill (shows why it's needed) | |
| K3 | Blue and staff unaffected | While K1 is on, T3 and T5 test their access | Still working | |
| K4 | Restore | Disable rule 0 | T2 recovers (may need to reconnect) | |
| K5 | Time it | Stopwatch from "toggle" to "first failure" | Under 10 s | |
| K6 | Via API, by the second owner | Run from the staff VLAN | Works only for the named owners | |

## B. Firewall access and hygiene
| # | Check | Expect | Result |
|---|---|---|---|
| B1 | Default LAN allow-any rule removed on every interface | Gone | |
| B2 | OPNsense GUI/SSH not reachable from T1, T2, T3 | Filtered | |
| B3 | Admin accounts are named; shared login disabled (or scheduled, with date) | Yes | |
| B4 | SSH: key-only, no root | Yes | |
| B5 | API user "provisioning": minimal rights, source-limited to shared VM | Yes | |
| B6 | Config backup taken, stored encrypted, not in the repo | Yes | |
| B7 | Outbound NAT does not translate team ranges | Confirmed | |
| B8 | Peer AllowedIPs are single /32s | Spot-check 5 peers | |

## C. Secrets
| # | Check | Expect | Result |
|---|---|---|---|
| C1 | `pre-commit run --all-files` | Passes on repo | |
| C2 | Try committing a fake token and a plaintext `vault.yml` | Both blocked | |
| C3 | `ansible-vault view` works with the `platform` ID and fails without it | Yes | |
| C4 | Vault passwords exist only in `~/.jengasec/` (mode 600) on Tier 0 machines | Yes | |
| C5 | `docs/secrets.md` inventory covers every credential seen during the test run | Add rows for anything new | |
| C6 | Any credential pasted into chat during the test | Rotate it | |
| C7 | WireGuard private keys: where are they generated and stored? | Prefer client-side; none in the DB | |
| C8 | Team pull tokens (GHCR/Docker Hub): where stored, when deleted | Encrypted; deleted after freeze | |

## D. Things to write down during the run
- Every credential you or anyone else had to use (to add to the inventory, with the place it lives).
- Every flow that was blocked that should have worked, or worked that should have been blocked.
- Latency and CPU of the net VM under the device count tested.
