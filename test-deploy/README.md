# App de prueba: podinfo

[podinfo](https://github.com/stefanprodan/podinfo) es una app web pequeña que se usa para
probar clústeres. En la interfaz web se ve **qué Pod contestó** cada petición, así que sirve
para comprobar el balanceo entre réplicas, los rolling updates y la autorreparación.

| Archivo | Qué crea |
| --- | --- |
| `namespace.yaml` | Namespace `test-deploy` |
| `deployment.yaml` | 2 réplicas de podinfo con probes y límites de recursos |
| `service.yaml` | Service NodePort `30090` |
| `kustomization.yaml` | Junta todo para `kubectl apply -k` (Kustomize viene dentro de kubectl, no hace falta Helm) |

Requisito: el clúster ya levantado (`make up` en la raíz del repo).

## 1. Copiar los manifiestos al bastión

**[TU PC]**, en la raíz del repo:

```bash
BASTION=$(terraform -chdir=terraform/infra output -raw bastion_public_ip)
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

scp $SSH_OPTS -r test-deploy rocky@$BASTION:~
ssh $SSH_OPTS rocky@$BASTION
```

Las opciones `SSH_OPTS` evitan el error de *host key changed*, que aparece porque cada
recreación trae llaves de host nuevas con la misma IP.

## 2. Desplegar

**[BASTIÓN]**

```bash
kubectl apply -k ~/test-deploy
kubectl -n test-deploy rollout status deployment/podinfo
kubectl -n test-deploy get pods,svc -o wide     # los Pods corren en worker.k8s.lab
```

## 3. Probar desde el bastión (sin navegador)

```bash
curl -s http://worker.k8s.lab:30090 | head -20

# El Service reparte entre las 2 réplicas: cambia el hostname
for i in $(seq 6); do curl -s http://worker.k8s.lab:30090 | grep '"hostname"'; done
```

`curl` recibe JSON; un navegador recibe la interfaz web.

## 4. Abrir la interfaz web en tu PC

Los nodos no tienen IP pública, así que se entra con un túnel SSH a través del bastión.
Elige una de estas dos formas.

### Opción A: túnel al NodePort (una sola terminal)

**[TU PC]**

```bash
ssh $SSH_OPTS -N -L 8080:worker.k8s.lab:30090 rocky@$BASTION
```

Abre <http://localhost:8080>. El bastión resuelve `worker.k8s.lab` con la zona privada de
Route 53 y reenvía el tráfico al NodePort.

### Opción B: `kubectl port-forward` en el bastión

No pasa por el NodePort: el API Server abre un túnel directo hasta un Pod.

**[TU PC]**, terminal 1: entra al bastión y reenvía el puerto 8080 de tu PC al 9898 del bastión.

```bash
ssh $SSH_OPTS -L 8080:localhost:9898 rocky@$BASTION
```

**[BASTIÓN]**, dentro de esa misma sesión:

```bash
kubectl -n test-deploy port-forward svc/podinfo 9898:9898
```

Abre <http://localhost:8080>. En este modo **siempre contesta el mismo Pod**:
`port-forward` elige un Pod al conectarse y no balancea.

## 5. Experimentos

Todo en **[BASTIÓN]**. Deja la interfaz web abierta para ver los cambios.

**Escalar:**

```bash
kubectl -n test-deploy scale deployment/podinfo --replicas=4
kubectl -n test-deploy get pods -o wide
```

**Rolling update** (cambiar el mensaje crea Pods nuevos y borra los viejos de a uno):

```bash
kubectl -n test-deploy set env deployment/podinfo PODINFO_UI_MESSAGE="Version 2"
kubectl -n test-deploy rollout status deployment/podinfo
kubectl -n test-deploy rollout history deployment/podinfo
kubectl -n test-deploy rollout undo deployment/podinfo      # volver atrás
```

**Autorreparación** (el ReplicaSet recrea el Pod borrado):

```bash
kubectl -n test-deploy delete pod -l app=podinfo --wait=false
kubectl -n test-deploy get pods -w          # Ctrl+C para salir
```

**DNS interno** (un Pod consume el Service por nombre, vía CoreDNS):

```bash
kubectl -n test-deploy run curl --image=curlimages/curl --rm -it --restart=Never -- \
  curl -s http://podinfo:9898/version
```

**Logs y métricas del Pod:**

```bash
kubectl -n test-deploy logs -l app=podinfo --tail=20
curl -s http://worker.k8s.lab:30090/env | grep NODE_NAME    # nodo donde corre el Pod
```

## 6. Limpiar

```bash
kubectl delete -k ~/test-deploy
```

Al borrar el namespace se borra todo lo que contiene. Con `make down` también desaparece,
junto con el resto del clúster.

## Si algo no responde

| Síntoma | Revisa |
| --- | --- |
| Pods en `ImagePullBackOff` | Salida a internet del worker (NAT): `ssh worker 'curl -sI https://ghcr.io'` |
| Pods en `Pending` | `kubectl -n test-deploy describe pod -l app=podinfo` (sección *Events*) |
| `curl` al 30090 se cuelga | `kubectl -n test-deploy get endpoints podinfo` debe listar 2 IPs `10.244.x.x`; si no, las probes están fallando |
| El túnel SSH no conecta | La IP del bastión cambia en cada `terraform apply`: vuelve a calcular `BASTION` |
