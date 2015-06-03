#!/bin/ash

###
## Author assy@insnaneworks.co.jp
## created 2015/05/29
## changed 2015/06/02
## * backup dir duplicated case added
###

######## CONFIGRATION BEGIN ########
# date set
TODAY=`date +%Y%m%d`
# shell's dir set
SH_DIR='PATH-TO-SHELL-DIR'
# backup target machine dir choose yourself
TARGET_DIR="PATH-TO-TARGET-DATASTORE"
# backup dir set dir choose yourself
BACKUP_DIR='PATH-TO-BACKUP-DATASTORE'
# backup keep days set
BACKUP_KEEP=2
# today's working dir set
TODAY_BK_DIR="$BACKUP_DIR/$TODAY"
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
}
# copy vm
copy_s_to_d_vmdk (){
  for i in $1 ; do
    vmkfstools --diskformat thin --clonevirtualdisk  $2/$i $3/$i
  done
}
######## FUNCTIONS END      ########

######## Let's Working!!    ########
# check before run  vmdk copy
[ -z "`ps -u | grep vmkfstools`" ] || die "running before proc"

### work pattern change
if [ "$1" = "backup" ] ; then
  [ ! -z "$2" ] || dir "Please input target machine"
  WORKS=$1
  echo "GET BACK START"
  if [ "$2" = "cron" ] ; then
    $TARGET_MACHINE=`cat $SH_DIR/target.lst`
  else
    $TARGET_MACHINE=$2
  fi
elif [ "$1" = "restore" ] ; then
  [ ! -z "$2" ] || dir "Please input target machine"
  echo "PUT RESTORE START"
  WORKS=$1
  $TARGET_MACHINE=$2
else
  die "Please input 1st args is backup/restore"
fi
### go to backup or restore working
if [ "$WORKS" = "backup" ] ; then
  for i in do $TARGET_MACHINE ; do
    # set source dir
    SOURCE_DIR="$TARGET_DIR/$TARGET_MACHINE"
    # set distination dir
    DISTINATION_DIR="$TODAY_BK_DIR/$TARGET_MACHINE"
    # set target Vmid
    MACHINE_ID=`vim-cmd vmsvc/getallvms | grep $TARGET_MACHINE | awk '{ print $1 }'`
    # set taget vmdk
    TARGET_VMDK=`cat $SOURCE_DIR/$TARGET_MACHINE.vmx | grep vmdk | cut -d " " -f 3 | sed -e "s/\"//g"`
  
    # make dir if dir not found
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
      cp $SOURCE_DIR/$TARGET_MACHINE".$i" $DISTINATION_DIR/
    done

    # take a snapshot (This process only)
    vim-cmd vmsvc/snapshot.create $MACHINE_ID $TARGET_MACHINE
    [ ! -z $? ] || die "Snapshot create error"
    # check before run -> call function
    while check_before_run $MACHINE_ID createSnapshot; do sleep 1; done

    # get backup -> call function
    ##### if your resource is not sufficient enough , select this
    ##### if your select monosparse, restore monosparse -> thin
    #for i in $TARGET_VMDK ; do
    #  vmkfstools --diskformat monosparse --clonevirtualdisk  $SOUECE_DIR/$i $DISTINATION_DIR/$i
    #done
    # if your resource is sufficient enough , select this
    copy_s_to_d_vmdk $TARGET_VMDK $SOURCE_DIR $DISTINATION_DIR
    [ ! -z $? ] || die "Error : cloning failed. your backup process did not complete."

    # remove this process used snapshot
    vim-cmd vmsvc/snapshot.removeall $MACHINE_ID

    # old dir cleaning
    find /vmfs/volumes/FreeNAS01Store/BACKUP/ -mtime +$BACKUP_KEEP -type d -maxdepth 1 -exec rm -r {} \;
  done
elif [ "$WORKS" = "restore" ] ; then
  # check remove machine data
  read -p "Do you want to remove the Target Machine Data ?[y/n] : " ANS01
  DATE_DIR=`ls -1 $BACKUP_DIR/`
  # check restore from time
  read -p "Do you want to restore from time ? [ `echo $DATE_DIR` ] : " ANS02

  # check target Vmid
  MACHINE_ID=`vim-cmd vmsvc/getallvms | grep $TARGET_MACHINE | awk '{ print $1 }'`
  # set source dir
  SOURCE_DIR="$BACKUP_DIR/$ANS02/$TARGET_MACHINE"
  DISTNATION_DIR="$TARGET_DIR/$TARGET_MACHINE"
  # get taget vmdk
  TARGET_VMDK=`cat $DISTNATION_DIR/$TARGET_MACHINE.vmx | grep vmdk | cut -d " " -f 3 | sed -e "s/\"//g"`

  # power off target machine
  vim-cmd vmsvc/power.off $MACHINE_ID
  # unregist target machine
  vim-cmd vmsvc/unregister $MACHINE_ID
  # check unregist before run
  while check_before_run $MACHINE_ID unregister; do sleep 1; done
  # target dir remove or move
  if [ "$ANS01" = "y" ] ; then
    echo "removing target machine image...."
    rm -rf $DISTNATION_DIR
  elif [ "$ANS01" = "n" ] ; then
    echo "moving target machine image to old_$TARGET_MACHINE"
    mv $DISTNATION_DIR/ ${DISTNATION_DIR}_old_$TODAY/
  else
    die "An unknown character was entered! stop this process!"
  fi
  # make dir if dir not found
  [ -d $DISTNATION_DIR ] || mkdir -p $DISTNATION_DIR
  ## copy config file
  for i in vmx vmxf vmsd nvram ; do
    cp $SOURCE_DIR/$TARGET_MACHINE".$i" $DISTNATION_DIR/
  done
  # put restore
  copy_s_to_d_vmdk $TARGET_VMDK $SOURCE_DIR $DISTINATION_DIR
  [ ! -z $? ] || die "Error : cloning failed. your restore  process did not complete."
  # regist target machine
  vim-cmd solo/registervm $DISTNATION_DIR/$TARGET_MACHINE.vmx
fi
# O-WA-RI
echo "Guest-"$TARGET_MACHINE" : $WORKS completely successed."
exit 0
