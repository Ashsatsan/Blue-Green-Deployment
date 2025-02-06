# **Blue-Green Deployment on Kubernetes with CI/CD Pipeline**

![Project Diagram](https://github.com/Ashsatsan/Blue-Green-Deployment/blob/main/images/jenkins-rbac-promethues.png?raw=true)  


## **Overview**
This project demonstrates a **Blue-Green Deployment Strategy** using **Kubernetes**, **Jenkins CI/CD**, and **AWS EKS**. It includes infrastructure provisioning via **Terraform**, role-based access control (RBAC), and monitoring/alerting with **Prometheus**, **Grafana**, **Loki**, and **Alertmanager**. The pipeline ensures zero-downtime deployments, security scans, and automated traffic switching between environments.

The repository is structured as follows:
- **Cluster Setup**: Terraform scripts for AWS EKS cluster creation are located in the `cluster` directory.
- **Kubernetes Manifests**: Deployment files for MySQL, applications, and services are in the `kubernetes-manifest` directory.
- **Monitoring Stack**: Prometheus exporters (e.g., MySQL Exporter, Blackbox Exporter) are located in the `helm-monitoring-stack/exporters` directory.

---

## **Key Features**
1. **Blue-Green Deployment**: Switch traffic seamlessly between blue and green environments.
2. **CI/CD Automation**: Jenkins pipeline automates build, test, scan, and deployment processes.
3. **Monitoring & Alerts**:
   - Deployed via the **Prometheus Stack Helm Chart**.
   - Includes exporters: Blackbox (HTTP/HTTPS), MySQL Exporter, and Vulnerability Exporter.
   - Alerts configured via Alertmanager and sent via email.
4. **Infrastructure as Code (IaC)**: Terraform provisions the AWS EKS cluster, VPC, subnets, and IAM roles.
5. **Security**:
   - Trivy for container vulnerability scanning.
   - SonarQube for code quality analysis.
   - RBAC for Kubernetes resource access control.

---

## **Prerequisites**
Before setting up the project, ensure you have the following:
1. **AWS Account** with permissions to create EKS clusters and related resources.
2. **Terraform** installed locally or in your CI/CD environment.
3. **Kubectl** configured to interact with the Kubernetes cluster.
4. **Docker Hub** account for pushing Docker images.
5. **Jenkins** server with required plugins (e.g., Docker, Kubernetes, Maven).
6. **Helm** CLI for deploying the Prometheus Stack.

---

## **Setup Instructions**

### **1. Infrastructure Setup**
1. Clone the repository:
   ```bash
   git clone https://github.com/your-repo-url/Blue-Green-Deployment.git
   cd Blue-Green-Deployment
   ```
2. Navigate to the `cluster` directory:
   ```bash
   cd cluster
   ```
3. Initialize Terraform:
   ```bash
   terraform init
   ```
4. Apply the Terraform configuration to create the AWS EKS cluster:
   ```bash
   terraform apply
   ```

### **2. Configure Kubernetes Access**
1. Update your kubeconfig to connect to the EKS cluster:
   ```bash
   aws eks --region us-east-2 update-kubeconfig --name bg-cluster
   ```
2. Verify connectivity:
   ```bash
   kubectl get nodes
   ```

---

### **3. RBAC Setup and Token Creation**
1. Apply the RBAC manifests from the `kubernetes-manifest` directory:
   ```bash
   kubectl apply -f kubernetes-manifest/role.yaml
   kubectl apply -f kubernetes-manifest/RoleBinding.yml
   kubectl apply -f kubernetes-manifest/sa.yaml
   ```
2. Create a non-expiring API token for the `jenkins` ServiceAccount:
   ```yaml
   apiVersion: v1
   kind: Secret
   type: kubernetes.io/service-account-token
   metadata:
     name: jenkins-secret
     namespace: webapps
     annotations:
       kubernetes.io/service-account.name: jenkins
   ```
   Save this as `jenkins-secret.yaml` and apply it:
   ```bash
   kubectl apply -f jenkins-secret.yaml
   ```
3. Retrieve the token:
   ```bash
   kubectl -n webapps describe secret jenkins-secret
   ```

---

### **4. Jenkins Integration**
#### **Register Credentials in Jenkins**
1. **AWS Credentials**:
   - Go to Jenkins → Manage Jenkins → Manage Credentials.
   - Add a new credential of type "AWS Credentials" and provide your AWS Access Key and Secret Key.
2. **Docker Hub Credentials**:
   - Add a new credential of type "Username with Password" for Docker Hub.
3. **SonarQube and Nexus**:
   - For SonarQube, add the server URL and authentication token under "Manage Jenkins → Configure System".
   - For Nexus, configure the repository URL and credentials in the Jenkins Global Tool Configuration.

#### **Integrate SonarQube and Nexus**
1. Install the SonarQube Scanner plugin in Jenkins.
2. Configure the Nexus repository in your `pom.xml` for Maven builds:
   ```xml
   <distributionManagement>
       <repository>
           <id>nexus-releases</id>
           <url>http://nexus-server-url/repository/maven-releases/</url>
       </repository>
   </distributionManagement>
   ```
   - Verify the artifact inside the nexus after cicd completion  
 ![Project Diagram](https://github.com/Ashsatsan/Blue-Green-Deployment/blob/main/images/jenkins-rbac-promethues.png?raw=true)  
---

### **5. Deploy Monitoring Stack**
1. Navigate to the `helm-monitoring-stack/exporters` directory:
   ```bash
   cd helm-monitoring-stack/exporters
   ```
2. Deploy the MySQL Exporter:
   ```bash
   kubectl apply -f mysql-exporter.yml
   ```
3. Deploy the Blackbox Exporter:
   ```bash
   kubectl apply -f bl.yml
   ```
4. Install the Prometheus Stack Helm chart:
   ```bash
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm install prometheus-stack prometheus-community/kube-prometheus-stack
   ```

---

### **6. Monitoring Stack Configuration**
The monitoring stack is deployed using the **Prometheus Stack Helm Chart**. The `prom-values.yaml` file contains custom configurations to ensure Prometheus scrapes metrics from all `ServiceMonitors` in the cluster.

#### **Key Configuration in `prom-values.yaml`**
1. **Service Monitor Scraping**:
   By default, Prometheus only scrapes `ServiceMonitors` created by the Helm chart itself. To allow Prometheus to scrape metrics from all `ServiceMonitors` (e.g., MySQL Exporter, Blackbox Exporter), you need to set the following parameter in `prom-values.yaml`:
   ```yaml
   prometheus:
     prometheusSpec:
       serviceMonitorSelectorNilUsesHelmValues: false
       serviceMonitorSelector: {}
       serviceMonitorNamespaceSelector: {}
   ```
   - **`serviceMonitorSelectorNilUsesHelmValues: false`**: Ensures Prometheus considers all `ServiceMonitors` in the cluster, not just those created by the Helm chart.
   - **`serviceMonitorSelector: {}`**: Allows Prometheus to select all `ServiceMonitors` without filtering.
   - **`serviceMonitorNamespaceSelector: {}`**: Ensures Prometheus scrapes `ServiceMonitors` across all namespaces.

2. **Grafana Integration**:
   Grafana is configured to include Loki as a data source for log aggregation:
   ```yaml
   grafana:
     sidecar:
       datasources:
         defaultDatasourceEnabled: true
     additionalDataSources:
       - name: Loki
         type: loki
         url: http://loki-loki-distributed-query-frontend.monitoring:3100
   ```

#### **Steps to Apply the Configuration**
1. Navigate to the `helm-monitoring-stack/observability-conf` directory:
   ```bash
   cd helm-monitoring-stack/observability-conf
   ```
2. Update the `prom-values.yaml` file with the above configurations.
3. Deploy the Prometheus Stack Helm chart with the custom values:
   ```bash
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm install prometheus-stack prometheus-community/kube-prometheus-stack -f prom-values.yaml
   ```

#### **Why This Matters**
Setting `serviceMonitorSelectorNilUsesHelmValues: false` ensures that Prometheus automatically discovers and scrapes metrics from all `ServiceMonitors` in the cluster. Without this configuration, you would need to manually label each `ServiceMonitor`, which can be error-prone and cumbersome.

---

### **7. Configure Alerts**
1. Define alerts in the `alertmanager-config.yml` file:
   ```yaml
   groups:
   - name: example-alerts
     rules:
     - alert: HighRequestLatency
       expr: job:request_latency_seconds:mean5m{job="mysql"} > 1
       for: 10m
       labels:
         severity: critical
       annotations:
         summary: "High request latency on MySQL"
         description: "MySQL request latency is above 1 second."
   ```
2. Apply the alert configuration:
   ```bash
   kubectl apply -f alertmanager-config.yml
   ```

---

### **8. Execute Kubernetes Resources**
For beginners, here’s how to apply Kubernetes manifests:
1. Navigate to the `kubernetes-manifest` directory:
   ```bash
   cd kubernetes-manifest
   ```
2. Apply all manifests:
   ```bash
   kubectl apply -f .
   ```
3. Verify deployments:
   ```bash
   kubectl get pods,svc,deployments -n webapps
   ```

---

## **Pipeline Workflow**
1. **Git Checkout**: Pulls the latest code from the repository.
2. **Compile & Test**: Builds and tests the application using Maven.
3. **Scanning**:
   - Trivy scans the filesystem and Docker image for vulnerabilities.
   - SonarQube analyzes code quality.
4. **Build & Push**: Packages the application, builds a Docker image, and pushes it to Docker Hub.
5. **Deploy**:
   - Deploys MySQL and application services to Kubernetes.
   - Switches traffic between blue and green environments based on pipeline parameters.
6. **Verify**: Validates the deployment by checking pod status and service endpoints.

---

## **Key Notes**
1. **Trivy Setup**:
   - Install Trivy locally or in your CI/CD environment.
   - Run scans using:
     ```bash
     trivy fs --format table -o fs.html .
     trivy image --format table -o image.html yoabhi/bankapp:blue
     ```
2. **Alerts**:
   - Alerts are triggered for HTTP/HTTPS failures, MySQL performance issues, and security vulnerabilities.
   - Notifications are sent via email using Alertmanager.
   - After intigrating trivy with the alert manager and the prometheus it will work like the following images:

a. Firstly after prometheus will start scraping exporter inside the alert section we will be able to alerts that we configured to target

  ![Image alt](https://github.com/Ashsatsan/Blue-Green-Deployment/blob/main/images/alert-3.png?raw=true)  

b.Once trivy exporter experience any issue with its metrics it will start triggering the alert

  ![Image alt](https://github.com/Ashsatsan/Blue-Green-Deployment/blob/main/images/alert-2.png?raw=true) 

c.After 2 mins or around it will shoot a alert trigger via provided handles 

  ![Image alt](https://github.com/Ashsatsan/Blue-Green-Deployment/blob/main/images/alert-1.png?raw=true) 

d. Similarly we have also set the alerts to the database using mysql exporter and blackbox exporter for the actively probing external endpoints 
  
  ![Image alt](https://github.com/Ashsatsan/Blue-Green-Deployment/blob/main/images/alert-4.png?raw=true) 

  
---

## Results to verify

1. Before executing the pipeline verify if the blue and green version choosing option appear on the jenkins console before apply build

     ![Image alt](https://github.com/Ashsatsan/Blue-Green-Deployment/blob/main/images/blue5.png?raw=true)
     
2. After pipeline success check if the sonarqube scanning the code correctly, if caught any issue check jenkins console log and also verify if the sonarqube integration and credentails also the tools resources are managed properly

     ![Image alt](https://github.com/Ashsatsan/Blue-Green-Deployment/blob/main/images/blue3.png?raw=true)
    
     ![Image alt](https://github.com/Ashsatsan/Blue-Green-Deployment/blob/main/images/blue2.png?raw=true)

3. Also verify the artifact appeared in the nexus repository or not

    ![Image alt](https://github.com/Ashsatsan/Blue-Green-Deployment/blob/main/images/nexus%20rep.png?raw=true)   

4. Lastly, after successfully running one version for example blue try to run the app green version too . During execution the pipeline will switch the traffic and it will be observed in build process.
   Note that: in the given image we can see that its indicated failed but in contrary its just a lag and the code is also bit outdated.So if you caught and then dont worry pipeline got successfully run 
 
   ![Image alt](https://github.com/Ashsatsan/Blue-Green-Deployment/blob/main/images/blue4.png?raw=true)      

---

## **Resources**
- **Manifest Files**:
  - RBAC configurations (`role.yaml`, `RoleBinding.yml`, `sa.yaml`).
  - MySQL and application deployments (`mysql-ds.yml`, `app-deployment-blue.yml`, `app-deployment-green.yml`).
  - Service definitions (`bankapp-service.yml`).
- **Terraform Files**:
  - VPC, subnets, EKS cluster, and node group (`main.tf`, `variables.tf`, `output.tf`).
- **Jenkins Pipeline**:
  - Complete CI/CD pipeline script (`Jenkinsfile`).

---

## **Contributing**
Contributions are welcome! Please open an issue or submit a pull request for any improvements or bug fixes.

---


