pipeline{
  agent any
  tools {
    maven "maven"
  }
  stages{
    stage("Get db address") {
      steps{
        withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: 'aws-key', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY']]) {
            sh "echo \$(docker run --env AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID --env AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY amazon/aws-cli rds describe-db-instances --region eu-central-1 --query DBInstances[*].Endpoint.Address) > text.txt"
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
    stage("Build Dockerfile"){
      steps{
         sh "docker build -t my_project ."
      }
    }
    stage("Tag and push image") {
      steps{
        withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: 'aws-key', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY']]) {
            sh """docker run --env AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID --env AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY amazon/aws-cli ecr get-login-password --region eu-cen>
            docker tag my_project:latest 966425126302.dkr.ecr.eu-central-1.amazonaws.com/my_project:latest; \
            docker push 966425126302.dkr.ecr.eu-central-1.amazonaws.com/my_project:latest; \
            sleep 1m"""
        }
      }
    }
  stage("Update ECS task") {
      steps{
        withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: 'aws-key', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY']]) {
            sh "docker run --env AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID --env AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY amazon/aws-cli ecs stop-task --cluster cluster --task \>
        }
      }
    }
  }
}
