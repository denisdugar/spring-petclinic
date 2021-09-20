FROM maven
CMD sed -i "s/localhost/$MY_MYSQL_URL/g" /mnt/spring-petclinic/src/main/resources/application-mysql.properties && (cd /mnt/spring-petclinic && ./mvnw package -Dspring-boot.run.profiles=mysql) 
