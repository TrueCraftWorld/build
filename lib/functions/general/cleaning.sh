#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-2.0
#
# Copyright (c) 2013-2023 Igor Pecovnik, igor@armbian.com
#
# This file is a part of the Armbian Build Framework
# https://github.com/armbian/build/

# general_cleaning <target>

# target: what to clean
# "make-atf" = make clean for ATF, if it is built.
# "make-uboot" = make clean for uboot, if it is built.
# "make-kernel" = make clean for kernel, if it is built. very slow.
# *important*: "make" by itself has disabled, since Armbian knows how to handle Make timestamping now.

# "debs" = delete packages in "./output/debs" for current branch and family. causes rebuilds, hopefully cached.
# "ubootdebs" - delete output/debs for uboot&board&branch
# "alldebs" = delete all packages in "./output/debs"
# "images" = delete "./output/images"
# "cache" = delete "./output/cache"
# "sources" = delete "./sources"
# "oldcache" = remove old cached rootfs except for the newest 8 files

function general_cleaning() {
	case $1 in
		debs) # delete ${DEB_STORAGE} for current branch and family
			if [[ -d "${DEB_STORAGE}" ]]; then
				display_alert "Cleaning" "general_cleaning '$1' - deprecated" "warn"
				display_alert "(not) cleaning ${DEB_STORAGE} for" "$BOARD $BRANCH" "info"
				# easier than dealing with variable expansion and escaping dashes in file names
				find "${DEB_STORAGE}" -name "${CHOSEN_UBOOT}_*.deb" #-delete
				find "${DEB_STORAGE}" \( -name "${CHOSEN_KERNEL}_*.deb" -o \
					-name "armbian-*.deb" -o \
					-name "plymouth-theme-armbian_*.deb" -o \
					-name "${CHOSEN_KERNEL/image/dtb}_*.deb" -o \
					-name "${CHOSEN_KERNEL/image/headers}_*.deb" -o \
					-name "${CHOSEN_KERNEL/image/source}_*.deb" -o \
					-name "${CHOSEN_KERNEL/image/firmware-image}_*.deb" \) #-delete
				[[ -n $RELEASE ]] && ls -la "${DEB_STORAGE}/${RELEASE}/${CHOSEN_ROOTFS}"_*.deb || true
				[[ -n $RELEASE ]] && ls -la "${DEB_STORAGE}/${RELEASE}/armbian-desktop-${RELEASE}"_*.deb || true
			fi
			;;

		ubootdebs) # delete ${DEB_STORAGE} for uboot, current branch and family
			if [[ -d "${DEB_STORAGE}" ]]; then
				display_alert "Cleaning ${DEB_STORAGE} for u-boot" "$BOARD $BRANCH" "info"
				# easier than dealing with variable expansion and escaping dashes in file names
				find "${DEB_STORAGE}" -name "${CHOSEN_UBOOT}_*.deb" -delete
			fi
			;;

		extras) # delete ${DEB_STORAGE}/extra/$RELEASE for all architectures
			if [[ -n $RELEASE && -d ${DEB_STORAGE}/extra/$RELEASE ]]; then
				display_alert "Cleaning ${DEB_STORAGE}/extra for" "$RELEASE" "info"
				rm -rf "${DEB_STORAGE}/extra/${RELEASE}"
			fi
			;;

		alldebs) # delete output/debs
			[[ -d "${DEB_STORAGE}" ]] && display_alert "Cleaning" "${DEB_STORAGE}" "info" && rm -rf "${DEB_STORAGE:?}"/*
			;;

		cache) # delete output/cache
			[[ -d "${SRC}"/cache/rootfs ]] && display_alert "Cleaning" "rootfs cache (all)" "info" && find "${SRC}"/cache/rootfs -type f -delete
			;;

		images) # delete output/images
			[[ -d "${DEST}"/images ]] && display_alert "Cleaning" "output/images" "info" && rm -rf "${DEST}"/images/*
			;;

		sources) # delete cache/sources and output/buildpkg
			[[ -d "${SRC}"/cache/sources ]] && display_alert "Cleaning" "sources" "info" && rm -rf "${SRC}"/cache/sources/* "${DEST}"/buildpkg/*
			;;

		oldcache) # remove old `cache/rootfs` except for the newest 8 files
			if [[ -d "${SRC}"/cache/rootfs && $(ls -1 "${SRC}"/cache/rootfs/*.zst* 2> /dev/null | wc -l) -gt "${ROOTFS_CACHE_MAX}" ]]; then
				display_alert "Cleaning" "rootfs cache (old)" "info"
				(
					cd "${SRC}"/cache/rootfs
					ls -t *.lz4 | sed -e "1,${ROOTFS_CACHE_MAX}d" | xargs -d '\n' rm -f
				)
				# Remove signatures if they are present. We use them for internal purpose
				(
					cd "${SRC}"/cache/rootfs
					ls -t *.asc | sed -e "1,${ROOTFS_CACHE_MAX}d" | xargs -d '\n' rm -f
				)
			fi
			;;

		*)
			display_alert "Unknown clean level" "Unknown clean level '${1}'" "warn"
			;;
	esac

	return 0 # a LOT of shortcircuits above; prevent spurious error messages
}

function clean_deprecated_mountpoints() {
	# Cleaning of old, deprecated mountpoints; only done if not running under Docker.
	# mountpoints under Docker manifest as volumes, and as such can't be cleaned this way.
	if [[ "${ARMBIAN_RUNNING_IN_CONTAINER}" != "yes" ]]; then
		prepare_armbian_mountpoints_description_dict
		local mountpoint=""
		for mountpoint in "${ARMBIAN_MOUNTPOINTS_DEPRECATED[@]}"; do
			local mountpoint_dir="${SRC}/${mountpoint}"
			display_alert "Considering cleaning deprecated mountpoint" "${mountpoint_dir}" "debug"
			if [[ -d "${mountpoint_dir}" ]]; then
				display_alert "Cleaning deprecated mountpoint" "${mountpoint_dir}" "info"
				run_host_command_logged rm -rf "${mountpoint_dir}"
			fi
		done
	fi
	return 0
}
