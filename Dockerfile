FROM maven
COPY target/*.jar .
CMD java -jar -Dspring.profiles.active=mysql *.jar
