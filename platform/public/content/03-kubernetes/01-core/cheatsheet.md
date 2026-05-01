# kubectl Cheatsheet

> One-liners you'll actually use. Set a shell alias: `alias k=kubectl`.

## Context & cluster

```bash
kubectl config get-contexts                      # list contexts
kubectl config use-context kind-devops-learning  # switch
kubectl config current-context
kubectl cluster-info
kubectl version
kubectl api-resources                            # all kinds + their groups
kubectl api-versions
kubectl explain pod.spec.containers              # field-level docs
```

## Get / describe / logs

```bash
k get pods                                       # current ns
k get pods -A                                    # all namespaces
k get pods -o wide                               # node, IP
k get pods -l app=hello                          # by label
k get pods --field-selector status.phase=Running
k get pods --sort-by=.metadata.creationTimestamp

k get pod my-pod -o yaml
k get pod my-pod -o jsonpath='{.spec.nodeName}'
k get pod my-pod -o jsonpath='{.status.containerStatuses[*].image}'

k describe pod my-pod                            # events at the bottom
k logs my-pod                                    # current container
k logs my-pod -c sidecar                         # specific container
k logs my-pod --previous                         # last crash
k logs -l app=hello --tail=100 -f                # follow by label
k logs deployment/hello                          # any pod from deployment
```

## Apply / delete / edit

```bash
k apply -f manifest.yaml
k apply -f ./dir/                                # all yamls in dir
k apply -k ./overlay/                            # kustomize
k apply --dry-run=client -f manifest.yaml -o yaml  # validate without sending
k apply --server-side -f manifest.yaml           # SSA (recommended for controllers)

k delete -f manifest.yaml
k delete pod my-pod --grace-period=0 --force     # nuke
k delete pods --all -n demo

k edit deployment/hello                          # opens $EDITOR
k patch deployment hello --type=merge -p '{"spec":{"replicas":5}}'
k replace -f manifest.yaml --force               # delete + recreate
```

## Scale / rollout

```bash
k scale deployment/hello --replicas=5
k autoscale deployment/hello --min=2 --max=10 --cpu-percent=60

k rollout status deployment/hello
k rollout history deployment/hello
k rollout undo deployment/hello
k rollout undo deployment/hello --to-revision=3
k rollout pause deployment/hello
k rollout resume deployment/hello
k rollout restart deployment/hello               # rolling restart with no spec change
```

## Exec / cp / port-forward

```bash
k exec -it my-pod -- sh
k exec my-pod -c sidecar -- env
k cp my-pod:/etc/passwd ./passwd
k cp ./local.txt my-pod:/tmp/

k port-forward pod/my-pod 8080:80
k port-forward svc/my-svc 8080:80
k port-forward deployment/hello 8080:80
```

## Run / debug

```bash
k run tmp --rm -it --image=busybox --restart=Never -- sh
k run tmp --rm -it --image=curlimages/curl --restart=Never -- \
  curl -s http://my-svc/

k debug -it my-pod --image=busybox --target=my-container          # ephemeral container
k debug node/kind-worker -it --image=busybox                       # node shell

k auth can-i list pods
k auth can-i delete pods --as=system:serviceaccount:default:app-sa
k auth can-i --list --as=system:serviceaccount:default:app-sa
```

## Resources & top

```bash
k top nodes
k top pods -A --sort-by=cpu
k top pod my-pod --containers
```

## Namespaces

```bash
k get ns
k create ns demo
k config set-context --current --namespace=demo  # change default ns
kubens demo                                      # if you have kubens
```

## Events

```bash
k get events --sort-by=.lastTimestamp -A
k get events --field-selector involvedObject.name=my-pod
```

## YAML generation (no need to memorize syntax)

```bash
k create deployment hello --image=nginx:1.27-alpine --dry-run=client -o yaml
k create service clusterip hello --tcp=80:8080  --dry-run=client -o yaml
k create configmap app --from-literal=ENV=prod  --dry-run=client -o yaml
k create secret generic db --from-literal=pw=x  --dry-run=client -o yaml
k create job hello --image=busybox --dry-run=client -o yaml -- echo hi
k create cronjob hello --image=busybox --schedule="*/1 * * * *" --dry-run=client -o yaml -- echo hi
```

## Selectors & jsonpath

```bash
k get pods -l 'env in (prod,staging),tier!=db'
k get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.podIP}{"\n"}{end}'
k get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'
```

## Network debug

```bash
k get endpoints my-svc
k get endpointslices -l kubernetes.io/service-name=my-svc
k run netshoot --rm -it --image=nicolaka/netshoot --restart=Never -- bash
# inside netshoot: dig, curl, nc, tcpdump, iperf3
```

## Cleanup helpers

```bash
k get pods --field-selector=status.phase=Failed -A
k delete pods --field-selector=status.phase=Failed -A
k delete pods --field-selector=status.phase=Succeeded -A
```

## Reference

- [kubectl Cheat Sheet (official)](https://kubernetes.io/docs/reference/kubectl/quick-reference/)
- [JSONPath support](https://kubernetes.io/docs/reference/kubectl/jsonpath/)
