#!/bin/bash
#
# Test devlink reload in nic mode while adding/deleting net namespace
#
# Bug SW #2938383: [K8S UPSTREAM BF2] DPU can't switch to switchdev mode

my_dir="$(dirname "$0")"
. $my_dir/common.sh

function toggle_ns() {
    local ns
    for ns in ns0 ns1 ns2; do
        ip netns add $ns
    done
    sleep 1
    for ns in ns0 ns1 ns2; do
        ip netns del $ns
    done
}

function start1() {
    local i

    title "devlink reload"
    toggle_ns &
    for i in 1 2; do
        devlink dev reload pci/$PCI
    done
    echo wait
    wait
}

config_sriov 0
enable_legacy
start1
config_sriov 2

test_done
