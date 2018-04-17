Param(
    [parameter(Mandatory=$true)][string]$resourceGroupName,
    [parameter(Mandatory=$false)][string]$location="eastus",
    [parameter(Mandatory=$false)][string]$registryName,
    [parameter(Mandatory=$true)][string]$orchestratorName,
    [parameter(Mandatory=$false)][string]$dnsName="",
    [parameter(Mandatory=$false)][bool]$createAcr=$true,
    [parameter(Mandatory=$false)][bool]$createRg=$true,
    [parameter(Mandatory=$false)][string]$agentvmsize="Standard_D2_v2",
    [parameter(Mandatory=$false)][Int]$agentcount=1
)


if ([string]::IsNullOrEmpty($orchestratorName)) {
    Write-Host "Must use --orchestratorName to set the AKS name" -ForegroundColor Red
    exit 1
}

if ([string]::IsNullOrEmpty($dnsName)) {
    Write-Host "k8s dns name set to $orchestratorName" -ForegroundColor Yellow
    $dnsName = $orchestratorName
}


# Create resource group
if ($createRg) {
    Write-Host "Creating resource group..." -ForegroundColor Yellow
    az group create --name=$resourceGroupName --location=$location
}


if ($createAcr -eq $true) {
    if (-not [string]::IsNullOrEmpty($registryName)) { 
        # Create Azure Container Registry
        Write-Host "Creating Azure Container Registry..." -ForegroundColor Yellow
        az acr create -n $registryName -g $resourceGroupName -l $location  --admin-enabled true --sku Basic
    }
    else {
        Write-Host "ACR not created as no name specified!" -ForegroundColor Yellow
    }
}

# Create kubernetes orchestrator
Write-Host "Creating managed kubernetes..." -ForegroundColor Yellow
az aks create --resource-group=$resourceGroupName --name=$orchestratorName --dns-name-prefix=$dnsName --node-vm-size=$agentvmsize --node-count=$agentcount --generate-ssh-keys

# Retrieve kubernetes cluster configuration and save it under ~/.kube/config 
az aks  get-credentials --resource-group=$resourceGroupName --name=$orchestratorName

if ($createAcr -eq $true) {
    # Show ACR credentials
    az acr credential show -n $registryName
}