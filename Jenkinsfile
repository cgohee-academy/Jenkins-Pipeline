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
    }

    stages {
        stage('Set Image Tag') {
            steps {
                script {
                    env.IMAGE_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT.substring(0, 7)}"
                }
            }
        }
        stage('Build Image') {
            steps {
                container('kaniko') {
                    sh """
                        /kaniko/executor \
                          --dockerfile=Dockerfile \
                          --context=. \
                          --destination=${DOCKER_REGISTRY}/${DOCKER_USERNAME}/${APP_NAME}:${IMAGE_TAG} \
                          --destination=${DOCKER_REGISTRY}/${DOCKER_USERNAME}/${APP_NAME}:latest \
                          --cache=true \
                          --cache-repo=${DOCKER_REGISTRY}/${DOCKER_USERNAME}/cache
                    """
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                container('kubectl') {
                    sh """
                        # Inject built image with tag into deployment before applying
                        sed -i "s|image: todoapp:latest|image: ${DOCKER_REGISTRY}/${DOCKER_USERNAME}/${APP_NAME}:${IMAGE_TAG}|g" k8s/todoapp-deployment.yaml

                        # Apply all manifests in the k8s directory
                        kubectl apply -f k8s/mysql-secret.yaml -n ${NAMESPACE}
                        kubectl apply -f k8s/mysql-service.yaml -n ${NAMESPACE}
                        kubectl apply -f k8s/mysql-statefulset.yaml -n ${NAMESPACE}
                        kubectl apply -f k8s/todoapp-deployment.yaml -n ${NAMESPACE}
                        kubectl apply -f k8s/todoapp-secret.yaml -n ${NAMESPACE}
                        kubectl apply -f k8s/todoapp-service.yaml -n ${NAMESPACE}
                        kubectl apply -f k8s/todoapp-servicemonitor.yaml -n ${NAMESPACE}

                        # Wait for rollout to finish
                        kubectl rollout status deployment/todoapp -n ${NAMESPACE}
                    """
                }
            }
        }
    }
}