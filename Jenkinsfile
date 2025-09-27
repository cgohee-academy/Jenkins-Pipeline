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

        stage('Manual Veto Check') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    script {
                        try {
                            input(
                                id: 'manual-veto-check',
                                message: 'Deployment complete. Do you see any unexpected errors or failures? Rollback if necessary.',
                                submitter: 'rcanonigo, @some-dev-team', 
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
