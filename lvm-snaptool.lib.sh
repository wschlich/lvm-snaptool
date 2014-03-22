## $Id: lvm-snaptool.lib.sh,v 1.5 2009/05/27 15:39:33 wschlich Exp wschlich $
## vim:ts=4:sw=4:nu:ai:nowrap:
##
## Created by Wolfram Schlich <wschlich@gentoo.org>
## Licensed under the GNU GPLv3
##

##
## NOTES
## =====
## - with XFS, do NOT manually call xfs_freeze:
##   http://readlist.com/lists/redhat.com/linux-lvm/0/952.html
##   http://readlist.com/lists/redhat.com/linux-lvm/0/957.html
##   http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=285979
##

##
## REQUIRED PROGRAMS IN PATH
## =========================
## - bc
## - cut
## - env
## - sort
## - touch
## - rm
## - mkdir
## - mount
## - umount
## - readlink
## - mktemp
## - blkid
## - xargs
## - hostname
## - uname
## - lvs
## - lvcreate
## - lvremove
##

##
## application control functions
##

function __init() {

	## parse command line options
	while getopts ':CDMd:e:f:hqs:' opt; do
		case "${opt}" in
			## create snapshots
			C)
				Task="create"
				;;
			## delete snapshots
			D)
				Task="delete"
				;;
			## mirror complete system
			M)
				Mode="mirror"
				;;
			## snapshot volume mount directory
			d)
				SnapshotVolumeMountDirectory="${OPTARG}"
				;;
			## exclude specific LVs
			e)
				LogicalVolumeExcludeList="${OPTARG}"
				;;
			## snapshot volume size factor
			f)
				SnapshotVolumeSizeFactor="${OPTARG}"
				;;
			## help
			h)
				Task="help"
				;;
			## quiet operation
			q)
				__MsgQuiet=1
				;;
			## snapshot volume name suffix
			s)
				SnapshotVolumeNameSuffix="${OPTARG}"
				;;
			## option without a required argument
			:)
				__die 2 "option -${OPTARG} requires an argument" # TODO FIXME: switch to __msg err
				;;
			## unknown option
			\?)
				__die 2 "unknown option -${OPTARG}" # TODO FIXME: switch to __msg err
				;;
			## this should never happen
			*)
				__die 2 "there's an error in the matrix!" # TODO FIXME: switch to __msg err
				;;
		esac
		__msg debug "command line argument: -${opt}${OPTARG:+ '${OPTARG}'}"
	done
	## check if command line options were given at all
	if [[ ${OPTIND} -eq 1 ]]; then
		__msg err "no command line option specified"
		printUsage && exit 2
	fi
	## shift off options + arguments
	let OPTIND--; shift ${OPTIND}; unset OPTIND
	args="${@}"
	set --

	## just show help?
	if [[ ${Task} == "help" ]]; then
		printUsage && exit 0
	fi

	## populate logical volume array
	## from logical volume list
	IFS=','
	LogicalVolumeArray=( ${LogicalVolumeList} )
	unset IFS
	#validateLogicalVolumeArray # TODO FIXME: implement function
	##*/*) # "any/any"

	## populate logical volume exclude array
	## from logical volume exclude list
	IFS=','
	LogicalVolumeExcludeArray=( ${LogicalVolumeExcludeList} )
	unset IFS
	#validateLogicalVolumeExcludeArray # TODO FIXME: implement function

	## populate snapshot volume size factor array
	## from snapshot volume size factor list
	IFS=','
	SnapshotVolumeSizeFactorArray=( ${SnapshotVolumeSizeFactor} )
	unset IFS
	#validateSnapshotVolumeSizeFactorArray # TODO FIXME: implement function
	##*/*:+([0-9])|*/*:+([0-9].[0-9])) # "any/any:num" or "any/any:num.num"
	##+([0-9])|+([0-9].[0-9])) # "num" or "num.num"

	## populate snapshot volume mount directory array
	## from snapshot volume mount directory list
	IFS=','
	SnapshotVolumeMountDirectoryArray=( ${SnapshotVolumeMountDirectory} )
	unset IFS
	#validateSnapshotVolumeMountDirectoryArray # TODO FIXME: implement function

	## system mirror mode
	case ${Mode} in
		mirror)
			case ${Task} in
				create)
					## check arguments for mirror creation
					if [[ -z ${SnapshotVolumeMountDirectory} ]]; then
						__msg err "snapshot volume mount directory not specified"
						printUsage && exit 2
					fi
					;;
				delete)
					## check arguments for mirror deletion
					if [[ -z ${SnapshotVolumeMountDirectory} ]]; then
						__msg err "snapshot volume mount directory not specified"
						printUsage && exit 2
					fi
					;;
				'')
					__msg err "mode '${Mode}': no task specified"
					printUsage && exit 2
					;;
				*)
					__msg err "mode '${Mode}': invalid task specified: '${Task}'"
					printUsage && exit 2
					;;
			esac
			;;
		'')
			__msg err "no mode specified"
			printUsage && exit 2
			;;
		*)
			__msg err "invalid mode specified: '${Mode}'"
			printUsage && exit 2
			;;
	esac

} # __init()

function __main() {

	if [[ ${Mode} == "mirror" ]]; then
		case ${Task} in
			create)
				## create mirror
				if ! createSystemMirror; then
					__die 2 "failed to create system mirror"
				else
					__msg info "successfully created system mirror"
				fi
				;;
			delete)
				## delete mirror
				if ! deleteSystemMirror; then
					__die 2 "failed to delete system mirror"
				else
					__msg info "successfully deleted system mirror"
				fi
				;;
		esac
	fi

} # __main()

##
## application worker functions
##

function printUsage() {

	## ----- head -----
	##
	## DESCRIPTION:
	##   prints usage information
	##
	## ARGUMENTS:
	##   /
	##
	## GLOBAL VARIABLES USED:
	##   /
	##

	## ----- main -----

	cat <<-USAGE

		Usage: ${__ScriptFile} [options]
		Options:
		-M:     system mirror mode, creates a mirror of all currently
		        mounted volumes in a new directory structure.
		        requires: one of -C -D
		        accepts: -d -e -f
		-C:     create snapshot(s).
		        requires: -M
		        excludes: -D
		        accepts: -d -e -f -s
		-D:     delete snapshot(s).
		        requires: -M
		        excludes: -C
		        accepts: -d -e -s
		        ignores: -f
		-e arg: logical volumes to exclude.
		        example: -e vg.sys/lv.home
		                 -e vg.sys/lv.home,vg.sys/lv.usr
		-f arg: snapshot volume size factor.
		        example: -f 0.2
		                 -f vg.sys/lv.home:0.1,vg.sys/lv.var:0.2,0.5
		        default: ${SnapshotVolumeSizeFactor}
		-s arg: snapshot volume name suffix.
		        example: -s .snapshot
		        default: ${SnapshotVolumeNameSuffix}
		-d arg: mount directory for system mirror.
		        example: -d /mnt/lvm-snapshots
		        default: ${SnapshotVolumeMountDirectory}

		Options -M and one of -C -D are required.

		USAGE

	return 0 # success

}

function createSnapshot() {

	## ----- head -----
	##
	## DESCRIPTION:
	##   creates a snapshot of a logical volume.
	##
	## ARGUMENTS:
	##   1: volumeGroupName (req): vg.sys
	##   2: logicalVolumeName (req): lv.home
	##   3: snapshotVolumeName (req): lv.home.snapshot
	##   4: snapshotVolumeSizeFactor (req): 0.2 (=20%)
	##
	## GLOBAL VARIABLES USED:
	##   LvmDevicesDirectory
	##

	local volumeGroupName=${1}
	if [[ -z "${volumeGroupName}" ]]; then
		__msg err "argument 1 (volumeGroupName) missing"
		return 2 # error
	fi
	__msg debug "volumeGroupName: ${volumeGroupName}"

	local logicalVolumeName=${2}
	if [[ -z "${logicalVolumeName}" ]]; then
		__msg err "argument 2 (logicalVolumeName) missing"
		return 2 # error
	fi
	__msg debug "logicalVolumeName: ${logicalVolumeName}"

	local snapshotVolumeName=${3}
	if [[ -z "${snapshotVolumeName}" ]]; then
		__msg err "argument 3 (snapshotVolumeName) missing"
		return 2 # error
	fi
	__msg debug "snapshotVolumeName: ${snapshotVolumeName}"

	local snapshotVolumeSizeFactor=${4}
	if [[ -z "${snapshotVolumeSizeFactor}" ]]; then
		__msg err "argument 4 (snapshotVolumeSizeFactor) missing"
		return 2 # error
	fi
	__msg debug "snapshotVolumeSizeFactor: ${snapshotVolumeSizeFactor}"

	## ----- main -----

	## generate logical volume device (e.g. /dev/vg.sys/lv.home)
	local logicalVolumeDevice="${LvmDevicesDirectory:-/dev}/${volumeGroupName}/${logicalVolumeName}"
	__msg debug "logicalVolumeDevice: ${logicalVolumeDevice}"

	## check if device is a logical volume
	if ! deviceIsLogicalVolume "${logicalVolumeDevice}"; then
		__msg err "device '${logicalVolumeDevice}' is not a logical volume"
		return 2 # error
	fi

	## get logical volume size
	local logicalVolumeSize=$(env LVM_SUPPRESS_FD_WARNINGS=1 lvs --separator : --noheadings --nosuffix \
		--units m -o lv_name,lv_size "${logicalVolumeDevice}" 2>>"${_L}" | cut -d : -f 2 2>>"${_L}")
	local -i lvsExitCode=${PIPESTATUS[0]}
	local -i cutExitCode=${PIPESTATUS[1]}
	if [[ ${lvsExitCode} -ne 0 || ${cutExitCode} -ne 0 || -z "${logicalVolumeSize}" ]]; then
		__msg err "failed to get size of logical volume '${logicalVolumeDevice}'"
		return 2 # error
	fi
	__msg debug "logicalVolumeSize: ${logicalVolumeSize}"

	## calculate snapshot volume size
	local snapshotVolumeSize=$(echo "${logicalVolumeSize} * ${snapshotVolumeSizeFactor}" | bc)
	local -i bcExitCode=${PIPESTATUS[1]}
	if [[ ${bcExitCode} -ne 0 || -z "${snapshotVolumeSize}" ]]; then
		__msg err "failed to calculate snapshot volume size for logical volume '${logicalVolumeDevice}'"
		return 2 # error
	fi
	__msg debug "snapshotVolumeSize: ${snapshotVolumeSize}"

	## generate snapshot volume device (e.g. /dev/vg.sys/lv.home.snapshot)
	local snapshotVolumeDevice="${LvmDevicesDirectory:-/dev}/${volumeGroupName}/${snapshotVolumeName}"
	__msg debug "snapshotVolumeDevice: ${snapshotVolumeDevice}"

	## check if snapshot volume device already exists
	if [[ -e "${snapshotVolumeDevice}" ]]; then
		__msg err "snapshot volume device '${snapshotVolumeDevice}' already exists"
		return 2 # error
	fi

	## create snapshot volume
	if ! env LVM_SUPPRESS_FD_WARNINGS=1 lvcreate -s -p r -c 512 -C y --addtag snapshots \
		-L "${snapshotVolumeSize}m" -n "${snapshotVolumeName}" \
		"${logicalVolumeDevice}" >>"${_L}" 2>&1; then
		__msg err "failed to create snapshot volume '${snapshotVolumeName}' of" \
			"logical volume '${volumeGroupName}/${logicalVolumeName}'"
		return 2 # error
	else
		__msg debug "successfully created snapshot volume '${snapshotVolumeName}' of" \
			"logical volume '${volumeGroupName}/${logicalVolumeName}'"
	fi

	return 0 # success

} # createSnapshot()

function deleteSnapshot() {

	## ----- head -----
	##
	## DESCRIPTION:
	##   deletes a snapshot volume.
	##
	## ARGUMENTS:
	##   1: volumeGroupName (req): vg.sys
	##   2: snapshotVolumeName (req): lv.home.snapshot
	##
	## GLOBAL VARIABLES USED:
	##   LvmDevicesDirectory
	##

	local volumeGroupName=${1}
	if [[ -z "${volumeGroupName}" ]]; then
		__msg err "argument 1 (volumeGroupName) missing"
		return 2 # error
	fi
	__msg debug "volumeGroupName: ${volumeGroupName}"

	local snapshotVolumeName=${2}
	if [[ -z "${snapshotVolumeName}" ]]; then
		__msg err "argument 2 (snapshotVolumeName) missing"
		return 2 # error
	fi
	__msg debug "snapshotVolumeName: ${snapshotVolumeName}"

	## ----- main -----

	## generate snapshot volume device (e.g. /dev/vg.sys/lv.home.snapshot)
	local snapshotVolumeDevice="${LvmDevicesDirectory:-/dev}/${volumeGroupName}/${snapshotVolumeName}"
	__msg debug "snapshotVolumeDevice: ${snapshotVolumeDevice}"

	## check if device is a snapshot volume
	if ! deviceIsSnapshotVolume "${snapshotVolumeDevice}"; then
		__msg err "device '${snapshotVolumeDevice}' is not a snapshot volume"
		return 2 # error
	fi

	## remove snapshot volume
	if ! env LVM_SUPPRESS_FD_WARNINGS=1 lvremove -f "${snapshotVolumeDevice}" >>"${_L}" 2>&1; then
		__msg err "failed to remove snapshot volume device '${snapshotVolumeDevice}'"
		return 2 # error
	else
		__msg debug "successfully removed snapshot volume device '${snapshotVolumeDevice}'"
	fi

	return 0 # success

} # deleteSnapshot()

function mountSnapshot() {

	## ----- head -----
	##
	## DESCRIPTION:
	##   mounts a snapshot volume on a directory.
	##
	## ARGUMENTS:
	##   1: volumeGroupName (req): vg.sys
	##   2: snapshotVolumeName (req): lv.home
	##   3: snapshotVolumeMountDirectory (req): /mnt/snapshots/home
	##
	## GLOBAL VARIABLES USED:
	##   LvmDevicesDirectory (fallback: /dev)
	##

	local volumeGroupName=${1}
	if [[ -z "${volumeGroupName}" ]]; then
		__msg err "argument 1 (volumeGroupName) missing"
		return 2 # error
	fi
	__msg debug "volumeGroupName: ${volumeGroupName}"

	local snapshotVolumeName=${2}
	if [[ -z "${snapshotVolumeName}" ]]; then
		__msg err "argument 2 (snapshotVolumeName) missing"
		return 2 # error
	fi
	__msg debug "snapshotVolumeName: ${snapshotVolumeName}"

	local snapshotVolumeMountDirectory=${3}
	if [[ -z "${snapshotVolumeMountDirectory}" ]]; then
		__msg err "argument 3 (snapshotVolumeMountDirectory) missing"
		return 2 # error
	fi
	__msg debug "snapshotVolumeMountDirectory: ${snapshotVolumeMountDirectory}"

	## ----- main -----

	## generate snapshot volume device (e.g. /dev/vg.sys/lv.home)
	local snapshotVolumeDevice="${LvmDevicesDirectory:-/dev}/${volumeGroupName}/${snapshotVolumeName}"
	__msg debug "snapshotVolumeDevice: ${snapshotVolumeDevice}"

	## check if snapshot volume device exists
	if [[ ! -e "${snapshotVolumeDevice}" ]]; then
		__msg err "snapshot volume device '${snapshotVolumeDevice}' does not exist"
		return 2 # error
	fi

	## check if device is a snapshot volume
	if ! deviceIsSnapshotVolume "${snapshotVolumeDevice}"; then
		__msg err "device '${snapshotVolumeDevice}' is not a snapshot volume"
		return 2 # error
	fi

	## use mount options based on determined filesystem type
	local filesystemType=$(blkid -c /dev/null -s TYPE -o value ${snapshotVolumeDevice} 2>>"${_L}")
	local -i blkidExitCode=${?}
	if [[ ${blkidExitCode} -ne 0 ]]; then
		__msg err "failed running blkid to determine filesystem type of snapshot volume device '${snapshotVolumeDevice}'"
		return 2 # error
	fi
	__msg debug "filesystemType: ${filesystemType}"
	local mountOpts=
	case "${filesystemType}" in
		 xfs) mountOpts="nouuid,norecovery,ro" ;; # special options for XFS
		ext2) mountOpts="ro" ;; # special options for ext2
		ext3) mountOpts="ro" ;; # special options for ext3
		   *) mountOpts="ro" ;; # default options
	esac
	__msg debug "mountOpts: ${mountOpts}"

	## check for mount directory
	if [[ ! -d "${snapshotVolumeMountDirectory}" ]]; then
		__msg info "snapshot volume mount directory '${snapshotVolumeMountDirectory}'" \
			"doesn't exist -- creating..."
		if ! mkdir -p "${snapshotVolumeMountDirectory}"; then
			__msg err "failed to create snapshot volume mount directory" \
				"'${snapshotVolumeMountDirectory}'"
			return 2 # error
		else
			__msg debug "successfully created snapshot volume mount directory" \
				"'${snapshotVolumeMountDirectory}'"
		fi
	fi

	## mount snapshot volume
	if ! mount -o ${mountOpts} "${snapshotVolumeDevice}" "${snapshotVolumeMountDirectory}"; then
		__msg err "failed to mount snapshot volume device '${snapshotVolumeDevice}'" \
			"on '${snapshotVolumeMountDirectory}' with options '${mountOpts}'"
		return 2 # error
	else
		__msg debug "successfully mounted snapshot volume device '${snapshotVolumeDevice}'" \
			"on '${snapshotVolumeMountDirectory}' with options '${mountOpts}"
	fi

	return 0 # success

} # mountSnapshot()

function bindMountDirectory() {

	## ----- head -----
	##
	## DESCRIPTION:
	##   bind-mounts a directory on another.
	##
	## ARGUMENTS:
	##   1: sourceDirectory (req)
	##   2: targetDirectory (req)
	##
	## GLOBAL VARIABLES USED:
	##   /
	##

	local sourceDirectory=${1}
	if [[ -z "${sourceDirectory}" ]]; then
		__msg err "argument 1 (sourceDirectory) missing"
		return 2 # error
	fi
	__msg debug "sourceDirectory: ${sourceDirectory}"

	local targetDirectory=${2}
	if [[ -z "${targetDirectory}" ]]; then
		__msg err "argument 2 (targetDirectory) missing"
		return 2 # error
	fi
	__msg debug "targetDirectory: ${targetDirectory}"

	## ----- main -----

	## check for source directory
	if [ ! -d "${sourceDirectory}" ]; then
		__msg err "source directory '${sourceDirectory}' doesn't exist"
		return 2 # error
	fi

	## check for target directory
	if [[ ! -d "${targetDirectory}" ]]; then
		__msg info "target directory '${targetDirectory}' doesn't exist -- creating..."
		if ! mkdir -p "${targetDirectory}"; then
			__msg err "failed to create target directory '${targetDirectory}'"
			return 2 # error
		else
			__msg debug "successfully created target directory '${targetDirectory}'"
		fi
	fi

	## check if mount point directory actually has something mounted on
	if directoryHasMount "${targetDirectory}"; then
		__msg err "something is already mounted on directory '${targetDirectory}'"
		return 2 # error
	fi

	## bind-mount source directory on target directory
	if ! mount -o bind "${sourceDirectory}" "${targetDirectory}" >>"${_L}" 2>&1; then
		__msg err "failed to bind-mount directory '${sourceDirectory}' on directory '${targetDirectory}'"
		return 2 # error
	else
		__msg debug "successfully bind-mounted directory '${sourceDirectory}' on directory '${targetDirectory}'"
	fi

	## remount bind-mounted directory ro (supported from kernel 2.6.26 on),
	## see http://lwn.net/Articles/281157/
	local kernelRelease=$(uname -r)
	local kernelRelease=${kernelRelease/[^0-9.]*/} # strip localversion
	IFS='.'
	set -- ${kernelRelease}
	unset IFS
	local -i kernelVersionMajor=${1}
	local -i kernelVersionMinor=${2}
	local -i kernelVersionPatchlevel=${3}
	set --
	if [[ ${kernelVersionMajor} -ge 2 && ${kernelVersionMinor} -ge 6 && ${kernelVersionPatchlevel} -ge 26 ]]; then
		__msg debug "trying to remount bind-mounted directory read-only (kernel version >= 2.6.26)"
		if ! mount -o remount,ro "${targetDirectory}" >>"${_L}" 2>&1; then
			__msg err "failed to remount bind-mounted directory '${targetDirectory}' read-only"
			return 2 # error
		else
			__msg debug "successfully remounted bind-mounted directory '${targetDirectory}' read-only"
		fi
	else
		__msg debug "not trying to remount bind-mounted directory read-only (kernel version < 2.6.26)"
	fi

	return 0 # success

} # bindMountDirectory()

function unmount() {

	## ----- head -----
	##
	## DESCRIPTION:
	##   unmounts a filesystem from a directory.
	##
	## ARGUMENTS:
	##   1: mountPointDirectory (req)
	##
	## GLOBAL VARIABLES USED:
	##   /
	##

	local mountPointDirectory=${1}
	if [[ -z "${mountPointDirectory}" ]]; then
		__msg err "argument 1 (mountPointDirectory) missing"
		return 2 # error
	fi
	__msg debug "mountPointDirectory: ${mountPointDirectory}"

	## ----- main -----

	## check if mount point directory actually has something mounted on
	if ! directoryHasMount "${mountPointDirectory}"; then
		__msg err "nothing mounted on directory '${mountPointDirectory}'"
		return 2 # error
	fi

	## unmount filesystem from mount point directory
	if ! umount "${mountPointDirectory}" >>"${_L}" 2>&1; then
		__msg err "failed to unmount filesystem from directory '${mountPointDirectory}'"
		return 2 # error
	else
		__msg debug "successfully unmounted filesystem from directory '${mountPointDirectory}'"
	fi

	return 0 # success

} # unmount()

function deviceIsLogicalVolume() {

	## ----- head -----
	##
	## DESCRIPTION:
	##   checks if the given device is a logical volume.
	##
	## ARGUMENTS:
	##   1: device (req)
	##
	## GLOBAL VARIABLES USED:
	##   /
	##

	local device=${1}
	if [[ -z "${device}" ]]; then
		__msg err "argument 1 (device) missing"
		return 2 # error
	fi
	__msg debug "device: ${device}"

	## ----- main -----

	## check if device exists
	if [[ ! -e "${device}" ]]; then
		__msg err "device '${device}' does not exist"
		return 2 # error
	fi

	## check if device is a block device
	local realDevice="$(readlink -f ${device})"
	__msg debug "realDevice: ${realDevice}"
	if [[ ! -b "${realDevice}" ]]; then
		__msg err "device '${device}' does not resolve to a block device"
		return 2 # error
	fi

	env LVM_SUPPRESS_FD_WARNINGS=1 lvs --noheadings -o lv_name "${device}" >>"${_L}" 2>&1
	local -i lvsExitCode=${?}
	if [[ ${lvsExitCode} -ne 0 ]]; then
		return 1 # check result: negative
	fi

	return 0 # check result: positive

} # deviceIsLogicalVolume()

function deviceIsSnapshotVolume() {

	## ----- head -----
	##
	## DESCRIPTION:
	##   checks if the given device is a snapshot volume.
	##
	## ARGUMENTS:
	##   1: device (req)
	##
	## GLOBAL VARIABLES USED:
	##   /
	##

	local device=${1}
	if [[ -z "${device}" ]]; then
		__msg err "argument 1 (device) missing"
		return 2 # error
	fi
	__msg debug "device: ${device}"

	## ----- main -----

	## check if device exists
	if [[ ! -e "${device}" ]]; then
		__msg err "device '${device}' does not exist"
		return 2 # error
	fi

	## check if device is a block device
	local realDevice="$(readlink -f ${device})"
	__msg debug "realDevice: ${realDevice}"
	if [[ ! -b "${realDevice}" ]]; then
		__msg err "device '${device}' does not resolve to a block device"
		return 2 # error
	fi

	## get snapshot volume origin
	local snapshotVolumeOrigin=$(
		env LVM_SUPPRESS_FD_WARNINGS=1 lvs --separator / --noheadings --nosuffix \
			--units m -o origin "${device}" 2>>"${_L}" | xargs -n 1 2>>"${_L}"
	)
	local -i lvsExitCode=${?}
	if [[ ${lvsExitCode} -ne 0 ]]; then
		__msg err "failed running 'lvs' to check if device '${device}' is a snapshot volume"
		return 2 # error
	fi
	__msg debug "snapshotVolumeOrigin: ${snapshotVolumeOrigin}"

	## empty origin indicates non-snapshot volume
	if [[ -z ${snapshotVolumeOrigin} ]]; then
		return 1 # check result: negative
	fi

	return 0 # check result: positive

} # deviceIsSnapshotVolume()

function mountPointIsBindMount() {

	## ----- head -----
	##
	## DESCRIPTION:
	##   checks if the given mount point is a bind-mount.
	##   looks in /etc/mtab as /proc/mounts shows bind-mounts
	##   as regular mounts .
	##
	## ARGUMENTS:
	##   1: mountPoint (req)
	##
	## GLOBAL VARIABLES USED:
	##   /
	##

	local mountPoint=${1}
	if [[ -z "${mountPoint}" ]]; then
		__msg err "argument 1 (mountPoint) missing"
		return 2 # error
	fi
	__msg debug "mountPoint: ${mountPoint}"

	## ----- main -----

	## check for /etc/mtab
	if [[ ! -e /etc/mtab ]]; then
		__msg err "/etc/mtab does not exist"
		return 2 # error
	fi

	## split /etc/mtab into array by newline
	IFS=$'\n'
	local -a mtabMountArray=( $(sort -k 2,2 < /etc/mtab) )
	local -a sortExitCode=${?}
	unset IFS
	if [[ ${sortExitCode} -ne 0 ]]; then
		__msg err "failed sorting /etc/mtab"
		return 2 # error
	fi
	
	## loop through array of mounts
	local -i i
	for ((i = 0; i < ${#mtabMountArray[@]}; i++)); do
		## split mount line into fields
		IFS=' '
		set -- ${mtabMountArray[i]}
		unset IFS
		#local mtabMountDevice=${1}
		local mtabMountPoint=${2}
		#local mtabMountFilesystemType=${3}
		local mtabMountOpts=${4}
		set --

		#__msg debug "mtabMountPoint: ${mtabMountPoint}; mtabMountOpts: ${mtabMountOpts}"
		## check if current mtab entry equals the mount point we're looking for
		if [[ "${mtabMountPoint}" == "${mountPoint%/}" ]]; then
			case "${mtabMountOpts}" in
				## check if current mtab entry is a bind mount
				bind|bind,*|*,bind|*,bind,*)
					return 0 # check result: positive
					;;
				*)
					continue
					;;
			esac
		fi
	done

	return 1 # check result: negative

} # mountPointIsBindMount()

function directoryHasMount() {

	## ----- head -----
	##
	## DESCRIPTION:
	##   checks if the given directory has something mounted on.
	##   looks in /proc/mounts.
	##
	## ARGUMENTS:
	##   1: directory (req)
	##
	## GLOBAL VARIABLES USED:
	##   /
	##

	local directory=${1}
	if [[ -z "${directory}" ]]; then
		__msg err "argument 1 (directory) missing"
		return 2 # error
	fi
	__msg debug "directory: ${directory}"

	## ----- main -----

	## check for /proc/mounts
	if [[ ! -e /proc/mounts ]]; then
		__msg err "/proc/mounts does not exist"
		return 2 # error
	fi

	## split /proc/mounts into array by newline
	IFS=$'\n'
	local -a procMountArray=( $(sort -k 2,2 < /proc/mounts) )
	local -i sortExitCode=${?}
	unset IFS
	if [[ ${sortExitCode} -ne 0 ]]; then
		__msg err "failed sorting /proc/mounts"
		return 2 # error
	fi

	## loop through array of mounts
	local -i i
	for ((i = 0; i < ${#procMountArray[@]}; i++)); do
		## split mount line into fields
		IFS=' '
		set -- ${procMountArray[i]}
		unset IFS
		#local procMountDevice=${1}
		local procMountPoint=${2}
		#local procMountFilesystemType=${3}
		local procMountOpts=${4}
		set --
		#__msg debug "procMountPoint: ${procMountPoint}; procMountOpts: ${procMountOpts}"
		## check if current proc entry equals the mount point we're looking for
		if [[ "${procMountPoint}" == "${directory%/}" ]]; then
			return 0 # check result: positive
		fi
	done

	return 1 # check result: negative

} # directoryHasMount()

function printAllMountedVolumes() {

	## ----- head -----
	##
	## DESCRIPTION:
	##   prints a list of all mounted volumes (including bind-mounts and excluding special filesystems).
	##   looks in /proc/mounts.
	##
	## ARGUMENTS:
	##   1: baseDirectory (opt): / or /mnt/snapshots (default: /)
	##   2: sortOrder (opt): 'asc' or 'desc' (default: 'asc')
	##
	## GLOBAL VARIABLES USED:
	##   /
	##

	local baseDirectory=${1:-/}
	local sortOrder=${2:-asc}
	__msg -q debug "baseDirectory: ${baseDirectory}"
	__msg -q debug "sortOrder: ${sortOrder}"

	## ----- main -----

	## check for /proc/mounts
	if [[ ! -e /proc/mounts ]]; then
		__msg -q err "/proc/mounts does not exist"
		return 2 # error
	fi

	## determine sort arguments based on sort order
	case ${sortOrder} in
		asc)
			local sortArgs=
			;;
		desc)
			local sortArgs="-r"
			;;
		*)
			;;
	esac

	## split /proc/mounts into array by newline
	IFS=$'\n'
	local -a procMountArray=( $(sort -k 2,2 ${sortArgs} < /proc/mounts) )
	local -i sortExitCode=${?}
	unset IFS
	if [[ ${sortExitCode} -ne 0 ]]; then
		__msg -q err "failed sorting /proc/mounts"
		return 2 # error
	fi

	## loop through array of mounts
	local -i i
	for ((i = 0; i < ${#procMountArray[@]}; i++)); do
		## split mount line into fields
		IFS=' '
		set -- ${procMountArray[i]}
		unset IFS
		local procMountDevice=${1}
		local procMountPoint=${2}
		local procMountFilesystemType=${3}
		#local procMountOpts=${4}
		set --
		#__msg -q debug "procMountDevice: ${procMountDevice}; procMountPoint: ${procMountPoint}; procMountFilesystemType: ${procMountFilesystemType}"
		## check for special filesystem types to skip
		case "${procMountFilesystemType}" in
			debugfs|devpts|nfsd|proc|rootfs|securityfs|sysfs|tmpfs|usbfs)
				continue
				;;
			ext2|ext3|jfs|reiserfs|xfs) # TODO FIXME: extend list
				;;
			*)
				continue # TODO FIXME: log unsupported fstype?
				;;
		esac
		## check if mount point is given base directory itself
		## or below given base directory
		case "${procMountPoint}" in
			"${baseDirectory%/}"|"${baseDirectory%/}"/*)
				;;
			*)
				continue
				;;
		esac
		## finally print device and mount point
		echo "${procMountDevice}:${procMountPoint}"
	done

	return 0 # success

} # printAllMountedVolumes()

function printAllLogicalVolumes() {

	## ----- head -----
	##
	## DESCRIPTION:
	##   prints a list of all logical volumes in the form "VG/LV"
	##   (without device directory prefix).
	##
	## ARGUMENTS:
	##   /
	##
	## GLOBAL VARIABLES USED:
	##   /
	##

	## ----- main -----
	env LVM_SUPPRESS_FD_WARNINGS=1 lvs --separator / --noheadings --nosuffix \
		--units m -o vg_name,lv_name 2>>"${_L}" | xargs -n 1 2>>"${_L}"
	local -i lvsExitCode=${PIPESTATUS[0]}
	local -i xargsExitCode=${PIPESTATUS[1]}
	if [[ ${lvsExitCode} -ne 0 ]]; then
		__msg -q err "failed to get list of all logical volumes"
		return 2 # error
	fi

	return 0 # success

} # printAllLogicalVolumes()

function printLogicalVolumeInfo() {

	## ----- head -----
	##
	## DESCRIPTION:
	##   prints the volume group name and logical volume name of a logical volume device.
	##
	## ARGUMENTS:
	##   1: device (req): /dev/mapper/vg.sys-lv.home
	##
	## GLOBAL VARIABLES USED:
	##   /
	##

	local device=${1}
	if [[ -z "${device}" ]]; then
		__msg -q err "argument 1 (device) missing"
		return 2 # error
	fi
	__msg -q debug "device: ${device}"

	## ----- main -----

	local logicalVolumeInfo=$(env LVM_SUPPRESS_FD_WARNINGS=1 lvs --separator / --noheadings --nosuffix \
		--units m -o vg_name,lv_name "${device}" 2>>"${_L}" | xargs -n 1 2>>"${_L}")
	local -i lvsExitCode=${PIPESTATUS[0]}
	local -i xargsExitCode=${PIPESTATUS[1]}
	if [[ ${lvsExitCode} -ne 0 ]]; then
		__msg -q err "failed to get logical volume info of device '${device}'"
		return 2 # error
	else
		echo "${logicalVolumeInfo}"
	fi

	return 0 # success

} # printLogicalVolumeInfo()

function logicalVolumeIsExcluded() {

	## ----- head -----
	##
	## DESCRIPTION:
	##   checks whether a logical volume is excluded
	##
	## ARGUMENTS:
	##   1: volumeGroupName
	##   2: logicalVolumeName
	##
	## GLOBAL VARIABLES USED:
	##   LogicalVolumeExcludeArray (fallback: none, may be empty)
	##

	local volumeGroupName=${1}
	if [[ -z "${volumeGroupName}" ]]; then
		__msg err "argument 1 (volumeGroupName) missing"
		return 2 # error
	fi
	__msg debug "volumeGroupName: ${volumeGroupName}"

	local logicalVolumeName=${2}
	if [[ -z "${logicalVolumeName}" ]]; then
		__msg err "argument 2 (logicalVolumeName) missing"
		return 2 # error
	fi
	__msg debug "logicalVolumeName: ${logicalVolumeName}"

	## ----- main -----

	local -i e excludeLogicalVolume=0
	for ((e = 0; e < ${#LogicalVolumeExcludeArray[@]}; e++)); do
		local logicalVolumeExcludeArrayEntry=${LogicalVolumeExcludeArray[e]}
		__msg debug "logicalVolumeExcludeArrayEntry: ${logicalVolumeExcludeArrayEntry}"
		case "${logicalVolumeExcludeArrayEntry}" in
			## "vg/lv": valid entry
			*/*)
				IFS='/'
				set -- ${logicalVolumeExcludeArrayEntry}
				unset IFS
				local arrayEntryVolumeGroupName=${1}
				local arrayEntryLogicalVolumeName=${2}
				set --
				case "${arrayEntryVolumeGroupName}/${arrayEntryLogicalVolumeName}" in
					"${volumeGroupName}/${logicalVolumeName}")
						## we found this vg/lv, so stop searching here
						let excludeLogicalVolume=1
						break
						;;
					*)
						## we found a different vg/lv, so continue searching
						continue
						;;
				esac
				;;
			## invalid entry
			*)
				__msg err "invalid entry in logical volume exclude array: '${logicalVolumeExcludeArrayEntry}'"
				return 2 # error
				;;
		esac
	done

	if [[ ${excludeLogicalVolume} -eq 1 ]]; then
		return 0 # lv is excluded
	fi

	return 1 # lv is not excluded

} # logicalVolumeIsExcluded()

function printSnapshotVolumeSizeFactor() {

	## ----- head -----
	##
	## DESCRIPTION:
	##   prints the snapshot volume size factor of a given vg/lv
	##
	## ARGUMENTS:
	##   1: volumeGroupName
	##   2: logicalVolumeName
	##
	## GLOBAL VARIABLES USED:
	##   SnapshotVolumeSizeFactorArray (fallback: none)
	##

	local volumeGroupName=${1}
	if [[ -z "${volumeGroupName}" ]]; then
		__msg -q err "argument 1 (volumeGroupName) missing"
		return 2 # error
	fi
	__msg -q debug "volumeGroupName: ${volumeGroupName}"

	local logicalVolumeName=${2}
	if [[ -z "${logicalVolumeName}" ]]; then
		__msg -q err "argument 2 (logicalVolumeName) missing"
		return 2 # error
	fi
	__msg -q debug "logicalVolumeName: ${logicalVolumeName}"

	## check for global variable: snapshot volume size factor array
	if [[ "${#SnapshotVolumeSizeFactorArray[@]}" -eq 0 ]]; then
		__msg -q err "global variable \${SnapshotVolumeSizeFactorArray} is empty"
		return 2 # error
	fi

	## ----- main -----

	local -i s
	for ((s = 0; s < ${#SnapshotVolumeSizeFactorArray[@]}; s++)); do
		local snapshotVolumeSizeFactorArrayEntry=${SnapshotVolumeSizeFactorArray[s]}
		__msg -q debug "snapshotVolumeSizeFactorArrayEntry: ${snapshotVolumeSizeFactorArrayEntry}"
		case ${snapshotVolumeSizeFactorArrayEntry} in
			## "vg/lv:factor" (vg/lv specific)
			*/*:*)
				IFS=':'
				set -- ${snapshotVolumeSizeFactorArrayEntry}
				unset IFS
				local arrayEntryVolumeGroupName=${1%/*}
				local arrayEntryLogicalVolumeName=${1#*/}
				local arrayEntrySnapshotVolumeSizeFactor=${2}
				set --
				case "${arrayEntryVolumeGroupName}/${arrayEntryLogicalVolumeName}" in
					"${volumeGroupName}/${logicalVolumeName}")
						local snapshotVolumeSizeFactor="${arrayEntrySnapshotVolumeSizeFactor}"
						## we found a specific factor for this vg/lv,
						## so stop searching here
						break
						;;
					*)
						## we found a specific factor for a different vg/lv,
						## so continue searching
						continue
						;;
				esac
				;;
			## "factor" (not vg/lv specific)
			*)
				local snapshotVolumeSizeFactor="${snapshotVolumeSizeFactorArrayEntry}"
				## we might still find a specific factor,
				## so continue searching
				continue
				;;
		esac
	done

	if [[ -z ${snapshotVolumeSizeFactor} ]]; then
		__msg -q err "failed to get snapshot volume size factor for logical volume '${volumeGroupName}/${logicalVolumeName}' from snapshot volume size array"
		return 2 # error
	fi

	echo ${snapshotVolumeSizeFactor}

	return 0 # success

} # printSnapshotVolumeSizeFactor()

function prepareSnapshotVolumeMountDirectory() {

	## ----- head -----
	##
	## DESCRIPTION:
	##   creates the snapshot volume mount directory if it doesn't exist.
	##
	## ARGUMENTS:
	##   /
	##
	## GLOBAL VARIABLES USED:
	##   SnapshotVolumeMountDirectory (fallback: none)
	##

	## check for snapshot volume mount directory variable
	if [[ -z "${SnapshotVolumeMountDirectory}" ]]; then
		__msg err "global variable \${SnapshotVolumeMountDirectory} is empty"
		return 2 # error
	## check for snapshot volume mount directory
	elif [[ ! -d "${SnapshotVolumeMountDirectory}" ]]; then
		__msg info "snapshot volume mount directory '${SnapshotVolumeMountDirectory}' doesn't exist -- creating..."
		## create snapshot volume mount directory
		if ! mkdir -p "${SnapshotVolumeMountDirectory}" &>"${_L}"; then
			__msg err "failed to create snapshot volume mount directory '${SnapshotVolumeMountDirectory}'"
			return 2 # error
		fi
	fi

	return 0 # success

} # prepareSnapshotVolumeMountDirectory()

function createSystemMirror() {

	## ----- head -----
	##
	## DESCRIPTION:
	##   creates a mirror of all mounted volumes (except bind-mounts and special filesystems).
	##
	## ARGUMENTS:
	##   /
	##
	## GLOBAL VARIABLES USED:
	##   SnapshotVolumeNameSuffix (fallback: .snapshot)
	##   SnapshotVolumeMountDirectory
	##

	## ----- main -----

	## prepare snapshot volume mount directory
	if ! prepareSnapshotVolumeMountDirectory; then
		__msg err "failed to prepare snapshot volume mount directory"
		return 2 # error
	fi

	## get list of all mounted volumes
	IFS=$'\n'
	local -a mountedVolumeArray=( $(printAllMountedVolumes "/" "asc") )
	local -i returnValue=${?}
	unset IFS
	case ${returnValue} in
		0)
			## check for mounted volumes
			if [[ ${#mountedVolumeArray[@]} -eq 0 ]]; then
				__msg err "failed to detect any volumes mounted below / (something's really weird here...)"
				return 2 # error
			fi
			;;
		2)
			__msg err "failed to print all mounted volumes below /"
			return 2 # error
			;;
		*)
			__msg err "undefined return value: ${returnValue}" ## TODO FIXME
			return 2 # error
			;;
	esac

	## 1st step: create snapshots of mounted logical volumes
	## 2nd step: mount snapshots of mounted logical volumes, bind-mount all other mounted volumes
	local createMirrorSteps="createSnapshots mountVolumes" createMirrorStep
	for createMirrorStep in ${createMirrorSteps}; do

		local logPrefix="createMirrorStep: ${createMirrorStep};"

		## loops through list of all mounted volumes in order to create snapshots
		local -i i
		for ((i = 0; i < ${#mountedVolumeArray[@]}; i++)); do

			IFS=':'
			set -- ${mountedVolumeArray[i]}
			unset IFS
			local device=${1}
			local mountPoint=${2}
			set --
			__msg debug "${logPrefix} device: ${device}; mountPoint: ${mountPoint}"

			## ignore bind-mounts (even bind-mounted logical volumes)
			if mountPointIsBindMount "${mountPoint}"; then

				continue

			## process logical volumes
			elif deviceIsLogicalVolume "${device}"; then

				## get logical volume info
				local logicalVolumeInfo=$(printLogicalVolumeInfo "${device}")
				local -i returnValue=${?}
				case ${returnValue} in
					0)
						## extract volume group name and logical volume name
						## from logical volume info
						IFS='/'
						set -- ${logicalVolumeInfo}
						unset IFS
						local volumeGroupName=${1}
						local logicalVolumeName=${2}
						set --
						__msg debug "${logPrefix} volumeGroupName: ${volumeGroupName}; logicalVolumeName: ${logicalVolumeName}"
						;;
					2)
						__msg err "${logPrefix} failed to print logical volume info for device '${device}'"
						return 2 # error
						;;
					*)
						__msg err "${logPrefix} undefined return value: ${returnValue}" ## TODO FIXME
						return 2 # error
						;;
				esac

				## determine whether logical volume is excluded
				logicalVolumeIsExcluded "${volumeGroupName}" "${logicalVolumeName}"
				local -i returnValue=${?}
				case ${returnValue} in
					0)
						__msg debug "${logPrefix} logical volume '${volumeGroupName}/${logicalVolumeName}' is excluded"
						continue
						;;
					1)
						__msg debug "${logPrefix} logical volume '${volumeGroupName}/${logicalVolumeName}' is not excluded"
						;;
					2)
						__msg err "${logPrefix} failed to check whether logical volume '${volumeGroupName}/${logicalVolumeName}' is excluded"
						return 2 # error
						;;
					*)
						__msg err "${logPrefix} undefined return value: ${returnValue}" ## TODO FIXME
						return 2 # error
						;;
				esac

				## generate snapshot volume name
				local snapshotVolumeName="${logicalVolumeName}${SnapshotVolumeNameSuffix:-.snapshot}"
				__msg debug "${logPrefix} snapshotVolumeName: ${snapshotVolumeName}"

				## create snapshot?
				if [[ ${createMirrorStep} == "createSnapshots" ]]; then

					## determine snapshot volume size factor from snapshot volume size factor array
					local snapshotVolumeSizeFactor=$(printSnapshotVolumeSizeFactor "${volumeGroupName}" "${logicalVolumeName}")
					local -i returnValue=${?}
					case ${returnValue} in
						0)
							__msg debug "${logPrefix} snapshotVolumeSizeFactor: ${snapshotVolumeSizeFactor}"
							;;
						2)
							__msg err "${logPrefix} failed to print snapshot volume size factor of logical volume '${volumeGroupName}/${logicalVolumeName}'"
							return 2 # error
							;;
						*)
							__msg err "${logPrefix} undefined return value: ${returnValue}" ## TODO FIXME
							return 2 # error
							;;
					esac

					## create snapshot
					if ! createSnapshot "${volumeGroupName}" "${logicalVolumeName}" "${snapshotVolumeName}" "${snapshotVolumeSizeFactor}"; then
						__msg err "${logPrefix} failed to create snapshot of logical volume '${volumeGroupName}/${logicalVolumeName}'"
						return 2 # error
					fi

				fi

				## mount snapshot?
				if [[ ${createMirrorStep} == "mountVolumes" ]]; then

					## generate mount target directory (subdirectory of snapshot volume mount directory)
					local mountTargetDirectory="${SnapshotVolumeMountDirectory}/${mountPoint#/}"
					__msg debug "${logPrefix} mountTargetDirectory: ${mountTargetDirectory}"

					## mount snapshot
					if ! mountSnapshot "${volumeGroupName}" "${snapshotVolumeName}" "${mountTargetDirectory}"; then
						__msg err "${logPrefix} failed to mount snapshot volume '${volumeGroupName}/${snapshotVolumeName}' on '${mountTargetDirectory}'"
						return 2 # error
					fi

				fi

			## bind-mount all other (physical) volumes
			else

				## bind-mount directory
				if [[ ${createMirrorStep} == "mountVolumes" ]]; then
					local mountTargetDirectory="${SnapshotVolumeMountDirectory}/${mountPoint#/}"
					__msg debug "${logPrefix} mountTargetDirectory: ${mountTargetDirectory}"
					if ! bindMountDirectory "${mountPoint}" "${mountTargetDirectory}"; then
						__msg err "${logPrefix} failed to mount directory '${mountPoint}' on '${mountTargetDirectory}'"
						return 2 # error
					fi
				fi

			fi

		done

	done

	return 0 # success

} # createSystemMirror()

function deleteSystemMirror() {

	## ----- head -----
	##
	## DESCRIPTION:
	##   deletes a mirror of all mounted volumes.
	##
	## ARGUMENTS:
	##   /
	##
	## GLOBAL VARIABLES USED:
	##   SnapshotVolumeMountDirectory
	##

	## check for snapshot volume mount directory
	if [[ ! -d "${SnapshotVolumeMountDirectory}" ]]; then
		__msg err "snapshot volume mount directory does not exist"
		return 2 # error
	fi

	## get list of all mounted volumes below snapshot volume mount directory
	## in descending order (suitable for unmounting)
	IFS=$'\n'
	local -a mountedVolumeArray=( $(printAllMountedVolumes "${SnapshotVolumeMountDirectory}" "desc") )
	unset IFS

	## check for mounted volumes
	if [[ ${#mountedVolumeArray[@]} -eq 0 ]]; then
		__msg err "no volumes mounted below snapshot volume mount directory '${SnapshotVolumeMountDirectory}'"
		return 2 # error
	fi

	## 1st step: create snapshots of mounted logical volumes
	## 2nd step: mount snapshots of mounted logical volumes, bind-mount all other mounted volumes
	local deleteMirrorSteps="unmountVolumes deleteSnapshots" deleteMirrorStep
	for deleteMirrorStep in ${deleteMirrorSteps}; do

		local logPrefix="deleteMirrorStep: ${deleteMirrorStep};"

		## loops through list of all mounted volumes in order to create snapshots
		local -i i
		for ((i = 0; i < ${#mountedVolumeArray[@]}; i++)); do

			IFS=':'
			set -- ${mountedVolumeArray[i]}
			unset IFS
			local device=${1}
			local mountPoint=${2}
			set --
			__msg debug "${logPrefix} device: ${device}; mountPoint: ${mountPoint}"

			## if device is a snapshot volume, delete it
			if deviceIsSnapshotVolume "${device}"; then

				## get logical volume info
				local logicalVolumeInfo=$(printLogicalVolumeInfo "${device}")
				local -i returnValue=${?}
				case ${returnValue} in
					0)
						## extract volume group name and logical volume name
						## from logical volume info
						IFS='/'
						set -- ${logicalVolumeInfo}
						unset IFS
						local volumeGroupName=${1}
						local logicalVolumeName=${2}
						set --
						__msg debug "${logPrefix} volumeGroupName: ${volumeGroupName}; logicalVolumeName: ${logicalVolumeName}"
						;;
					2)
						__msg err "${logPrefix} failed to print logical volume info for device '${device}'"
						return 2 # error
						;;
					*)
						__msg err "${logPrefix} undefined return value: ${returnValue}" ## TODO FIXME
						return 2 # error
						;;
				esac

				## delete snapshot
				if [[ ${deleteMirrorStep} == "deleteSnapshots" ]]; then
					local snapshotVolumeName=${logicalVolumeName}
					if ! deleteSnapshot "${volumeGroupName}" "${snapshotVolumeName}"; then
						__msg err "${logPrefix} failed to delete snapshot volume '${volumeGroupName}/${snapshotVolumeName}'"
						return 2 # error
					fi
				fi

			fi

			## unmount volumes
			if [[ ${deleteMirrorStep} == "unmountVolumes" ]]; then
				if ! unmount "${mountPoint}"; then
					__msg err "${logPrefix} failed to unmount '${mountPoint}'"
					return 2 # error
				fi
			fi

		done

	done

	return 0 # success

} # deleteSystemMirror()
