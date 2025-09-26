pipeline {
    agent {
        kubernetes {
            label 'kaniko'
        }
    }

    environment {
        DOCKER_REGISTRY = 'docker.io'
        DOCKER_USERNAME = 'rcanonigo'
        APP_NAME = 'todo-webapp-observability'
        NAMESPACE = 'todo-app'
        MONITORING_NAMESPACE = 'monitoring'
        DEPLOYMENT_NAME = 'todoapp' 
    }

    stages {
        stage('Set Image Tag') {
            steps {
                script {
                    // FIX: Handle missing GIT_COMMIT when running outside of SCM context
                    if (env.GIT_COMMIT == null) {
                        env.GIT_COMMIT = "NOCOMMIT" 
                    }
                    env.IMAGE_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT.substring(0, 7)}"
                }
            }
        }

        stage('Checkout Code') {
            steps {
                // ✅ FINAL FIX: Using the ID for the "Username with password" credential
                // This correctly passes your GitHub username (as username) and the PAT (as password).
                checkout([
                    $class: 'GitSCM', 
                    branches: [[name: '*/main']], 
                    doGenerateSubmoduleConfigurations: false, 
                    extensions: [], 
                    userRemoteConfigs: [[credentialsId: 'github-pat-auth', url: 'https://github.com/opswerks-academy/i9b-observability.git']]
                ])
            }
        }
        
        stage('Build and Push Image') { 
            steps {
                // FIX: Explicitly use the 'kaniko' container
                container('kaniko') {
                    sh """
                        /kaniko/executor \\
                          --dockerfile=Dockerfile \\
                          --context=. \\
                          --destination=${DOCKER_REGISTRY}/${DOCKER_USERNAME}/${APP_NAME}:${IMAGE_TAG} \\
                          --destination=${DOCKER_REGISTRY}/${DOCKER_USERNAME}/${APP_NAME}:latest \\
                          --cache=true \\
                          --cache-repo=${DOCKER_REGISTRY}/${DOCKER_USERNAME}/cache
                    """
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                // FIX: Explicitly use the 'kubectl' container
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

                        // Wait for rollout to finish before prompting for manual input
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
            // FIX: Explicitly use the 'kubectl' container
            container('kubectl') {
                sh "kubectl rollout undo deployment/${DEPLOYMENT_NAME} -n ${NAMESPACE}"
            }
        }
        success {
            echo "Deployment successful and passed manual review period."
        }
    }
}
