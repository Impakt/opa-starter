#!/bin/bash
minikube stop; minikube delete &&
docker stop $(docker ps -aq) &&
rm -rf ~/.kube ~/.minikube &&
sudo rm -rf /usr/local/bin/localkube /usr/local/bin/minikube &&
launchctl stop '*kubelet*.mount' &&
launchctl stop localkube.service &&
launchctl disable localkube.service &&
sudo rm -rf /etc/kubernetes/ &&
docker system prune -af --volumes


rm ca.crt
rm ca.key
rm ca.srl

rm webhook-configuration.yaml

rm server.crt server.csr server.key

rm policies/bundle.tar.gz

rm minikube-darwin-amd64
rm opa