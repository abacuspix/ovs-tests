#!/bin/bash
#
# Bug SW #1487302: [upstream] failing to set mode switchdev when we have 127 vfs
# Bug SW #1601565: long time to bring up reps
#

my_dir="$(dirname "$0")"
. $my_dir/common.sh


function cleanup() {
    restore_sriov_autoprobe
}

function test_reps() {
    local want=$1

    title "Config $want VFs on $NIC"
    config_reps $want $NIC

    (( want += 1 ))        # reps will be verified by switch id so add one for pf port.
    # newer kernels have phys_switch_id readable also when sriov is disabled or in legacy
    if cat /sys/class/net/$NIC2/phys_switch_id &>/dev/null ; then
        (( want += 1 ))
    fi

    count_reps $want $NIC

    enable_legacy
    config_sriov 2 $NIC
}


trap cleanup EXIT
disable_sriov_autoprobe
config_sriov 0 $NIC2

test_reps 32
if [ $TEST_FAILED -eq 0 ] || [ -e $__probe_fs ]; then
    test_reps 127
else
    err "Skipping 127 reps case due to failure in prev case"
fi

echo "Cleanup"
cleanup
test_done
