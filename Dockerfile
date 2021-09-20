FROM maven
COPY target/spring-petclinic-2.4.5.jar .
CMD java -jar *.jar -Dspring-boot.run.profiles=mysql
