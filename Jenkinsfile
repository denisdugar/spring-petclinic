pipeline{
  agent any
  stages{
    stage("Build app in docker") {
      steps{
        withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: 'aws-key', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY']]) {
            sh 'export MY_MYSQL_URL=${docker run --env AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID --env AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY amazon/aws-cli aws rds describe-db-instances --query 'DBInstances[*].Endpoint.Address'}  \
                echo MY_MYSQL_URL'
        }
      }
    }
  }
}
