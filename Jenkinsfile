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
            // The pod is already running due to the global agent { kubernetes { label 'kaniko' } }
            steps {
                script {
                    // --- 1. START A BACKGROUND SLEEP PROCESS ---
                    // This process runs in the background for 11 minutes, 
                    // telling the agent it's still busy.
                    def p = sh(script: 'nohup sleep 660 &', returnStatus: true) // 660 seconds = 11 minutes
                    
                    try {
                        // --- 2. RUN THE TIMEOUT/INPUT CHECK ---
                        timeout(time: 10, unit: 'MINUTES') {
                            input(
                                id: 'manual-veto-check',
                                message: 'Deployment complete. Do you see any unexpected errors or failures? Abort to rollback.',
                                ok: 'Proceed'
                            )
                        }
                        echo "Manual check passed. Deployment is considered successful."
        
                    } catch (err) {
                        // --- 3. HANDLE ABORT/TIMEOUT LOGIC ---
                        if (err instanceof org.jenkinsci.plugins.workflow.steps.FlowInterruptedException) {
                            if (err.causes.find { it instanceof org.jenkinsci.plugins.workflow.steps.TimeoutStepExecution.ExceededTimeout }) {
                                echo "10-minute timeout reached. Assuming the app is WORKING and proceeding."
                            } else {
                                echo "User explicitly requested a rollback. Proceeding to Rollback Stage."
                                currentBuild.result = 'FAILURE'
                                throw err
                            }
                        } else {
                            throw err
                        }
        
                    } finally {
                        // --- 4. KILL THE BACKGROUND PROCESS (OPTIONAL BUT CLEAN) ---
                        // The process will eventually terminate anyway, but this is cleaner.
                        sh(script: 'pkill sleep || true', returnStatus: true) 
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
