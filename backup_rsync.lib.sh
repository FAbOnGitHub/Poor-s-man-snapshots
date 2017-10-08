##############################################################################
# $Id$
# backup_rsync crée avec cs par fab le 'Thu Jun 16 09:16:28 CEST 2011'
VERSION=0.0.1
# Objectif :
# Avoir un snapshot du pauvre
# rsync -a --delete --link-dest=../backup.1 data/ backup.0
# Author: Fabrice Mendes
# Last Revision :
# - $Revision$
# - $Author$
# - $Date$
#
######################################################(FAb)###################

#
# Structure de dépose des snapshots :
# SNAPSHOTS / Cible / Version
# STOCK     / KEY   / Timestamp
# /mnt/sda2/SNAPSHOTS / 8f01269dc14db7e66a20e730fe75b8b0_Bill+FAb / 20110731-175959/
# /go/Documents/Bill+FAb|md5sum -> 8f01269dc14db7e66a20e730fe75b8b0
#
# snapshot de D_WdirCopy vers D_SnapCopy en utilisant D_RefCopy
#
# Docs:
# http://www.sanitarium.net/golug/rsync_backups_2010.html
# http://blog.interlinked.org/tutorials/rsync_time_machine.html
#
# LIRE ../backup
# rsync -a --delete --link-dest=../backup.1 source_directory/  backup.0/
#
#
# Usage dans le cron :
#
# */13 1-23 * * * 	/root/bin/backup_rsync /go/Documents/Bill+FAb/
# 17/32 0-23 * * * 	/root/bin/backup_rsync /etc
# 8 1-23 * * *	  	/root/bin/backup_rsync /home/fab
# 0 0 * * *		/root/bin/backup_rsync_purge -a 4 /home/fab
# 0 0 * * *		/root/bin/backup_rsync_purge -a 14 /go/Documents/Bill+FAb/
# 0 0 * * *		/root/bin/backup_rsync_purge -a 14 /etc

#
# À faire :
# - trouver l'archive de référence (ok)
# - voir l'initialisation (ok)
# - voir la purge


TGT=		# argument target
D_TARGET=	# Target to backup (basenamed)
D_DIRNAME_TARGET=	# Dirname for target
D_STOCK=	# main directory
D_WorkCopy=	# what to backup
D_RefCopy=	# Previous copy as reference
D_SnapCopy=	# Snapshot of the day
sConfigFile=	# ConfigFile
PREFIX=		# 'Backup_', empty or whatever we want

FUCK_UP=..

#D_STOCK=/mnt/sda2/SNAPSHOTS
D_STOCK=/mnt/_attic/SNAPSHOTS
bFake=0

# Internal vars
sKey=
VERBOSE=0

function find_ref()
{

    [ ! -d "$D_STOCK" ] && die  "Main dir D_STOCK='$D_STOCK' not found"

    sPattern="[0-9]\{8,8\}-[0-9]\{6,6\}"
    auto_init="$1"

    D_KEY="$D_STOCK/$sKey"
    [ ! -d "$D_KEY" ] && mkdir -p "$D_KEY"
    [ ! -d "$D_KEY" ] && die "error creating $D_KEY"
    cd "$D_KEY" || die "error: cd $D_KEY"

    if [ "x$PREFIX" = "x" ];then
        sLast=$(ls -1 | grep "${PREFIX}$sPattern" |tail -1)
    else
        sLast=$(ls -1 | grep "$sPattern" |tail -1)
    fi

    debug "[sLast=$sLast][auto_init=$auto_init]"
    if [ "x$sLast" = "x" ]; then
        if [ "x$auto_init" = "xauto" ]; then
            error "Je dois créer un référentiel par cp -a vers $D_TARGET "
            return 1;
        else
            die "$ME: no REF dir found '$x' :-( "
        fi
    fi
    debug "find_ref [REF=$sLast]"
    REF="$sLast"
    cd - >/dev/null
    return 0;
}

function show_env()
{
    debug "[bFake=$bFake]"
    debug "[TGT=$TGT]"
    debug "[D_TARGET=$D_TARGET]"
    debug "[sKey=$sKey]"
    debug "[REF: D_RefCopy=$D_RefCopy]"
    debug "[SRC: D_WorkCopy=$D_WorkCopy]"
    debug "[DST: D_SnapCopy=$D_SnapCopy]"
    debug "[sConfigFile=$sConfigFile]"
    debug "[iAge=$iAge]"
}

function normalize_filename()
{
# bug autour du sed " ko mais ' ok
    tmp="$(echo "$1" | sed -e 's@\(.*\)/$@\1@' )"
    debug "[grrr tmp=$tmp](1=$1)"
    D_TARGET="$(basename "$tmp")"
    D_DIRNAME_TARGET="$(dirname "$tmp")"
    sNormalized="$(basename "$tmp"| tr ' /;' '___' )"

    i=$(expr index "$D_TARGET" " ")
    debug "Index of ' ' in '$D_TARGET' :$i"
    [ $i -ne 0 ] && die "Target name '$D_TARGET' has a 'space' into it"

}
function uniquify_filename()
{
    normalize_filename "$1"
    sSanitized="$(echo "$1" | sed -e 's@\(.*\)/$@\1@' )"
    singleton="$(echo $sSanitized|md5sum|cut -c1-32)_$sNormalized"
}
