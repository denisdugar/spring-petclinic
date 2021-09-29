pipeline{
  agent any
  tools {
    maven "maven"
  }
  stages{
    stage("Get db address") {
      steps{
        withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: 'aws-key', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY']]) {
            sh "echo \$(docker run --env AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID --env AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY amazon/aws-cli rds describe-db-instances --region eu-west-1 --query DBInstances[*].Endpoint.Address) > text.txt"
            sh "pwd"
            sh """export  MY_MYSQL_URL=\$(cut -d '"' -f 2 text.txt);  \
                  sed -i "s/localhost/\$MY_MYSQL_URL/g" /var/jenkins_home/workspace/Build/src/main/resources/application-mysql.properties"""
        }
      }
    }
    stage("Build app"){
      steps{
         sh "./mvnw package"
      }
    }
    stage("save jar"){
     steps{
       sh "cp target/spring-petclinic-2.4.5.jar /var/jenkins_home"
      }
    }
  }
}
