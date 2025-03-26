📋 blog‑check

> A macOS/zsh script for auditing Blogger custom‑domain DNS settings, Google Search Console verification, propagation status, and root‑to‑www forwarding.

---

🚀 Features

- ✅ **Self‑Test Environment** (dig, ping, curl)
- 🔍 **DNS Audit & Propagation**  
  - Verify CNAMEs for `www`, optional subdomain, and Google Search Console  
  - Compare resolution across public (8.8.8.8, 1.1.1.1, 9.9.9.9) vs authoritative nameservers  
- 🔄 **Root‑Domain Forwarding Validation**  
- 🔒 **Blogger HTTPS Status** (Availability + HTTP→HTTPS redirect)  
- ⚠️ **Nameserver Sanity Check** (detects “glue‑style” NS misconfiguration)  
- 🛠 **Advanced Diagnostics** (`--advanced` flag): traceroute + subdomain enumeration  
- 🐞 **Debug Mode** (`--debug` flag): raw `dig +trace` + full HTTP headers  


📋 Requirements

- **OS:** macOS (zsh)  
- **Required CLI Tools:** `dig`, `curl`, `ping`  
- **Optional (for advanced):** `traceroute`, `subfinder`


💾 Installation

```bash
git clone https://github.com/<your-username>/blog-check.git
cd blog-check
chmod +x blog-check.sh


⚙️ Usage

./blog-check.sh [--advanced] [--debug]
Flag	Description
--advanced	Run traceroute (4 hops) & subdomain enumeration
--debug	Dump raw DNS trace & full HTTP headers for troubleshooting


📝 Changelog

✨ v4.4 (2025‑03‑26)
- ✅ **Added** dual‑mode root‑domain detection: Blogger A‑records **or** registrar DNS‑forwarding  
- 💡 **Enhanced** root‑domain logic to clearly distinguish Blogger vs registrar vs misconfigured states  
- 🔧 **Fixed** duplicate header block and trailing `echo"` typo  
- 📝 **Updated** DESCRIPTION (renumbered items; removed obsolete Squarespace section)  
- ✅ **Improved** DEPENDENCIES spelling (“Alternative”)

✨ v4.3 (2025‑03‑26)
- ✅ **Added** Nameserver Sanity check (detect glue‑style NS)  
- ✅ **Added** Root A‑Record presence validation  
- ✅ **Added** Blogger HTTPS status (availability + redirect)  
- ⚡ **Enhanced** DNS audit to show separate public vs authoritative propagation counts  
- ⚡ **Enhanced** strict root‑forwarding validation (301 → https://www.<CUSTOM_DOMAIN>/)  
- 🐛 **Fixed** zsh syntax errors (nested tests, read‑only variable)  
- 🐛 **Fixed** variable collisions (`http_status`, `forward_status`)  
- ⚡ **Improved** HTTP header fetch consolidation  
- ➕ **New** `--debug` flag (raw `dig +trace` + full headers)

🛠 v4.2 → v4.3
- 🐛 Minor bug fixes & documentation polish

🚀 v4.0 (TEMPLATE)
- 🚧 Initial script: basic DNS audit, propagation, and forwarding checks


🤝 Contributing

This script was created as a one‑time, standalone audit tool.

If you’d like to adapt or extend it for your own needs, please **fork** this repository and customize it however you like.

Pull requests are welcome **only** for:
- Documentation improvements  
- Minor bug fixes  

Major feature changes or rewrites will **not** be merged into the main branch — please maintain your own fork for larger adaptations.
