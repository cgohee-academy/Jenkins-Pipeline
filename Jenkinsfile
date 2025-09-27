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
            agent {
                label 'none' 
            }
            
            steps {
                script {
                    try {
                        // The pipeline will wait here for 10 minutes.
                        // If the user clicks 'Proceed', execution continues below the 'timeout'.
                        // If the user clicks 'Abort' (the default abort button), an exception is thrown.
                        // If the 10-minute timeout is reached, an exception is thrown.
                        timeout(time: 10, unit: 'MINUTES') {
                            input(
                                id: 'manual-veto-check',
                                message: 'Deployment complete. Do you see any unexpected errors or failures? Abort to rollback.',
                                ok: 'Proceed' // This is the 'Proceed' button
                            )
                        }
                        // This part is reached ONLY if a user clicks "Proceed" BEFORE the timeout.
                        echo "Manual check passed. Deployment is considered successful."
        
                    } catch (err) {
                        // This catch block handles:
                        // 1. User clicking 'Abort' (FlowInterruptedException)
                        // 2. The 10-minute timeout (FlowInterruptedException)
        
                        if (err instanceof org.jenkinsci.plugins.workflow.steps.FlowInterruptedException) {
                            // Check if the interruption was NOT caused by the timeout, implying a user abort.
                            if (err.causes.find { it instanceof org.jenkinsci.plugins.workflow.steps.TimeoutStepExecution.ExceededTimeout }) {
                                // **TIMEOUT REACHED:** The error was the timeout. Treat this as a successful "soft proceed".
                                echo "10-minute timeout reached. Assuming the app is WORKING and proceeding."
        
                            } else {
                                // **USER ABORTED:** The error was an explicit user abort.
                                echo "User explicitly requested a rollback. Proceeding to Rollback Stage."
                                currentBuild.result = 'FAILURE'
                                throw err // Re-throw to cause the failure block to execute
                            }
                        } else {
                            // Other unexpected exception
                            throw err
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
