#!/bin/bash
#
# Verify traffic for OVN-Kubernetes pod to external is offloaded
#

my_dir="$(dirname "$0")"
. $my_dir/common-ovn-k8s-test.sh

require_interfaces NIC
require_remote_server

read_k8s_topology_pod_ext

nic=$NIC
export REMOTE_CHASSIS=$(on_remote_exec "get_ovs_id")

function __clean_up_test() {
    ovn_stop_ovn_controller
    ovn_remove_ovs_config
    ovn_remove_network $BRIDGE $nic
    start_clean_openvswitch
    __reset_nic
}

function clean_up_test() {
    __clean_up_test
    ip -all netns del
    config_sriov 0

    on_remote_exec "__clean_up_test"

    ovn_start_clean
    ovn_stop_northd_central
}

function config_test() {
    ovn_start_northd_central $CLIENT_NODE_IP
    ovn_create_topology

    config_ovn_k8s_pf $CLIENT_NODE_IP $CLIENT_NODE_IP $CLIENT_NODE_IP_MASK $CLIENT_NODE_MAC CLIENT_VF CLIENT_REP
    ovn_config_interface_namespace $CLIENT_VF $CLIENT_REP $CLIENT_NS $CLIENT_PORT $CLIENT_MAC $CLIENT_IPV4 $CLIENT_IPV6 $CLIENT_GATEWAY_IPV4 $CLIENT_GATEWAY_IPV6

    on_remote_exec "config_ovn_k8s_pf_ext_server $CLIENT_NODE_IP $SERVER_NODE_IP $SERVER_NODE_IP_MASK $SERVER_NODE_MAC"

    # WA remove the ip on the bridge.
    # There should be single ovn k8s yaml and config is done with all settings in it.
    ip addr del $CLIENT_NODE_IP/$CLIENT_NODE_IP_MASK dev $BRIDGE
}

function run_test() {
    ovs-vsctl show
    ovn-sbctl show

    # Offloading ICMP with connection tracking is not supported
    title "Test ICMP traffic between $CLIENT_VF($CLIENT_IPV4) -> $BRIDGE($SERVER_IPV4)"
    ip netns exec $CLIENT_NS ping -w 4 $SERVER_IPV4 && success || err

    title "Test TCP traffic between $CLIENT_VF($CLIENT_IPV4) -> $BRIDGE($SERVER_IPV4) offloaded"
    check_remote_tcp_traffic_offload $SERVER_IPV4

    title "Test UDP traffic between $CLIENT_VF($CLIENT_IPV4) -> $BRIDGE($SERVER_IPV4) offloaded"
    check_remote_udp_traffic_offload $SERVER_IPV4
}

TRAFFIC_INFO['server_ns']=""
TRAFFIC_INFO['server_verify_offload']=""

clean_up_test
trap clean_up_test EXIT

config_test
run_test

trap - EXIT
clean_up_test

test_done
