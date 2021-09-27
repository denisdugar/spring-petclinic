@Library('github.com/releaseworks/jenkinslib') _
pipeline {
    agent any

  node {
    stage("List S3 buckets") {
      withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: 'aws-key', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY']]) {
          AWS("--region=eu-central-1 s3 ls")
      }
    }
  }
}
