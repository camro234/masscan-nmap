#!/bin/bash -x

echo -e "\e[0;35m_________                                  ________  ________     _____
\_   ___ \ _____     _____ _______   ____  \_____  \ \_____  \   /  |  |
/    \  \/ \__  \   /     \\_  __ \ /  _  \  /  ____/   _(__  <  /   |  |_
\     \____ / __ \_|  Y Y  \|  | \/(  <_> )/       \  /       \/    ^   /
 \______  /(____  /|__|_|  /|__|    \____/ \_______ \/______  /\____   |
        \/      \/       \/                        \/       \/      |__|"
echo -e "\e[0;33mFast port scanner - now with improved proxychains support for lateral movement\n\n\e[m"

# check for sudo privs
if [[ "$EUID" -ne 0 ]]; then
    echo -e "Must be root to run script (\e[0;91mWARNING\e[0m)"
    exit 1
fi

SHOW_USAGE="n"

while [ $# -gt 0 ]; do
  tmp=$(echo $1 | tr '[:lower:]' '[:upper:]')
  if [[ $1 == "--"* ]]; then
    param="${tmp/--/}"
    declare $param="$2" 2>/dev/null
  fi

  if [[ $1 == "-"* ]]; then
    param="${tmp/-/}"
    declare $param="$2" 2>/dev/null
  fi

  if [[ $1 == "-"* ]]; then
    if [ $param != "-IP" ] && [ $param != "-IP_FILE" ] && [ $param != "-INTERFACE" ] && [ $param != "-USE_PROXYCHAINS" ] && [ $param != "-OUTDIR" ]; then
      SHOW_USAGE="y"
      echo -e "\e[0;91mERROR: Invalid parameter $1\e[0m"
    fi
  fi

  shift
done

if ! command -v nmap &> /dev/null
then
    echo -e  "\e[0;91mERROR: nmap must be installed for this script to run\e[0m"
    exit 1
fi
if ! command -v masscan &> /dev/null
then
    echo -e  "\e[0;91mERROR: masscan must be installed for this script to run\e[0m"
    exit 1
fi

MY_DIR=$(dirname "$0")
MY_DIR=${MY_DIR%/}

if [[ -z $IP_FILE ]] && [[ -z $IP ]]; then
  echo -e "\e[0;91mERROR: An IP address is required, either as a file or directly as an address\e[0m"
  SHOW_USAGE="y"
fi

if [[ -z $INTERFACE ]]; then
  INTERFACE="tun0"
fi

if [[ -z $OUTDIR ]]; then
  OUTDIR="./"
fi
OUTDIR=${OUTDIR%/}

if [[ $IP == *"/"* ]] && [[ ! $IP == *"/24" ]]; then
  echo -e "\e[0;91mERROR: The only CIDR network address style currently supported is /24\e[0m"
  exit 1
fi
if [[ $IP == *"/"* ]]; then
  SOCKS_TARGET_IP=$(echo $IP | sed 's/[0-9]\{1,3\}\/[0-9]\{1,2\}/\{\}/g')
fi
if [[ $IP == *"{"* ]]; then
  SOCKS_TARGET_IP=$IP
fi
if [[ -z $SOCKS_TARGET_IP ]]; then
  if [[ $USE_PROXYCHAINS = "y" ]]; then
    echo -e "\e[0;91mERROR --use_proxychains specified but a network style IP address wasn't used, you need to specify as either 1.1.1.{} or 1.1.1.0/24\e[0m"
    exit 1
  fi
fi

if [[ -z $USE_PROXYCHAINS ]]; then
  USE_PROXYCHAINS="n"
else
  if ! command -v proxychains4 &> /dev/null
  then
    echo -e  "ERROR: proxychains4 must be installed for this script to run"
    exit 1
  fi
fi
     
if [[ $SHOW_USAGE = "y" ]]; then
  echo -e "\e[0;92musage:\n\t$0 (--ip 10.1.1.1 | --ip_file <filename>) [--interface tun0] [--use_proxychains n] [--outdir ./]\e[0m"
  exit 1
fi

PORT_LIST="7,9,13,21-23,25-26,37,53,79-81,88,106,110-111,113,119,135,139,143-144,179,199,389,427,443-445,465,513-515,543-544,548,554,587,631,646,873,990,993,995,1025-1029,1110,1433,1720,1723,1755,1900,2000-2049,2121,2717,3000,3128,3306,3389,3986,4899,5000,5009,5051,5060,5101,5190,5357,5432,5631,5666,5800,5900,5985-5986,6000-6001,6379,6646,7070,8000,8008-8009,8080-8081,8443,8888,9100,9999-10000,27017,29819-29820,32768,49152-49157"

if [[ -z $IP_FILE ]]; then
  IP_FILE_PARAM=""
  IP_PARAM="$IP"
else
  IP_FILE_PARAM="-iL $IP_FILE"
  IP_PARAM=""
fi

if [[ $USE_PROXYCHAINS = "n" ]]; then
  echo -e "Starting Masscan scan (\e[0;92mINFO\e[0m)"
  # if you don't specify an adapter, packets distributed over 
  # several interfaces which is not what you want
  # setting packets per second to 10,000
  masscan $IP_FILE_PARAM $IP_PARAM \
    --ports "$PORT_LIST" \
    --rate=10000 \
    --adapter $INTERFACE \
    --http-user-agent 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36' \
    --open-only \
    -oG $OUTDIR/masscan.out

  echo -e "\nStarting Nmap ALL port fast scan (\e[0;92mINFO\e[0m)\n"
  # run nmap against the target IP's in file, specifying the ports 
  # that were discovered port by masscan for further interrogation
  nmap -vvv -e $INTERFACE $IP_FILE_PARAM $IP_PARAM -p- --min-rate 10000 -oA $OUTDIR/nm_fastports.out
  nmap -vvv -e $INTERFACE $IP_FILE_PARAM $IP_PARAM -p- --min-rate 10000 -oA $OUTDIR/nm_fastports2.out

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
  nmap -v -e $INTERFACE $IP_FILE_PARAM $IP_PARAM -p $(cat $OUTDIR/ports) -Pn --open -sC -sV -oA $OUTDIR/nmap-$(date '+%Y%m%d%H%M')

  echo -e "\nUDP Nmap scan (\e[0;92mINFO\e[0m)\n"
  # run nmap against UDP and see if anything interesting there
  nmap -e $INTERFACE $IP_FILE_PARAM $IP_PARAM -sU --top-ports 10 -sV -oA $OUTDIR/nmap-udp-$(date '+%Y%m%d%H%M')

  echo -e "\nStarting Nmap vuln scan (\e[0;92mINFO\e[0m)\n"
  # run nmap against the target IP's in file, specifying the ports 
  # that were discovered port by masscan for further interrogation
  nmap -vvv -e $INTERFACE $IP_FILE_PARAM $IP_PARAM -p $(cat $OUTDIR/ports) --script=vuln -oA $OUTDIR/nmap-vuln-$(date '+%Y%m%d%H%M')
else
  echo -e "\nStarting Nmap scan against proxychains target(s)(\e[0;92mINFO\e[0m)\n"
  # run nmap against the target IP's in file, specifying the ports 
  # that were discovered port by masscan for further interrogation

  echo -e "\nDiscovering hosts(\e[0;92mINFO\e[0m)\n"
  # run nmap against the target IP's in file, specifying the ports 
  seq 1 254 | xargs -P 50 -I{} proxychains4 -q -f /etc/proxychains.conf nmap -p 21,22,23,80,135,389,443,445,8080-8081 -sT -Pn --open -n -T4 --min-parallelism 100 --min-rate 10000 --oG $OUTDIR/proxychains_nmap_fast --append-output $SOCKS_TARGET_IP 1>/dev/null 2>&1

  grep open/tcp $OUTDIR/proxychains_nmap_fast | awk -F' ' '{print $2}' | sort -t . -g -k1,1 -k2,2 -k3,3 -k4,4 | uniq -i > $OUTDIR/proxychains_ips_found

  echo -e "\nStarting detailed scan of discovered hosts(\e[0;92mINFO\e[0m)\n"
  # run nmap against the target IP's in file, specifying the ports 
  cat $MY_DIR/portlist_full | xargs -P 50 -I{} proxychains4 -q -f /etc/proxychains.conf nmap -p {} -sT -Pn --open -n -T4 --min-parallelism 100 --min-rate 10000 --oG $OUTDIR/proxychains_nmap_all --append-output -iL $OUTDIR/proxychains_ips_found 1>/dev/null 2>&1

  grep open/tcp $OUTDIR/proxychains_nmap_all | sort -V > $OUTDIR/nmap-proxychains-$(date '+%Y%m%d%H%M')
fi


# echo -e "\nStarting Nmap ALL port scan (\e[0;92mINFO\e[0m)\n"
# run nmap against the target IP's in file, specifying the ports 
# that were discovered port by masscan for further interrogation
# nmap -vvv -e $INTERFACE -iL $IP_FILE -p- -sC -sV -oA $OUTDIR/nmap-all-$(date '+%Y%m%d%H%M')

echo -e "\n\e[0;92mScans are complete\e[0m"

