#!/bin/bash
#
# Test inserting mirror rules with 16 destinations
#

my_dir="$(dirname "$0")"
. $my_dir/common.sh

function cleanup() {
    restore_sriov_autoprobe
}

trap cleanup EXIT

disable_sriov_autoprobe
config_sriov 16
enable_switchdev
vx=vxlan1
vxlan_port=4789


function test1() {
    title "Add local mirror rule with 16 dst"
    reset_tc $NIC
    local cmd="tc_filter_success add dev $NIC ingress protocol arp prio 1 flower skip_sw"
    for i in {0..14}; do
        TMP_REP=`get_rep $i`
        cmd+=" action mirred egress mirror dev $TMP_REP pipe"
    done
    TMP_REP=`get_rep 15`
    cmd+=" action mirred egress redirect dev $TMP_REP"
    eval $cmd
    reset_tc $NIC
}

function test2() {
    local ip_src=1.1.1.1
    local ip_dst=1.1.1.2


    title "Add remote mirror rule with 16 dst"
    ip link del $vx >/dev/null 2>&1
    ip link add $vx type vxlan dstport $vxlan_port external
    [ $? -ne 0 ] && err "Failed to create vxlan interface" && return 1

    ip a show dev $vx

    ip addr flush dev $NIC
    ip addr add $ip_src/16 dev $NIC
    ip neigh add $ip_dst lladdr e4:11:22:11:55:55 dev $NIC

    reset_tc $REP
    local cmd="tc_filter_success add dev $REP ingress protocol arp prio 1 flower skip_sw"
    for i in {1..15}; do
        cmd+=" action tunnel_key set src_ip $ip_src dst_ip $ip_dst dst_port 4789 id $i ttl 64 nocsum pipe action mirred egress mirror dev $vx pipe"
    done
    cmd+=" action tunnel_key set src_ip $ip_src dst_ip $ip_dst dst_port 4789 id 16 ttl 64 nocsum pipe action mirred egress redirect dev $vx"
    eval $cmd

    ip link del $vx &>/dev/null
    reset_tc $REP
}

function test3() {
    local ip_src=1.1.1.1
    local ip_dst=1.1.1.2


    title "Add loacl and remote mirror rule with 16 dst"
    ip link del $vx >/dev/null 2>&1
    ip link add $vx type vxlan dstport $vxlan_port external
    [ $? -ne 0 ] && err "Failed to create vxlan interface" && return 1

    ip a show dev $vx

    ip addr flush dev $NIC
    ip addr add $ip_src/16 dev $NIC
    ip neigh add $ip_dst lladdr e4:11:22:11:55:55 dev $NIC

    local cmd="tc_filter_success add dev $REP ingress protocol arp prio 1 flower skip_sw"
    for i in {1..7}; do
        TMP_REP=`get_rep $i`
        cmd+=" action mirred egress mirror dev $TMP_REP pipe"
        cmd+=" action tunnel_key set src_ip $ip_src dst_ip $ip_dst dst_port 4789 id $i ttl 64 nocsum pipe action mirred egress mirror dev $vx pipe"
    done
    TMP_REP=`get_rep 8`
    cmd+=" action mirred egress mirror dev $TMP_REP pipe"
    cmd+=" action tunnel_key set src_ip $ip_src dst_ip $ip_dst dst_port 4789 id 16 ttl 64 nocsum pipe action mirred egress redirect dev $vx"
    eval $cmd

    ip link del $vx &>/dev/null
    reset_tc $REP
}

test1
test2
test3
config_sriov 2
test_done
