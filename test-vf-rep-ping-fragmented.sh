#!/bin/bash
#
# Bug SW #1040416: slow path xmit on VF reps broken
# Bug SW #896876: IP fragments sent by VFs are dropped
#

my_dir="$(dirname "$0")"
. $my_dir/common.sh

IP1="7.7.7.1"
IP2="7.7.7.2"

enable_switchdev
bind_vfs
require_interfaces VF REP

function cleanup() {
    clear_ns_dev ns0 $VF $REP
}

cleanup
config_vf ns0 $VF $REP $IP2
ifconfig $REP $IP1/24 up

SIZE=2222

title "Test ping REP($IP1) -> VF($IP2)"
ping -q -c 10 -i 0.2 -w 4 -s $SIZE $IP2 && success || err

title "Test ping VF($IP2) -> REP($IP1)"
ip netns exec ns0 ping -q -c 10 -i 0.2 -w 4 -s $SIZE $IP1 && success || err

#title "Test later fragmented packet"
#/usr/bin/python -c 'from scapy.all import * ; send( fragment(IP(dst="7.7.7.2")/ICMP()/("X"*60000))[1:] )'
# check with tcpdump for fragmented packets

cleanup
test_done
