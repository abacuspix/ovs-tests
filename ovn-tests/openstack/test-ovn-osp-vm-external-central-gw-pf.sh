#!/bin/bash
#
# Test traffic VM to external with central gateway chassis
#

my_dir="$(dirname "$0")"
. $my_dir/common-ovn-osp-test.sh

require_interfaces NIC
require_remote_server

read_osp_topology_vm_ext_snat
ovn_set_ips

SERVER_PORT=$NIC
export GW_CHASSIS=$(on_remote_exec "get_ovs_id")

function clean_up_test() {
    ovn_stop_ovn_controller
    ovn_remove_ovs_config
    start_clean_openvswitch
    ip -all netns del
    config_sriov 0
    __reset_nic $NIC

    on_remote_exec "ovn_stop_ovn_controller
                    ovn_remove_ovs_config
                    ovn_remove_network $BRIDGE $NIC
                    start_clean_openvswitch
                    __reset_nic $NIC"

    ovn_start_clean
    ovn_stop_northd_central
}

function config_test() {
    ovn_start_northd_central $ovn_central_ip
    ovn_create_topology

    config_ovn_osp_local_pf $ovn_central_ip $ovn_controller_ip
    ovn_config_interface_namespace $CLIENT_VF $CLIENT_REP $CLIENT_NS $CLIENT_PORT $CLIENT_MAC $CLIENT_IPV4 $CLIENT_IPV6 $CLIENT_GATEWAY_IPV4 $CLIENT_GATEWAY_IPV6

    on_remote_exec "config_ovn_osp_gw_chassis_pf $ovn_central_ip $ovn_remote_controller_ip"
}

function run_test() {
    ovs-vsctl show
    ovn-sbctl show

    run_local_traffic "icmp6_is_not_offloaded" "icmp4_is_not_offloaded" $SERVER_PORT
}

if [ "$DPDK" == "1" ] || [ "$DOCA" == "1" ]; then
    warn "In dpdk and doca, we don't support internal port rules offloading, turning off offload checking"
    TRAFFIC_INFO['client_verify_offload']=""
fi

TRAFFIC_INFO['server_ns']=""
TRAFFIC_INFO['server_verify_offload']=""
TRAFFIC_INFO['local_traffic']=1

clean_up_test
trap clean_up_test EXIT

config_test
run_test

trap - EXIT
clean_up_test

test_done
