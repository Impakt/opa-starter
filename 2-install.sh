#!/bin/bash

kubectl apply -f webhook-configuration.yaml

# https://www.openpolicyagent.org/docs/latest/kubernetes-tutorial/#7-exercise-restrict-hostnames-policy
kubectl create -f qa-namespace.yaml
kubectl create -f production-namespace.yaml

# create ingress-ok and ingress-bad yaml in the docs, but they're already here

echo "this ingress file should work
"
kubectl create -f ingress-ok.yaml -n production

echo "this ingress file should be REJECTED
"
kubectl create -f ingress-bad.yaml -n qa

# https://www.openpolicyagent.org/docs/latest/kubernetes-tutorial/#8-exercise-prohibit-hostname-conflicts-policy
# docs say to create staging-namespace.yaml, but it's already here
kubectl create -f staging-namespace.yaml

echo "The next command should report a BadRequest Error saying it's already defined in ingress production/ingress-ok

"
kubectl create -f ingress-ok.yaml -n staging
