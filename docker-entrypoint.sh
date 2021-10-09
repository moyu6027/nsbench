#!/usr/bin/env sh
echo -e '# ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## #'
echo -e '#      Network-Storageclasses-Bench-Script           #'
echo -e '#                     v2021-06-15                    #'
echo -e '#                                           sean.yu  #'
echo -e '# ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## #'

echo -e
date

# gather basic system information (inc. CPU, AES-NI/virt status, RAM + swap + disk size)
echo -e 
echo -e "Basic System Information:"
echo -e "---------------------------------"
if [[ $ARCH = *aarch64* || $ARCH = *arm* ]]; then
    CPU_PROC=$(lscpu | grep "Model name" | sed 's/Model name: *//g')
else
    CPU_PROC=$(awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
fi
echo -e "Processor  : $CPU_PROC"
if [[ $ARCH = *aarch64* || $ARCH = *arm* ]]; then
    CPU_CORES=$(lscpu | grep "^[[:blank:]]*CPU(s):" | sed 's/CPU(s): *//g')
    CPU_FREQ=$(lscpu | grep "CPU max MHz" | sed 's/CPU max MHz: *//g')
    [[ -z "$CPU_FREQ" ]] && CPU_FREQ="???"
    CPU_FREQ="${CPU_FREQ} MHz"
else
    CPU_CORES=$(awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo)
    CPU_FREQ=$(awk -F: ' /cpu MHz/ {freq=$2} END {print freq " MHz"}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
fi
echo -e "CPU cores  : $CPU_CORES @ $CPU_FREQ"
CPU_AES=$(cat /proc/cpuinfo | grep aes)
[[ -z "$CPU_AES" ]] && CPU_AES="\xE2\x9D\x8C Disabled" || CPU_AES="\xE2\x9C\x94 Enabled"
echo -e "AES-NI     : $CPU_AES"
CPU_VIRT=$(cat /proc/cpuinfo | grep 'vmx\|svm')
[[ -z "$CPU_VIRT" ]] && CPU_VIRT="\xE2\x9D\x8C Disabled" || CPU_VIRT="\xE2\x9C\x94 Enabled"
echo -e "VM-x/AMD-V : $CPU_VIRT"
# TOTAL_RAM=$(format_size $(free | awk 'NR==2 {print $2}'))
# echo -e "RAM        : $TOTAL_RAM"
# TOTAL_SWAP=$(format_size $(free | grep Swap | awk '{ print $2 }'))
# echo -e "Swap       : $TOTAL_SWAP"
# # total disk size is calculated by adding all partitions of the types listed below (after the -t flags)
# TOTAL_DISK=$(format_size $(df -t simfs -t ext2 -t ext3 -t ext4 -t btrfs -t xfs -t vfat -t ntfs -t swap --total 2>/dev/null | grep total | awk '{ print $2 }'))
# echo -e "Disk       : $TOTAL_DISK"


set -e

if [ -z $NSBENCH_MOUNTPOINT ]; then
    NSBENCH_MOUNTPOINT=/tmp
fi

if [ -z $FIO_SIZE ]; then
    FIO_SIZE=2G
fi

if [ -z $FIO_OFFSET_INCREMENT ]; then
    FIO_OFFSET_INCREMENT=500M
fi

if [ -z $FIO_DIRECT ]; then
    FIO_DIRECT=1
fi

echo Working dir: $NSBENCH_MOUNTPOINT
echo

if [ "$1" = 'fio' ]; then

    echo Testing Read IOPS...
    echo -e "---------------------------------"
    READ_IOPS=$(fio --randrepeat=0 --verify=0 --ioengine=libaio --direct=$FIO_DIRECT --gtod_reduce=1 --name=read_iops --filename=$NSBENCH_MOUNTPOINT/fiotest --bs=4K --iodepth=64 --size=$FIO_SIZE --readwrite=randread --time_based --ramp_time=2s --runtime=15s)
    echo "$READ_IOPS"
    READ_IOPS_VAL=$(echo "$READ_IOPS"|grep -E 'read ?:'|grep -Eoi 'IOPS=[0-9k.]+'|cut -d'=' -f2)
    echo
    echo

    echo Testing Write IOPS...
    echo -e "---------------------------------"
    WRITE_IOPS=$(fio --randrepeat=0 --verify=0 --ioengine=libaio --direct=$FIO_DIRECT --gtod_reduce=1 --name=write_iops --filename=$NSBENCH_MOUNTPOINT/fiotest --bs=4K --iodepth=64 --size=$FIO_SIZE --readwrite=randwrite --time_based --ramp_time=2s --runtime=15s)
    echo "$WRITE_IOPS"
    WRITE_IOPS_VAL=$(echo "$WRITE_IOPS"|grep -E 'write:'|grep -Eoi 'IOPS=[0-9k.]+'|cut -d'=' -f2)
    echo
    echo

    echo Testing Read Bandwidth...
    echo -e "---------------------------------"
    READ_BW=$(fio --randrepeat=0 --verify=0 --ioengine=libaio --direct=$FIO_DIRECT --gtod_reduce=1 --name=read_bw --filename=$NSBENCH_MOUNTPOINT/fiotest --bs=128K --iodepth=64 --size=$FIO_SIZE --readwrite=randread --time_based --ramp_time=2s --runtime=15s)
    echo "$READ_BW"
    READ_BW_VAL=$(echo "$READ_BW"|grep -E 'read ?:'|grep -Eoi 'BW=[0-9GMKiBs/.]+'|cut -d'=' -f2)
    echo
    echo

    echo Testing Write Bandwidth...
    echo -e "---------------------------------"
    WRITE_BW=$(fio --randrepeat=0 --verify=0 --ioengine=libaio --direct=$FIO_DIRECT --gtod_reduce=1 --name=write_bw --filename=$NSBENCH_MOUNTPOINT/fiotest --bs=128K --iodepth=64 --size=$FIO_SIZE --readwrite=randwrite --time_based --ramp_time=2s --runtime=15s)
    echo "$WRITE_BW"
    WRITE_BW_VAL=$(echo "$WRITE_BW"|grep -E 'write:'|grep -Eoi 'BW=[0-9GMKiBs/.]+'|cut -d'=' -f2)
    echo
    echo

    if [ "$NSBENCH_QUICK" == "" ] || [ "$NSBENCH_QUICK" == "no" ]; then
        echo Testing Read Latency...
        echo -e "---------------------------------"
        READ_LATENCY=$(fio --randrepeat=0 --verify=0 --ioengine=libaio --direct=$FIO_DIRECT --name=read_latency --filename=$NSBENCH_MOUNTPOINT/fiotest --bs=4K --iodepth=4 --size=$FIO_SIZE --readwrite=randread --time_based --ramp_time=2s --runtime=15s)
        echo "$READ_LATENCY"
        READ_LATENCY_VAL=$(echo "$READ_LATENCY"|grep ' lat.*avg'|grep -Eoi 'avg=[0-9.]+'|cut -d'=' -f2)
        echo
        echo

        echo Testing Write Latency...
        echo -e "---------------------------------"
        WRITE_LATENCY=$(fio --randrepeat=0 --verify=0 --ioengine=libaio --direct=$FIO_DIRECT --name=write_latency --filename=$NSBENCH_MOUNTPOINT/fiotest --bs=4K --iodepth=4 --size=$FIO_SIZE --readwrite=randwrite --time_based --ramp_time=2s --runtime=15s)
        echo "$WRITE_LATENCY"
        WRITE_LATENCY_VAL=$(echo "$WRITE_LATENCY"|grep ' lat.*avg'|grep -Eoi 'avg=[0-9.]+'|cut -d'=' -f2)
        echo
        echo

        echo Testing Read Sequential Speed...
        echo -e "---------------------------------"
        READ_SEQ=$(fio --randrepeat=0 --verify=0 --ioengine=libaio --direct=$FIO_DIRECT --gtod_reduce=1 --name=read_seq --filename=$NSBENCH_MOUNTPOINT/fiotest --bs=1M --iodepth=16 --size=$FIO_SIZE --readwrite=read --time_based --ramp_time=2s --runtime=15s --thread --numjobs=4 --offset_increment=$FIO_OFFSET_INCREMENT)
        echo "$READ_SEQ"
        READ_SEQ_VAL=$(echo "$READ_SEQ"|grep -E 'READ:'|grep -Eoi '(aggrb|bw)=[0-9GMKiBs/.]+'|cut -d'=' -f2)
        echo
        echo

        echo Testing Write Sequential Speed...
        echo -e "---------------------------------"
        WRITE_SEQ=$(fio --randrepeat=0 --verify=0 --ioengine=libaio --direct=$FIO_DIRECT --gtod_reduce=1 --name=write_seq --filename=$NSBENCH_MOUNTPOINT/fiotest --bs=1M --iodepth=16 --size=$FIO_SIZE --readwrite=write --time_based --ramp_time=2s --runtime=15s --thread --numjobs=4 --offset_increment=$FIO_OFFSET_INCREMENT)
        echo "$WRITE_SEQ"
        WRITE_SEQ_VAL=$(echo "$WRITE_SEQ"|grep -E 'WRITE:'|grep -Eoi '(aggrb|bw)=[0-9GMKiBs/.]+'|cut -d'=' -f2)
        echo
        echo

        echo Testing Read/Write Mixed...
        echo -e "---------------------------------"
        RW_MIX=$(fio --randrepeat=0 --verify=0 --ioengine=libaio --direct=$FIO_DIRECT --gtod_reduce=1 --name=rw_mix --filename=$NSBENCH_MOUNTPOINT/fiotest --bs=4k --iodepth=64 --size=$FIO_SIZE --readwrite=randrw --rwmixread=75 --time_based --ramp_time=2s --runtime=15s)
        echo "$RW_MIX"
        RW_MIX_R_IOPS=$(echo "$RW_MIX"|grep -E 'read ?:'|grep -Eoi 'IOPS=[0-9k.]+'|cut -d'=' -f2)
        RW_MIX_W_IOPS=$(echo "$RW_MIX"|grep -E 'write:'|grep -Eoi 'IOPS=[0-9k.]+'|cut -d'=' -f2)
        echo
        echo
    fi

    echo All tests complete.
    echo
    echo ==================
    echo = NSBench Summary =
    echo ==================
    echo "Random Read/Write IOPS: $READ_IOPS_VAL/$WRITE_IOPS_VAL. BW: $READ_BW_VAL / $WRITE_BW_VAL"
    if [ -z $NSBENCH_QUICK ] || [ "$NSBENCH_QUICK" == "no" ]; then
        echo "Average Latency (usec) Read/Write: $READ_LATENCY_VAL/$WRITE_LATENCY_VAL"
        echo "Sequential Read/Write: $READ_SEQ_VAL / $WRITE_SEQ_VAL"
        echo "Mixed Random Read/Write IOPS: $RW_MIX_R_IOPS/$RW_MIX_W_IOPS"
    fi

    rm $NSBENCH_MOUNTPOINT/fiotest
    exit 0
fi

exec "$@"
