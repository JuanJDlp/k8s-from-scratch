# Kubernetes Application Deployment Lab
This lab demonstrates how to deploy a simple application using Kubernetes. The lab utilizes various Kubernetes resources such as Deployments, ReplicaSets, Services, Secrets, and ConfigMaps to deploy and manage the application.

## Prerequisites
Before starting this lab, you should have the following prerequisites installed:
- kubectl: Kubernetes command-line tool.
- Docker: Containerization platform to build and push container images.
## Description
In this lab, we deploy a simple web application to a Kubernetes cluster. The application consists of a backend service and a frontend interface. We utilize the following Kubernetes resources:
- Deployment: Manages the Pods and ReplicaSets, ensuring the desired number of Pod replicas are running.
- ReplicaSet: Ensures that a specified number of Pod replicas are running at all times.
- Service: Exposes the application to external traffic and provides load balancing.
- Secrets: Stores sensitive data such as credentials securely.
- ConfigMap: Stores non-sensitive configuration data for the application.
## Lab Structure
The lab repository contains the following files:

- webapp-deployment.yaml: Defines the Deployment for the application.
- webapp-service.yaml: Defines the Service to expose the application.
- webapp-configmap.yaml: Defines the ConfigMap for application configuration.
- webapp-dhsecret.yaml and webapp-dbsecret.yaml: Defines the Secrets for sensitive data storage.

## Steps

### Step 1: Create a Docker Image
1. Clone this repository to your local machine.
2. Navigate to the `K8S-apps` directory.
3. Build the Docker image using the provided Dockerfile:
    ```bash
    # docker build -t web-app .
    # docker tag webapp:latest <your-dockerhub-username>/webapp:v1
    ```
4. Push the Docker image to your Docker Hub repository:
    ```bash
    docker push <your-dockerhub-username>/webapp:v1
    ```

### Step 2: Update Deployment and ReplicaSet Configurations
1. Open files `app-deployment.yaml` and `app-replicaset.yaml` in the K8S_files directory.
2. Replace `<nombre_de_usuario_en_docker_hub>` with your Docker Hub username.
3. Replace `<nombre_del_repositorio>` with the name of your Docker Hub repository.
4. Replace `<tag>` with the desired tag for your image.
5. Save the changes.

### Step 3: Apply Kubernetes Configurations
Apply the Kubernetes configurations to deploy the application:
```bash
kubectl apply -f K8S_files/webapp-configmap.yaml
kubectl apply -f K8S_files/webapp-dhsecret.yaml
kubectl apply -f K8S_files/webapp-dbsecret.yaml
kubectl apply -f K8S_files/webapp-deployment.yaml
kubectl apply -f K8S_files/webapp-replicaset.yaml
kubectl apply -f K8S_files/webapp-service.yaml
 ```
### Step 4: Access the Application
Once the resources are deployed, you can access the application by finding the external IP of the Service:
```bash
kubectl get svc webapp-service
 ```
Then, open a web browser and navigate to http://<EXTERNAL_IP>:30001.

### Step 5:
To clean up the resources created in this lab, run the following command:
```bash
kubectl delete deployment webapp-deployment
kubectl delete replicaset webapp-replicaset
kubectl delete service webapp-service
kubectl delete configmap webapp-configmap
kubectl delete secret webapp-dhsecret webapp-dbsecret
 ```
## Additional Notes
You can customize the application by modifying the source code in the app directory.
Explore other Kubernetes resources and features to further enhance your understanding of Kubernetes.
