# Работа с mdadm
## Создание программного RAID
Убедимся, что в системе отображаются новые диски под массив

```
[vagrant@rocky9-kernel6 ~]$ lsblk
NAME                             MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda                                8:0    0 15.6G  0 disk
├─sda1                             8:1    0    1G  0 part /boot
└─sda2                             8:2    0 14.6G  0 part
  ├─rl_packer--rocky9--temp-root 253:0    0 13.1G  0 lvm  /
  └─rl_packer--rocky9--temp-swap 253:1    0  1.6G  0 lvm  [SWAP]
sdb                                8:16   0  250M  0 disk
sdc                                8:32   0  250M  0 disk
sdd                                8:48   0  250M  0 disk
```

На всякий случай занулим суперблоки

```sudo mdadm --zero-superblock --force /dev/sd{b,c,d}```

Теперь создадим из 3 дисков программный RAID типа 5

```sudo mdadm --create --verbose /dev/md5 --level=5 --raid-devices=3 /dev/sd{b,c,d}```

Проверим состояние созданного RAID

```
[vagrant@rocky9-kernel6 ~]$ cat /proc/mdstat
Personalities : [raid6] [raid5] [raid4]
md5 : active raid5 sdd[3] sdc[1] sdb[0]
      507904 blocks super 1.2 level 5, 512k chunk, algorithm 2 [3/3] [UUU]

unused devices: <none>
```

## Поломка и ремонт RAID
Просимулируем выход из строя одного из дисков и посмотрим, как это отразится на состоянии RAID

```
[vagrant@rocky9-kernel6 ~]$ sudo mdadm /dev/md5 --fail /dev/sdc
mdadm: set /dev/sdc faulty in /dev/md5
[vagrant@rocky9-kernel6 ~]$ cat /proc/mdstat
Personalities : [raid6] [raid5] [raid4]
md5 : active raid5 sdd[3] sdc[1](F) sdb[0]
      507904 blocks super 1.2 level 5, 512k chunk, algorithm 2 [3/2] [U_U]

unused devices: <none>
[vagrant@rocky9-kernel6 ~]$ sudo mdadm -D /dev/md5
...
State : clean, degraded
...
    Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync   /dev/sdb
       -       0        0        1      removed
       3       8       48        2      active sync   /dev/sdd

       1       8       32        -      faulty   /dev/sdc
```

Видим, что диск /dev/sdc помечен как неисправный. Удалим его из массива

```sudo mdadm /dev/md5 --remove /dev/sdc```

"Зачистим" метаданные и данные на извлеченном диске

```
sudo mdadm --zero-superblock --force /dev/sdc
sudo wipefs --all --force /dev/sdc
```

Добавим "новый" диск к массиву и проверим состояние RAID

```
[vagrant@rocky9-kernel6 ~]$ sudo mdadm /dev/md5 --add /dev/sdc
mdadm: added /dev/sdc
[vagrant@rocky9-kernel6 ~]$ cat /proc/mdstat
Personalities : [raid6] [raid5] [raid4]
md5 : active raid5 sdc[4] sdd[3] sdb[0]
      507904 blocks super 1.2 level 5, 512k chunk, algorithm 2 [3/3] [UUU]

unused devices: <none>
```

Считаем и запишем конфигурацию mdadm в файл

```
sudo mkdir /etc/mdadm
sudo echo "DEVICE partitions" > /etc/mdadm/mdadm.conf
mdadm --detail --scan --verbose | awk '/ARRAY/ {print}' >> /etc/mdadm/mdadm.conf
```
## Создание разделов, ФС, монтирование
Инициализируем RAID диск как GPT

```sudo parted /dev/md5 mklabel gpt```

Создаем разделы и ФС на них

```
sudo parted /dev/md5 mkpart primary 0% 20%
sudo parted /dev/md5 mkpart primary 20% 40%
sudo parted /dev/md5 mkpart primary 40% 60%
sudo parted /dev/md5 mkpart primary 60% 80%
sudo parted /dev/md5 mkpart primary 80% 100%
for i in $(seq 1 5); do mkfs.ext4 /dev/md5p$i; done
```

Настроим монтирование по каталогам, в т.ч. при старте системы

```
sudo mkdir -p /storage/raid5/part{1,2,3,4,5}
for i in $(seq 1 5); do
    sudo echo "/dev/md5p$i /storage/raid5/part$i ext4 defaults 0 0" >> /etc/fstab
done
sudo mount -a
```

Проверим, что все смонтировалось успешно

```
[vagrant@rocky9-kernel6 ~]$ lsblk
...
sdb                                8:16   0  250M  0 disk
└─md5                              9:5    0  496M  0 raid5
  ├─md5p5                        259:0    0   98M  0 part  /storage/raid5/part5
  ├─md5p1                        259:4    0   98M  0 part  /storage/raid5/part1
  ├─md5p2                        259:5    0   99M  0 part  /storage/raid5/part2
  ├─md5p3                        259:6    0  100M  0 part  /storage/raid5/part3
  └─md5p4                        259:7    0   99M  0 part  /storage/raid5/part4
sdc                                8:32   0  250M  0 disk
└─md5                              9:5    0  496M  0 raid5
  ├─md5p5                        259:0    0   98M  0 part  /storage/raid5/part5
  ├─md5p1                        259:4    0   98M  0 part  /storage/raid5/part1
  ├─md5p2                        259:5    0   99M  0 part  /storage/raid5/part2
  ├─md5p3                        259:6    0  100M  0 part  /storage/raid5/part3
  └─md5p4                        259:7    0   99M  0 part  /storage/raid5/part4
sdd                                8:48   0  250M  0 disk
└─md5                              9:5    0  496M  0 raid5
  ├─md5p5                        259:0    0   98M  0 part  /storage/raid5/part5
  ├─md5p1                        259:4    0   98M  0 part  /storage/raid5/part1
  ├─md5p2                        259:5    0   99M  0 part  /storage/raid5/part2
  ├─md5p3                        259:6    0  100M  0 part  /storage/raid5/part3
  └─md5p4                        259:7    0   99M  0 part  /storage/raid5/part4
```

## Автоматизация
сведем использованные ранее команды для создания массива, разделов, ФС и монтирования в скрипт *create_raid.sh* и укажем его в параметре provision в Vagrantfile, чтобы сразу после развертывания образа получить готовые смонтированные разделы на программном RAID.
Проверим
```
[kgeor@rocky-ls lab2]$ vagrant ssh
[vagrant@rocky9-raid ~]$ sudo fdisk -l
...
Disk /dev/md5: 496 MiB, 520093696 bytes, 1015808 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 524288 bytes / 1048576 bytes
Disklabel type: gpt
Disk identifier: 77536E97-DF7E-4C32-A8DA-1B133E9FBD76

Device      Start     End Sectors  Size Type
/dev/md5p1   2048  202751  200704   98M Linux filesystem
/dev/md5p2 202752  405503  202752   99M Linux filesystem
/dev/md5p3 405504  610303  204800  100M Linux filesystem
/dev/md5p4 610304  813055  202752   99M Linux filesystem
/dev/md5p5 813056 1013759  200704   98M Linux filesystem
[vagrant@rocky9-raid ~]$ ls /storage/raid5/part3
lost+found
```
на примере одного из разделов видим, что он успешно автоматически создался и смонтировался. **PROFIT!**