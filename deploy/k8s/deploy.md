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

Now you can cancel the command (`Ctrl+C`): The `a.b.c.d` is the public ip assigned to your cluster. **It won't change** so write down for future reference.

>**Note** You can always get the public ip by command `kubectl get ing sh360-ingress`

## Deploy microservices (as many times you need it)

The `deploy.ps1` file is used to deploy the microservices. This file deletes all cluster content (except _ingress_ and _ingress controller_) and deploy all microservices (**no selective deployment is supported yet**, although you can do it by using custom scripts or using kubectl directly).

>**Note**: You can choose by deploying only the microservices or the microservices AND the databases (sql server and postgre) in the cluster. Set `deployInfrastructure` to `$true` for deploying databases also.

**For deploying microservices in a k8s, images must be in a Docker repository**. It can be DockerHub or ACR and the images can be public or private. Let's assume you have the images in a ACR called `my-acr`. Then the command to deploy everything is:

```
.\deploy.ps1 -configFile .\conf_all.yml -dockerUser <your-docker-user> -dockerPassword <your-docker-password> -registry <docker-registry> -imageTag latest -deployInfrastructure $true -buildImages $false -dockerOrg <your-docker-org> -pushImages $false
```

> **Note** If you don't use organizations in your repository pass an empty string to `dockerOrg` parameter (`-dockerOrg ''`).

* `dockerUser`: Docker user (for private repos OR if images are pushed)
* `dockerPassword`: Docker password (for private repos OR if images are pushed)
* `registry`: Docker registry (defaults to DockerHub)
* `imageTag`: Tag to deploy to k8s (defaults to current Git branch)
* `deployInfrastructure`: If `$true` sql & postgres containers are deployed (defaults to  `$false`)
* `buildImages`: If `$true` Docker Images are built (defaults to `$false`)
* `pushImages`: If `$true` Docker Images are push onto registry (defaults to `$false`)
* `configFile`: Configuration file to use (connection strings and so on). **READ NEXT SECTION about config files**
* `dockerOrg`: Organization where images are (defaults to `smarthotel360`). If you don't use organizations in your repository use an empty string `''`.
* `discoveryServiceFile`: Configuration endpoint file. **READ SECTION Configuration endpoint file** for more information.

Once deploy.ps1 finish you can check everything is installed by typing `kubectl get services`. The answer should be like:

```
NAME            CLUSTER-IP     EXTERNAL-IP    PORT(S)                      AGE
bookings        10.0.72.109    <none>         80/TCP                       18h
config          10.0.159.143   <none>         80/TCP                       18h
discounts       10.0.46.77     <none>         80/TCP                       18h
hotels          10.0.42.187    <none>         80/TCP                       18h
kubernetes      10.0.0.1       <none>         443/TCP                      7d
notifications   10.0.228.103   <none>         80/TCP                       18h
profiles        10.0.229.70    <none>         80/TCP                       18h
reviews         10.0.213.186   <none>         80/TCP                       18h
suggestions     10.0.156.59    <none>         80/TCP                       18h
tasks           10.0.68.136    <none>         80/TCP                       18h
```

>**Note** If you used `deployInfrastructure` to `$true` three more services will appear (`sql-data`, `tasks-data` and `reviews-data`).

## Configuration files

The `-configFile` parameter sets the configuration file to configure all the services on the cluster. The `conf_local.yml` is a sample of this configuration file. **All entries are mandatory, and you can retrieve its values from the Azure portal** once you have created the resources. So, for creating a valid `configFile` just edit the  `conf_local.yml` file and add your desired values to the keys. 

>**Important Note**: If you used `$deployInfrastructure` to `$true`, then use `conf_all.yml` as a value for `configFile` (the file `conf_all.yml` contains everything configured to use the container databases).

> **Note**: The AAD B2C values that are in both files (`conf_local.yml` and `conf_all.yml`) are only valid for the services hosted in the public endpoint. You can leave as it if you don't want to use B2C. If you want to use your own B2C you need to update those values.

## Configuration endpoint file

Client applications (Public web, Xamarin) use a **configuration endpoint** to get all services URLs and other configuration stuff. The _configuration microservice_ provides this endpoint in the url http://YOUR-CLUSTER/configuration-api/cfg:

![configuration endpoint](../../docs/config-endpoint.png)

This endpoint returns a set of "valid environments" (like `build-demo`, `localhost-docker` or `custom`). To get the configuration for one environment its name is appended to the configuration endpoint (like http://YOUR-CLUSTER/configuration-api/cfg/localhost-docker). Answer is a JSON containing the environment configuration needed by the clients.

Environments are defined at docker image level in the configuration microservice. Look for `/src/SmartHotel.Services.Configuration/cfg` folder. This folder contains the configuration json files (one per environment). When the Docker image is built, those files are included in the image and the container simply looks at this path to find its environments.

**Unfortunately this makes hard for you to add your custom environment**. If you are building the images yourself the solution is pretty straightforward: add a new configuration file in the `/src/SmartHotel.Services.Configuration/cfg` before building the images. **But, how about if you want to use a prebuilt image?**

Well, you can do it using the `discoveryServiceFile` parameter of the `deploy.ps1` script. If this parameter is set it must point to a environment configuration file. In this case **the environment configuration file provided is mapped to the image** under the name of `custom`.

So **configuration microservice deployed in k8s will ALWAYS expose an environment named custom**. And the configuration of this environment will be either:

1. An empty JSON (if `discoveryServiceFile` is not set)
2. The value of the file pointed by `discoveryServiceFile` parameter.

### Configuration endpoint file template

Here you have a configuration endpoint file template for reference:

```
  "urls": {
    "hotels": "http://localhost:6101/",
    "bookings": "http://localhost:6100/",
    "suggestions": "http://localhost:6102/",
    "tasks": "http://localhost:6104/",
    "notifications": "http://localhost:6105/",
    "reviews": "http://localhost:6106/",
    "discounts": "http://localhost:6107/",
    "images_base": "https://sh360imgdev.blob.core.windows.net/"
  },
  "pets_config": {
    "blobName": "PUT YOUR LOCAL BLOB NAME HERE",
    "blobKey": "PUT THE BLOB KEY HERE",
    "cosmosUri": "https://YOUR-COSMOS-DB-HERE.documents.azure.com:443/",
    "cosmosKey": "PUT THE COSMOS DB HERE"

  },
  "tokens": {
    "bingmaps": "PUT YOUR BING MAPS TOKEN"
  },
  "b2c": {
    "tenant": "smarthotel360.onmicrosoft.com",
    "policy": "B2C_1_SignUpInPolicy",
    "client": "b3cfbe11-ac36-4dcb-af16-8656ee286dcc"
  },
  "analytics": {
    "android": "f4754bd4-1edf-4bd8-83cd-b9f6539293da",
    "ios": "f3584cf1-6c12-465e-9511-d8db225bd340",
    "uwp": "fd822e0c-f6fd-446c-846c-622c3c229006"
  },
  "others": {
    "fallbackMapsLocation": "40.762246,-73.986943"
  },
  "bot": {
    "id": "897f3818-8da3-4d23-a613-9a0f9555f2ea",
    "FacebookBotId": "120799875283148"
  }
```
Most relevant sections are:

* `urls` section contains the microservices URLs
* `pets_config` section contains configuration needed by "Bring your pet" demo of Public Web
* `tokens`: Need to provide your Bing Maps API token (for Xamarin app)
* `b2c`: Need to provide your AAD B2C configuration if using a custom AAD B2C
  *  `client` is the ID of the "Public Web" in your AAD B2C

## Next steps

1. [Configure TLS on the cluster](./deploy-ssl.md) (if needed)
2. [Deploy infrastructure on Azure](../../docs/deploy-azure.md)