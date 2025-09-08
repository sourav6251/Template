pipeline {
    agent any

    // options {
    //     skipDefaultCheckout(true) // avoids duplicate checkout
    // }
    // triggers { }
    // environment { }

    // // run only on main branch
    // when {
    //     branch 'main'
    // }


    stages {

        stage("Checkout") {
            when { branch 'main' }
            steps {
                echo "======== Executing Checkout ========"
                checkout scm
            }
        }

        stage("Validate server") {
            steps {
                echo "==== Executing Validate Server ===="
                dir('server') {
                    sh 'mvn validate'
                }
            }
            post {
                failure {
                    echo "==== Validate Server execution failed ===="
                }
            }
        }

        stage("Compile server") {
            steps {
                echo "==== Executing Compile Server ===="
                dir('server') {
                    sh 'mvn clean compile'
                }
            }
            post {
                failure {
                    echo "==== Compile Server execution failed ===="
                }
            }
        }

        stage("Verify server") {
            steps {
                echo "==== Executing Verify Server ===="
                dir('server') {
                    withCredentials([
                        string(credentialsId: 'db-username', variable: 'DB_USERNAME'),
                        string(credentialsId: 'db-password', variable: 'DB_PASSWORD'),
                        string(credentialsId: 'db-url', variable: 'DB_URL'),
                        string(credentialsId: 'clerk-secret', variable: 'WEBHOOK_SECRET')
                    ]) {
                        sh '''
                            echo "DB User = $DB_USERNAME"
                            echo "DB URL = $DB_URL"

                            # Run tests and generate Jacoco report
                            mvn clean verify \
                                -Dspring.datasource.url="$DB_URL" \
                                -Dspring.datasource.username="$DB_USERNAME" \
                                -Dspring.datasource.password="$DB_PASSWORD" \
                                -Dclerk.webhook.secret="$WEBHOOK_SECRET" \
                                jacoco:report

                            # Create per-build Jacoco report folder
                            mkdir -p target/site/jacoco-${BUILD_NUMBER}

                            # Safely copy Jacoco files
                            if [ -d target/site/jacoco ]; then
                                cp -r target/site/jacoco/. target/site/jacoco-${BUILD_NUMBER}/
                            fi
                        '''
                    }
                }
            }
            post {
                always {
                    publishHTML([
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: "server/target/site/jacoco-${BUILD_NUMBER}",
                        reportFiles: 'index.html',
                        reportName: "Jacoco Coverage Report #${BUILD_NUMBER}"
                    ])
                }
                success {
                    echo "==== Server Verify Successfully ===="
                }
                failure {
                    echo "==== Server Verify Failed ===="
                }
            }

        }



        stage("Build server") {
            steps {
                echo "==== Executing Build Server ===="
                dir('server') {
                    sh 'mvn clean package -DskipTests'
                }
            }
            post {
                always {
                    echo "==== Always after Build Server ===="
                }
                success {
                    echo "==== Server Build Successfully ===="
                }
                failure {
                    echo "==== Server Build Failed ===="
                }
            }
        }

        stage("Build server image") {
            steps {
                echo "==== Executing Build Server Image ===="
                dir('server') {
                    sh "docker build -t souravkd23/todo-server:${BUILD_NUMBER} ."
                }
            }
            post {
                success {
                    echo "==== Build Server Image executed successfully ===="
                }
                failure {
                    echo "==== Build Server Image execution failed ===="
                }
            }
        }

        stage("Push Image") {
            steps {
                echo "==== Executing Push Image ===="
                dir('server') {
                    withCredentials([
                        usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')
                    ]) {
                        sh '''
                            echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                            docker push souravkd23/todo-server:${BUILD_NUMBER}
                            docker rmi souravkd23/todo-server:${BUILD_NUMBER}
                        '''
                    }
                }
            }
            post {
                always {
                    echo "==== Always after Push Image ===="
                }
                success {
                    echo "==== Push Image executed successfully ===="
                }
                failure {
                    echo "==== Push Image execution failed ===="
                }
            }
        }

        stage("Deploy to Server") {
            steps {
                echo "==== Executing Deployment ===="
                withCredentials([
                    sshUserPrivateKey(credentialsId: 'server-ssh-key', keyFileVariable: 'SSH_KEY'),
                    string(credentialsId: 'db-username', variable: 'DB_USERNAME'),
                    string(credentialsId: 'db-password', variable: 'DB_PASSWORD'),
                    string(credentialsId: 'db-url', variable: 'DB_URL'),
                    string(credentialsId: 'clerk-secret', variable: 'WEBHOOK_SECRET'),
                    usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')
                ]) {
                    sh '''
                        # Copy docker-compose.yml to server
                        scp -i $SSH_KEY -o StrictHostKeyChecking=no docker-compose.yml user@34.67.188.124:/home/dassourav3738/todo

                        # SSH into server and deploy
                        ssh -i $SSH_KEY -o StrictHostKeyChecking=no user@34.67.188.124 << EOF
                            cd /home/dassourav3738/todo

                            echo "DB_USERNAME=$DB_USERNAME" > .env
                            echo "DB_PASSWORD=$DB_PASSWORD" >> .env
                            echo "DB_URL=$DB_URL" >> .env
                            echo "WEBHOOK_SECRET=$WEBHOOK_SECRET" >> .env

                            # Authenticate to Docker Hub
                            echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin

                            docker-compose pull
                            docker-compose up -d

                            rm -f .env docker-compose.yml
                        EOF
                    '''
                }
            }
            post {
                success {
                    echo "==== Deployment executed successfully ===="
                }
                failure {
                    echo "==== Deployment failed ===="
                }
            }
        }

    }

    post {
        always {
            echo "======== Always after Pipeline ========"
        }
        success {
            echo "======== Pipeline executed successfully ========"
        }
        failure {
            echo "======== Pipeline execution failed ========"
        }
    }
}


