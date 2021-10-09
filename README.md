# NSBench 

## -Network Storage benchmark Test

Benchmark Kubernetes persistent disk volumes with `fio-3.27`: Read/write IOPS, bandwidth MB/s and latency.

# Usage

1. ==nsbench.yaml== and edit the `storageClassName` to match your Kubernetes provider's Storage Class `kubectl get storageclasses`
2. Deploy NSBench using: `kubectl apply -f nsbench.yaml`
3. Once deployed, the NSbench Job will:
    * provision a Persistent Volume of `100Gi` (default) using `storageClassName: longhorn` (default)
    * run a series of `fio` tests on the newly provisioned disk
    * currently there are 9 tests, 15s per test - total runtime is ~2.5 minutes
4. Follow benchmarking progress using: `kubectl logs -f job/nsbench` (empty output means the Job not yet created, or `storageClassName` is invalid, see Troubleshooting below)
5. At the end of all tests, you'll see a summary that looks similar to this:
```
==================
= NSbench Summary=
==================
Random Read/Write IOPS: 75.7k/59.7k. BW: 523MiB/s / 500MiB/s
Average Latency (usec) Read/Write: 183.07/76.91
Sequential Read/Write: 536MiB/s / 512MiB/s
Mixed Random Read/Write IOPS: 43.1k/14.4k
```
6. Once the tests are finished, clean up using: `kubectl delete -f nsbench.yaml` and that should deprovision the persistent disk and delete it to minimize storage billing.
7. Nsbench.yaml

```yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: nsbench-pv-claim
spec:
  storageClassName: longhorn
  # storageClassName: gp2
  # storageClassName: local-storage
  # storageClassName: ibmc-block-bronze
  # storageClassName: ibmc-block-silver
  # storageClassName: ibmc-block-gold
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
---
apiVersion: batch/v1
kind: Job
metadata:
  name: nsbench
spec:
  template:
    spec:
      containers:
      - name: nsbench
        image: moyu6027/nsbench:0.1
        imagePullPolicy: Always
        env:
          - name: NSBENCH_MOUNTPOINT
            value: /data
          # - name: NSBENCH_QUICK
          #   value: "yes"
          # - name: FIO_SIZE
          #   value: 1G
          # - name: FIO_OFFSET_INCREMENT
          #   value: 256M
          # - name: FIO_DIRECT
          #   value: "0"
        volumeMounts:
        - name: nsbench-pv
          mountPath: /data
      restartPolicy: Never
      volumes:
      - name: nsbench-pv
        persistentVolumeClaim:
          claimName: nsbench-pv-claim
  backoffLimit: 4

```



## Notes / Troubleshooting

* If the Persistent Volume Claim is stuck on Pending, it's likely you didn't specify a valid Storage Class. Double check using `kubectl get storageclasses`. Also check that the volume size of `100Gi` (default) is available for provisioning.
* It can take some time for a Persistent Volume to be Bound and the Kubernetes Dashboard UI will show the NSbench Job as red until the volume is finished provisioning.
* It's useful to test multiple disk sizes as most cloud providers price IOPS per GB provisioned. So a `4000Gi` volume will perform better than a `1000Gi` volume. Just edit the yaml, `kubectl delete -f nsbench.yaml` and run `kubectl apply -f nsbench.yaml` again after deprovision/delete completes.
* A list of all `fio` tests are in [docker-entrypoint.sh](https://github.com/logdna/dbench/blob/master/docker-entrypoint.sh).

## Contributors

* Sean.yu
