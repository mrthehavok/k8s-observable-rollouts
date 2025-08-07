# Troubleshooting Guide

## Common Issues and Solutions

### Minikube Won't Start

**Problem**: Minikube fails to start with driver errors.

**Solutions**:

1. Ensure Docker is running: `docker ps`
2. Clean up old instances: `minikube delete --all`
3. Try different driver: `--driver=virtualbox` or `--driver=hyperkit`
4. Increase resources: `--memory=16384 --cpus=8`

### Ingress Not Working

**Problem**: Cannot access services via ingress URLs.

**Solutions**:

1. Check ingress controller: `kubectl get pods -n ingress-nginx`
2. Verify DNS entries: `cat /etc/hosts`
3. Test with port-forward: `kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80`
4. Check ingress resources: `kubectl describe ingress -A`

### Out of Memory

**Problem**: Pods are being evicted due to memory pressure.

**Solutions**:

1. Increase Minikube memory: `minikube stop && minikube start --memory=16384`
2. Check resource usage: `kubectl top nodes && kubectl top pods -A`
3. Adjust resource limits in values files
4. Enable metrics-server: `minikube addons enable metrics-server`

### Image Pull Errors

**Problem**: Cannot pull images from local registry.

**Solutions**:

1. Build directly to Minikube: `minikube image build -t image:tag .`
2. Use Minikube registry: `minikube addons enable registry`
3. Load from Docker: `minikube image load image:tag`
4. Check registry config: `kubectl get cm -n kube-public local-registry-hosting`

### SSL/TLS Certificate Issues

**Problem**: Browser shows certificate warnings.

**Solutions**:

1. Accept self-signed certificates in browser
2. Add Minikube CA: `cat ~/.minikube/ca.crt >> /usr/local/share/ca-certificates/`
3. Use HTTP for local development
4. Configure proper certificates in production

## Debug Commands

```bash
# General cluster info
minikube status -p k8s-rollouts
kubectl cluster-info dump

# Pod debugging
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh

# Network debugging
kubectl run debug --image=nicolaka/netshoot -it --rm
minikube ssh -p k8s-rollouts

# Resource usage
kubectl top nodes
kubectl top pods -A --sort-by=memory
```
