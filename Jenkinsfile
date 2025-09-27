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
                    // FIX APPLIED: Git token is now properly double-escaped (\\$) inside the triple-quote block
                    withCredentials([string(credentialsId: 'github-pat-auth', variable: 'GITHUB_TOKEN')]) {
                        sh """
                            # Clone into a temporary directory using the GITHUB_TOKEN for authentication
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
                        kubectl rollout status deployment/${DEPLOYMENT_NAME} -n ${NAMESPACE}
                    """
                }
            }
        }

        stage('Manual Veto Check') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    script {
                        try {
                            input(
                                id: 'manual-veto-check',
                                message: 'Deployment complete. Do you see any unexpected errors or failures? Rollback if necessary.',
                                submitter: 'rcanonigo, @some-dev-team', 
                                parameters: [
                                    choice(name: 'action', choices: ['PROCEED_SUCCESS', 'REVERT_ROLLBACK'], description: 'Choose action.')
                                ]
                            )
                        } catch (err) {
                            if (currentBuild.result == 'TIMEOUT') {
                                echo "10-minute timeout reached. Assuming the app is WORKING."
                            } else {
                                echo "User explicitly requested a rollback. Proceeding to Rollback Stage."
                                currentBuild.result = 'FAILURE'
                                throw err 
                            }
                        }
                    }
                }
            }
        }
    }
    
    post {
        failure {
            echo 'Deployment failed (User Veto). Initiating automatic rollback.'
            container('kubectl') {
                sh "kubectl rollout undo deployment/${DEPLOYMENT_NAME} -n ${NAMESPACE}"
            }
        }
        success {
            echo "Deployment successful and passed manual review period."
        }
    }
}
