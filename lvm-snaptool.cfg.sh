## $Id: lvm-snaptool.cfg.sh,v 1.3 2009/05/27 12:20:30 wschlich Exp wschlich $
## vim:ts=4:sw=4:nu:ai:nowrap:
##
## Created by Wolfram Schlich <wschlich@gentoo.org>
## Licensed under the GNU GPLv3
##

##
## application settings
##

export LvmDevicesDirectory="/dev"
export SnapshotVolumeMountDirectory="/mnt/lvm-snapshots" # default for -d
export SnapshotVolumeSizeFactor="0.1" # default for -f
export SnapshotVolumeNameSuffix=".snapshot" # default for -s
