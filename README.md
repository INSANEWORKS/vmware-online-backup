# VMWare ESXi オンラインバックアップ取得方法リストア方法

* この作業は各VMwareホスト機での操作です。
* バックアップはオンラインでできますがリストアは一旦オフラインが必要です。
* 保持期限は2日にしてますが、vmdk_backup.sh の内部で変更可能です
* 使用方法
 ```bash
 cd /vmfs/volumes/datastore1/works/scripts/BK_WORKS/vmdk_manage.sh 操作名 対象サーバー
 第一引数 : 操作名       -> backup もしくは restore もしくは cron
 第二引数 : 対象サーバー -> ex)  example.machine
 ※ 操作名をcronにした場合は第二引数不要(リストにあるすべてのサーバーのバックアップを取得)
 ```
* コマンド例
 ```bash
 ~# /bin/ash vmdk_manage.sh backup example.machine
 ```

* 各種configは各ファイルの以下を変更くださいまし
 
 ```bash
 ######## CONFIGRATION BEGIN ########
 # backup target set
 TARGET_MACHINE=$1
 # backup target machine dir choose yourself
 TARGET_MACHINE_DIR="TARGET-DATASTORE/$TARGET_MACHINE"
 # backup dir set dir choose yourself
 BACKUP_DIR='PATH-TO-BACKUP-DATASTORE'
 # backup keep days set
 BACKUP_KEEP=2
 # date set
 TODAY=`date +%Y%m%d`
 ######## CONFIGRATION END   ########
 ```

※現状はbackup/restore を個別に叩くことも想定し各ファイルでconfigureを備えてますが、いずれは統合したほうが便利な気がしますん

## バックアップ(サーバー追加から初回手動実行)

1. シェルを叩きます
 ```bash
 ~ # /bin/ash /vmfs/volumes/datastore1/works/scripts/BK_WORKS/vmdk_backup.sh example.machine
 ```
1. ここですでに当日のバックアップが取得されていた場合消して新たに作り直すか聞かれます。
 ```bash
 todays dir is already exists . Do you remove it ?[y/n] : y
 ```
1. ここまで入力すればリストアが走ります
 1. vmdkにファイルアクセスするためにsnapshotを作成しています
 ```bash
 Create Snapshot:
 ```
 1. vm-config/vmdk リストア
 ```bash
 Destination disk format: VMFS thin-provisioned
 Cloning disk '/vmfs/volumes/datastore1/example.machine/example.machine.vmdk'...
 Clone: 100% done.
 Remove All Snapshots:
 ```
 1. 終わりましたのご報告です。
 ```bash
 Guest-example.machine : backup completely successed.
 ```

## バックアップ(Cronへの次回自動取得登録作業)

1. リストに登録します
```bash
~ # vi /vmfs/volumes/datastore1/works/scripts/BK_WORKS/target.lst
```

※Cronセット検証後正式な物とします。


## リストア (リストア元を削除しない場合)

1. シェルを叩きます
 ```bash
 ~ # /bin/ash /vmfs/volumes/datastore1/works/scripts/BK_WORKS/vmdk_manage.sh restore example.machine
 PUT RESTORE START
 ```
1. リストアが必要なサーバーの元データを消すか聞かれるので n を入力します。
 ```bash
 Do you want to remove the Target Machine Data ?[y/n] : n
 ```
1. 直近取得しているバックアップの日付が表示されどこからリストアをするか求められます。
 ```bash
 Do you want to restore from time ? [ 20150601 20150602 ] : 20150602
 ```
1. ここまで入力すればリストアが走ります
 1. 電源を落とし、イベントリから削除を行っています。
  ```bash
  Powering off VM:
  ```
 1. 元のデータをoldという名前にディレクトリ名を変更しています。
  ```bash
  moving target machine image to old_example.machine
  ```
 1. vm-config/vmdk リストア
  ```bash
  Destination disk format: VMFS thin-provisioned
  Cloning disk '/vmfs/volumes/FreeNAS01Store/BACKUP/20150602/example.machine/example.machine.vmdk'...
  Clone: 100% done.
  ```
 1. 再度イベント理登録完了しマシンIDを返してきます。
  ```
  31
  ```
 1. 終わりましたのご報告です。
  ```bash
  Guest-example.machine : restore completely successed.
  ```
1. 実際に削除は行わなかったのでdatastoreの中に_old_今日の日付でファイルは保存されています。
 ```bash
 ~ # ls -ltrah /vmfs/volumes/datastore1/
 total 800864
 drwxr-xr-x    1 root     root        1.1K Jun  2 07:34 example.machine_old_20150602
 drwxr-xr-x    1 root     root        1.1K Jun  2 07:45 example.machine
 ```

## リストア (リストア元を削除する場合)

1. シェルを叩きます
 ```bash
 ~ # /bin/ash /vmfs/volumes/datastore1/works/scripts/BK_WORKS/vmdk_manage.sh restore example.machine
 PUT RESTORE START
 ```
1. リストアが必要なサーバーの元データを消すか聞かれるので y を入力します。
 ```bash
 Do you want to remove the Target Machine Data ?[y/n] : y
 ```
1. 直近取得しているバックアップの日付が表示されどこからリストアをするか求められます。
 ```
 Do you want to restore from time ? [ 20150601 20150602 ] : 20150602
 ```
1. ここまで入力すればリストアが走ります
 1. 電源を落とし、イベントリから削除を行っています。
 ```bash
 Powering off VM:
 ```
 1. 元のデータをdatastore1から消しています。
  ```bash
  removing target machine image....
  ```
 1. vm-config/vmdk リストア
  ```bash
  Destination disk format: VMFS thin-provisioned
  Cloning disk '/vmfs/volumes/FreeNAS01Store/BACKUP/20150602/example.machine/example.machine.vmdk'...
  Clone: 100% done.
  ```
 1. 再度イベント理登録完了しマシンIDを返してきます。
  ```
  33
  ```
 1. 終わりましたのご報告です。
  ```bash
  Guest-example.machine : restore completely successed.
  ```
1. 実際に削除を行ったためdatastoreの中にリストアした物以外は保持していません。
 ```bash
 ~ # ls -ltrah /vmfs/volumes/datastore1/
 total 800856
 drwxr-xr-x    1 root     root        1.1K Jun  2 08:40 example.machine
 drwxr-xr-x    1 root     root         512 Jun  2 08:41 ..
 ```
