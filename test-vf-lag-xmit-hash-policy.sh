#!/bin/bash
#
# Check configuring bond with different xmit hash policies.
# Bond modes are balance-xor and 802.3ad.
#
# Bug SW #2780336: Kernel panic and call trace appears in mlx5_del_flow_rules when creating vf-lag with xmit hash policy layer2+3

my_dir="$(dirname "$0")"
. $my_dir/common.sh

require_module bonding
not_relevant_for_nic cx4 cx4lx cx5 cx6 cx6lx

function config() {
    config_sriov 2
    config_sriov 2 $NIC2
    enable_switchdev
    enable_switchdev $NIC2
}

function cleanup() {
    clear_bonding
    config_sriov 0 $NIC2
}

function check_bond_xmit_hash_policy() {
    for mode in balance-xor 802.3ad; do
        for policy in layer2 layer2+3 layer3+4 encap2+3 encap3+4; do
            title "Checking bond mode $mode xmit hash policy $policy"
            config_bonding $NIC $NIC2 $mode $policy
            clear_bonding
            dmesg | tail -n20 | grep -q "mode:hash"
            if [ $? -ne 0 ]; then
                err "Expected vf lag mode hash"
                return
            fi
        done
    done
}

trap cleanup EXIT
cleanup
config
check_bond_xmit_hash_policy
test_done