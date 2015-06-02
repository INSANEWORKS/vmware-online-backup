#!/bin/ash

###
## Author assy@insnaneworks.co.jp
## changed 2015/06/02
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
######## CONFIGRATION END   ########

######## FUNCTIONS BEGIN    ########
# this proc die
die (){
  echo $1
  exit 1
}
# this proc dir
check_before_run (){
  for i in `vim-cmd vimsvc/task_list | grep vim.Task:haTask-$1 | grep $2 | sed -e 's/.*vim.Task://' -e "s/[', ]//g"`; do
    [ -z "`vim-cmd vimsvc/task_info $i | grep running`" ] || die "running before proc"
  done
  return 1
}
######## FUNCTIONS END    ########

######## Let's Working!!    ########
# check remove machine data
read -p "Do you want to remove the Target Machine Data ?[y/n] : " ANS01
DATE_DIR=`ls -1 $BACKUP_DIR/`
# check restore from time
read -p "Do you want to restore from time ? [ `echo $DATE_DIR` ] : " ANS02

# check target Vmid
MACHINE_ID=`vim-cmd vmsvc/getallvms | grep $TARGET_MACHINE | awk '{ print $1 }'`
# set working dir
SOURCE_DIR="$BACKUP_DIR/$ANS02/$TARGET_MACHINE"
# get taget vmdk
TARGET_VMDK=`cat $TARGET_MACHINE_DIR/$TARGET_MACHINE.vmx | grep vmdk | cut -d " " -f 3 | sed -e "s/\"//g"`

# power off target machine
vim-cmd vmsvc/power.off $MACHINE_ID
# unregist target machine
vim-cmd vmsvc/unregister $MACHINE_ID
while check_before_run $MACHINE_ID unregister; do sleep 1; done

# target dir remove or move
if [ "$ANS01" = "y" ] ; then
  echo "removing target machine image...."
  rm -rf $TARGET_MACHINE_DIR
elif [ "$ANS01" = "n" ] ; then
  echo "moving target machine image to old_$TARGET_MACHINE"
  mv $TARGET_MACHINE_DIR/ ${TARGET_MACHINE_DIR}_old_$TODAY/
else
  echo "An unknown character was entered! stop this process!"
fi

# make dir if dir not found
[ -d $TARGET_MACHINE_DIR ] || mkdir -p $TARGET_MACHINE_DIR

## copy config file
for i in vmx vmxf vmsd nvram ; do
  cp $SOURCE_DIR/$TARGET_MACHINE".$i" $TARGET_MACHINE_DIR/
done

# put restore
for i in $TARGET_VMDK ; do
  vmkfstools --diskformat thin --clonevirtualdisk  $SOURCE_DIR/$i $TARGET_MACHINE_DIR/$i
done

[ ! -z $? ] || die "Error : cloning failed. your restore  process did not complete."

# regist target machine
vim-cmd solo/registervm $TARGET_MACHINE_DIR/$TARGET_MACHINE.vmx

# O-WA-RI
echo "Guest-"$TARGET_MACHINE" : restore completely successed."
exit 0

