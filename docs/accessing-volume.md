Spin up a pod and mount the desired PVC:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: shell
  namespace: media
spec:
  containers:
    - name: shell
      image: ubuntu
      command: ["tail", "-f", "/dev/null"]
      volumeMounts:
        - name: config
          mountPath: /config
  volumes:
    - name: config
      persistentVolumeClaim:
        claimName: <volume-to-mount>
```
