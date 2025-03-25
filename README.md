# blog‑check

A macOS/zsh script for auditing Blogger custom‑domain DNS settings, Google Search Console verification, propagation status, and root‑to‑www forwarding.

## Features

- Self‑test environment (dig, ping, curl)
- Verify Blogger CNAME records (www + optional subdomain)
- Verify Google Search Console verification CNAME
- Public vs authoritative DNS propagation checks
- Root‑domain HTTP → www redirect validation
- Optional advanced checks: traceroute & subdomain enumeration

## Requirements

- macOS (zsh)
- CLI tools: `dig`, `curl`, `ping` (builtin)
- Optional: `traceroute`, `subfinder`

## Installation

```bash
git clone https://github.com/<your‑username>/blog-check.git
cd blog-check
chmod +x blog-check-template.sh

