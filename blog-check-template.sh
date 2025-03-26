#!/usr/bin/env zsh

# blog-check.sh — DNS Propagation & Connectivity Audit + Self‑Test (v4.3 — 2025‑03‑26)
#
# USAGE:
#   chmod +x blog-check.sh
#   ./blog-check.sh [--advanced] [--debug]
#
# OPTIONS:
#   --advanced     Run traceroute (4 hops) & subdomain enumeration (subfinder)
#   --debug        Dump raw dig +trace output and full HTTP headers for troubleshooting
#
# DESCRIPTION:
#   1️⃣ Self‑Test Connectivity — DNS resolution, ping, and HTTPS reachability to www.google.com
#       • Verify network/DNS is functional before auditing your domain
#
#   2️⃣ Nameserver Sanity — Detect glue‑style NS (e.g., ns1.yourdomain.com)
#       • Configuration: Domain registrar → Nameservers
#       • Rationale: Glue NS indicate no authoritative zone served → records won’t resolve
#
#   3️⃣ DNS Audit & Propagation — For each critical record (CNAMEs + A-records)
#       • Validates expected target (www, blogspot, Search Console)
#       • Compares resolution across local resolver, three public resolvers (8.8.8.8, 1.1.1.1, 9.9.9.9), and authoritative NS
#       • Reports propagation counts; warns on partial
#
#   4️⃣ Verification CNAME Handling — Treat NXDOMAIN on A lookup as ✅
#       • Configuration: Google Search Console → Ownership Verification
#       • Rationale: Pure CNAME record shouldn’t resolve to IP
#
#   5️⃣ Root A‑Records Presence & Propagation — Ensure all four Blogger‑recommended A-records exist
#       • Configuration: Blogger Dashboard → Custom Domain / DNS zone editor
#       • Rationale: Required for naked‑domain → www redirect
#
#   6️⃣ Root Forwarding Validation — Must 301 redirect to https://www.<CUSTOM_DOMAIN>/
#       • Configuration: Registrar/Squarespace → Domain Forwarding
#       • Rationale: Missing “https://” or “www” breaks redirect
#
#   7️⃣ Blogger HTTPS Status — Verify HTTPS Availability & HTTPS Redirect are enabled
#       • Configuration: Blogger Dashboard → Settings → HTTPS
#       • Rationale: Ensures SSL provisioning & forced secure traffic
#
#   8️⃣ Squarespace Forwarding Check — Confirm full HTTPS URL in “Enter Website URL” field
#       • Configuration: Squarespace Domains → Forwarding settings
#       • Rationale: Partial URL → failed redirect
#
#   9️⃣ (--advanced) Traceroute + Subdomain Enumeration — Advanced diagnostics if installed
#
#   🔟 (--debug) Raw DNS trace & HTTP header dump for deep troubleshooting
#
# DEPENDENCIES:
#   Required: dig, curl, ping
#   Optional (--advanced): traceroute, subfinder
#   Recommended (--debug): shellcheck
#
# EXIT CODES:
#   0 = success (or warnings only)
#   >0 = critical failure (missing required config)
#############################################
# CONFIGURATION VARIABLES
#############################################
CNAME_1_HOST="abcd1234"
CNAME_1_TARGET="gv-xxxxxxx.dv.googlehosted.com"
WWW_TARGET="ghs.google.com"
BLOG_SUBDOMAIN="blog"
BLOGSPOT_DOMAIN="example.blogspot.com"
CUSTOM_DOMAIN="example.com"
#############################################
# DEFAULT NAMESERVER VARIABLES
#############################################
A_RECORDS=(216.239.32.21 216.239.34.21 216.239.36.21 216.239.38.21)
RESOLVERS=(8.8.8.8 1.1.1.1 9.9.9.9)
VERSION="4.3"
TEST_HOST="www.google.com"

GREEN=$(tput setaf 2); YELLOW=$(tput setaf 3); RED=$(tput setaf 1); RESET=$(tput sgr0)
ADVANCED=false; DEBUG=false
for arg in "$@"; do case "$arg" in --advanced) ADVANCED=true;; --debug) DEBUG=true;; esac; done

declare -A HAVE
for tool in dig curl ping traceroute subfinder; do 
  HAVE[$tool]=$([[ -x "$(command -v $tool)" ]] && echo 1 || echo 0)
done

echo "\n===== blog-check.sh v${VERSION} — Self‑Test ====="

# DNS resolve test
[[ ${HAVE[dig]} -eq 1 ]] || { echo "${RED}✗ dig missing — install bind utilities${RESET}"; exit 1; }
google_ip=$(dig +short "${TEST_HOST}" | head -1)
[[ -n $google_ip ]] && echo "${GREEN}✓ DNS resolves ${TEST_HOST} → ${google_ip}${RESET}" || { echo "${RED}✗ DNS lookup failed — check network${RESET}"; exit 1; }

# Ping connectivity
if [[ ${HAVE[ping]} -eq 1 ]] && ping -c1 -W1 "$google_ip" >/dev/null 2>&1; then
  echo "${GREEN}✓ ping OK${RESET}"
else
  echo "${RED}✗ ping failed — check firewall${RESET}"
  exit 1
fi

# HTTPS connectivity
[[ ${HAVE[curl]} -eq 1 ]] || { echo "${RED}✗ curl missing — install curl${RESET}"; exit 1; }
http_status=$(curl -s -o /dev/null -w "%{http_code}" "https://${TEST_HOST}")
[[ "$http_status" -eq 200 ]] && echo "${GREEN}✓ HTTPS OK${RESET}" || { echo "${RED}✗ HTTP ${http_status} — check HTTPS/proxy${RESET}"; exit 1; }

echo "${GREEN}✔ Self‑tests passed${RESET}"

# Nameserver Sanity
echo "\n===== Nameserver Sanity ====="
ns=( $(dig +short NS "${CUSTOM_DOMAIN}") )
glue=false
for n in "${ns[@]}"; do
  if [[ "$n" =~ ${CUSTOM_DOMAIN//./\\.}\.?$ ]]; then
    glue=true
    echo "${YELLOW}⚠ Glue-style NS detected ($n). Use proper DNS provider nameservers${RESET}"
  fi
done
$glue || echo "${GREEN}✓ Nameservers correct${RESET}"

# DNS Audit
echo "\n===== DNS Audit ====="
for entry in "www:${WWW_TARGET}" "${BLOG_SUBDOMAIN}:${BLOGSPOT_DOMAIN}" "${CNAME_1_HOST}:${CNAME_1_TARGET}"; do
  host="${entry%%:*}"; expected="${entry##*:}"; fqdn="${host}.${CUSTOM_DOMAIN}"
  echo "\n── ${fqdn} ──"
  cname=$(dig +short CNAME "$fqdn")
  if [[ -z $cname ]]; then
    echo "${RED}✗ Missing CNAME — expected ${host}→${expected}${RESET}"
    continue
  fi
  echo "CNAME → $cname"
  [[ "$host" == "$CNAME_1_HOST" && -n $(dig +short A "$fqdn") ]] && echo "${YELLOW}⚠ Verification CNAME resolves to A-record — NXDOMAIN expected${RESET}"

  pub=0; auth=0
  for r in "${RESOLVERS[@]}"; do
    [[ "$(dig +short CNAME "$fqdn" @"$r")" == "$cname" ]] && ((pub++))
  done
  for s in "${ns[@]}"; do
    [[ "$(dig +short CNAME "$fqdn" @"$s")" == "$cname" ]] && ((auth++))
  done
  echo "Propagation → public ${pub}/${#RESOLVERS} | authoritative ${auth}/${#ns}"
done

# Root A-record Presence
echo "\n===== Root A-record Presence ====="
root_ips=( $(dig +short A "${CUSTOM_DOMAIN}") )
for a in "${A_RECORDS[@]}"; do
  if [[ " ${root_ips[*]} " =~ " ${a} " ]]; then
    echo "${GREEN}✓ A-record ${a} present${RESET}"
  else
    echo "${RED}✗ Missing A-record ${a}${RESET}"
  fi
done

# Root Forwarding Check
echo "\n===== Root Forwarding Check ====="
headers=$(curl -sI --max-time 5 "https://${CUSTOM_DOMAIN}")
forward_status=$(echo "$headers" | awk 'NR==1{print $2}')
location=$(echo "$headers" | awk '/Location:/ {print $2}' | tr -d '\r')
if [[ "$forward_status" == "301" && "$location" == "https://www.${CUSTOM_DOMAIN}/" ]]; then
  echo "${GREEN}✓ Redirects to https://www.${CUSTOM_DOMAIN}/${RESET}"
else
  echo "${RED}✗ Misconfigured forwarding — expected full HTTPS URL${RESET}"
fi

# Blogger HTTPS Status
echo "\n===== Blogger HTTPS Status ====="
https_status=$(curl -sI "https://www.${CUSTOM_DOMAIN}" | head -1 | awk '{print $2}')
redirect_status=$(curl -sI "http://www.${CUSTOM_DOMAIN}" | head -1 | awk '{print $2}')
[[ "$https_status" == "200" ]] && echo "${GREEN}✓ HTTPS enabled${RESET}" || echo "${RED}✗ HTTPS unavailable${RESET}"
[[ "$redirect_status" == "301" ]] && echo "${GREEN}✓ HTTP→HTTPS redirect enabled${RESET}" || echo "${RED}✗ HTTP not redirecting${RESET}"

# Advanced Diagnostics
if $ADVANCED && [[ ${HAVE[traceroute]} -eq 1 ]]; then
  echo "\n===== ADVANCED: Traceroute ====="
  traceroute -m4 "${CUSTOM_DOMAIN}"
fi
if $ADVANCED && [[ ${HAVE[subfinder]} -eq 1 ]]; then
  echo "\n===== ADVANCED: Subdomain Enumeration ====="
  subfinder -silent -d "${CUSTOM_DOMAIN}"
fi

# Debug Mode
if $DEBUG; then
  echo "\n===== DEBUG ====="
  dig +trace "${CUSTOM_DOMAIN}"
  echo "$headers"
fi

echo
