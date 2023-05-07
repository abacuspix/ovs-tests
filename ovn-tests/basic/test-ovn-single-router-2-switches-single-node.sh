#!/bin/bash
#
# Verify traffic between VFs configured with OVN router and 2 switches is offloaded
#

my_dir="$(dirname "$0")"
. $my_dir/common-ovn-basic-test.sh

require_interfaces NIC

read_single_router_two_switches_topology

function config_test() {
    config_ovn_single_node
    ovn_config_interface_namespace $CLIENT_VF $CLIENT_REP $CLIENT_NS $CLIENT_PORT $CLIENT_MAC $CLIENT_IPV4 $CLIENT_IPV6 $CLIENT_GATEWAY_IPV4 $CLIENT_GATEWAY_IPV6
    ovn_config_interface_namespace $SERVER_VF $SERVER_REP $SERVER_NS $SERVER_PORT $SERVER_MAC $SERVER_IPV4 $SERVER_IPV6 $SERVER_GATEWAY_IPV4 $SERVER_GATEWAY_IPV6
}

function run_test() {
    ovs-vsctl show
    ovn-sbctl show
    run_local_traffic "icmp6_is_not_offloaded"
}

TRAFFIC_INFO['local_traffic']=1

ovn_clean_up
trap ovn_clean_up EXIT

config_test
run_test

trap - EXIT
ovn_clean_up

test_done
