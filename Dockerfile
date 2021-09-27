FROM maven
COPY . .
CMD ./mvnw package
