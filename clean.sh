

## FILE UNDER BUILDING.....



## GitLab
helm uninstall gitlab --namespace gitlab-system
helm uninstall gitlab-operator --namespace gitlab-system
oc delete project gitlab-system
helm repo remove gitlab-operator
