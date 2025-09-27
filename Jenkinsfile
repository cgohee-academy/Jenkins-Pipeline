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
                script {
                    try {
                        timeout(time: 10, unit: 'MINUTES') {
                            input(
                                id: 'manual-veto-check',
                                message: 'Deployment complete. Do you see any unexpected errors or failures? Abort to rollback.',
                                ok: 'Proceed'
                            )
                        }
                        // This part is reached ONLY if a user clicks "Proceed".
                        echo "Manual check passed. Deployment is considered successful."
    
                    } catch (err) {
                        if (err instanceof org.jenkinsci.plugins.workflow.steps.FlowInterruptedException) {
                            echo "User explicitly requested a rollback. Proceeding to Rollback Stage."
                            currentBuild.result = 'FAILURE'
                            throw err
                        } else {
                            echo "10-minute timeout reached. Assuming the app is WORKING."
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
