

## FILE UNDER BUILDING.....



## GitLab
helm uninstall gitlab demo-operator-gitlab --namespace gitlab-system
helm uninstall gitlab-operator gitlab-operator/gitlab-operator
oc delete project gitlab-system
helm repo remove gitlab-operator