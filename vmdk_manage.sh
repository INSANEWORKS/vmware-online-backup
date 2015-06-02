#!/bin/ash
###
## Author assy@insnaneworks.co.jp
## changed 2015/06/02
###

######## CONFIGRATION BEGIN ########
SH_DIR=/vmfs/volumes/datastore1/works/scripts/BK_WORKS
######## CONFIGRATION END   ########

######## FUNCTIONS BEGIN    ########
# this proc die
die (){
  echo $1
  exit 1
}
######## FUNCTIONS END    ########
# check before run
[ -z "`ps -u | grep vmkfstools`" ] || die "running before proc"

# WORKING
if [ "$1" = "backup" ] ; then
  echo "GET BACK START"
  [ ! -z "$2" ] || dir "Please input target machine"
  /bin/ash $SH_DIR/vmdk_backup.sh $2
elif [ "$1" = "restore" ] ; then
  echo "PUT RESTORE START"
  [ ! -z "$2" ] || dir "Please input target machine"
  /bin/ash $SH_DIR/vmdk_restore.sh $2
elif [ "$1" = "cron" ] ; then
  for i in `cat $SH_DIR/target.lst` ; do
    echo "############ $i start `date` ##########"
    /bin/ash $SH_DIR/vmdk_backup.sh $i
    echo "############ $i fin.. `date` ##########"
    sleep 180
  done
else
  echo "It is unclear input..."
  exit 1
fi
