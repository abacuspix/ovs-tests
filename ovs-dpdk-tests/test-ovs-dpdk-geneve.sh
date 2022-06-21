#!/bin/bash
#
# Test OVS-DPDK with geneve traffic
#
# Require external server
#

my_dir="$(dirname "$0")"
. $my_dir/../common.sh
. $my_dir/common-dpdk.sh

require_remote_server

config_sriov 2
require_interfaces REP NIC
unbind_vfs
bind_vfs

trap cleanup_test EXIT

function config() {
    cleanup_test
    set_e2e_cache_enable false
    debug "Restarting OVS"
    start_clean_openvswitch

    config_tunnel "geneve"
    config_local_tunnel_ip $LOCAL_TUN_IP br-phy
}

function config_remote() {
    on_remote ip link del $TUNNEL_DEV &>/dev/null
    on_remote ip link add $TUNNEL_DEV type geneve id $TUNNEL_ID remote $LOCAL_TUN_IP dstport 6081
    on_remote ip a flush dev $REMOTE_NIC
    on_remote ip a add $REMOTE_TUNNEL_IP/24 dev $REMOTE_NIC
    on_remote ip a add $REMOTE_IP/24 dev $TUNNEL_DEV
    on_remote ip l set dev $TUNNEL_DEV up
    on_remote ip l set dev $REMOTE_NIC up
}

function run() {
    config
    config_remote
    ovs-ofctl dump-flows br-int --color

    verify_ping $REMOTE_IP ns0

    generate_traffic "remote" $LOCAL_IP

    # check offloads
    check_dpdk_offloads $LOCAL_IP
}

run
start_clean_openvswitch
test_done
