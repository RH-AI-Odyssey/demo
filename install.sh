#!/bin/bash

##### Variables #####
OCP_DOMAIN=$(oc get IngressController default -n openshift-ingress-operator -o json | jq -r '.status.domain')
INFRA_NAME=$(oc get infrastructure cluster -o json | jq -r '.status.infrastructureName')
SUBNET=$(oc get machineset.machine.openshift.io -n openshift-machine-api -o jsonpath='{.items[0].spec.template.spec.providerSpec.value.subnet.filters[0].values[0]}')
AVAILABILITYZONE=$(oc get machineset.machine.openshift.io -n openshift-machine-api -o jsonpath='{.items[0].spec.template.spec.providerSpec.value.placement.availabilityZone}')
REGION=$(oc get machineset.machine.openshift.io -n openshift-machine-api -o jsonpath='{.items[0].spec.template.spec.providerSpec.value.placement.region}')

GITLAB_ADMIN_EMAIL=gitlab@gitlab.com
GITLAB_ADMIN_USERNAME=root
GITLAB_ADMIN_PASSWORD=
GITLAB_ROUTE=gitlab.$OCP_DOMAIN

ARGOCD_VERSION=1.14.0-116
ARGOCD_CLI=argocd-linux-amd64.tar.gz
ARGOCD_ADMIN_USERNAME=admin
ARGOCD_ADMIN_PASSWORD=
ARGOCD_ROUTE=

MINIO_USERNAME=minio
MINIO_PASSWORD=minio123
MINIO_ROUTE=

ELASTIC_USERNAME=elastic
ELASTIC_PASSWORD=
ELASTIC_SERVICE=demo-app-elasticsearch-es-default.demo-app-elasticsearch.svc.cluster.local

##### Functions #####
install_git_lfs(){
    wget https://github.com/git-lfs/git-lfs/releases/download/v3.6.0/git-lfs-linux-amd64-v3.6.0.tar.gz
    tar -xvf git-lfs-linux-amd64-v3.6.0.tar.gz
    sudo ./git-lfs-3.6.0/install.sh 
    git lfs install
    rm -rf git-lfs*
    sleep 2
}

install_helm_cli() {
    wget -O get-helm-3 https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 &> /dev/null
    chmod 700 get-helm-3
    ./get-helm-3
    rm -f get-helm-3
    sleep 2
}

install_argocd_cli() {
    wget -O $ARGOCD_CLI https://developers.redhat.com/content-gateway/file/pub/openshift-v4/clients/openshift-gitops/$ARGOCD_VERSION/$ARGOCD_CLI &> /dev/null
    tar xvzf $ARGOCD_CLI
    sudo mv argocd /usr/local/bin/argocd
    sudo chmod 700 /usr/local/bin/argocd
    rm -f $ARGOCD_CLI
    sleep 2
}

install_minio_cli() {
    curl https://dl.min.io/client/mc/release/linux-amd64/mc \
        --create-dirs \
        -o $HOME/minio-binaries/mc
    chmod +x $HOME/minio-binaries/mc
    export PATH=$PATH:$HOME/minio-binaries/
}

create_openshift_project() {
    oc new-project $1 &> /dev/null
    oc label namespace $1 app=demo &> /dev/null
    sleep 2
}

create_gitlab_repository() {
    curl -k -H "Content-Type: application/json" \
        -d '{ "name" : "'$1'", "visibility" : "public" }' \
        -H "Authorization: Bearer $GITLAB_ACCESS_TOKEN" \
        https://$GITLAB_ROUTE/api/v4/projects &> /dev/null
    #PROJECT_ID=$(curl --request GET --header "Authorization: Bearer ${GITLAB_ACCESS_TOKEN}" "https://${GITLAB_ROUTE}/api/v4/projects?search=$1" | jq -r '.[0].id')
    # the search above returns more than 1 project
    # TODO sorry about the loop =]
    # max=10
    # for i in `seq 1 $max`
    # do
    #     curl --request DELETE --header "Authorization: Bearer ${GITLAB_ACCESS_TOKEN}" "https://${GITLAB_ROUTE}/api/v4/projects/$i/protected_branches/main" &> /dev/null
    # done
    cd $1
    rm -rf .git/
    git init &> /dev/null
    git config user.name $GITLAB_ADMIN_USERNAME
    git config user.email $GITLAB_ADMIN_EMAIL
    git add * &> /dev/null
    git add .* &> /dev/null
    git commit -m "Hello World, $1!" &> /dev/null
    git branch -m main
    git push -f -u https://$GITLAB_ADMIN_USERNAME:$GITLAB_ADMIN_PASSWORD@$GITLAB_ROUTE/$GITLAB_ADMIN_USERNAME/$1.git main
    cd ..
    sleep 2
}

create_argocd_repository() {
    argocd repo add https://$GITLAB_ROUTE/$GITLAB_ADMIN_USERNAME/$1.git \
        --username $GITLAB_ADMIN_USERNAME \
        --password $GITLAB_ADMIN_PASSWORD
    sleep 2
}

create_argocd_project() {
    argocd app create $1 \
        --repo https://$GITLAB_ROUTE/$GITLAB_ADMIN_USERNAME/$1.git \
        --path . \
        --dest-server https://kubernetes.default.svc \
        --dest-namespace default \
        --sync-policy automated \
        --sync-option Prune=true \
        --self-heal
    oc label namespace $1 "argocd.argoproj.io/managed-by=openshift-gitops"
    sleep 2
}

new_project() {
    create_openshift_project $1
    create_gitlab_repository $1
    create_argocd_repository $1
    create_argocd_project $1
    # argocd app wait $1
}

new_python_project() {
    create_openshift_project $1
    create_gitlab_repository $1
    create_gitlab_repository $1-gitops
    create_argocd_repository $1-gitops
    create_argocd_project $1-gitops
    oc new-app https://$GITLAB_ROUTE/$GITLAB_ADMIN_USERNAME/$1.git -n $1
}

echo_task() {
    echo "##### $1 #####"
    sleep 1
}

##### Helm #####
echo_task "Installing Helm CLI"

install_helm_cli

echo_task "Helm CLI installed!"

##### Git LFS #####
echo_task "Installing Git LFS"

install_git_lfs

echo_task "Git LFS installed!"

##### MinIO cli #####
echo_task "Installing MinIO CLI"

install_minio_cli

echo_task "MinIO CLI installed!"

##### Scale nodes #####
echo_task "Scaling CPU nodes"

MACHINESET=$(oc get machineset.machine.openshift.io -n openshift-machine-api -o jsonpath='{.items[0].metadata.name}')
oc scale --replicas=2 machineset $MACHINESET -n openshift-machine-api
sleep 10

echo_task "CPU nodes scaled!"

echo_task "Installing cluster config"

helm install demo-cluster-config demo-cluster-config --set infraName=$INFRA_NAME --set subnet=$SUBNET --set availabilityZone=$AVAILABILITYZONE --set region=$REGION
sleep 10
# TODO check node status and wait...

echo_task "Cluster config installed!"

##### OpenShift GitOps Operator #####
echo_task "Installing OpenShift GitOps Operator"

create_openshift_project demo

helm install demo-operator-gitops demo-operator-gitops/
sleep 2

until oc wait --for='condition=Available' deployment/openshift-gitops-server -n openshift-gitops &> /dev/null
do
    echo "Waiting for the openshift-gitops-server deployment to be available..."
    sleep 10
done
sleep 2

ARGOCD_ADMIN_PASSWORD=$(oc get secret openshift-gitops-cluster -o json -n openshift-gitops | jq -r '.data."admin.password"' | base64 -d)
ARGOCD_ROUTE=$(oc get route openshift-gitops-server -o json -n openshift-gitops | jq -r '.spec.host')
sleep 2

echo_task "OpenShift GitOps Operator installed!"

#### GitLab ####
echo_task "Installing GitLab"
helm repo add gitlab-operator https://gitlab.com/api/v4/projects/18899486/packages/helm/stable

helm install gitlab-operator gitlab-operator/gitlab-operator --create-namespace --namespace gitlab-system

until oc wait -n gitlab-system --for='condition=Available' deployment/gitlab-controller-manager &> /dev/null
do
    echo "Waiting for the gitlab-operator deployment to be available..."
    sleep 10
done

helm install gitlab demo-operator-gitlab --namespace gitlab-system --set domain=$OCP_DOMAIN

until oc wait -n gitlab-system --for='condition=Available' deployment/gitlab-webservice-default &> /dev/null
do
    echo "Waiting for the gitlab deployment to be available..."
    sleep 10
done

GITLAB_ADMIN_PASSWORD=$(oc get secret gitlab-gitlab-initial-root-password -n gitlab-system -o json | jq -r '.data.password' | base64 -d)
echo_task "GitLab installed!"

#GITLAB_ACCESS_TOKEN=$(curl --data "grant_type=password&username=root&password=Hkbv6GBFmHSbjsyJ8byxA2mwE4DcNb56CEPbzxBwF5XG3rP4GZQG3VgvFSF4RbOq" --request POST "https://gitlab.apps.cluster-v9xxj.v9xxj.sandbox3056.opentlc.com/oauth/token" | jq -r '.access_token')
GITLAB_ACCESS_TOKEN=$(curl --data "grant_type=password&username=${GITLAB_ADMIN_USERNAME}&password=${GITLAB_ADMIN_PASSWORD}" --request POST "https://${GITLAB_ROUTE}/oauth/token" | jq -r '.access_token')
GITLAB_TOKEN=$(curl --request POST --header "Authorization: Bearer ${GITLAB_ACCESS_TOKEN}" --data "name=rhdh_token" --data "expires_at=2025-11-01" \
     --data "scopes[]=api,read_repository,write_repository" "https://${GITLAB_ROUTE}/api/v4/users/1/personal_access_tokens"  | jq -r '.token')

##### ArgoCD #####
echo_task "Installing ArgoCD CLI"

install_argocd_cli

argocd login --username $ARGOCD_ADMIN_USERNAME --password $ARGOCD_ADMIN_PASSWORD $ARGOCD_ROUTE --grpc-web &> /dev/null
sleep 2

echo_task "ArgoCD CLI installed!"

##### Users #####
echo_task "Configure users"

create_gitlab_repository demo-httpasswd-config
create_argocd_repository demo-httpasswd-config
create_argocd_project demo-httpasswd-config

echo_task "users configured!"

##### Operators #####
echo_task "Installing Operators"

new_project demo-operators
argocd app wait demo-operators

echo_task "Operators installed!"

##### Node Feature Discovery Operator Component #####
until oc wait -n openshift-nfd --for='condition=Available' deployment/nfd-controller-manager &> /dev/null
do
    echo "Waiting for the node feature discovery operator deployment to be available..."
    sleep 10
done

echo_task "Installing NFD Component"

helm install nfd-instance demo-operator-nfd-comps/ -n openshift-nfd

echo_task "NFD Component installed!"

##### NVIDIA GPU Operator Component #####
until oc wait -n openshift-nfd --for='condition=Available' deployment/nfd-master &> /dev/null
do
    echo "Waiting for the nfd-instance deployment to be available..."
    sleep 10
done

until oc wait -n nvidia-gpu-operator --for='condition=Available' deployment/gpu-operator &> /dev/null
do
    echo "Waiting for the nvidia gpu operator deployment to be available..."
    sleep 10
done

echo_task "NVIDIA GPU Operator Component"

helm install cluster-policy-gpu demo-operator-nvidia-comps/ -n nvidia-gpu-operator

echo_task "NVIDIA GPU Operator Component installed!"

##### Operators Components #####
echo_task "Installing Operators Components"

new_project demo-operators-comps

echo_task "Operators components installed!"

argocd app set demo-operators-comps -p domain=$OCP_DOMAIN -p gitlab_token=$GITLAB_TOKEN -p gitlab_route=$GITLAB_ROUTE

until oc wait -n redhat-ods-applications --for='condition=Available' deployment/rhods-dashboard &> /dev/null
do
    echo "Waiting for the rhods-dashboard deployment to be available..."
    sleep 10
done

helm install rhoai-config demo-operator-rhoai-config/ -n redhat-ods-applications

echo_task "Operators components installed!"

##### Model Registries #####
##### Disable to catch new deployment ######

# until oc wait -n redhat-ods-applications --for='condition=Available' deployment/model-registry-operator-controller-manager &> /dev/null
# do
#     echo "Waiting for the model-registry-operator-controller-manager deployment to be available..."
#     sleep 10
# done

echo_task "Installing Database to Model Registry"

create_gitlab_repository demo-model-registry
create_argocd_repository demo-model-registry
create_argocd_project demo-model-registry

echo_task "Database to Model Registry installed!"

##### Elasticsearch #####
echo_task "Installing Elasticsearch"

new_project demo-app-elasticsearch
argocd app wait demo-app-elasticsearch

echo_task "Elasticsearch installed!"

ELASTIC_PASSWORD=$(oc get secret demo-app-elasticsearch-es-elastic-user -o json -n demo-app-elasticsearch | jq -r '.data."elastic"' | base64 -d)
sleep 2

##### MinIO #####
echo_task "Installing MinIO"

new_project demo-app-minio

until oc wait --for='condition=Available' deployment/demo-app-minio -n demo-app-minio &> /dev/null
do
    echo "Waiting for the demo-app-minio deployment to be available..."
    sleep 10
done

MINIO_API_ROUTE='https://'$(oc get route demo-app-minio-api -n demo-app-minio -o json | jq -r '.spec.host')
MINIO_UI_ROUTE='https://'$(oc get route demo-app-minio-ui -n demo-app-minio -o json | jq -r '.spec.host')
sleep 2

mc alias set demo-minio $MINIO_API_ROUTE $MINIO_USERNAME $MINIO_PASSWORD
sleep 2

echo_task "MinIO installed!"

##### Models Deploy #####
echo_task "deploying models & runtimes serving"

new_project demo-models-deploy
mc mb demo-minio/models

echo_task "models & runtimes serving deployed"

##### App Telegram Pipeline #####
echo_task "Installing App Telegram Pipeline"

sed -i 's/elasticsearch_password/'"${ELASTIC_PASSWORD}"'/' demo-app-telegram-pipeline-gitops/templates/configmap.yaml

new_python_project demo-app-telegram-pipeline
sleep 2

oc label namespace demo-app-telegram-pipeline "opendatahub.io/dashboard=true"
sleep 2

until oc wait --for='condition=Available' deployment/demo-app-telegram-pipeline -n demo-app-telegram-pipeline &> /dev/null
do
    echo "Waiting for the demo-app-telegram-pipeline deployment to be available..."
    sleep 10
done

mc admin config set demo-minio/ notify_webhook:index-document endpoint="http://demo-app-telegram-pipeline.demo-app-telegram-pipeline.svc.cluster.local:8080/index_document"
sleep 2

mc admin service restart demo-minio/
sleep 10

mc event add --event "put" demo-minio/telegram-pipelines arn:minio:sqs::index-document:webhook
sleep 2

##### App Telegram #####
echo_task "Installing App Telegram"

sed -i 's/elasticsearch_password/'"${ELASTIC_PASSWORD}"'/' demo-app-telegram-gitops/templates/configmap.yaml

new_python_project demo-app-telegram
sleep 2

until oc wait --for='condition=Available' deployment/demo-app-telegram -n demo-app-telegram &> /dev/null
do
    echo "Waiting for the demo-app-telegram deployment to be available..."
    sleep 10
done

echo_task "App Telegram installed!"

##### Install RHDH plugins server #####
echo_task "Installing Dynamic RHDH plugins server"
# fail if already deployed
/bin/bash deploy-rhdh-plugins.sh

# /bin/bash update-rhdh-plugins.sh


##### Install quarkus app #####

sudo yum -y install java-21-openjdk-devel

./rhdh-ai-embedder/mvnw -f rhdh-ai-embedder/pom.xml clean package -Dquarkus.container-image.build=true -Dquarkus.openshift.deploy=true -Dquarkus.openshift.env.vars.elastic-password=${ELASTIC_PASSWORD} > .mvn.log  


##### Add demo-payment repository #####
DEVSPACES_ROUTE=$(oc get route devspaces -n demo-devspaces -o json | jq -r '.spec.host')

sed 's/devspaces_route/'"${DEVSPACES_ROUTE}"'/' demo-payment/catalog-info_model.yaml | sed 's/gitlab_route/'"${GITLAB_ROUTE}"'/' > ./catalog-info.yaml
mv catalog-info.yaml demo-payment/catalog-info.yaml

create_gitlab_repository demo-payment

GITLAB_DEMO_PAYMENT_PROJECT_ID=$(curl --request GET --header "Authorization: Bearer ${GITLAB_ACCESS_TOKEN}" "https://${GITLAB_ROUTE}/api/v4/projects?search=demo-payment" | jq -r '.[0].id')

curl --request POST --header "Authorization: Bearer ${GITLAB_ACCESS_TOKEN}" \
     --url "https://${GITLAB_ROUTE}/api/v4/projects/${GITLAB_DEMO_PAYMENT_PROJECT_ID}/hooks" \
     --data "push_events=true" \
     --data "enable_ssl_verification=false" \
     --data "url=http://embedder-demo-operators-comps.${OCP_DOMAIN}/injest" 


##### Clean & Restore #####
git restore demo-app-telegram-gitops/templates/configmap.yaml
git restore demo-app-telegram-pipeline-gitops/templates/configmap.yaml

##### Exit #####
echo_task "Demo Project installed!"

RHDH_ROUTE=$(oc get route backstage-developer-hub -o json -n demo-operators-comps | jq -r '.spec.host')

##### Summary #####
echo_task "SUMMARY"
echo "ARGOCD"
echo " Route: https://${ARGOCD_ROUTE}"
echo " User : ${ARGOCD_ADMIN_USERNAME}"
echo " Pass : ${ARGOCD_ADMIN_PASSWORD}"

echo "GitLab"
echo " Route: https://${GITLAB_ROUTE}"
echo " User : ${GITLAB_ADMIN_USERNAME}"
echo " Pass : ${GITLAB_ADMIN_PASSWORD}"
echo " Token: ${GITLAB_TOKEN}"
echo " Access Token: ${GITLAB_ACCESS_TOKEN}"

echo "Elasticsearch"
echo " User   : ${ELASTIC_USERNAME}"
echo " Pass   : ${ELASTIC_PASSWORD}"
echo " Service: ${ELASTIC_SERVICE}"

echo "Developer Hub"
echo " Route: https://${RHDH_ROUTE}"

echo "Dev Spaces"
echo " Route: https://${DEVSPACES_ROUTE}"

echo "Minio"
echo "API Route: ${MINIO_API_ROUTE}"
echo "UI Route : ${MINIO_UI_ROUTE}"
echo "User     : ${MINIO_USERNAME}"
echo "Pass     : ${MINIO_PASSWORD}"

exit