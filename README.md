###This repo uses AKS, Terraform and Helm. For the modules it uses the public modules from Terraform Registries.

Steps on testing:

Make sure you have all of the dependencies installed (Azure CLI, Kubectl, Helm and Terraform) / all the perms are given (Azure permission - can be done via Terminal)
Clone the repo
Run terraform init, then apply
After the output, run kubectl get svc -n kubernetes-dashboard kubernetes-dashboard to make sure the kubernetes dashboard is running
Run kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443 to the proxy and port forwarding
Go to localhost:8443 to get access to the kubernetes dashboard
To get the bearer's key, run kubectl -n kubernetes-dashboard get secret $(kubectl -n kubernetes-dashboard get sa dashboard-admin-user -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' | base64 --decode


Learned / Ran into:
- AKS requires Premium tier for US East & US West (haven't checked other regions)
- AKS requires LTS kubernetes version (and almost all of them are premium tier), need to specify the sku_tier & support_plan (I did in main.tf)
