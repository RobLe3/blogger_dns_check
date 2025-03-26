#!/usr/bin/env python3
"""
blog_check.py — DNS Propagation & Connectivity Audit + Self‑Test (v4.4 — 2025‑03‑26)

USAGE:
    chmod +x blog_check.py
    ./blog_check.py [--advanced] [--debug]

OPTIONS:
    --advanced     Run traceroute (4 hops) & subdomain enumeration (subfinder)
    --debug        Dump raw dig +trace output and full HTTP headers for troubleshooting

DESCRIPTION:
 1️⃣ Self‑Test Connectivity
     • DNS resolution, ping, and HTTPS reachability to www.google.com  
     • Rationale: Verify network/DNS is functional before auditing your domain

 2️⃣ Nameserver Sanity
     • Detect glue‑style NS (e.g., ns1.yourdomain.com)  
     • Configuration: Domain registrar → Nameservers  
     • Rationale: Glue NS indicate no authoritative zone served → records won’t resolve

 3️⃣ DNS Audit & Propagation
     • Validate expected CNAME/A targets (www, blogspot, Search Console)  
     • Compare resolution across local resolver, three public resolvers, and authoritative NS  
     • Reports propagation counts; warns on partial propagation

 4️⃣ Verification CNAME Handling
     • Treat NXDOMAIN on A lookup as ✅ for Search Console verification CNAME  
     • Configuration: Google Search Console → Ownership Verification  
     • Rationale: Pure CNAME records shouldn’t resolve to IP

 5️⃣ Root A‑Records Presence & Forwarding
     • Detect if root domain uses Blogger’s four recommended A‑records (216.239.32.21, .34.21, .36.21, .38.21)
       **or** common registrar DNS‑forwarding IPs (198.49.x / 198.185.x)  
     • Configuration: Blogger Dashboard → Custom Domain DNS (for Blogger)  
                      Registrar → DNS Forwarding (for registrar)  
     • Rationale: Ensures naked domain points somewhere valid — Blogger A‑records provide built‑in HTTPS redirect; registrar forwarding is valid but less flexible

 6️⃣ Root Forwarding Validation
     • If using Blogger A‑records, confirms HTTP 301 → https://www.<CUSTOM_DOMAIN>/  
     • If using registrar forwarding, acknowledges redirect is handled externally  
     • Configuration: Blogger Dashboard → Custom Domain redirect  
                      Registrar → Forwarding URL  
     • Rationale: Verifies visitors reach secure “www” site regardless of forwarding method

 7️⃣ Blogger HTTPS Status
     • Verify HTTPS Availability and HTTP→HTTPS redirect  
     • Configuration: Blogger Dashboard → Settings → HTTPS  
     • Rationale: Ensures SSL provisioning and forced secure traffic

 8️⃣ (--advanced) Traceroute + Subdomain Enumeration
     • Advanced diagnostics if installed (traceroute, subfinder)

 9️⃣ (--debug) Raw DNS trace & HTTP header dump for deep troubleshooting

DEPENDENCIES:
    Required: dig, curl, ping  
    Optional (--advanced): traceroute, subfinder  
    Alternative (--advanced + --debug): traceroute, subfinder, shellcheck

EXIT CODES:
    0 = success (or warnings only)
    >0 = critical failure (missing required config)
"""

import argparse, subprocess, sys, shutil, re
from typing import List
from colorama import init, Fore, Style

init(autoreset=True)

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
RESOLVERS = ["8.8.8.8", "1.1.1.1", "9.9.9.9"]
VERSION = "4.4"
TEST_HOST = "www.google.com"

BLOGGER_IPS = ["216.239.32.21","216.239.34.21","216.239.36.21","216.239.38.21"]
FORWARD_IPS = ["198.49.23.144","198.49.23.145","198.185.159.144","198.185.159.145"]

exit_code = 0
last_headers: List[str] = []

def print_status(ok, msg):
    sym, col = ("✓", Fore.GREEN) if ok else ("✗", Fore.RED)
    print(f"{col}{sym} {msg}{Style.RESET_ALL}")
    return not ok

def print_warning(msg):
    print(f"{Fore.YELLOW}⚠ {msg}{Style.RESET_ALL}")

def run(cmd):
    try: return subprocess.check_output(cmd, stderr=subprocess.DEVNULL, text=True).strip()
    except: return ""

def dig(name, rtype='A', resolver=None):
    args=['dig','+short','-t',rtype,name]
    if resolver: args.append(f"@{resolver}")
    return run(args).splitlines()

def ping(ip):
    return subprocess.call(['ping','-c1','-W1',ip], stdout=subprocess.DEVNULL)==0

def curl_status(url):
    return run(['curl','-s','-o','/dev/null','-w','%{http_code}',url])

def curl_headers(url):
    return run(['curl','-sI','--max-time','5',url]).splitlines()

def self_test():
    global exit_code
    print(f"\n===== blog-check.py v{VERSION} — Self‑Test =====")
    if not shutil.which('dig'):
        exit_code |= print_status(False, 'dig missing')
        sys.exit(exit_code)

    ip = dig(TEST_HOST)[0] if dig(TEST_HOST) else ''
    exit_code |= print_status(bool(ip), f'DNS resolves {TEST_HOST} → {ip}')
    if not ip or not ping(ip):
        exit_code |= print_status(False, 'ping failed')
        sys.exit(exit_code)

    print_status(True, 'ping OK')
    status = curl_status(f'https://{TEST_HOST}')
    if status != '200':
        exit_code |= print_status(False, f'HTTPS status {status}')
        sys.exit(exit_code)

    print_status(True, 'HTTPS OK')
    # match shell’s “✔ Self‑tests passed”
    print(f"{Fore.GREEN}✔ Self‑tests passed{Style.RESET_ALL}")

def nameserver_sanity():
    print("\n===== Nameserver Sanity =====")
    ns = dig(CUSTOM_DOMAIN, 'NS')
    glue = any(re.search(fr"{re.escape(CUSTOM_DOMAIN)}$", n) for n in ns)
    if glue: print_warning(f'Glue-style NS detected: {ns}')
    else: print_status(True, 'Nameservers correct')
    return ns

def dns_audit(ns_list):
    global exit_code
    print("\n===== DNS Audit =====")
    for host, expected in [( "www", WWW_TARGET ),( BLOG_SUBDOMAIN, BLOGSPOT_DOMAIN ),( CNAME_1_HOST, CNAME_1_TARGET )]:
        fqdn = f"{host}.{CUSTOM_DOMAIN}"
        print(f"\n── {fqdn} ──")
        cname = dig(fqdn, 'CNAME')
        if not cname:
            exit_code |= print_status(False, f'Missing CNAME — expected {host}→{expected}')
            continue
        print(f'CNAME → {cname[0]}')
        if host == CNAME_1_HOST:
            a = dig(fqdn, 'A')
            if a: print_warning('Verification CNAME resolves to A-record — NXDOMAIN expected')
            else: print_status(True, 'Verification CNAME NXDOMAIN on A lookup')
        pub = sum((dig(fqdn,'CNAME',r) or [''])[0]==cname[0] for r in RESOLVERS)
        auth = sum((dig(fqdn,'CNAME',ns) or [''])[0]==cname[0] for ns in ns_list)
        print(f'Propagation → public {pub}/{len(RESOLVERS)} | authoritative {auth}/{len(ns_list)}')

def root_a_record_check():
    global exit_code
    print("\n===== Root A-record Presence & Forwarding =====")
    root_ips = dig(CUSTOM_DOMAIN)
    if all(ip in root_ips for ip in BLOGGER_IPS):
        print_status(True, 'All Blogger A-records present'); return 'blogger'
    if all(ip in root_ips for ip in FORWARD_IPS):
        print_warning('Registrar DNS‑forwarding detected — recommend switching to Blogger A‑records')
        print_status(True, 'Registrar DNS‑forwarding — redirect handled externally')
        return 'registrar'
    exit_code |= print_status(False, f'A-record misconfigured — found {root_ips}')
    return 'invalid'

def redirect_check(mode: str):
    global last_headers, exit_code
    if mode == 'blogger':
        last_headers = curl_headers(f'https://{CUSTOM_DOMAIN}')
        status = last_headers[0].split()[1] if last_headers else ''
        location = next((l.split()[1] for l in last_headers if l.startswith('Location:')), '')
        exit_code |= print_status(
            status == '301' and location == f'https://www.{CUSTOM_DOMAIN}/',
            'HTTP 301 → www'
        )

def https_status():
    global exit_code
    print("\n===== Blogger HTTPS Status =====")
    exit_code |= print_status(curl_status(f'https://www.{CUSTOM_DOMAIN}')=='200','HTTPS enabled')
    exit_code |= print_status(curl_status(f'http://www.{CUSTOM_DOMAIN}')=='301','HTTP→HTTPS redirect enabled')

def advanced_diagnostics():
    if shutil.which('traceroute'):
        print("\n===== ADVANCED: Traceroute ====="); subprocess.call(['traceroute','-m4',CUSTOM_DOMAIN])
    if shutil.which('subfinder'):
        print("\n===== ADVANCED: Subdomain Enumeration ====="); subprocess.call(['subfinder','-silent','-d',CUSTOM_DOMAIN])

def debug_info():
    print("\n===== DEBUG =====")
    subprocess.call(['dig','+trace',CUSTOM_DOMAIN])
    if last_headers: print("\n".join(last_headers))

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--advanced', action='store_true')
    parser.add_argument('--debug', action='store_true')
    args = parser.parse_args()

    self_test()
    ns_list = nameserver_sanity()
    dns_audit(ns_list)
    mode = root_a_record_check()
    redirect_check(mode)
    https_status()
    if args.advanced: advanced_diagnostics()
    if args.debug: debug_info()
    sys.exit(exit_code)

if __name__=='__main__':
    main()