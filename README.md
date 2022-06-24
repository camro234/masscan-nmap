# masscan-nmap
Combined script that does a fast scan of ports using masscan and nmap, then more detailed scan through nmap on the discovered ports
Now includes support for fast scanning of networks with proxychains4! 
This was the fastest method I found to discover hosts and ports through a socks proxy (such as chisel)

## summary
As always, this script is here more for my benefit than for use by others, but others may find it helpful too.
I originally took the script from somewhere in Github I believe (and I wanted to fork it and modify with my version but I can't find it anywhere,
so if you think you know where the original came from please let me know and I'll fork from it).
I modified the original quite a bit though to suit my purposes, so much so that it would be barely recognisable to be honest.
This script first runs a fast port scan through *masscan*, followed by a fast port scan using a well known *nmap* technique. It then uses the combined ports
found to do a more thorough scan through those ports. Finally, it ignores those found ports and does a slow **all** ports scan.

For proxychains, it uses proxychains4 to do TCP scans but run through multiple threads against the usually found ports, then it does a more detailed scan
of only the discovered hosts using multiple threads for a much more thorough list of ports. It's not perfect, but it runs pretty well. In my testing
I found it could discover and fully scan a /24 network somewhere between 8 mins and 30 mins depending on the number of hosts and speed of the network YMMV

Useful for things like hackthebox and similar. I use it to quickly find me ports and details and vulnerabilities from those, then let it do more thorough scans
while I look in more detail at other things using the results I have.

## special note re noisiness
You'll see the script is quite noisy in repeating the commands as it runs. This was so that it can be used for things like OSCP or a pen test report where
you will want to show all the commands run. Remove the -x from the first line if you don't want this. 

## usage
Example:
    ./masscan-nmap.sh tun0 ~/attack/ips.txt ~/attack/results/
    
Then go off and do other parts of the box while you wait for the results to come in. You'll get the initial results files through pretty 
quickly which in most cases are all you need, then leave it doing the slow all ports scans while you are looking at other things
