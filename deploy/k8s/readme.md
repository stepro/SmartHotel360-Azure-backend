# Deploying backend services on a k8s cluster

## Creating Kubernetes cluster (on Windows)

There are **two powershell scripts** for creating a Kubernetes cluster:

* `gen-k8s-env.ps1` to create a k8s cluster on Azure using ACS
* `gen-aks-env.ps1` to create managed k8s cluster using AKS

>**Note**: Both scripts have the same parameters and, once executes, you ending having a Kubernetes cluster that is managed using `kubectl` in both cases. 

If you are on Windows, use the script you prefer to create the k8s cluster. Both scripts accept the same parameters:

* resourceGroupName: Mandatory. Name of the resource where kubernetes cluster will be deployed 
* createRg: Optional. If `$true` means that the resource group must be created. If `$false` resource group must already exists. Default is `$true`.
* location: Optional. Location where to create all resources. Defaults to `eastus`.
* orchestratorName: Mandatory. Name of the ACS resource that contains the Kubernetes cluster
* dnsName: Optional. DNS name of the ACS. If not set defaults to `orchestratorName`.
* registryName: Optional. Name of the ACR to create.
* createAcr: Optional. If the ACR has to be created (`Strue`) or not (`$false`). Default value is `$true`, but ACR is only created if `registryName` has any value.
* agentvmsize: Optional. VM agent size. Defaults to `Standard_D2_v2`. Must be a valid VM agent size on the resource group and subscription used.
* agentcount: Optional. Number of nodes. Defaults to `1`. 

The simplest way to invoke the script is just pass the two mandatory parameters, to deploy a k8s cluster named `k8s-aks` into a new resource group (`k8sdev`):

```
 .\gen-aks-env.ps1  -resourceGroupName k8sdev -orchestratorName k8s-aks
```

If you want to deploy also an ACR just add the `registryName` parameter:

```
 .\gen-aks-env.ps1  -resourceGroupName k8sdev -orchestratorName k8s-aks -registryName k8sdevacr
```

Once you have a k8s cluster (ACS or AKS) created follow [these instructions](./deploy.md) to deploy all microservices on it.
