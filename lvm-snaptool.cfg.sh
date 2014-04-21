## vim:ts=4:sw=4:tw=200:nu:ai:nowrap:
##
## application config for lvm-snaptool
##
## Created by Wolfram Schlich <wschlich@gentoo.org>
## Licensed under the GNU GPLv3
## Web: http://www.bashinator.org/projects/lvm-snaptool/
## Code: https://github.com/wschlich/lvm-snaptool/
##

##
## application settings
##

export LvmDevicesDirectory="/dev"
export SnapshotVolumeMountDirectory="/mnt/lvm-snapshots" # default for -d
export SnapshotVolumeSizeFactor="0.1" # default for -f
export SnapshotVolumeNameSuffix=".snapshot" # default for -s
