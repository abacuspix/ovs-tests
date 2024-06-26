#!/bin/bash

my_dir="$(dirname "$0")"
. $my_dir/../macsec-common.sh

require_remote_server

function config() {
    config_macsec_env
}

function cleanup() {
    macsec_cleanup
}

function run_test() {
    run_test_macsec --mtu 1500 --ip-proto ipv4 --macsec-ip-proto ipv4 --net-proto icmp --offload-side none --multi-sa off --xpn on --client_pn 4294967290 --server_pn 4294967290 --outer-vlan --vlan-ip-proto ipv6
    run_test_macsec --mtu 1500 --ip-proto ipv4 --macsec-ip-proto ipv4 --net-proto icmp --offload-side both --multi-sa off --xpn on --client_pn 4294967290 --server_pn 4294967290 --outer-vlan --vlan-ip-proto ipv6
    run_test_macsec --mtu 1500 --ip-proto ipv4 --macsec-ip-proto ipv4 --net-proto icmp --offload-side both --multi-sa off --xpn on --client_pn 2147483638 --server_pn 2147483638 --outer-vlan --vlan-ip-proto ipv6
}

trap cleanup EXIT
cleanup
config
run_test
trap - EXIT
cleanup
test_done
