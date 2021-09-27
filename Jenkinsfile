pipeline {
    agent any
    tools {
        terraform 'terraform' 
    }
    stages {
        stage ('Build') {
            steps {
                docker build -t my_project .
            }
        }
    }
}
