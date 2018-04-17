# Deploy services on Azure

> **Note** All tasks must be performed from the `/deploy/k8s` folder. Also you need the [Azure CLI 2.0](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest) installed on your system.

## Creating the Kubernetes cluster and deploy Microservices on it

1. To create the AKS cluster run the `/deploy/k8s/gen-k8s-env.ps1` script from a Powershell window. **Read the [documentation here](../deploy/k8s/readme.md) for details**.
2. To deploy Microservices on the k8s cluster you have to use `/deploy/k8s/deploy.ps1` from a Powershell window. **Read the [step by step here](../deploy/k8s/deploy.md)**.

## Creating all Azure resources

Once the kubernetes cluster is created, you need to create all remaining Azure infrastructure (databases, storages and so on). In the `/deploy/k8s/arm` folder there is one ARM script to create all items. You can use the `deploy.cmd` file to deploy the Azure resources in a new resource group by just typing:

```
deploy azuredeploy <resource-group> -c <location>
```

i.e. to deploy in a resource group called `my-new-rg` and located in `eastus` you can type:

```
deploy azuredeploy my-new-rg -c eastus
```

This will create a set of resources like following ones:

![azure resources](./azure-rg.png)



# The configuration service

If you run your own Kubernetes cluster and want to connect the public web and the Xamarin application to it you **need to update the configuration servide** to reflect your new endpoints.

> Note that this prevents you to use the public DockerHub images. You must build the images yourself, and push to your own Docker repository. Remember that `docker-compose build` will build the images without any other requirement.

To do it, open the `/src/SmartHotel.Services.Configuration/cfg` folder and create a new file `myenv.json`. Use the  `localhost-docker.json` file as a template. You need to update:

* The `urls` section with the urls of your services.
* The `pets_config` section (only if you want to recreate the bring your pet demo on local)

> **Note** The bring your pet demo is included in the [Public Web repository][https://github.com/Microsoft/SmartHotel360-public-web/]. Is the public web which contains the deployment scripts for the pets demo. You need an Azure Function, Storage, CosmosDB and Vision API to run it. For more info please go to the [instructions in the public web repo](https://github.com/Microsoft/SmartHotel360-public-web/blob/master/doc/pet-demo.md).

## Urls section

When running on Kubernetes all services share the same IP (the public IP created when deploying in the cluster). All services are exposed in `http://<public-ip>` with following paths:

* /hotels-api -> For hotels
* /bookings-api -> For bookings
* /suggestions-api -> For suggestions
* /tasks-api -> For tasks
* /notifications-api -> For notifications
* /reviews-api -> For reviews
* /discounts-api -> For discounts

So, if your public IP is http://a.b.c.d then the endpoint for Hotels API is http://a.b.c.d/hotels-api

> **Note**: Xamarin app do not support https, so must use http if plan to use Xamarin App.

> **Note**: You can create more than one configuration by just creating more files in the `/src/SmartHotel.Services.Configuration/cfg` folder. Then you can go to http://a.b.c.d/configuration-api/cfg to list all configurations and to http://a.b.c.d/configuration-api/cfg/[config] to load the configuration file named `[config.json]`.

Of course once you dropped this file **you must recreate the Docker image of the configuration api** by typing (located in `/src` folder):

```
docker-compose build configuration-api
```

Once the image is rebuilt you have to repush it to the repository and then redeploy the services on the cluster. Finally check the cluster has the updated configuration service by accessing your new configuration endpoint.

# Azure B2C

If you want to use B2C you must create your own B2C and then create applications on it:

* One application for the client (web & Xamarin)
* One application for the hotels api
* One application for the bookings api
* One application for the notifications api

## API applications

All three applications for the APIs share the same config:

![API configuration for the b2c](./b2c-api.png)

Once configured be sure that in the section "Published scopes" of each API application the scope "user_impersonation" is defined (if not, add it yourself):

![user_impersonation scope](./b2c-scope.png)

## Client application

The client application should have a configuration like:

![Client application b2c config](./b2c-client.png)

Also in the "API Access" section you need to grant access to the three APIs applications:

![Client application b2c api access](./b2c-api-access.png)

With this configuration client app is given access to all three APIs secured by B2C.

> **Note** Remember to update the _configuration file_ (i. e. the `conf_local.yml`) file with the B2C values and redeploy the k8s cluster.
