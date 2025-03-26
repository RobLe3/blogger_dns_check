📋 blog‑check

A macOS/zsh and Python3 audit tool for verifying Blogger custom‑domain DNS settings, Google Search Console verification, propagation status, and root‑to‑www forwarding.


🚀 Features

✅ Self‑Test Environment (dig, ping, curl)
🔍 DNS Audit & Propagation
Verify CNAMEs for www, optional subdomain, and Search Console
Compare resolution across public (8.8.8.8, 1.1.1.1, 9.9.9.9) vs authoritative nameservers
🔄 Root‑Domain Forwarding Validation
🔒 Blogger HTTPS Status (Availability + HTTP→HTTPS redirect)
⚠️ Nameserver Sanity Check (detects “glue‑style” NS misconfiguration)
🛠 Advanced Diagnostics (--advanced flag): traceroute + subdomain enumeration
🐞 Debug Mode (--debug flag): raw dig +trace + full HTTP headers


📋 Editions

Script	Language	Filename	Requirements
Original Shell	zsh	blog-check.sh	macOS, dig, curl, ping
Python Port	Python3	blog-check-template.py	Python 3.9+, colorama, dig, curl, ping


💾 Installation

🐚 Shell version
git clone https://github.com/<your-username>/blog-check.git
cd blog-check
chmod +x blog-check.sh

🐍 Python version
git clone https://github.com/<your-username>/blog-check.git
cd blog-check
pip install -r requirements.txt


⚙️ Usage

Shell
./blog-check.sh [--advanced] [--debug]

Python
./blog-check-template.py [--advanced] [--debug]

Flag	Description
--advanced	Run traceroute (4 hops) & subdomain enumeration (subfinder)
--debug	Dump raw DNS trace (dig +trace) & full HTTP headers


📝 Changelog

✨ v4.4 (2025‑03‑26)
✅ Added dual‑mode root‑domain detection: Blogger A‑records or registrar DNS‑forwarding
💡 Enhanced forwarding logic
🐍 Introduced Python port (blog-check-template.py) with identical functionality
📝 Updated README to include Python specification

✨ v4.3 (2025‑03‑26)
Added Nameserver Sanity, Root A‑Record validation, Blogger HTTPS status, propagation counts, and debug flag


🤝 Contributing

Fork for major changes; PRs welcome for documentation fixes and minor bugs.