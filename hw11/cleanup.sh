#!/bin/bash
set -e

kubectl delete -f k8s/
helm uninstall nginx -n m
kubectl delete namespace m
#minikube stop