#!/bin/ash

###
## Author assy@insnaneworks.co.jp
## created 2015/05/29
## changed 2015/06/02
## * backup dir duplicated case added
###

######## CONFIGRATION BEGIN ########
# backup target set
TARGET_MACHINE=$1
# backup target machine dir
TARGET_MACHINE_DIR="/vmfs/volumes/datastore1/$TARGET_MACHINE"
# backup dir set
BACKUP_DIR='/vmfs/volumes/FreeNAS01Store/BACKUP'
# backup keep days set
BACKUP_KEEP=2
# date set
TODAY=`date +%Y%m%d`
WORKIN_DIR="$BACKUP_DIR/$TODAY"
######## CONFIGRATION END   ########

######## FUNCTIONS BEGIN    ########
# this proc die
die (){
  echo $1
  exit 1
}

# check before run
check_before_run (){
  for i in `vim-cmd vimsvc/task_list | grep vim.Task:haTask-$1 | grep $2 | sed -e 's/.*vim.Task://' -e "s/[', ]//g"`; do
    [ -z "`vim-cmd vimsvc/task_info $i | grep running`" ] || die "running before proc"
  done
  return 1
}
######## FUNCTIONS END      ########

######## Let's Working!!    ########

# check target Vmid
MACHINE_ID=`vim-cmd vmsvc/getallvms | grep $TARGET_MACHINE | awk '{ print $1 }'`
# set working dir
DISTINATION_DIR="$WORKIN_DIR/$TARGET_MACHINE"
# get taget vmdk
TARGET_VMDK=`cat $TARGET_MACHINE_DIR/$TARGET_MACHINE.vmx | grep vmdk | cut -d " " -f 3 | sed -e "s/\"//g"`
# make dir if dir not found
#[ -d $DISTINATION_DIR ] || mkdir -p $DISTINATION_DIR
if [ -e $DISTINATION_DIR ]; then
  read -p "todays dir is already exists . Do you remove it ?[y/n] : " ANS01
  if [ "$ANS01" = "y" ]; then
    rm -rf $DISTINATION_DIR && mkdir -p $DISTINATION_DIR
  else
    die "this process is stopped..."
  fi
else
  mkdir -p $DISTINATION_DIR
fi

## copy config file
for i in vmx vmxf vmsd nvram ; do
  cp $TARGET_MACHINE_DIR/$TARGET_MACHINE".$i" $DISTINATION_DIR/
done

# take a snapshot (This process only)
vim-cmd vmsvc/snapshot.create $MACHINE_ID $TARGET_MACHINE
[ ! -z $? ] || die "Snapshot create error"

# check before run -> call function
while check_before_run $MACHINE_ID createSnapshot; do sleep 1; done

# get backup
##### if your resource is not sufficient enough , select this
##### if your select monosparse, restore monosparse -> thin
#for i in $TARGET_VMDK ; do
#  vmkfstools --diskformat monosparse --clonevirtualdisk  $TARGET_MACHINE_DIR/$i $DISTINATION_DIR/$i
#done

# if your resource is sufficient enough , select this
for i in $TARGET_VMDK ; do
  vmkfstools --diskformat thin --clonevirtualdisk  $TARGET_MACHINE_DIR/$i $DISTINATION_DIR/$i
done

[ ! -z $? ] || die "Error : cloning failed. your backup process did not complete."

# remove this process used snapshot
vim-cmd vmsvc/snapshot.removeall $MACHINE_ID
#
# old dir cleaning
find /vmfs/volumes/FreeNAS01Store/BACKUP/ -mtime +$BACKUP_KEEP -type d -maxdepth 1 -exec rm -r {} \;

# O-WA-RI
echo "Guest-"$TARGET_MACHINE" : backup completely successed."
exit 0
