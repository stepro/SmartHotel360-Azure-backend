# Deploying microservices to a Kubernetes Cluster in AKS

> **Note**: This doc assumes that you have an AKS created and `kubectl` is configure to run agains it.

## One-time action: deploy NGINX ingress controller

You have to deploy NGINX ingress controller to your AKS. You need to do this **only once**. Just run:

```
deploy-ingress.ps1
deploy-ingress-azure.ps1
```

Verify that NGINX controller is installed by `kubectl get services -n ingress-nginx`:

```
NAME                   TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)                      AGE
default-http-backend   ClusterIP      10.0.175.32    <none>        80/TCP                       1m
ingress-nginx          LoadBalancer   10.0.205.248   <pending>     80:32505/TCP,443:31279/TCP   42s
```

Then use the command `kubectl get ing -w` to list the _ingress_ resource and watch for changes on it:

```
NAME            HOSTS     ADDRESS   PORTS     AGE
sh360-ingress   *                   80        2m
```

This command keeps running until there is a change in _ingress_. This change happens when a PUBLIC IP is assigned (this takes some minutes). A new line should appear when the public ip is assigned:

```
NAME            HOSTS     ADDRESS   PORTS     AGE
sh360-ingress   *                   80        2m
sh360-ingress   *         a.b.c.d   80        4m
```

Now you can cancel the command (`Ctrl+C`): The `a.b.c.d` is the public ip assigned to your cluster. It won't change.

## Deploy microservices

The `deploy.ps1` file is used to deploy the microservices. This file deletes all cluster content and deploy all microservices (no selective deployment is supported, although you can do it by using custom scripts or using kubectl directly).

For deploying microservices in a AKS, images must be in a Docker repository. It can be DockerHub or ACR and the images can be public or private. Let's assume you have the images in a ACR called my-acr. Then the command to deploy everything is:

```
.\deploy.ps1 -configFile .\conf_all.yml -dockerUser <your-docker-user> -dockerPassword <your-docker-password> -registry <docker-registry> -imageTag latest -deployInfrastructure $true -buildImages $false -dockerOrg <your-docker-org> -pushImages $false
```

* `dockerUser`: Docker user (for private repos OR if images are pushed)
* `dockerPassword`: Docker password (for private repos OR if images are pushed)
* `registry`: Docker registry (defaults to DockerHub)
* `imageTag`: Tag to deploy to k8s (defaults to current Git branch)
* `deployInfrastructure`: If `$true` sql & postgres containers are deployed (defaults to  `$false`)
* `buildImages`: If `$true` Docker Images are built (defaults to `$false`)
* `pushImages`: If `$true` Docker Images are push onto registry (defaults to `$false`)
* `configFile`: Configuration file to use (connection strings and so on)

For creating a valid `configFile` just edit the  `conf_local.yml` file and add your desired values to the keys. **Note**: If you used `$deployInfrastructure` to `$true`, then use `conf_all.yml` as a value for `configFile` (the file `conf_all.yml` contains everything configured to use the container databases).

## Add TLS support to Kubernetes Cluster

>**Pre-requisite** In Azure [set a DNS entry](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/portal-create-fqdn) to the public ip used by the cluster. This IP is located in the same resource group as the cluster is.

TLS support is provided through [cert-manager](https://github.com/jetstack/cert-manager/). You **can use [helm](https://helm.sh/)** to install cer-manager. To install helm:

1. Download appropiate CLI for your OS from its [download page](https://github.com/kubernetes/helm/releases). Once CLI is installed just type `helm init` (add `--canary-flag` if you are using an RC version of helm). This will install _Tiller_ in your cluster.
2. Ensure _tiller_ is running by typing `kubectl get pods -n kube-system`. One pod whose name starts with  `tiller-deploy-`  should exist.

Once Helm is installed in your machine and Tiller is in the cluster you can install cert-manager:

```
helm install --name cert-manager --namespace kube-system stable/cert-manager
```

Now we need to configure cert-manager for getting Let's Encrypt certificatres using ACME protocol. Let's do that by creating an issuer and a certificate on k8s.

### Creating an issuer

Open (end edit if needed) the `issuer.yml` file, as this is the base template.

The line `server: https://acme-staging.api.letsencrypt.org/directory` sets the certificate provider: the staging server of Let's Encrypt. Good for testing, not for production as certificates are not signed. When you have tested all proces, change the value to Let's Encrypt production server: `https://acme-v01.api.letsencrypt.org/directory`

The `http01` enables use of HTTP-01 challenge (another option of cert-manager is DNS-01). With a HTTP-01 challenge, you prove ownership of a domain by ensuring that a particular file is present at the domain. It is assumed that you control the domain if you are able to publish the given file under a given path. No further configuration is possible at the moment.

### Creating the certificate

Open (end edit if needed) the `certificate.yml` file, as this is the base template.

In `commonName` enter the **DNS name of your cluster** (DNS value assigned to public ip). In `dnsNames` can enter a list of [Subject Alternative Names](https://en.wikipedia.org/wiki/Subject_Alternative_Name).

The `acme` section is the section that specifies the configuration for responding the ACME challenges. **To verify the ownership of every entry in `http01` cert-manager will create a _pod_ (exposed through _ingress_) that will serve the requested file**. In the `domains:` list you must enter all domains needed to be validated.

### Sample files

I. e. if the public IP of your cluster has the DNS name of `sh360ingress.eastus.cloudapp.azure.com` the  `certificate.yml` file will look like:

```
apiVersion: certmanager.k8s.io/v1alpha1
kind: Certificate
metadata:
  name: mysh360-cert
  namespace: default
spec:
  secretName: mysh360-cert-tls
  issuerRef:
    name: letsencrypt-staging
  commonName: example.com
  dnsNames:
  - www.example.com
  acme:
    config:
    - http01:
        ingress: sh360-ingress
      domains:
      - www.example.com
```

File `issuer.yml` no needs to be changed.

### Deploy & verify

Now we can deploy these two files:

```
kubectl apply -f issuer.yml
kubectl apply -f certificate.yml
```

Once deployed we can use `kubectl describe certificate mysh360-cert` to view its status. In the events you should see something like

```
  Type     Reason                 Age                From                     Message
  ----     ------                 ----               ----                     -------
  Warning  ErrorCheckCertificate  59s                cert-manager-controller  Error checking existing TLS certificate: secret "mysh360-cert-tls" not found
  Normal   PrepareCertificate     59s                cert-manager-controller  Preparing certificate with issuer
  Normal   PresentChallenge       59s                cert-manager-controller  Presenting http-01 challenge for domain sh360ingress.eastus.cloudapp.azure.com
  Normal   SelfCheck              58s                cert-manager-controller  Performing self-check for domain sh360ingress.eastus.cloudapp.azure.com
  Normal   ObtainAuthorization    34s                cert-manager-controller  Obtained authorization for domain sh360ingress.eastus.cloudapp.azure.com
  Normal   IssueCertificate       33s                cert-manager-controller  Issuing certificate...
  Normal   CeritifcateIssued      33s                cert-manager-controller  Certificated issued successfully
  Normal   RenewalScheduled       33s (x3 over 33s)  cert-manager-controller  Certificate scheduled for renewal in 1438 hours
```

Last step is **configure _ingress_ to use the certificate**. Open the `ingress.yaml` file and locate the lines:

```
spec:
  rules:
#  - host: YOUR_DNS_NAME
#    http:
  - http:
```

**Comment the last line and uncomment the two commented lines**. In the `- host:` entry of the commented line enter your DNS.

Also, at the end of file there is a block of commented code:

```
#  tls:
#  - secretName: mysh360-cert-tls
#    hosts:
#      - YOUR_DNS_NAME
```

**Uncomment all these lines**. Finally use `kubectl apply -f ingress.yaml` to deploy this changes to _ingress_ resource.

Now the certificate is set. If you use https://YOUR-DNS-NAME you will receive an invalid certificate from the organization `Fake LE Intermediate X1`: this is the staging Let's Encrypt organization!

To sign with a real certificate only three steps are needed:

1. Update `issuer.yml` to use Let's Encrypt production server
2. Run `kubectl apply -f issuer.yml`
3. Delete current secret (`kubectl delete secret mysh360-cert-tls`)
4. Delete certificate (`kubectl delete -f certificate.yml`)
5. Reinstall the certificate (`kubectl apply -f certificate.yml`)

In a few seconds a new certificate will be issued from Let's Encrypt production server.

