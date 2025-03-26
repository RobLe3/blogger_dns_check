📋 blog‑check
An easy‑to‑use tool that instantly verifies your custom Blogger domain is set up correctly. In one command it:
Checks your internet connection and DNS (domain name) is working
Confirms your website address (e.g., www.yourdomain.com) points to Blogger
Ensures any extra blog subdomain and Google Search Console verification record are live everywhere
Verifies your root domain (yourdomain.com) correctly redirects visitors to the secure “www” address
Makes sure HTTPS (the little padlock in browsers) is enabled and forced
▶️ No technical knowledge required — you’ll see clear ✅ passes, ⚠ warnings, or ✗ failures for each step.
▶️ Add --advanced for deeper network diagnostics or --debug for full raw DNS and HTTP details.


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
    git clone https://github.com/RobLe3//blog-check.git
    cd blog-check

🐚 Shell version
    chmod +x blog-check.sh

🐍 Python version
    pip install -r requirements.txt


⚙️ Configuration
Open either script (blog-check.sh or blog-check-template.py) in your editor and replace the following defaults with your own values:

        CNAME_1_HOST="abcd1234"
        CNAME_1_TARGET="gv-xxxxxxx.dv.googlehosted.com"
        WWW_TARGET="ghs.google.com"
        BLOG_SUBDOMAIN="blog"
        BLOGSPOT_DOMAIN="example.blogspot.com"
        CUSTOM_DOMAIN="example.com"

⚙️ Usage

Shell
    ./blog-check.sh [--advanced] [--debug]

Python
    ./blog-check.py [--advanced] [--debug]

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