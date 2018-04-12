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
* `useSSL`: **NOT IMPLEMENTED YET** If `$true` TLS is configured in cluster.
* `configFile`: Configuration file to use (connection strings and so on)

For creating a valid `configFile` just edit the  `conf_local.yml` file and add your desired values to the keys. **Note**: If you used `$deployInfrastructure` to `$true`, then use `conf_all.yml` as a value for `configFile` (the file `conf_all.yml` contains everything configured to use the container databases).
