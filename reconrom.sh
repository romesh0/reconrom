#!/bin/bash

# Define the interval (in seconds)
INTERVAL=3600  # 1 hour

while true; do
    # Check for correct number of arguments
    if [ $# -ne 1 ]; then
        echo "Usage: $0 <domain>"
        exit 1
    fi

    DOMAIN=$1

    # Create a directory to store results
    mkdir -p recon_results
    cd recon_results || exit

    # Step 1: Domain and Subdomain Enumeration
    echo "[*] Starting subdomain enumeration for $DOMAIN"
    amass enum -passive -d $DOMAIN -o amass_passive.txt
    sublist3r -d $DOMAIN -o sublist3r.txt
    subfinder -d $DOMAIN -o subfinder.txt
    cat amass_passive.txt sublist3r.txt subfinder.txt | sort -u > all_subdomains.txt
    echo "[*] Subdomain enumeration completed. Results saved to all_subdomains.txt"

    # Step 2: WHOIS Information Gathering
    echo "[*] Gathering WHOIS information for $DOMAIN"
    whois $DOMAIN > whois_info.txt
    echo "[*] WHOIS information saved to whois_info.txt"

    # Step 3: Checking for Live Subdomains
    echo "[*] Checking for live subdomains using httpx"
    httpx -1 all_subdomains.txt -o live_subdomains.txt
    echo "[*] Live subdomains check completed. Results saved to live_subdomains.txt"

    # Step 4: Port Scanning
    echo "[*] Starting port scanning"
    while IFS= read -r subdomain; do
        echo "[*] Scanning $subdomain with Masscan"
        masscan -p1-65535 $subdomain --rate=1000 -OG masscan_output_$subdomain.txt
        echo "[*] Scanning $subdomain with Naabu"
        naabu -host $subdomain -o naabu_output_$subdomain.txt
    done < live_subdomains.txt
    echo "[*] Port scanning completed. Results saved to masscan_output_*.txt and naabu_output_*.txt"

    # Step 5: Service Enumeration
    echo "[*] Starting service enumeration"
    while IFS= read -r subdomain; do
        echo "[*] Enumerating services on $subdomain"
        whatweb $subdomain -o whatweb_$subdomain.txt
        wappalyzer $subdomain -o wappalyzer_$subdomain.json
    done < live_subdomains.txt
    echo "[*] Service enumeration completed. Results saved to whatweb_*.txt and wappalyzer_*.json"

    # Step 6: Vulnerability Scanning
    echo "[*] Starting vulnerability scanning"
    while IFS= read -r subdomain; do
        echo "[*] Scanning $subdomain with Nikto"
        nikto -h $subdomain -o nikto_$subdomain.txt
        echo "[*] Scanning $subdomain with OWASP ZAP"
        zap-baseline.py -t http://$subdomain -r zap_report_$subdomain.html
        echo "[*] Scanning $subdomain with Nuclei"
        nuclei -u http://$subdomain -o nuclei_$subdomain.txt
    done < live_subdomains.txt
    echo "[*] Vulnerability scanning completed. Results saved to nikto_*.txt, zap_report_*.html, and nuclei_*.txt"

    # Step 7: Taking Screenshots of Live Domains
    echo "[*] Taking screenshots of live domains"
    eyewitness --web -f live_subdomains.txt --no-prompt --results eyewitness_results
    echo "[*] Screenshots taken and saved in the eyewitness_results directory"
    echo "[*] Recon workflow completed. All results are saved in the recon_results directory."

    # Wait for the specified interval before running again
    echo "[*] Waiting for $INTERVAL seconds before the next run..."
    sleep $INTERVAL
done
