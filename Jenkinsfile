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
        stage('Build') {
            steps {
                echo 'Building the application...'
            }
        }

        stage('Approval') {
            steps {
                script {
                    // Prompt the user to proceed or abort
                    def userInput = input(
                        id: 'ApprovalPrompt',       // unique ID for resuming
                        message: 'Deploy to production?',
                        ok: 'Proceed',
                        parameters: [
                            choice(
                                name: 'ACTION',
                                choices: ['Proceed', 'Abort'],
                                description: 'Choose what to do next.'
                            )
                        ]
                    )

                    // Save the choice into an environment variable
                    env.USER_CHOICE = userInput
                }
            }
        }

        stage('Deploy') {
            when {
                expression { env.USER_CHOICE == 'Proceed' }
            }
            steps {
                echo 'Deploying to production...'
            }
        }

        stage('Abort Notice') {
            when {
                expression { env.USER_CHOICE == 'Abort' }
            }
            steps {
                echo 'Deployment was aborted by user.'
            }
        }
    }
}
