# **Blue-Green Deployment on Kubernetes with CI/CD Pipeline**

![Project Diagram](./path-to-your-diagram.png)  
*(Replace `path-to-your-diagram.png` with the actual path to your attached project stack diagram.)*

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

### **6. Configure Alerts**
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

### **7. Execute Kubernetes Resources**
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
