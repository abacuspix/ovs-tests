#!/usr/bin/python3

import argparse
import math
import socket
import sys
import time


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('-s', '--server', help='Run in server mode', action='store_true')
    parser.add_argument('-c', '--client', help='Run in client mode, connecting to <server-address>')
    parser.add_argument('-p', '--port', help='Port (default: %default)', type=int, default=5555)
    parser.add_argument('-6', help='Run over IPv6', action='store_true')
    parser.add_argument('--packets', help='Number of packets to send (default: %default)', type=int, default=50)
    parser.add_argument('--pass-rate', help='Accepted packet pass rate (default: %default)', type=float, default=0.7)

    args = parser.parse_args()
    if (args.server and args.client) or (not args.server and not args.client):
        raise AttributeError("Invalid args: Either use --server or --client")

    if args.pass_rate <= 0 or args.pass_rate > 1:
        raise AttributeError("Invalid args: --pass-rate should be > 0 and <= 1")

    return args


def wait_for_handshake(sock):
    # listen packet
    data, client = sock.recvfrom(10)
    print(f'Server: Received packet from {client}')

    packets = int(data[0])
    print(f'Server: Packets to send {packets}')

    # Send Ack
    sock.sendto(bytes([0]), client)

    return client, packets


def listen(port, is_ipv6):
    try:
        socket_family = socket.AF_INET if not is_ipv6 else socket.AF_INET6
        udp_socket = socket.socket(socket_family, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
        udp_socket.bind(('', port))

        client, packets = wait_for_handshake(udp_socket)
    except Exception as ex:
        print(ex)
        return 1

    for _ in range(packets):
        try:
            time.sleep(0.1)
            udp_socket.sendto(bytes([0]), client)
            udp_socket.recvfrom(10)
        except Exception as ex:
            print(ex)

    return 0


def hand_shake(sock, server_address, port, packets):
    # Send handshake packet to server
    sock.sendto(bytes([packets]), (server_address, port))

    # listen for Ack
    _, server = sock.recvfrom(10)
    print(f'Client: Received Ack from {server}')


def send(server_address, port, packets, pass_rate, is_ipv6):
    try:
        socket_family = socket.AF_INET if not is_ipv6 else socket.AF_INET6
        udp_socket = socket.socket(socket_family, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
        udp_socket.settimeout(2)
        hand_shake(udp_socket, server_address, port, packets)
    except Exception as ex:
        print(f'Client: Failed to communicate server {server_address}:{port}, {ex}')
        return 1

    received_packets = 0

    for _ in range(packets):
        try:
            time.sleep(0.1)
            udp_socket.sendto(bytes([0]), (server_address, port))
            udp_socket.recvfrom(10)
            received_packets += 1
        except Exception as ex:
            print(ex)

    return 0 if received_packets / packets >= pass_rate else 1


def main():
    try:
        args = parse_args()
        is_pv6 = args.__getattribute__('6')
        if args.server:
            print(f'Server listening on {args.port}, IPv{6 if is_pv6 else 4}')
            return listen(args.port, is_pv6)

        print(f'Connecting {args.client}:{args.port}, IPv{6 if is_pv6 else 4}')
        return send(args.client, args.port, args.packets, args.pass_rate, is_pv6)
    except Exception as ex:
        print(ex)
        return 1

    return 0


if __name__ == "__main__":
    rc = main()
    sys.exit(rc)