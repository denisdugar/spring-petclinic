FROM maven
ADD . .
CMD mvn spring-boot:start -Dspring-boot.run.profiles=mysql
