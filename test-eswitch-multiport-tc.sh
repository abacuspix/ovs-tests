#!/bin/bash
#
# Test add redirect rule from VF on esw0 to uplink on esw1 after setting multiport_esw lag port select mode
# Bug SW #2847145: [ASAP, OFED 5.5, multiport esw] Adding redirect rule PF2 -> REP fails in multiport esw mode

my_dir="$(dirname "$0")"
. $my_dir/common.sh

min_nic_cx6dx

function config() {
    enable_lag_resource_allocation_mode
    set_lag_port_select_mode "multiport_esw"
    config_sriov 2
    config_sriov 2 $NIC2
    enable_switchdev
    enable_switchdev $NIC2
    REP2=`get_rep 0 $NIC2`
    reset_tc $NIC $REP $NIC2 $REP2
    enable_esw_multiport
}

function cleanup() {
    disable_esw_multiport
    restore_lag_port_select_mode
    restore_lag_resource_allocation_mode
    enable_legacy $NIC2
    config_sriov 0 $NIC2
}

function add_tc_rule() {
    local dev1=$1
    local dev2=$2
    title "Add redirect rule $dev1 -> $dev2"
    tc_filter add dev $dev1 protocol ip ingress flower skip_sw action \
        mirred egress redirect dev $dev2
}

function add_tc_rules() {
    for i in $NIC $NIC2; do
        for j in $REP $REP2; do
            add_tc_rule $i $j
            add_tc_rule $j $i
        done
    done
}

trap cleanup EXIT

config
add_tc_rules
reset_tc $NIC $NIC2 $REP $REP2
trap - EXIT
cleanup
test_done
