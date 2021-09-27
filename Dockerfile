FROM maven
ADD . .
CMD mvn spring-boot:run -Dspring-boot.run.profiles=mysql
