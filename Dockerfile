FROM maven
ADD . .
CMD ./mvnw package
