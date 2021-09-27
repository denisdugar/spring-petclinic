pipeline{
  agent any
  stages{
    stage("Get db address") {
      steps{
        withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: 'aws-key', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY']]) {
            sh "echo \$(docker run --env AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID --env AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY amazon/aws-cli rds describe-db-instances --region eu-central-1 --query DBInstances[*].Endpoint.Address) > text.txt"
            sh """echo "MY_MYSQL_URL=\$(cut -d '"' -f 2 text.txt)" >> /etc/environment"""
        }
      }
    }
    stage("Build app"){
      steps{
       withMaven {
         sh "./mvnw package"
        }
      }
    }
  }
}
