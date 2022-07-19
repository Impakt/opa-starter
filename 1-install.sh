#!/bin/bash

#set -x 

#Install minikube
if ! command -v minikube &> /dev/null
then
    if [ ! -f minikube-darwin-amd64 ]; then
        curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-darwin-amd64
    fi    
    sudo install minikube-darwin-amd64 /usr/local/bin/minikube
fi

# taken from https://www.openpolicyagent.org/docs/latest/kubernetes-tutorial/
if [ ! -f opa ]; then
    curl -L -o opa https://openpolicyagent.org/downloads/v0.42.2/opa_darwin_amd64
    chmod 755 ./opa
    export PATH=$PATH:$PWD
fi

# https://www.openpolicyagent.org/docs/latest/kubernetes-tutorial/#1-enable-recommended-kubernetes-admission-controllers
minikube start
minikube addons enable ingress

# https://www.openpolicyagent.org/docs/latest/kubernetes-tutorial/#2-create-a-new-namespace-to-deploy-opa-into
kubectl create namespace opa
kubectl config set-context opa-tutorial --user minikube --cluster minikube --namespace opa
kubectl config use-context opa-tutorial

# https://www.openpolicyagent.org/docs/latest/kubernetes-tutorial/#3-create-tls-credentials-for-opa
openssl genrsa -out ca.key 2048
openssl req -x509 -new -nodes -sha256 -key ca.key -days 100000 -out ca.crt -subj "/CN=admission_ca"

# now the docs say to create server.conf but it's already here

openssl genrsa -out server.key 2048
openssl req -new -key server.key -sha256 -out server.csr -extensions v3_ext -config server.conf
openssl x509 -req -in server.csr -sha256 -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 100000 -extensions v3_ext -extfile server.conf

kubectl create secret tls opa-server --cert=server.crt --key=server.key --namespace opa

# https://www.openpolicyagent.org/docs/latest/kubernetes-tutorial/#4-define-opa-policy
cd policies

# https://www.openpolicyagent.org/docs/latest/kubernetes-tutorial/#5-build-and-publish-opa-bundle
# now the docs say to create the policies and .manifest files but they're already here
opa build -b .

set -x 
docker run --rm --name bundle-server -d -p 8888:80 -v ${PWD}:/usr/share/nginx/html:ro nginx:latest

set +x

# https://www.openpolicyagent.org/docs/latest/kubernetes-tutorial/#6-deploy-opa-as-an-admission-controller
cd ..
kubectl apply -f admission-controller.yaml

cat > webhook-configuration.yaml <<EOF
kind: ValidatingWebhookConfiguration
apiVersion: admissionregistration.k8s.io/v1
metadata:
  name: opa-validating-webhook
webhooks:
  - name: validating-webhook.openpolicyagent.org
    namespaceSelector:
      matchExpressions:
      - key: openpolicyagent.org/webhook
        operator: NotIn
        values:
        - ignore
    rules:
      - operations: ["CREATE", "UPDATE"]
        apiGroups: ["*"]
        apiVersions: ["*"]
        resources: ["*"]
    clientConfig:
      caBundle: $(cat ca.crt | base64 | tr -d '\n')
      service:
        namespace: opa
        name: opa
    admissionReviewVersions: ["v1"]
    sideEffects: None
EOF

kubectl label ns kube-system openpolicyagent.org/webhook=ignore
kubectl label ns opa openpolicyagent.org/webhook=ignore

kubectl apply -f webhook-configuration.yaml
echo -e "The OPA logs will now appear, press ctrl+c to exit the logs and continue the script. If the container is still starting, enter \e[32mkubectl logs -l app=opa -c opa -f\e[0m to try again until it's up"
echo -e "That's \e[32mkubectl logs -l app=opa -c opa -f\e[0m"

kubectl logs -l app=opa -c opa -f