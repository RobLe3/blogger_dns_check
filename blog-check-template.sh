#!/usr/bin/env zsh

# blog-check-template.sh — DNS Propagation & Connectivity Audit + Self‑Test (v4.0 — TEMPLATE)
#
# Developed for macOS (zsh). Verifies that required CLI tools are installed:
#   • dig          → DNS resolution
#   • curl         → HTTP status checks
#   • ping         → connectivity
#   • traceroute   → network path diagnostics (optional, --advanced)
#   • subfinder    → subdomain enumeration (optional, --advanced)
#
# Description:
#   1) Self‑tests DNS, ping, and HTTP against www.google.com.
#   2) Validates Blogger CNAME records (www + optional subdomain) and Google verification CNAME.
#   3) Checks DNS propagation (public vs authoritative).
#   4) Confirms root domain → www forwarding.
#   5) (--advanced) Runs traceroute + subdomain enumeration if installed.
#
# Usage:
#   chmod +x blog-check-template.sh
#   ./blog-check-template.sh [--advanced]
#############################################
#            CONFIGURABLE VARIABLES
#############################################

# 1) Google Search Console Verification CNAME
CNAME_1_HOST="abcd1234"                                   # ← CNAME “Label / Host”
CNAME_1_TARGET="gv-xxxxxxx.dv.googlehosted.com"           # ← CNAME “Destination / Target”

# 2) Blogger’s required CNAME for “www”
WWW_TARGET="ghs.google.com"

# 3) (Optional) Secondary subdomain → your blogspot address
BLOG_SUBDOMAIN="blog"
BLOGSPOT_DOMAIN="example.blogspot.com"

# 4) Your custom domain
CUSTOM_DOMAIN="example.com"
#############################################

VERSION="4.0"
TEST_HOST="www.google.com"
HOSTS=(
  "www:${WWW_TARGET}"
  "${BLOG_SUBDOMAIN}:${BLOGSPOT_DOMAIN}"
  "${CNAME_1_HOST}:${CNAME_1_TARGET}"
)

GREEN=$(tput setaf 2); YELLOW=$(tput setaf 3); RED=$(tput setaf 1); RESET=$(tput sgr0)
ADVANCED=false; [[ "$1" == "--advanced" ]] && ADVANCED=true

declare -A HAVE
for tool in dig curl ping traceroute subfinder; do
  HAVE[$tool]=$([[ -x "$(command -v $tool)" ]] && echo 1 || echo 0)
done

echo "\n===== blog-check-template.sh v${VERSION} — Self‑Test ====="

# Self‑Tests
if [[ ${HAVE[dig]} -eq 1 ]]; then
  google_ip=$(dig +short "${TEST_HOST}" | head -1)
  [[ -z $google_ip ]] && { echo "${RED}✗ dig failed${RESET}"; exit 1; } \
    || echo "${GREEN}✓ dig resolves ${TEST_HOST} → ${google_ip}${RESET}"
else echo "${RED}✗ dig not installed${RESET}"; exit 1; fi

if [[ ${HAVE[ping]} -eq 1 ]] && ping -c1 -W1 "$google_ip" &>/dev/null; then
  echo "${GREEN}✓ ping OK${RESET}"
else echo "${RED}✗ ping failed${RESET}"; exit 1; fi

if [[ ${HAVE[curl]} -eq 1 ]]; then
  http_status=$(curl -s -o /dev/null -w "%{http_code}" "https://${TEST_HOST}")
  [[ $http_status -eq 200 ]] \
    && echo "${GREEN}✓ HTTP 200 OK${RESET}" \
    || { echo "${RED}✗ HTTP ${http_status}${RESET}"; exit 1; }
else echo "${RED}✗ curl not installed${RESET}"; exit 1; fi

echo "${GREEN}✔ Self‑tests passed — proceeding${RESET}"

if $ADVANCED && [[ ${HAVE[subfinder]} -eq 1 ]]; then
  echo "\n===== ADVANCED: Subdomain Enumeration ====="
  subfinder -silent -d "${CUSTOM_DOMAIN}"
fi

echo "\n===== DNS Audit ====="
for entry in "${HOSTS[@]}"; do
  host="${entry%%:*}"; expected="${entry##*:}"; fqdn="${host}.${CUSTOM_DOMAIN}"
  echo "\n── ${fqdn} ──"
  echo "Expected → ${expected}"
  cname=$(dig +short "${fqdn}" CNAME)
  [[ -z $cname ]] && { echo "${RED}✗ No CNAME${RESET}"; continue; }
  ip=$(dig +short "$cname" | head -1)
  echo "CNAME → ${cname} → IP ${ip:-none}"
  resolver_ok=0
  for r in 8.8.8.8 1.1.1.1 9.9.9.9; do
    [[ "$(dig +short "${fqdn}" CNAME @"$r")" == "$cname" ]] && ((resolver_ok++))
  done
  auth_ns=( $(dig +short NS "${CUSTOM_DOMAIN}") ); auth_ok=0
  for ns in "${auth_ns[@]}"; do
    [[ "$(dig +short "${fqdn}" CNAME @"$ns")" == "$cname" ]] && ((auth_ok++))
  done
  echo "Propagation → public ${resolver_ok}/3 | authoritative ${auth_ok}/${#auth_ns}"
done

echo "\n===== ROOT DOMAIN FORWARDING CHECK ====="
if [[ ${HAVE[curl]} -eq 1 ]]; then
  root_status=$(curl -sI --max-time 5 "https://${CUSTOM_DOMAIN}" | head -1 | awk '{print $2}')
  root_location=$(curl -sI --max-time 5 "https://${CUSTOM_DOMAIN}" | awk '/Location:/ {print $2}' | tr -d '\r')
  if [[ "$root_status" == "301" && "$root_location" == "https://www.${CUSTOM_DOMAIN}/" ]]; then
    echo "${GREEN}✓ Root → 301 → www${RESET}"
  else
    echo "${RED}✗ Forwarding misconfigured${RESET}"
    echo "  • Status: ${root_status:-none} | Location: ${root_location:-none}"
  fi
else
  echo "${YELLOW}⚠ curl unavailable${RESET}"
fi

if $ADVANCED && [[ ${HAVE[traceroute]} -eq 1 ]]; then
  echo "\n===== ADVANCED: Traceroute ====="
  traceroute -m4 "${CUSTOM_DOMAIN}"
fi

echo

