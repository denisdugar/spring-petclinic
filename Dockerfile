FROM maven
COPY /var/jenkins_home/workspace/Build/target/*.jar .
CMD java -jar -Dspring.profiles.active=mysql *.jar
