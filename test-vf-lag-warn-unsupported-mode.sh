#!/bin/bash
#
# Feature #2101052: Add message to Linux dmesg & logging when VF-LAG fails to start
#

my_dir="$(dirname "$0")"
. $my_dir/common.sh

require_module bonding
require_interfaces NIC NIC2

function config() {
    echo "- Config"
    config_sriov 2
    config_sriov 2 $NIC2
    unbind_vfs $NIC $NIC2
    enable_switchdev
    enable_switchdev $NIC2
    reset_tc $NIC $NIC2 $REP
}

function test_bond_mode() {
    local ret1
    local ret2
    local vf_lag
    local mode=$1

    title "Test $1 mode"

    ip link add name bond0 type bond mode $mode miimon 100 || fail "Failed to create bond interface"

    ip link set dev $NIC down
    ip link set dev $NIC2 down
    ret1=$(ip link set dev $NIC master bond0 2>&1 >/dev/null)
    ret2=$(ip link set dev $NIC2 master bond0 2>&1 >/dev/null)
    ip link set dev bond0 up
    ip link set dev $NIC up
    ip link set dev $NIC2 up

    vf_lag=$(is_vf_lag_activated)
    if [[ $ret1 != "" || $ret2 != $warning ]]; then
        echo $ret1
        echo $ret2
        err "unexpected warning returned."
    elif [[ ! $vf_lag && $warning == "" ]] ; then
        echo $ret1
        echo $ret2
        err "VF LAG is not activated."
    elif [[ $vf_lag && $warning != "" ]] ; then
        echo $ret1
        echo $ret2
        err "VF LAG is activated."
    else
        success
    fi

    clear_bonding
}

config

warning=""
test_bond_mode active-backup

warning="Warning: mlx5_core: Can't activate LAG offload, TX type isn't supported."
test_bond_mode broadcast

test_done
