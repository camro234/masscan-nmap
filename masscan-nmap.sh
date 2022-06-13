#!/bin/bash -x

INTERFACE=$1
IP_FILE=$2
OUTDIR=${3%/}

# check for sudo privs
if [[ "$EUID" -ne 0 ]]; then
    echo -e "Must be root to run script (\e[0;91mWARNING\e[0m)"
    exit 1
fi

if [[ -z $IP_FILE || -z $INTERFACE ]]; then
    echo -e "usage:\n\t$0 <interface> <ip-file>"
    exit 1
fi

PORT_LIST="7,9,13,21-23,25-26,37,53,79-81,88,106,110-111,113,119,135,139,143-144,179,199,389,427,443-445,465,513-515,543-544,548,554,587,631,646,873,990,993,995,1025-1029,1110,1433,1720,1723,1755,1900,2000-2001,2049,2121,2717,3000,3128,3306,3389,3986,4899,5000,5009,5051,5060,5101,5190,5357,5432,5631,5666,5800,5900,6000-6001,6379,6646,7070,8000,8008-8009,8080-8081,8443,8888,9100,9999-10000,27017,32768,49152-49157"

echo -e "Starting Masscan scan (\e[0;92mINFO\e[0m)"
# if you don't specify an adapter, packets distributed over 
# several interfaces which is not what you want
# setting packets per second to 10,000
masscan -iL $IP_FILE \
    --ports "$PORT_LIST" \
    --rate=10000 \
    --adapter $INTERFACE \
    --http-user-agent 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36' \
    --open-only \
    -oG $OUTDIR/masscan.out

echo -e "\nStarting Nmap ALL port fast scan (\e[0;92mINFO\e[0m)\n"
# run nmap against the target IP's in file, specifying the ports 
# that were discovered port by masscan for further interrogation
nmap -vvv -e $INTERFACE -iL $IP_FILE -p- --min-rate 10000 -oA $OUTDIR/nm_fastports.out
nmap -vvv -e $INTERFACE -iL $IP_FILE -p- --min-rate 10000 -oA $OUTDIR/nm_fastports2.out

# filter masscan output for discovered ports
grep 'Host' $OUTDIR/masscan.out | \
    awk '{print $7}' | \
    awk -F/ '{print $1}' | \
    grep '[0-9]' | \
    sort -n | \
    uniq > $OUTDIR/ports_part.out

# add nmap fastports result to discovered ports
grep 'open' $OUTDIR/nm_fastports.out.nmap | awk '{print $1}' | tr -d '/tcp' | tr -d '/udp' >> $OUTDIR/ports_part.out
grep 'open' $OUTDIR/nm_fastports2.out.nmap | awk '{print $1}' | tr -d '/tcp' | tr -d '/udp' >> $OUTDIR/ports_part.out

# create consolidated list
cat $OUTDIR/ports_part.out | sort -n | uniq | tr '\n' ',' | sed 's/,$//' > $OUTDIR/ports

echo -e "\nStarting Nmap scan (\e[0;92mINFO\e[0m)\n"
# run nmap against the target IP's in file, specifying the ports 
# that were discovered port by masscan for further interrogation
nmap -v -e $INTERFACE -iL $IP_FILE -p $(cat $OUTDIR/ports) -Pn --open -sC -sV -oA $OUTDIR/nmap-$(date '+%Y%m%d%H%M')

echo -e "\nUDP Nmap scan (\e[0;92mINFO\e[0m)\n"
# run nmap against UDP and see if anything interesting there
nmap -e $INTERFACE -iL $IP_FILE -sU --top-ports 10 -sV -oA $OUTDIR/nmap-udp-$(date '+%Y%m%d%H%M')

echo -e "\nStarting Nmap vuln scan (\e[0;92mINFO\e[0m)\n"
# run nmap against the target IP's in file, specifying the ports 
# that were discovered port by masscan for further interrogation
nmap -vvv -e $INTERFACE -iL $IP_FILE -p $(cat $OUTDIR/ports) --script=vuln -oA $OUTDIR/nmap-vuln-$(date '+%Y%m%d%H%M')

# echo -e "\nStarting Nmap ALL port scan (\e[0;92mINFO\e[0m)\n"
# run nmap against the target IP's in file, specifying the ports 
# that were discovered port by masscan for further interrogation
# nmap -vvv -e $INTERFACE -iL $IP_FILE -p- -sC -sV -oA $OUTDIR/nmap-all-$(date '+%Y%m%d%H%M')

echo -e "\nScans are complete (\e[0;97mATTENTION\e[0m)"

