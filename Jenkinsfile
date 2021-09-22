pipeline {
    agent any
    tools {
        terraform 'terraform' 
    }
    stages {
        stage ('Build') {
            steps {
                sh 'ls'
                sh 'pwd'
                sh 'cd jenkins_terraform'
                sh 'ls'
                sh 'terraform init -chdir=jenkins_terraform'
                sh 'terraform plan'
                sh 'terraform apply -auto-approve'
                sh 'sleep 25m'
                sh 'terraform destroy -auto-approve'
            }
        }
    }
}
