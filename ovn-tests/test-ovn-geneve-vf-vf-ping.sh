#!/bin/bash
#
# Test traffic between VFs configured with OVN and OVS then check traffic is offloaded
#

my_dir="$(dirname "$0")"
. $my_dir/../common.sh
. $my_dir/common-ovn.sh

require_ovn

# IPs and MACs
IP1="7.7.7.1"
IP2="7.7.7.2"

MAC1="50:54:00:00:00:01"
MAC2="50:54:00:00:00:02"

# switch and ports
SWITCH="sw0"
PORT1="sw0-port1"
PORT2="sw0-port2"

OVN_CENTRAL_IP="127.0.0.1"
OVN_TUNNEL="geneve"

TCPDUMP_FILE=/tmp/$$.pcap

# stop OVN, clean namespaces, ovn network topology, and ovs br-int interfaces
function cleanup() {
    # Remove OVN topology
    ovn_delete_switch_port $PORT1
    ovn_delete_switch_port $PORT2
    ovn_delete_switch $SWITCH

    # Stop ovn
    ovn_remove_ovs_config
    ovn_stop_ovn_controller
    ovn_stop_northd_central

    # Clean namespaces
    ip netns del ns0 2>/dev/null
    ip netns del ns1 2>/dev/null

    # Remove IPs from VFs
    for i in $VF $VF2; do
        ifconfig $i 0 &>/dev/null
    done

    # Clean ovs br-int
    ovs_clear_bridges
}

function pre_test() {
    # Verify required ENV vars
    test -z "$NIC" && fail "Missing NIC"
    test -z "$VF" && fail "Missing VF"
    test -z "$REP" && fail "Missing REP"
    test -z "$VF2" && fail "Missing VF2"
    test -z "$REP2" && fail "Missing REP2"

    # Verfiy NIC
    require_interfaces NIC

    # switchdev mode for NIC
    unbind_vfs
    enable_switchdev
    bind_vfs

    # Verify VFs and REPs
    require_interfaces VF VF2 REP REP2

    # Start OVN
    ovn_start_northd_central $OVN_CENTRAL_IP
    ovn_start_ovn_controller
    ovn_set_ovs_config $OVN_SYSTEM_ID $OVN_CENTRAL_IP $OVN_CENTRAL_IP $OVN_TUNNEL
}

function run_test() {
    # Add network topology to OVN
    ovn_add_switch $SWITCH
    ovn_add_port_to_switch $SWITCH $PORT1
    ovn_add_port_to_switch $SWITCH $PORT2
    ovn_set_switch_port_addresses $PORT1 $MAC1 $IP1
    ovn_set_switch_port_addresses $PORT2 $MAC2 $IP2

    ovn-nbctl show

    # Add REP to OVS
    ovs_add_port_to_switch $OVN_BRIDGE_INT $REP
    ovs_add_port_to_switch $OVN_BRIDGE_INT $REP2

    ovs-vsctl show

    # Bind OVS ports to OVN
    ovn_bind_ovs_port $REP $PORT1
    ovn_bind_ovs_port $REP2 $PORT2

    ovn-sbctl show

    # Move VFs to namespaces and set MACs and IPS
    config_vf ns0 $VF $REP $IP1 $MAC1
    config_vf ns1 $VF2 $REP2 $IP2 $MAC2

    # Listen to traffic on representor
    timeout 15 tcpdump -nnepi $REP icmp -c 8 -w $TCPDUMP_FILE &
    tdpid=$!
    sleep 0.5

    # Traffic between VFs
    title "Test traffic between $VF($IP1) -> $VF2($IP2)"
    ip netns exec ns0 ping -w 4 $IP2 && success || err
    # 2 rules should appear, ICMP request and reply

    title "Check OVS offload rules"
    ovs_dump_flows type=offloaded
    check_offloaded_rules 2

    title "Check traffic is offloaded"
    # Stop tcpdump
    kill $tdpid 2>/dev/null
    sleep 1

    # Ensure 2 packets appeared (request and reply)
    count=$(tcpdump -nnr $TCPDUMP_FILE | wc -l)
    if [[ $count -gt 2 ]]; then
        err "No offload"
        tcpdump -nnr $TCPDUMP_FILE
    else
        success
    fi
}

cleanup
pre_test

# trap for existing script to clean up
trap cleanup EXIT

start_check_syndrome
run_test

check_syndrome

test_done
