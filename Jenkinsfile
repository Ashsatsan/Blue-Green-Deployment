pipeline {
    agent any

    parameters {
        choice(name: 'DEPLOY_ENV', choices: ['blue', 'green'], description: 'Choose which environment to deploy: Blue or Green')
        choice(name: 'DOCKER_TAG', choices: ['blue', 'green'], description: 'Choose the Docker image tag for the deployment')
        booleanParam(name: 'SWITCH_TRAFFIC', defaultValue: false, description: 'Switch traffic between Blue and Green')
    }

    tools {
        maven 'maven3'
    }

    environment {
        IMAGE_NAME = "yoabhi/bankapp"
        TAG = "${params.DOCKER_TAG}"
        SCANNER_HOME = tool 'sonar-scanner'
        KUBE_NAMESPACE = 'webapps'
    }

    stages {
        stage('Git Checkout') {
            steps {
                git branch: 'main', credentialsId: 'github-token', url: 'https://github.com/Ashsatsan/Blue-Green-Deployment.git'
            }
        }

        stage('Compile') {
            steps {
                sh 'mvn compile'
            }
        }

        stage('Run Tests') {
            steps {
                sh 'mvn test -DskipTests=true'
            }
        }

        stage('Trivy FS Scan') {
            steps {
                sh 'trivy fs --format table -o fs.html .'
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('sonarserver') {
                    sh '''
                        $SCANNER_HOME/bin/sonar-scanner \
                        -Dsonar.projectKey=Multitier \
                        -Dsonar.projectName=Multitier \
                        -Dsonar.java.binaries=target
                    '''
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 1, unit: 'HOURS') {
                    waitForQualityGate abortPipeline: false
                }
            }
        }

        stage('Build') {
            steps {
                sh 'mvn package -DskipTests=true'
            }
        }

        stage('Deploy to Nexus') {
            steps {
                withMaven(globalMavenSettingsConfig: 'maven-settings', maven: 'maven3', traceability: true) {
                    sh 'mvn deploy -DskipTests=true'
                }
            }
        }

        stage('Docker Build and Push') {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'docker-hub') {
                        sh 'docker build -t ${IMAGE_NAME}:${TAG} .'
                        sh 'docker push ${IMAGE_NAME}:${TAG}'
                    }
                }
            }
        }

        stage('Trivy Image Scan') {
            steps {
                sh "trivy image --format table -o image.html ${IMAGE_NAME}:${TAG}"
            }
        }

        stage('Deploy MySQL Deployment and Service') {
            steps {
                script {
                    withKubeConfig(
                        credentialsId: 'kube-token', 
                        namespace: KUBE_NAMESPACE, 
                        serverUrl: 'https://488BC04CED1644F3B52456533BB834D8.gr7.us-east-2.eks.amazonaws.com'
                    ) {
                        sh "kubectl apply -f mysql-ds.yml -n ${KUBE_NAMESPACE} --validate=false"
                    }
                }
            }
        }

        stage('Deploy Application Service') {
            steps {
                script {
                    withKubeConfig(
                        credentialsId: 'kube-token', 
                        namespace: KUBE_NAMESPACE, 
                        serverUrl: 'https://488BC04CED1644F3B52456533BB834D8.gr7.us-east-2.eks.amazonaws.com'
                    ) {
                        sh '''
                            if ! kubectl get svc bankapp-service -n ${KUBE_NAMESPACE}; then
                                kubectl apply -f bankapp-service.yml -n ${KUBE_NAMESPACE}
                            fi
                        '''
                    }
                }
            }
        }

        stage('Deploy Application') {
            steps {
                script {
                    def deploymentFile = params.DEPLOY_ENV == 'blue' ? 'app-deployment-blue.yml' : 'app-deployment-green.yml'

                    withKubeConfig(
                        credentialsId: 'kube-token', 
                        namespace: KUBE_NAMESPACE, 
                        serverUrl: 'https://488BC04CED1644F3B52456533BB834D8.gr7.us-east-2.eks.amazonaws.com'
                    ) {
                        sh "kubectl apply -f ${deploymentFile} -n ${KUBE_NAMESPACE}"
                    }
                }
            }
        }

        stage('Switch Traffic Between Environments') {
            when {
                expression { params.SWITCH_TRAFFIC }
            }
            steps {
                script {
                    def newEnv = params.DEPLOY_ENV

                    withKubeConfig(
                        credentialsId: 'kube-token', 
                        namespace: KUBE_NAMESPACE, 
                        serverUrl: 'https://488BC04CED1644F3B52456533BB834D8.gr7.us-east-2.eks.amazonaws.com'
                    ) {
                        sh '''
                            kubectl patch service bankapp-service \
                            -p "{\\"spec\\": {\\"selector\\": {\\"app\\": \\"bankapp\\", \\"version\\": \\"''' + newEnv + '''\\"}}}" \
                            -n ${KUBE_NAMESPACE}
                        '''
                    }
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                script {
                    def verifyEnv = params.DEPLOY_ENV

                    withKubeConfig(
                        credentialsId: 'kube-token', 
                        namespace: KUBE_NAMESPACE, 
                        serverUrl: 'https://488BC04CED1644F3B52456533BB834D8.gr7.us-east-2.eks.amazonaws.com'
                    ) {
                        sh '''
                            kubectl get pods -l version=${verifyEnv} -n ${KUBE_NAMESPACE}
                            kubectl get svc bankapp-service -n ${KUBE_NAMESPACE}
                        '''
                    }
                }
            }
        }
    }
}
