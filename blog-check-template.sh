#!/usr/bin/env zsh

# blog-check.sh — DNS Propagation & Connectivity Audit + Self‑Test (v4.4 — 2025‑03‑26)
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
#   1️⃣ Self‑Test Connectivity
#       • DNS resolution, ping, and HTTPS reachability to www.google.com  
#       • Rationale: Verify network/DNS is functional before auditing your domain
#
#   2️⃣ Nameserver Sanity
#       • Detect glue‑style NS (e.g., ns1.yourdomain.com)  
#       • Configuration: Domain registrar → Nameservers  
#       • Rationale: Glue NS indicate no authoritative zone served → records won’t resolve
#
#   3️⃣ DNS Audit & Propagation
#       • Validate expected CNAME/A targets (www, blogspot, Search Console)  
#       • Compare resolution across local resolver, three public resolvers, and authoritative NS  
#       • Reports propagation counts; warns on partial propagation
#
#   4️⃣ Verification CNAME Handling
#       • Treat NXDOMAIN on A lookup as ✅ for Search Console verification CNAME  
#       • Configuration: Google Search Console → Ownership Verification  
#       • Rationale: Pure CNAME records shouldn’t resolve to IP
#
#   5️⃣ Root A‑Records Presence & Forwarding
#       • Detect if root domain uses Blogger’s four recommended A‑records (216.239.32.21, .34.21, .36.21, .38.21)
#         **or** common registrar DNS‑forwarding IPs (198.49.x / 198.185.x)  
#       • Configuration: Blogger Dashboard → Custom Domain DNS (for Blogger)  
#                        Registrar → DNS Forwarding (for registrar)  
#       • Rationale: Ensures naked domain points somewhere valid — Blogger A‑records provide built‑in HTTPS redirect;
#                    registrar forwarding is valid but less flexible
#
#   6️⃣ Root Forwarding Validation
#       • If using Blogger A‑records, confirms HTTP 301 → https://www.<CUSTOM_DOMAIN>/  
#       • If using registrar forwarding, acknowledges redirect is handled externally  
#       • Configuration: Blogger Dashboard → Custom Domain redirect  
#                        Registrar → Forwarding URL  
#       • Rationale: Verifies visitors reach secure “www” site regardless of forwarding method
#
#   7️⃣ Blogger HTTPS Status
#       • Verify HTTPS Availability and HTTP→HTTPS redirect  
#       • Configuration: Blogger Dashboard → Settings → HTTPS  
#       • Rationale: Ensures SSL provisioning and forced secure traffic
#
#   8️⃣ (--advanced) Traceroute + Subdomain Enumeration
#       • Advanced diagnostics if installed (traceroute, subfinder)
#
#   9️⃣ (--debug) Raw DNS trace & HTTP header dump for deep troubleshooting
#
# DEPENDENCIES:
#   Required: dig, curl, ping
#   Optional (--advanced): traceroute, subfinder
#   Alternative (--advanced + --debug): traceroute, subfinder, shellcheck
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
RESOLVERS=(8.8.8.8 1.1.1.1 9.9.9.9)
VERSION="4.4"
TEST_HOST="www.google.com"

GREEN=$(tput setaf 2); YELLOW=$(tput setaf 3); RED=$(tput setaf 1); RESET=$(tput sgr0)
ADVANCED=false; DEBUG=false
for arg in "$@"; do case "$arg" in --advanced) ADVANCED=true;; --debug) DEBUG=true;; esac; done

declare -A HAVE
for tool in dig curl ping traceroute subfinder; do HAVE[$tool]=$([[ -x "$(command -v $tool)" ]] && echo 1 || echo 0); done

echo "\n===== blog-check.sh v${VERSION} — Self‑Test ====="

# Self‑Tests
[[ ${HAVE[dig]} -eq 1 ]] || { echo "${RED}✗ dig missing${RESET}"; exit 1; }
google_ip=$(dig +short "${TEST_HOST}" | head -1)
[[ -n $google_ip ]] && echo "${GREEN}✓ DNS resolves ${TEST_HOST} → ${google_ip}${RESET}" || { echo "${RED}✗ DNS lookup failed${RESET}"; exit 1; }

if [[ ${HAVE[ping]} -eq 1 ]] && ping -c1 -W1 "$google_ip" >/dev/null 2>&1; then
  echo "${GREEN}✓ ping OK${RESET}"
else
  echo "${RED}✗ ping failed${RESET}"; exit 1
fi

[[ ${HAVE[curl]} -eq 1 ]] || { echo "${RED}✗ curl missing${RESET}"; exit 1; }
http_status=$(curl -s -o /dev/null -w "%{http_code}" "https://${TEST_HOST}")
[[ "$http_status" -eq 200 ]] && echo "${GREEN}✓ HTTPS OK${RESET}" || { echo "${RED}✗ HTTP ${http_status}${RESET}"; exit 1; }

echo "${GREEN}✔ Self‑tests passed${RESET}"

# Nameserver Sanity
echo "\n===== Nameserver Sanity ====="
ns=( $(dig +short NS "${CUSTOM_DOMAIN}") ); glue=false
for n in "${ns[@]}"; do
  if [[ "$n" =~ ${CUSTOM_DOMAIN//./\\.}\.?$ ]]; then
    glue=true
    echo "${YELLOW}⚠ Glue-style NS detected ($n)${RESET}"
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
    echo "${RED}✗ Missing CNAME — expected ${host}→${expected}${RESET}"; continue
  fi
  echo "CNAME → $cname"
  [[ "$host" == "$CNAME_1_HOST" && -n $(dig +short A "$fqdn") ]] && echo "${YELLOW}⚠ Verification CNAME resolves to A-record — NXDOMAIN expected${RESET}"
  pub=0; auth=0
  for r in "${RESOLVERS[@]}"; do [[ "$(dig +short CNAME "$fqdn" @"$r")" == "$cname" ]] && ((pub++)); done
  for s in "${ns[@]}";        do [[ "$(dig +short CNAME "$fqdn" @"$s")" == "$cname" ]] && ((auth++)); done
  echo "Propagation → public ${pub}/${#RESOLVERS} | authoritative ${auth}/${#ns}"
done

# Root A-record Presence & Forwarding
echo "\n===== Root A-record Presence & Forwarding ====="
BLOGGER_IPS=(216.239.32.21 216.239.34.21 216.239.36.21 216.239.38.21)
FORWARD_IPS=(198.49.23.144 198.49.23.145 198.185.159.144 198.185.159.145)
root_ips=( $(dig +short A "${CUSTOM_DOMAIN}") )

blog_count=0; forward_count=0
for want in "${BLOGGER_IPS[@]}"; do [[ " ${root_ips[*]} " =~ " ${want} " ]] && ((blog_count++)); done
for want in "${FORWARD_IPS[@]}"; do [[ " ${root_ips[*]} " =~ " ${want} " ]] && ((forward_count++)); done

if [[ $blog_count -eq ${#BLOGGER_IPS[@]} ]]; then
  echo "${GREEN}✓ All Blogger A‑records present${RESET}"; mode="blogger"
elif [[ $forward_count -eq ${#FORWARD_IPS[@]} ]]; then
  echo "${YELLOW}⚠ Registrar DNS‑forwarding detected — recommend switching to Blogger A‑records${RESET}"; mode="registrar"
else
  echo "${RED}✗ A-record misconfigured${RESET}"
  echo "  Found: ${root_ips[*]:-none}"
  echo "  Expected Blogger: ${BLOGGER_IPS[*]}"
  echo "  Or Registrar: ${FORWARD_IPS[*]}"
  mode="invalid"
fi

if [[ "$mode" == "blogger" ]]; then
  headers=$(curl -sI --max-time 5 "https://${CUSTOM_DOMAIN}")
  status=$(echo "$headers" | awk 'NR==1{print $2}')
  location=$(echo "$headers" | awk '/Location:/ {print $2}' | tr -d '\r')
  if [[ "$status" == "301" && "$location" == "https://www.${CUSTOM_DOMAIN}/" ]]; then
    echo "${GREEN}✓ HTTP 301 → www${RESET}"
  else
    echo "${RED}✗ HTTP redirect misconfigured${RESET}"
  fi
elif [[ "$mode" == "registrar" ]]; then
  echo "${GREEN}✓ Registrar DNS‑forwarding — redirect handled externally${RESET}"
fi

# Blogger HTTPS Status
echo "\n===== Blogger HTTPS Status ====="
https_status=$(curl -sI "https://www.${CUSTOM_DOMAIN}" | head -1 | awk '{print $2}')
redirect_status=$(curl -sI "http://www.${CUSTOM_DOMAIN}" | head -1 | awk '{print $2}')
[[ "$https_status" == "200" ]] && echo "${GREEN}✓ HTTPS enabled${RESET}" || echo "${RED}✗ HTTPS unavailable${RESET}"
[[ "$redirect_status" == "301" ]] && echo "${GREEN}✓ HTTP→HTTPS redirect enabled${RESET}" || echo "${RED}✗ HTTP not redirecting${RESET}"

# Advanced Diagnostics
if $ADVANCED && [[ ${HAVE[traceroute]} -eq 1 ]]; then echo "\n===== ADVANCED: Traceroute ====="; traceroute -m4 "${CUSTOM_DOMAIN}"; fi
if $ADVANCED && [[ ${HAVE[subfinder]} -eq 1 ]]; then echo "\n===== ADVANCED: Subdomain Enumeration ====="; subfinder -silent -d "${CUSTOM_DOMAIN}"; fi

# Debug Mode
if $DEBUG; then
  echo "\n===== DEBUG ====="
  dig +trace "${CUSTOM_DOMAIN}"
  [[ -n $headers ]] && echo "$headers"
fi

echo