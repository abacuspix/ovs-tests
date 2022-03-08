#!/bin/bash
# ex:ts=4:sw=4:sts=4:et
#
# Test MPLS over UDP traffic
#
# Bug SW #2576950: traffic of MPLS Over UDP is broken in v5.12
#
#
# Note that the test assumes that NIC and REP have same names on local and remote hosts
#

my_dir="$(dirname "$0")"
. $my_dir/common.sh

require_mlxconfig
require_remote_server

LABEL=555 # use whatever you want
UDPPORT=6635 # reserved UDP port

# local
tunip1=8.8.8.21
vfip1=2.2.2.21
tundest1=8.8.8.22
vfdest1=2.2.2.22

# remote
tunip2=8.8.8.22
vfip2=2.2.2.22
tundest2=8.8.8.21
vfdest2=2.2.2.21

function cleanup_remote() {
    on_remote "ip link del dev bareudp0 2>/dev/null"
    for i in $NIC $REP $VF; do
        on_remote reset_tc $i &>/dev/null
        on_remote ip link set $i mtu 1500 &>/dev/null
        on_remote ifconfig $i 0 &>/dev/null
    done
}

function cleanup() {
    ip link del dev bareudp0 2>/dev/null
    for i in $NIC $REP $VF; do
        reset_tc $i &>/dev/null
        ip link set $i mtu 1500 &>/dev/null
        ifconfig $i 0 &>/dev/null
    done
    cleanup_remote
}
trap cleanup EXIT

function prep_setup()
{
    local profile=$1; shift
    local remote=$1; shift

    local cmd="config_sriov 2
               enable_switchdev
               unbind_vfs
               bind_vfs
               start_clean_openvswitch
               reset_tc $NIC $REP
               ip link set dev $VF mtu 1468
               modprobe -av bareudp || fail \"Can't load bareudp module\""

    if [ "X$remote" != "X" ]; then
        title "Prep remote"
        on_remote_dt "$cmd"
    else
        title "Prep local"
        cmd="fw_config FLEX_PARSER_PROFILE_ENABLE=$profile || fail \"Cannot set flex parser profile\"
             fw_reset
             $cmd"
        eval "$cmd"
    fi
    [ $? -eq 0 ] || fail "Preparing setup failed!"
    set +x
}

function setup_topo()
{
    local tundev=$1; shift
    local vf=$1; shift
    local rep=$1; shift
    local tunip=$1; shift
    local vfip=$1; shift
    local vfdest=$1; shift
    local tundest=$1; shift
    local remote=$1; shift

    if [ "X$remote" != "X" ]; then
        remote="on_remote"
    fi
    local dstmac=$(eval $remote ip link show dev $vf | grep ether | gawk '{print $2}')
    local srcmac=$(eval ip link show dev $vf | grep ether | gawk '{print $2}')
    local cmd="ip link add dev bareudp0 type bareudp dstport 6635 ethertype mpls_uc
               ip link set up dev bareudp0
               ip link set up dev $vf
               ip link set up dev $rep
               ip addr add $tunip/24 dev $tundev
               ip link set up dev $tundev
               ip addr add $vfip/24 dev $vf
               ip neigh add $vfdest lladdr 00:11:22:33:44:55 dev $vf
               if [ "X$remote" != "X" ]; then ethtool -K $REP hw-tc-offload off ; fi
               tc filter add dev $rep protocol ip prio 1 root flower src_ip $vfip dst_ip $vfdest action tunnel_key set src_ip $tunip dst_ip $tundest  dst_port $UDPPORT tos 4 ttl 6 action mpls push protocol mpls_uc label $LABEL tc 3 action mirred egress redirect dev bareudp0
               tc qdisc add dev bareudp0 ingress
               tc filter add dev bareudp0 protocol mpls_uc prio 1 ingress flower enc_dst_port $UDPPORT mpls_label  $LABEL action mpls pop protocol ip pipe action vlan push_eth dst_mac $dstmac src_mac $srcmac pipe action mirred egress redirect dev $rep"

    if [ "X$remote" != "X" ]; then
        title "Setup topo on remote"
        on_remote_dt "$cmd"
    else
        title "Setup topo on local"
        eval "$cmd"
    fi
    [ $? -eq 0 ] || fail "Preparing test topo failed!"
}

cleanup
remote_disable_sriov
disable_sriov
wait_for_ifaces

prep_setup 1
prep_setup 1 "remote"

require_interfaces NIC VF REP
on_remote_dt "require_interfaces NIC VF REP"

setup_topo "$NIC" "$VF" "$REP" "$tunip1" "$vfip1" "$vfdest1" "$tundest1"
setup_topo "$NIC" "$VF" "$REP" "$tunip2" "$vfip2" "$vfdest2" "$tundest2" "remote"

verify_in_hw bareudp0 1
verify_in_hw $REP 1

title "Test ping local $VF($vfip1) -> remote $VF($vfip2)"
ping -I $vfip1 $vfip2 -s 56 -f -nc 100 -w 1 && success || err "ping expected to pass"

title "Test iperf3"
iperf3 -s -1 -D &>/dev/null
on_remote timeout 10 iperf3 -c $vfip1 -t 5 || err "failed iperf3"
killall -9 iperf3 &>/dev/null

echo
title "=============       Local TC rules          =================="
title $REP
tc -s filter show dev $REP ingress
title "bareudp0"
tc -s filter show dev bareudp0 ingress

echo
title "=============       Remote TC rules         =================="
title $REP
on_remote tc -s filter show dev $REP ingress
title "bareudp0"
on_remote tc -s filter show dev bareudp0 ingress
echo

echo
title "=============           Cleanup             =================="
cleanup
prep_setup 0
prep_setup 0 "remote"

test_done
