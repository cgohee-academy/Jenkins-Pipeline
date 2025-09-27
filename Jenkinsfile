pipeline {
    agent {
        kubernetes {
            label 'kaniko'
        }
    }

    environment {
        // Docker registry settings
        DOCKER_REGISTRY = 'docker.io'
        DOCKER_USERNAME = 'rcanonigo'
        APP_NAME = 'todo-webapp-observability'
        
        // Kubernetes deployment settings
        NAMESPACE = 'todo-app'
        MONITORING_NAMESPACE = 'monitoring'
        DEPLOYMENT_NAME = 'todoapp' 
    }

    stages {
        stage('Checkout Application Code') {
            steps {
                script {
                    // FIX: Using sh 'git clone' to guarantee the application code is in the workspace root.
                    withCredentials([string(credentialsId: 'github-pat-auth', variable: 'GITHUB_TOKEN')]) {
                        sh """
                            # Clone into a temporary directory using the GITHUB_TOKEN for authentication.
                            # The token is correctly double-escaped (\\$) for Groovy.
                            git clone https://\\$GITHUB_TOKEN@github.com/opswerks-academy/i9b-observability.git app_temp
                            
                            # Move all contents from the cloned repo to the root of the workspace
                            mv app_temp/* .
                            mv app_temp/.git .
                            rm -rf app_temp
                        """
                    }

                    // Set the image tag using the application code's commit hash.
                    if (env.GIT_COMMIT == null) {
                        env.GIT_COMMIT = sh(returnStdout: true, script: 'git rev-parse HEAD').trim() 
                    }
                    env.IMAGE_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT.substring(0, 7)}"
                    echo "Building image with tag: ${env.IMAGE_TAG}"
                }
            }
        }
        
        stage('Build and Push Image') { 
            steps {
                container('kaniko') {
                    // FIX: Using triple quotes (sh """), and patching the Dockerfile with sed
                    sh """
                        # --- PATCH DOCKERFILE FOR 'LABEL' ERROR ---
                        # Safely remove any line that contains ONLY 'LABEL' (and optional surrounding whitespace).
                        sed -i '/^\\s*LABEL\\s*$/d' Dockerfile

                        # Run Kaniko executor command
                        /kaniko/executor --dockerfile=Dockerfile --context=. --destination=${DOCKER_REGISTRY}/${DOCKER_USERNAME}/${APP_NAME}:${IMAGE_TAG} --destination=${DOCKER_REGISTRY}/${DOCKER_USERNAME}/${APP_NAME}:latest --cache=true --cache-repo=${DOCKER_REGISTRY}/${DOCKER_USERNAME}/cache
                    """
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                container('kubectl') {
                    sh """
                        # 1. Inject built image with tag into deployment before applying
                        sed -i "s|image: todoapp:latest|image: ${DOCKER_REGISTRY}/${DOCKER_USERNAME}/${APP_NAME}:${IMAGE_TAG}|g" k8s/todoapp-deployment.yaml

                        # 2. Apply all manifests
                        kubectl apply -f k8s/todoapp-alerts.yaml -n ${MONITORING_NAMESPACE}
                        kubectl apply -f k8s/mysql-secret.yaml -n ${NAMESPACE}
                        kubectl apply -f k8s/mysql-service.yaml -n ${NAMESPACE}
                        kubectl apply -f k8s/mysql-statefulset.yaml -n ${NAMESPACE}
                        kubectl apply -f k8s/todoapp-deployment.yaml -n ${NAMESPACE}
                        kubectl apply -f k8s/todoapp-secret.yaml -n ${NAMESPACE}
                        kubectl apply -f k8s/todoapp-service.yaml -n ${NAMESPACE}
                        kubectl apply -f k8s/todoapp-servicemonitor.yaml -n ${NAMESPACE}

                        echo "Waiting for deployment rollout to complete before proceeding to manual check..."
