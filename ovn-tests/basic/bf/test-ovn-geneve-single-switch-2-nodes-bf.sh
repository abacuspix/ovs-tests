#!/bin/bash
#
# Verify traffic with OVN between VFs on BlueField on 2 nodes
#

my_dir="$(dirname "$0")"
. $my_dir/common-ovn-basic-bf-test.sh

require_remote_server

read_single_switch_topology
ovn_set_ips

function clean_up_test() {
    ip -all netns del
    config_sriov 0
    on_bf_exec "ovn_stop_ovn_controller
                ovn_remove_ovs_config
                start_clean_openvswitch
                __reset_nic $BF_NIC
                ovn_start_clean
                ovn_stop_northd_central"

    on_remote_exec "ip -all netns del
                    config_sriov 0"
    on_remote_bf_exec "ovn_stop_ovn_controller
                       ovn_remove_ovs_config
                       start_clean_openvswitch
                       __reset_nic $BF_NIC"
}

function config_test() {
    config_sriov
    require_interfaces CLIENT_VF
    on_bf_exec "ovn_start_northd_central $ovn_central_ip
                ovn_create_topology
                config_bf_ovn_pf $ovn_central_ip $ovn_controller_ip"
    config_bf_ovn_interface_namespace $CLIENT_VF $CLIENT_REP $CLIENT_NS $CLIENT_PORT $CLIENT_MAC $CLIENT_IPV4 $CLIENT_IPV6

    on_remote_exec "config_sriov"
    on_remote_bf_exec "config_bf_ovn_pf $ovn_central_ip $ovn_remote_controller_ip"
    config_bf_ovn_remote_interface_namespace $SERVER_VF $SERVER_REP $SERVER_NS $SERVER_PORT $SERVER_MAC $SERVER_IPV4 $SERVER_IPV6
}

function run_test() {

    title "Test ICMP traffic between $CLIENT_VF($CLIENT_IPV4) -> $SERVER_VF($SERVER_IPV4) offloaded"
    check_icmp_traffic_offload $SERVER_IPV4

    title "Test TCP traffic between $CLIENT_VF($CLIENT_IPV4) -> $SERVER_VF($SERVER_IPV4) offloaded"
    check_remote_tcp_traffic_offload $SERVER_IPV4

    title "Test UDP traffic between $CLIENT_VF($CLIENT_IPV4) -> $SERVER_VF($SERVER_IPV4) offloaded"
    check_remote_udp_traffic_offload $SERVER_IPV4

    title "Test ICMP6 traffic between $CLIENT_VF($CLIENT_IPV6) -> $SERVER_VF($SERVER_IPV6) offloaded"
    check_icmp6_traffic_offload $SERVER_IPV6

    title "Test TCP6 traffic between $CLIENT_VF($CLIENT_IPV6) -> $SERVER_VF($SERVER_IPV6) offloaded"
    check_remote_tcp6_traffic_offload $SERVER_IPV6

    title "Test UDP6 traffic between $CLIENT_VF($CLIENT_IPV6) -> $SERVER_VF($SERVER_IPV6) offloaded"
    check_remote_udp6_traffic_offload $SERVER_IPV6
}

clean_up_test
trap clean_up_test EXIT

config_test
run_test

trap - EXIT
clean_up_test

test_done
