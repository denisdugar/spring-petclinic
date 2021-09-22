pipeline {
    agent any
    tools {
        terraform 'terraform' 
    }
    stages {
        stage ('Build') {
            steps {
                withAWS(credentials: 'aws_creds'){
                sh "cd jenkins_terraform; \
                terraform init; \
                terraform plan; \
                terraform apply -auto-approve; \
                sleep 25m; \
                terraform destroy -auto-approve"
               }
            }
        }
    }
}
