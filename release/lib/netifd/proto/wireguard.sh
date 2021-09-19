#!/bin/sh
# Copyright 2016-2017 Dan Luedtke <mail@danrl.com>
# Licensed to the public under the Apache License 2.0.
# 
# Original: https://github.com/openwrt/openwrt/blob/master/package/network/utils/wireguard-tools/files/wireguard.sh
#

LOGGER="/usr/bin/logger -t wireguard -p"
WG_IMPL=/usr/bin/wireguard-go
if [ ! -x $WG_IMPL ]; then
	$LOGGER daemon.err "Missing $WG_IMPL - aborting"
	exit 0
fi
WG_UTIL=/usr/bin/wg-go
if [ ! -x $WG_UTIL ]; then
	$LOGGER daemon.err "Missing $WG_UTIL - aborting"
	exit 0
fi

[ -n "$INCLUDE_ONLY" ] || {
	. /lib/functions.sh
	. ../netifd-proto.sh
	init_proto "$@"
}

proto_wireguard_init_config() {
	proto_config_add_string "private_key"
	proto_config_add_int "listen_port"
	proto_config_add_int "mtu"
	proto_config_add_string "fwmark"
	available=1
	no_proto_task=1
}

proto_wireguard_setup_peer() {
	local peer_config="$1"

	local public_key
	local preshared_key
	local allowed_ips
	local route_allowed_ips
	local endpoint_host
	local endpoint_port
	local persistent_keepalive

	config_get public_key "${peer_config}" "public_key"
	config_get preshared_key "${peer_config}" "preshared_key"
	config_get allowed_ips "${peer_config}" "allowed_ips"
	config_get_bool route_allowed_ips "${peer_config}" "route_allowed_ips" 0
	config_get endpoint_host "${peer_config}" "endpoint_host"
	config_get endpoint_port "${peer_config}" "endpoint_port"
	config_get persistent_keepalive "${peer_config}" "persistent_keepalive"

	if [ -z "$public_key" ]; then
		$LOGGER daemon.warn "$peer_config: Skipping peer config because public key is not defined."
		return 0
	fi

	echo "[Peer]" >> "${wg_cfg}"
	[ "${LOG_LEVEL}" = "debug" ] && $LOGGER daemon.debug "$peer_config: PublicKey=${public_key}"
	echo "PublicKey=${public_key}" >> "${wg_cfg}"
	if [ -n "${preshared_key}" ]; then
		[ "${LOG_LEVEL}" = "debug" ] && $LOGGER daemon.debug "$peer_config: PresharedKey=${preshared_key}"
		echo "PresharedKey=${preshared_key}" >> "${wg_cfg}"
	fi

	if [ -n "${allowed_ips}" ]; then
		local allowed="$(echo $allowed_ips | tr ' ' ',')"
		[ "${LOG_LEVEL}" = "debug" ] && $LOGGER daemon.debug "$peer_config: AllowedIPs=${allowed}"
		echo "AllowedIPs=${allowed}" >> "${wg_cfg}"
	fi
	if [ -n "${endpoint_host}" ]; then
		case "${endpoint_host}" in
			*:*)
				endpoint="[${endpoint_host}]"
				;;
			*)
				endpoint="${endpoint_host}"
				;;
		esac
		if [ -n "${endpoint_port}" ]; then
			endpoint="${endpoint}:${endpoint_port}"
		else
			endpoint="${endpoint}:51820"
		fi
		[ "${LOG_LEVEL}" = "debug" ] && $LOGGER daemon.debug "$peer_config: Endpoint=${endpoint}"
		echo "Endpoint=${endpoint}" >> "${wg_cfg}"
	fi
	if [ -n "${persistent_keepalive}" ]; then
		[ "${LOG_LEVEL}" = "debug" ] && $LOGGER daemon.debug "$peer_config: PersistentKeepalive=${persistent_keepalive}"
		echo "PersistentKeepalive=${persistent_keepalive}" >> "${wg_cfg}"
	fi

	if [ ${route_allowed_ips} -ne 0 ]; then
		for allowed_ip in ${allowed_ips}; do
			case "${allowed_ip}" in
				*:*/*)
					[ "${LOG_LEVEL}" = "debug" ] && $LOGGER daemon.debug "$peer_config: proto_add_ipv6_address ${allowed_ip%%/*} ${allowed_ip##*/}"
					proto_add_ipv6_route "${allowed_ip%%/*}" "${allowed_ip##*/}"
					;;
				*.*/*)
					[ "${LOG_LEVEL}" = "debug" ] && $LOGGER daemon.debug "$peer_config: proto_add_ipv4_address ${allowed_ip%%/*} ${allowed_ip##*/}"
					proto_add_ipv4_route "${allowed_ip%%/*}" "${allowed_ip##*/}"
					;;
				*:*)
					[ "${LOG_LEVEL}" = "debug" ] && $LOGGER daemon.debug "$peer_config: proto_add_ipv6_address ${allowed_ip%%/*} 128"
					proto_add_ipv6_route "${allowed_ip%%/*}" "128"
					;;
				*.*)
					[ "${LOG_LEVEL}" = "debug" ] && $LOGGER daemon.debug "$peer_config: proto_add_ipv4_address ${allowed_ip%%/*} 32"
					proto_add_ipv4_route "${allowed_ip%%/*}" "32"
					;;
			esac
		done
	fi
}

proto_wireguard_setup() {
	local config="$1"
	local wg_dir="/tmp/wireguard"
	local wg_cfg="${wg_dir}/${config}"

	local private_key
	local listen_port
	local mtu

	config_load network
	config_get private_key "${config}" "private_key"
	config_get listen_port "${config}" "listen_port"
	config_get addresses "${config}" "addresses"
	config_get mtu "${config}" "mtu"
	config_get fwmark "${config}" "fwmark"
	config_get ip6prefix "${config}" "ip6prefix"
	config_get nohostroute "${config}" "nohostroute"
	config_get tunlink "${config}" "tunlink"
	config_get log_level "${config}" "log_level"
	config_get enabled "${config}" "enabled"

    export LOG_LEVEL="${log_level}"

	[ "${LOG_LEVEL}" = "debug" ] && $LOGGER daemon.debug "ip link del dev ${config}"
	ip link del dev "${config}" >/dev/null 2>&1

	if [ "${enabled}" = "0" ]; then
		[ "${LOG_LEVEL}" = "debug" ] && $LOGGER daemon.debug "${config} disabled (enabled=${enabled})"
		return
	fi

	[ "${LOG_LEVEL}" = "debug" ] && $LOGGER daemon.debug "$WG_IMPL ${config}"
	if [ "${LOG_LEVEL}" = "debug" ]; then
		$WG_IMPL -f "${config}" | $LOGGER daemon.debug &
	else
		$WG_IMPL "${config}"
	fi

	if [ -n "${mtu}" ]; then
		[ "${LOG_LEVEL}" = "debug" ] && $LOGGER daemon.debug ip link set mtu "${mtu}" dev "${config}"
		ip link set mtu "${mtu}" dev "${config}"
	fi

	[ "${LOG_LEVEL}" = "debug" ] && $LOGGER daemon.debug "proto_init_update ${config} 1"
	proto_init_update "${config}" 1

	umask 077
	mkdir -p "${wg_dir}"
	echo "[Interface]" > "${wg_cfg}"
	[ "${LOG_LEVEL}" = "debug" ] && $LOGGER daemon.debug "$config: PrivateKey=${private_key}"
	echo "PrivateKey=${private_key}" >> "${wg_cfg}"
	if [ -n "${listen_port}" ]; then
		[ "${LOG_LEVEL}" = "debug" ] && $LOGGER daemon.debug "$config: ListenPort=${listen_port}"
		echo "ListenPort=${listen_port}" >> "${wg_cfg}"
	fi
	if [ "${fwmark}" ]; then
		[ "${LOG_LEVEL}" = "debug" ] && $LOGGER daemon.debug "$config: FwMark=${fwmark}"
		echo "FwMark=${fwmark}" >> "${wg_cfg}"
	fi

	config_foreach proto_wireguard_setup_peer "wireguard_${config}"

	# apply configuration file
	[ "${LOG_LEVEL}" = "debug" ] && $LOGGER daemon.debug "${WG_UTIL} setconf ${config} ${wg_cfg}"
	${WG_UTIL} setconf "${config}" "${wg_cfg}"
	QK_RETURN=$?
	[ "${LOG_LEVEL}" = "debug" ] && $LOGGER daemon.debug QK_RETURN="${QK_RETURN}"

	if [ ${QK_RETURN} -ne 0 ]; then
		sleep 5
		proto_setup_failed "${config}"
		exit 1
	fi

	for address in ${addresses}; do
		case "${address}" in
			*:*/*)
				[ "${LOG_LEVEL}" = "debug" ] && $LOGGER daemon.debug "$config: proto_add_ipv6_address ${address%%/*} ${address##*/}"
				proto_add_ipv6_address "${address%%/*}" "${address##*/}"
				;;
			*.*/*)
				[ "${LOG_LEVEL}" = "debug" ] && $LOGGER daemon.debug "$config: proto_add_ipv4_address ${address%%/*} ${address##*/}"
				proto_add_ipv4_address "${address%%/*}" "${address##*/}"
				;;
			*:*)
				[ "${LOG_LEVEL}" = "debug" ] && $LOGGER daemon.debug "$config: proto_add_ipv6_address ${address%%/*} 128"
				proto_add_ipv6_address "${address%%/*}" "128"
				;;
			*.*)
				[ "${LOG_LEVEL}" = "debug" ] && $LOGGER daemon.debug "$config: proto_add_ipv4_address ${address%%/*} 32"
				proto_add_ipv4_address "${address%%/*}" "32"
				;;
		esac
	done

	for prefix in ${ip6prefix}; do
		[ "${LOG_LEVEL}" = "debug" ] && $LOGGER daemon.debug "$config: proto_add_ipv6_prefix $prefix"
		proto_add_ipv6_prefix "$prefix"
	done

	# endpoint dependency
	if [ "${nohostroute}" != "1" ]; then
		for address in $(${WG_UTIL} show "${config}" endpoints | cut -d= -f2 | cut -d: -f1 | xargs); do
			[ "${LOG_LEVEL}" = "debug" ] && $LOGGER daemon.debug "$config: proto_add_host_dependency ${config} ${address} ${tunlink}"
			proto_add_host_dependency "${config}" "${address}" "${tunlink}"
		done
	fi

	[ "${LOG_LEVEL}" = "debug" ] && $LOGGER daemon.debug "proto_send_update ${config}"
	proto_send_update "${config}"
}

proto_wireguard_teardown() {
	local config="$1"
	ip link del dev "${config}" >/dev/null 2>&1
}

[ -n "$INCLUDE_ONLY" ] || {
	add_protocol wireguard
}