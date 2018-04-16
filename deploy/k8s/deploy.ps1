Param(
    [parameter(Mandatory=$true)][string]$configFile,    
    [parameter(Mandatory=$false)][string]$registry,
    [parameter(Mandatory=$false)][string]$dockerUser,
    [parameter(Mandatory=$false)][string]$dockerPassword,
    [parameter(Mandatory=$false)][string]$execPath,
    [parameter(Mandatory=$false)][string]$kubeconfigPath,
    [parameter(Mandatory=$false)][string]$imageTag,
    [parameter(Mandatory=$false)][bool]$deployCI=$false,
    [parameter(Mandatory=$false)][bool]$buildImages=$false,
    [parameter(Mandatory=$false)][bool]$pushImages=$false,
    [parameter(Mandatory=$false)][bool]$deployInfrastructure=$false,
    [parameter(Mandatory=$false)][string]$discoveryServiceFile="",
    [parameter(Mandatory=$false)][string]$dockerOrg="smarthotels"
)

$scriptPath = Split-Path $script:MyInvocation.MyCommand.Path

if (-not [string]::IsNullOrEmpty($dockerOrg)) {
    $dockerOrg = "$dockerOrg/"
}

function ExecKube($cmd) {    
    if($deployCI) {
        $kubeconfig = $kubeconfigPath + 'config';
        $exp = $execPath + 'kubectl ' + $cmd + ' --kubeconfig=' + $kubeconfig
        Invoke-Expression $exp
    }
    else{
        $exp = $execPath + 'kubectl ' + $cmd
        Invoke-Expression $exp
    }
}

# Initialization
$debugMode = $PSCmdlet.MyInvocation.BoundParameters["Debug"].IsPresent
$useDockerHub = [string]::IsNullOrEmpty($registry)

$externalDns = & ExecKube -cmd 'get svc ingress-nginx -n ingress-nginx -o=jsonpath="{.status.loadBalancer.ingress[0].ip}"'
Write-Host "Ingress ip detected: $externalDns" -ForegroundColor Yellow 

if (-not [bool]($externalDns -as [ipaddress])) {
    Write-Host "Must install ingress first" -ForegroundColor Red
    Write-Host "Run deploy-ingress.ps1 and  deploy-ingress-azure.ps1." -ForegroundColor Red
    exit
}

# Check required commands (only if not in CI environment)
if(-not $deployCI) {
        $requiredCommands = ("docker", "docker-compose", "kubectl")
        foreach ($command in $requiredCommands) {
        if ((Get-Command $command -ErrorAction SilentlyContinue) -eq $null) {
            Write-Host "$command must be on path" -ForegroundColor Red
            exit
        }
    }
}
else {
    $pushImages = false;
    $buildImages = false;       # Never build images through CI, as they previously built
}

# Get tag to use from current branch if no tag is passed
if ([string]::IsNullOrEmpty($imageTag)) {
    $imageTag = $(git rev-parse --abbrev-ref HEAD)
}

Write-Host "Docker image Tag: $imageTag" -ForegroundColor Yellow

# if we have login/pwd add the secret to k8s
if (-not [string]::IsNullOrEmpty($dockerUser)) {
    $registryFDQN =  if (-not $useDockerHub) {$registry} else {"index.docker.io/v1/"}

    Write-Host "Logging in to $registryFDQN as user $dockerUser" -ForegroundColor Yellow
    if ($useDockerHub) {
        docker login -u $dockerUser -p $dockerPassword
    }
    else {
        docker login -u $dockerUser -p $dockerPassword $registryFDQN
    }
    
    if (-not $LastExitCode -eq 0) {
        Write-Host "Login failed" -ForegroundColor Red
        exit
    }

    # create registry key secret
    ExecKube -cmd 'create secret docker-registry registry-key `
    --docker-server=$registryFDQN `
    --docker-username=$dockerUser `
    --docker-password=$dockerPassword `
    --docker-email=not@used.com'
}

if ($buildImages) {
    Write-Host "Building Docker images tagged with '$imageTag'" -ForegroundColor Yellow
    $env:TAG=$imageTag
    docker-compose -p .. -f ../../src/docker-compose.yml -f ../../src/docker-compose-tagged.yml  build    
}

if ($pushImages) {
    Write-Host "Pushing images to $registry/$dockerOrg..." -ForegroundColor Yellow
    $services = ("bookings", "hotels", "suggestions", "tasks", "configuration", "notifications", "reviews", "discounts", "profiles")

    foreach ($service in $services) {
        $imageFqdn = if ($useDockerHub)  {"${dockerOrg}${service}"} else {"$registry/${dockerOrg}${service}"}
        docker tag smarthotels/${service}:$imageTag ${imageFqdn}:$imageTag
        docker push ${imageFqdn}:$imageTag            
    }
}


# Removing previous services & deployments
Write-Host "Removing existing services & deployments.." -ForegroundColor Yellow
ExecKube -cmd 'delete -f deployments.yaml'
ExecKube -cmd 'delete  -f services.yaml'
if ($deployInfrastructure) {
    ExecKube -cmd 'delete -f sql-data.yaml -f postgres.yaml'
}
ExecKube -cmd 'delete configmap config-files'
ExecKube -cmd 'delete configmap externalcfg'
ExecKube -cmd 'delete configmap discovery-file'

if ($deployInfrastructure) {
    Write-Host 'Deploying infrastructure deployments'  -ForegroundColor Yellow
    ExecKube -cmd 'create -f sql-data.yaml -f postgres.yaml'
}


ExecKube -cmd 'create configmap config-files --from-file=nginx-conf=nginx.conf'
ExecKube -cmd 'label configmap config-files app=smarthotels'

if (-not [string]::IsNullOrEmpty($discoveryServiceFile)) {
    Write-Host "Creating discovery service file from $discoveryServiceFile" -ForegroundColor Yellow
    ExecKube -cmd "create configmap discovery-file --from-file=custom.json=$discoveryServiceFile"
}
else {
    Write-Host "Creating empty discovery service file from $discoveryServiceFile. This is not an error!" -ForegroundColor Yellow
    ExecKube -cmd "create configmap discovery-file --from-file=custom.json=empty.json"
}

Write-Host 'Deploying WebAPIs' -ForegroundColor Yellow
ExecKube -cmd 'create -f services.yaml'

Write-Host "Deploying configuration from $configFile" -ForegroundColor Yellow

ExecKube -cmd "create -f $configFile"

Write-Host "Creating desployments on k8s..." -ForegroundColor Yellow
ExecKube -cmd 'create -f deployments.yaml'

# update deployments with the correct image (with tag and/or registry)
$registryPath = ""
if (-not [string]::IsNullOrEmpty($registry)) {
    $registryPath = "$registry/"
}

if ($imageTag -eq "latest" -and $dockerOrg -eq "smarthotels" -and [String]::IsNullOrEmpty($registryPath)) {
    Write-Host "No need to update image containers (default values used)"-ForegroundColor Yellow
}
else {
    Write-Host "Update Image containers to use prefix '$registry/$dockerOrg' and tag '$imageTag'" -ForegroundColor Yellow
    ExecKube -cmd 'set image deployments/hotels hotels=${registryPath}${dockerOrg}hotels:$imageTag'
    ExecKube -cmd 'set image deployments/bookings bookings=${registryPath}${dockerOrg}bookings:$imageTag'
    ExecKube -cmd 'set image deployments/suggestions suggestions=${registryPath}${dockerOrg}suggestions:$imageTag'
    ExecKube -cmd 'set image deployments/tasks tasks=${registryPath}${dockerOrg}tasks:$imageTag'
    ExecKube -cmd 'set image deployments/config config=${registryPath}${dockerOrg}configuration:$imageTag'
    ExecKube -cmd 'set image deployments/notifications notifications=${registryPath}${dockerOrg}notifications:$imageTag'
    ExecKube -cmd 'set image deployments/reviews reviews=${registryPath}${dockerOrg}reviews:$imageTag'
    ExecKube -cmd 'set image deployments/discounts discounts=${registryPath}${dockerOrg}discounts:$imageTag'
    ExecKube -cmd 'set image deployments/profiles profiles=${registryPath}${dockerOrg}profiles:$imageTag'
}

Write-Host "Execute rollout..." -ForegroundColor Yellow
ExecKube -cmd 'rollout resume deployments/hotels'
ExecKube -cmd 'rollout resume deployments/bookings'
ExecKube -cmd 'rollout resume deployments/suggestions'
ExecKube -cmd 'rollout resume deployments/config'
ExecKube -cmd 'rollout resume deployments/tasks'
ExecKube -cmd 'rollout resume deployments/notifications'
ExecKube -cmd 'rollout resume deployments/reviews'
ExecKube -cmd 'rollout resume deployments/discounts'
ExecKube -cmd 'rollout resume deployments/profiles'

Write-Host "$loadBalancerIp is the root IP/DNS of thhe cluster" -ForegroundColor Yellow