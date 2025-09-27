pipeline {
  agent {
    kubernetes {
      // Inline Pod YAML so the 'kaniko' and 'kubectl' containers actually exist in the pod
      yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    jenkins: kaniko-pod
spec:
  containers:
  - name: kaniko
    image: gcr.io/kaniko-project/executor:latest
    command:
    - cat
    tty: true
    volumeMounts:
    - name: kaniko-docker-config
      mountPath: /kaniko/.docker
  - name: kubectl
    image: bitnami/kubectl:1.27
    command:
    - cat
    tty: true
  volumes:
  - name: kaniko-docker-config
    secret:
      # Replace 'regcred' with your k8s secret name that contains .dockerconfigjson
      secretName: regcred
"""
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
    stage('Checkout Application Code') {
      steps {
        script {
          checkout([
            $class: 'GitSCM',
            branches: [[name: '*/main']],
            doGenerateSubmoduleConfigurations: false,
            extensions: [],
            userRemoteConfigs: [[credentialsId: 'github-pat-auth', url: 'https://github.com/opswerks-academy/i9b-observability.git']]
          ])

          if (!env.GIT_COMMIT) {
            env.GIT_COMMIT = sh(returnStdout: true, script: 'git rev-parse HEAD').trim()
          }
          env.IMAGE_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT.substring(0,7)}"
          echo "Building image with tag: ${env.IMAGE_TAG}"
        }
      }
    }

    stage('Build and Push Image') {
      steps {
        container('kaniko') {
          // No leading space; using WORKSPACE so kaniko context resolves correctly
          sh "/kaniko/executor --dockerfile=Dockerfile --context=${WORKSPACE} --destination=${DOCKER_REGISTRY}/${DOCKER_USERNAME}/${APP_NAME}:${IMAGE_TAG} --destination=${DOCKER_REGISTRY}/${DOCKER_USERNAME}/${APP_NAME}:latest --cache=true --cache-repo=${DOCKER_REGISTRY}/${DOCKER_USERNAME}/cache --verbosity=info"
        }
      }
    }

    stage('Deploy to Kubernetes') {
      steps {
        container('kubectl') {
          sh """
            # ensure namespaces exist
            kubectl create namespace ${MONITORING_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
            kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

            # Replace image line robustly (tolerant of spaces)
            sed -E -i "s|image:[[:space:]]*todoapp:latest|image: ${DOCKER_REGISTRY}/${DOCKER_USERNAME}/${APP_NAME}:${IMAGE_TAG}|g" k8s/todoapp-deployment.yaml || true

            # Apply manifests
            kubectl apply -f k8s/todoapp-alerts.yaml -n ${MONITORING_NAMESPACE}
            kubectl apply -f k8s/mysql-secret.yaml -n ${NAMESPACE}
            kubectl apply -f k8s/mysql-service.yaml -n ${NAMESPACE}
            kubectl apply -f k8s/mysql-statefulset.yaml -n ${NAMESPACE}
            kubectl apply -f k8s/todoapp-deployment.yaml -n ${NAMESPACE}
            kubectl apply -f k8s/todoapp-secret.yaml -n ${NAMESPACE}
            kubectl apply -f k8s/todoapp-service.yaml -n ${NAMESPACE}
            kubectl apply -f k8s/todoapp-servicemonitor.yaml -n ${NAMESPACE}

            echo "Waiting for deployment rollout..."
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
              def result = input(
                id: 'manual-veto-check',
                message: 'Deployment complete. Do you see any unexpected errors or failures? Rollback if necessary.',
                submitter: 'rcanonigo,@some-dev-team',
                parameters: [
                  choice(name: 'action', choices: ['PROCEED_SUCCESS', 'REVERT_ROLLBACK'], description: 'Choose action.')
                ]
              )

              echo "Manual action chosen: ${result['action']}"

              if (result['action'] == 'REVERT_ROLLBACK') {
                echo "User requested rollback — performing rollback now."
                container('kubectl') {
                  sh "kubectl rollout undo deployment/${DEPLOYMENT_NAME} -n ${NAMESPACE}"
                }
                currentBuild.result = 'FAILURE'
                error("Rollback triggered by manual veto.")
              } else {
                echo "Proceeding after manual check."
              }

            } catch (err) {
              // differentiate timeout vs abort
              if (err.getMessage() != null && err.getMessage().contains('Timeout')) {
                echo "10-minute timeout reached. Assuming the app is working and proceeding."
              } else {
                echo "Manual approval aborted or other error: ${err}"
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
      echo 'Deployment failed or vetoed. Initiating automatic rollback.'
      container('kubectl') {
        sh "kubectl rollout undo deployment/${DEPLOYMENT_NAME} -n ${NAMESPACE} || true"
      }
    }
    success {
      echo "Deployment successful and passed manual review period."
    }
  }
}
