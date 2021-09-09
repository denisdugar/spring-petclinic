#!/bin/bash
./mvnw package
mvn spring-boot:run -Dspring-boot.run.profiles=mysql
