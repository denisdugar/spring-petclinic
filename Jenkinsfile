pipeline {
    agent any
    tools { 
        maven 'maven'
        /*jdk 'java' */
    }
    stages {
        stage ('Build') {
            steps {
                sh 'mvn package'
            }
        }
    }
}
