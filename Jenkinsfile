pipeline{
  agent any
  stages{
    stage("Build app in docker") {
      steps{
        withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: 'aws-key', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY']]) {
            sh "echo \$(sudo docker run --env AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID --env AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY amazon/aws-cli rds describe-db-instances --region eu-central-1 --query DBInstances[*].Endpoint.Address) > text.txt"
            sh "cat text.txt"
        }
      }
    }
  }
}
