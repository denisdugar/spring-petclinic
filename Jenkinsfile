pipeline {
    agent any
    stages {
        stage ('Build') {
            steps {
                sh 'cd jenkins_terraform'
                sh 'terraform init'
                sh 'terraform plan'
                sh 'terraform apply -auto-approve'
                sh 'sleep 25m'
                sh 'terraform destroy -auto-approve'
            }
        }
    }
}
