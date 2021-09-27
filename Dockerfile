FROM ubuntu
ADD . .
RUN apt install maven
CMD mvn spring-boot:run -Dspring-boot.run.profiles=mysql
