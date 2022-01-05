#!/bin/bash
#
# Test traffic between VFs on different nodes configured with OVN and OVS then check traffic is offloaded
#

CONFIG_REMOTE=1

my_dir="$(dirname "$0")"
. $my_dir/common-ovn-test-utils.sh

TOPOLOGY=$TOPOLOGY_SINGLE_SWITCH

CLIENT_SWITCH=$SWITCH1
CLIENT_PORT=$SWITCH1_PORT1
CLIENT_MAC=$(ovn_get_switch_port_mac $TOPOLOGY $CLIENT_SWITCH $CLIENT_PORT)
CLIENT_IPV4=$(ovn_get_switch_port_ip $TOPOLOGY $CLIENT_SWITCH $CLIENT_PORT)
CLIENT_IPV6=$(ovn_get_switch_port_ipv6 $TOPOLOGY $CLIENT_SWITCH $CLIENT_PORT)
CLIENT_NS=ns0
CLIENT_VF=$VF
CLIENT_REP=$REP

SERVER_SWITCH=$SWITCH1
SERVER_PORT=$SWITCH1_PORT2
SERVER_MAC=$(ovn_get_switch_port_mac $TOPOLOGY $SERVER_SWITCH $SERVER_PORT)
SERVER_IPV4=$(ovn_get_switch_port_ip $TOPOLOGY $SERVER_SWITCH $SERVER_PORT)
SERVER_IPV6=$(ovn_get_switch_port_ipv6 $TOPOLOGY $SERVER_SWITCH $SERVER_PORT)
SERVER_NS=ns0
SERVER_VF=$VF
SERVER_REP=$REP

function run_test() {
    ovn_config_interface_namespace $CLIENT_VF $CLIENT_REP $CLIENT_NS $CLIENT_PORT $CLIENT_MAC $CLIENT_IPV4 $CLIENT_IPV6 $CLIENT_GATEWAY_IPV4 $CLIENT_GATEWAY_IPV6
    on_remote_exec "ovn_config_interface_namespace $SERVER_VF $SERVER_REP $SERVER_NS $SERVER_PORT $SERVER_MAC $SERVER_IPV4 $SERVER_IPV6 $SERVER_GATEWAY_IPV4 $SERVER_GATEWAY_IPV6"

    ovs-vsctl show
    ovn-sbctl show

    title "Test ICMP traffic between $CLIENT_VF($CLIENT_IPV4) -> $SERVER_VF($SERVER_IPV4) offloaded"
    check_icmp_traffic_offload $CLIENT_REP $CLIENT_NS $SERVER_IPV4

    title "Test TCP traffic between $CLIENT_VF($CLIENT_IPV4) -> $SERVER_VF($SERVER_IPV4) offloaded"
    check_remote_tcp_traffic_offload $CLIENT_REP $CLIENT_NS $SERVER_NS $SERVER_IPV4

    title "Test UDP traffic between $CLIENT_VF($CLIENT_IPV4) -> $SERVER_VF($SERVER_IPV4) offloaded"
    check_remote_udp_traffic_offload $CLIENT_REP $CLIENT_NS $SERVER_NS $SERVER_IPV4

    title "Test ICMP6 traffic between $CLIENT_VF($CLIENT_IPV6) -> $SERVER_VF($SERVER_IPV6) offloaded"
    check_icmp6_traffic_offload $CLIENT_REP $CLIENT_NS $SERVER_IPV6

    title "Test TCP6 traffic between $CLIENT_VF($CLIENT_IPV6) -> $SERVER_VF($SERVER_IPV6) offloaded"
    check_remote_tcp6_traffic_offload $CLIENT_REP $CLIENT_NS $SERVER_NS $SERVER_IPV6

    title "Test UDP6 traffic between $CLIENT_VF($CLIENT_IPV6) -> $SERVER_VF($SERVER_IPV6) offloaded"
    check_remote_udp6_traffic_offload $CLIENT_REP $CLIENT_NS $SERVER_NS $SERVER_IPV6
}

ovn_execute_test
