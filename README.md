# masscan-nmap
Combined script that does a fast scan of ports using masscan and nmap, then more detailed scan through nmap on the discovered ports

## summary
As always, this script is here more for my benefit than for use by others, but others may find it helpful too.
I originally took the script from somewhere in Github I believe (and I wanted to fork it and modify with my version but I can't find it anywhere,
so if you think you know where the original came from please let me know and I'll fork from it).
I modified the original quite a bit though to suit my purposes.
This script first runs a fast port scan through *masscan*, followed by a fast port scan using a well known *nmap* technique. It then uses the combined ports
found to do a more thorough scan through those ports. Finally, it ignores those found ports and does a slow **all** ports scan.

Useful for things like hackthebox and similar. I use it to quickly find me ports and details and vulnerabilities from those, then let it do more thorough scans
while I look in more detail at other things using the results I have.

## usage
Example:
    ./masscan-nmap.sh tun0 ~/attack/ips.txt ~/attack/results/
    
Then go off and do other parts of the box while you wait for the results to come in. You'll get the initial results files through pretty 
quickly which in most cases are all you need, then leave it doing the slow all ports scans while you are looking at other things
