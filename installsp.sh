#!/bin/bash
# SONATA QUICK DEPLOYMENT SCRIPT
if [ $# -eq 0]
  then
    echo "USAGE ./installsp.sh sp.sonata.local 192.168.1.20"
    exit 1
fi

echo "Cleaning the environment"
echo "Deleting the stopped containers"
docker rm -fv $(docker ps -qa)
sleep 10

#Creating sonata network
if ! [[ "$(docker network inspect -f {{.Name}} sonata 2> /dev/null)" == "" ]]; then docker network rm sonata ; fi
docker network create sonata

#PULL THE CONTAINERS
docker pull registry.sonata-nfv.eu:5000/son-gui
docker pull registry.sonata-nfv.eu:5000/son-yo-gen-bss
docker pull registry.sonata-nfv.eu:5000/son-gtkpkg
docker pull registry.sonata-nfv.eu:5000/son-gtkusr
docker pull registry.sonata-nfv.eu:5000/son-gtksrv
docker pull registry.sonata-nfv.eu:5000/son-gtkapi
docker pull registry.sonata-nfv.eu:5000/son-gtkfnct
docker pull registry.sonata-nfv.eu:5000/son-gtkrec
docker pull registry.sonata-nfv.eu:5000/son-gtkvim
docker pull registry.sonata-nfv.eu:5000/son-gtklic
docker pull registry.sonata-nfv.eu:5000/son-gtkkpi
docker pull registry.sonata-nfv.eu:5000/son-sec-gw
docker pull registry.sonata-nfv.eu:5000/son-keycloak
docker pull registry.sonata-nfv.eu:5000/son-catalogue-repos
docker pull registry.sonata-nfv.eu:5000/pluginmanager
docker pull registry.sonata-nfv.eu:5000/specificmanagerregistry
docker pull registry.sonata-nfv.eu:5000/servicelifecyclemanagement
docker pull registry.sonata-nfv.eu:5000/son-sp-infrabstract
docker pull registry.sonata-nfv.eu:5000/wim-adaptor
docker pull registry.sonata-nfv.eu:5000/son-monitor-influxdb
docker pull registry.sonata-nfv.eu:5000/son-monitor-pushgateway
docker pull registry.sonata-nfv.eu:5000/son-monitor-prometheus
docker pull registry.sonata-nfv.eu:5000/son-monitor-manager
docker pull registry.sonata-nfv.eu:5000/son-monitor-probe
docker pull registry.sonata-nfv.eu:5000/son-monitor-vmprobe


#Databases:
#Postgres
docker run -d -p 5432:5432 --name son-postgres --net=sonata --network-alias=son-postgres -e POSTGRES_DB=gatekeeper -e POSTGRES_USER=sonatatest -e POSTGRES_PASSWORD=sonata --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900 ntboes/postgres-uuid
while ! nc -z sp.int3.sonata-nfv.eu 5432; do
  sleep 1 && echo -n .; # waiting for postgres
done;
#Mongo
docker run -d -p 27017:27017 --name son-mongo --net=sonata --network-alias=son-mongo --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900 mongo
while ! nc -z sp.int3.sonata-nfv.eu 27017; do
  sleep 1 && echo -n .; # waiting for mongo
done;
#docker run -d --name son-monitor-mysql -e MYSQL_ROOT_PASSWORD=1234 -e MYSQL_USER=monitoringuser -e MYSQL_PASSWORD=sonata -e MYSQL_DATABASE=monitoring -p 3306:3306 --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900 registry.sonata-nfv.eu:5000/son-monitor-mysql
docker run -d -p 5433:5432 --name son-monitor-postgres --net=sonata --network-alias=son-monitos-postgres -e POSTGRES_DB=monitoring -e POSTGRES_USER=monitoringuser -e POSTGRES_PASSWORD=sonata --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900 ntboes/postgres-uuid
docker run -d --name son-monitor-influxdb --net=sonata --network-alias=son-monitor-influxdb -p 8086:8086 --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900 registry.sonata-nfv.eu:5000/son-monitor-influxdb

#Broker 
#Rabbitmq
docker run -d -p 5672:5672 -p 8080:15672 --name son-broker --net=sonata --network-alias=son-broker  -e RABBITMQ_CONSOLE_LOG=new --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900 rabbitmq:3-management
while ! nc -z sp.int3.sonata-nfv.eu 5672; do
  sleep 1 && echo -n .; # waiting for rabbitmq
done;

#Keycloak
echo keycloak
docker run --name son-keycloak -d -p 5601:5601 --net=sonata --network-alias=son-keycloak -e KEYCLOAK_USER=admin -e KEYCLOAK_PASSWORD=admin --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900 registry.sonata-nfv.eu:5000/son-keycloak

#GUI
#TODO: ADD environmental variables
echo son-gui
docker run -d --name son-gui --net=sonata --network-alias=son-gui -P -e "MON_URL=sp.int3.sonata-nfv.eu:8000" -e "GK_URL=sp.int3.sonata-nfv.eu:32001/api/v2" -e "LOGS_URL=logs.sonata-nfv.eu:12900" --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900 registry.sonata-nfv.eu:5000/son-gui

#BSS
docker run -d -t -i --name son-bss --net=sonata --network-alias=son-bss -h sp.int3.sonata-nfv.eu -p 25001:1337 -p 25002:1338 -v /etc/ssl/private/sonata/:/usr/local/yeoman/SonataBSS/app/certs/ --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900 registry.sonata-nfv.eu:5000/son-yo-gen-bss sudo grunt serve:integration --gkApiUrl=https://sp.int3.sonata-nfv.eu/api/v2 --hostname=sp.int3.sonata-nfv.eu --userManagementEnabled=false --licenseManagementEnabled=false --protocol=https --debug

#Gatekeeper
echo gtkpkg
docker run --name son-gtkpkg --net=sonata --network-alias=son-gtkpkg -d -p 5100:5100 -e CATALOGUES_URL=http://sp.int3.sonata-nfv.eu:4002/catalogues/api/v2 -e RACK_ENV=integration --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900 registry.sonata-nfv.eu:5000/son-gtkpkg
echo gtksrv
echo populate database
docker run -i --net=sonata -e DATABASE_HOST=sp.int3.sonata-nfv.eu -e MQSERVER=amqp://guest:guest@sp.int3.sonata-nfv.eu:5672 -e RACK_ENV=integration -e CATALOGUES_URL=http://sp.int3.sonata-nfv.eu:4002/catalogues/api/v2 -e DATABASE_HOST=sp.int3.sonata-nfv.eu -e DATABASE_PORT=5432 -e POSTGRES_PASSWORD=sonata -e POSTGRES_USER=sonatatest --rm=true --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900 registry.sonata-nfv.eu:5000/son-gtksrv bundle exec rake db:migrate
echo gtksrv
docker run --name son-gtksrv --net=sonata --network-alias=son-gtksrv -d -p 5300:5300 -e MQSERVER=amqp://guest:guest@sp.int3.sonata-nfv.eu:5672 -e CATALOGUES_URL=http://sp.int3.sonata-nfv.eu:4002/catalogues/api/v2 -e RACK_ENV=integration -e DATABASE_HOST=sp.int3.sonata-nfv.eu -e DATABASE_PORT=5432 -e POSTGRES_PASSWORD=sonata -e POSTGRES_USER=sonatatest -e MQSERVER=amqp://guest:guest@sp.int3.sonata-nfv.eu:5672 -e RACK_ENV=integration --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900 registry.sonata-nfv.eu:5000/son-gtksrv
echo gtkfnct
docker run --name son-gtkfnct --net=sonata --network-alias=son-gtkfnct -d -p 5500:5500 -e RACK_ENV=integration -e CATALOGUES_URL=http://sp.int3.sonata-nfv.eu:4002/catalogues/api/v2 --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900 registry.sonata-nfv.eu:5000/son-gtkfnct
echo gtkrec
docker run --name son-gtkrec --net=sonata --network-alias=son-gtkrec -d -p 5800:5800 -e RACK_ENV=integration -e REPOSITORIES_URL=http://sp.int3.sonata-nfv.eu:4002/records --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900 registry.sonata-nfv.eu:5000/son-gtkrec
echo gtkvim
echo populate database
docker run --net=sonata -i -e DATABASE_HOST=sp.int3.sonata-nfv.eu -e MQSERVER=amqp://guest:guest@sp.int3.sonata-nfv.eu:5672 -e RACK_ENV=integration -e DATABASE_PORT=5432 -e POSTGRES_PASSWORD=sonata -e POSTGRES_USER=sonatatest --rm=true --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900 registry.sonata-nfv.eu:5000/son-gtkvim bundle exec rake db:migrate
docker run --name son-gtkvim --net=sonata --network-alias=son-gtkvim  -d -p 5700:5700 -e MQSERVER=amqp://guest:guest@sp.int3.sonata-nfv.eu:5672 -e RACK_ENV=integration -e DATABASE_HOST=sp.int3.sonata-nfv.eu -e DATABASE_PORT=5432 -e POSTGRES_PASSWORD=sonata -e POSTGRES_USER=sonatatest -e MQSERVER=amqp://guest:guest@sp.int3.sonata-nfv.eu:5672 -e RACK_ENV=integration --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900 registry.sonata-nfv.eu:5000/son-gtkvim
echo gtklic
echo populate database
docker run --name son-gtklic --net=sonata --network-alias=son-gtklic -i -e DATABASE_HOST=sp.int3.sonata-nfv.eu -e DATABASE_PORT=5432 -e POSTGRES_PASSWORD=sonata -e POSTGRES_USER=sonatatest -e POSTGRES_DB=gatekeeper --rm=true --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900 registry.sonata-nfv.eu:5000/son-gtklic python manage.py db upgrade
docker run --name son-gtklic --net=sonata --network-alias=son-gtklic -d -p 5900:5900 -e PORT=5900 -e DATABASE_HOST=sp.int3.sonata-nfv.eu -e DATABASE_PORT=5432 -e POSTGRES_PASSWORD=sonata -e POSTGRES_USER=sonatatest -e POSTGRES_DB=gatekeeper registry.sonata-nfv.eu:5000/son-gtklic
echo gtkkpi
docker run --name son-gtkkpi --net=sonata --network-alias=son-gtkkpi -d -p 5400:5400 -e PUSHGATEWAY_HOST=sp.int3.sonata-nfv.eu -e PUSHGATEWAY_PORT=9091 -e PROMETHEUS_PORT=9090 -e RACK_ENV=integration --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900 registry.sonata-nfv.eu:5000/son-gtkkpi 
echo gtkusr
docker run --name son-gtkusr --net=sonata --network-alias=son-gtkusr -d -p 5600:5600 -e KEYCLOAK_ADDRESS=son-keycloak -e KEYCLOAK_PORT=5601 -e KEYCLOAK_PATH=auth -e SONATA_REALM=sonata -e CLIENT_NAME=adapter --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900 registry.sonata-nfv.eu:5000/son-gtkusr 
echo gtkapi
docker run --name son-gtkapi --net=sonata --network-alias=son-gtkapi -d -p 32001:5000 -e RACK_ENV=integration -e PACKAGE_MANAGEMENT_URL=http://sp.int3.sonata-nfv.eu:5100 -e SERVICE_MANAGEMENT_URL=http://sp.int3.sonata-nfv.eu:5300 -e FUNCTION_MANAGEMENT_URL=http://sp.int3.sonata-nfv.eu:5500 -e VIM_MANAGEMENT_URL=http://sp.int3.sonata-nfv.eu:5700 -e RECORD_MANAGEMENT_URL=http://sp.int3.sonata-nfv.eu:5800 -e KPI_MANAGEMENT_URL=http://sp.int3.sonata-nfv.eu:5400 -e USER_MANAGEMENT_URL=http://son-gtkusr:5600 --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900 registry.sonata-nfv.eu:5000/son-gtkapi 
echo son-sec-gw
docker run --name son-sec-gw --net=sonata --network-alias=son-sec-gw -d -p 80:80 -p 443:443 -v /etc/ssl/private/sonata/:/etc/nginx/cert/ --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900 registry.sonata-nfv.eu:5000/son-sec-gw 

#Catalogues
docker run --name son-catalogue-repos --net=sonata --network-alias=son-catalogue-repos -d -p 4002:4011 --add-host mongo:10.30.0.112 --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900 registry.sonata-nfv.eu:5000/son-catalogue-repos
sleep 15
#docker run --name son-catalogue-repos1 -i --rm=true --add-host mongo:sp.int3.sonata-nfv.eu --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900 registry.sonata-nfv.eu:5000/son-catalogue-repos rake init:load_samples[integration]

#son-mano-framework
docker run -d --name pluginmanager --net=sonata --network-alias=pluginmanager -p 8001:8001 -e mongo_host=sp.int3.sonata-nfv.eu -e broker_host=amqp://guest:guest@sp.int3.sonata-nfv.eu:5672/%2F --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900 registry.sonata-nfv.eu:5000/pluginmanager /bin/bash /delayedstart.sh 10 son-mano-pluginmanager
sleep 10
docker run -d --name specificmanagerregistry --net=sonata --network-alias=specificmanagerregistry -e broker_name=son-broker,broker -e broker_host=amqp://guest:guest@sp.int3.sonata-nfv.eu:5672/%2F -v '/var/run/docker.sock:/var/run/docker.sock' --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900 registry.sonata-nfv.eu:5000/specificmanagerregistry
docker run -d --name servicelifecyclemanagement --net=sonata --network-alias=servicelifecyclemanagement -e url_nsr_repository=http://sp.int3.sonata-nfv.eu:4002/records/nsr/ -e url_vnfr_repository=http://sp.int3.sonata-nfv.eu:4002/records/vnfr/ -e url_monitoring_server=http://sp.int3.sonata-nfv.eu:8000/api/v1/ -e broker_host=amqp://guest:guest@sp.int3.sonata-nfv.eu:5672/%2F --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900 registry.sonata-nfv.eu:5000/servicelifecyclemanagement /bin/bash /delayedstart.sh 10 son-mano-service-lifecycle-management
#docker run -d --name functionlifecyclemanagement -e broker_host=amqp://guest:guest@sp.int3-sonata-nfv.eu:5672/%2F --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900 registry.sonata-nfv.eu:5000/functionlifecyclemanagement /bin/bash /delayedstart.sh 10 son-mano-function-lifecycle-management
#docker run -d --name placementexecutive -e broker_host=amqp://guest:guest@sp.int3.sonata-nfv.eu:5672/%2F --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900 registry.sonata-nfv.eu:5000/placementexecutive /bin/bash /delayedstart.sh 10 son-mano-placement

#son-sp-infrabstract
docker run -d --name son-sp-infrabstract --net=sonata --network-alias=son-sp-infrabstract -e broker_host=sp.int3.sonata-nfv.eu -e broker_uri=amqp://guest:guest@sp.int3.sonata-nfv.eu:5672/%2F -e repo_host=sp.int3.sonata-nfv.eu -e repo_port=5432 -e repo_user=sonatatest -e repo_pass=sonata --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900  registry.sonata-nfv.eu:5000/son-sp-infrabstract /docker-entrypoint.sh
#docker run -d --name son-sp-infrabstract -e broker_host=sp.int3.sonata-nfv.eu -e broker_uri=amqp://guest:guest@sp.int3.sonata-nfv.eu:5672/%2F --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900 registry.sonata-nfv.eu:5000/son-sp-infrabstract 

while ! docker exec -t son-postgres psql -h localhost -U postgres -d vimregistry -c "SELECT * FROM VIM"; do
  sleep 2 && echo -n .; # waiting for table creation
done;

while ! docker exec -t son-postgres psql -h localhost -U postgres -d vimregistry -c "SELECT * FROM LINK_VIM"; do
  sleep 2 && echo -n .; # waiting for table creation
done;

# ADD THE VIMs
## 1.0
### PoP#1
##docker exec -t son-postgres psql -h localhost -U postgres -d vimregistry -c "INSERT INTO VIM (uuid, type, vendor, endpoint, username, tenant, tenant_ext_net, tenant_ext_router, pass, authkey) VALUES ('1111-22222222-33333333-4444', 'compute', 'Heat', '10.100.32.200', 'admin', 'admin', 'c999f013-2022-4464-b44f-88f4437f23b0', '0e5d6e42-e544-4ec3-8ce1-9ac950ae994b', 'admin_pass', null);"
##docker exec -t son-postgres psql -h localhost -U postgres -d vimregistry -c "INSERT INTO VIM (uuid, type, vendor, endpoint, username, tenant, tenant_ext_net, tenant_ext_router, pass, authkey) VALUES ('aaaa-bbbbbbbb-cccccccc-dddd', 'network', 'ovs', '10.100.32.200', 'operator', 'operator_ten', null, null, '0p3r470r', null);"
##docker exec -t son-postgres psql -h localhost -U postgres -d vimregistry -c "INSERT INTO LINK_VIM (COMPUTE_UUID, NETWORKING_UUID) VALUES ('1111-22222222-33333333-4444', 'aaaa-bbbbbbbb-cccccccc-dddd');"

### PoP#2
##docker exec -t son-postgres psql -h localhost -U postgres -d vimregistry -c "INSERT INTO VIM (uuid, type, vendor, endpoint, username, tenant, tenant_ext_net, tenant_ext_router, pass, authkey) VALUES ('5555-66666666-77777777-8888', 'compute', 'Heat', '10.100.32.10', 'admin', 'admin', '4ac2b52e-8f6b-4af3-ad28-38ede9d71c83', 'cbc5a4fa-59ed-4ec1-ad2d-adb270e21693', 'admin_pass', null);"
##docker exec -t son-postgres psql -h localhost -U postgres -d vimregistry -c "INSERT INTO VIM (uuid, type, vendor, endpoint, username, tenant, tenant_ext_net, tenant_ext_router, pass, authkey) VALUES ('1324-acbdf1324-acbdf1324-3546', 'network', 'odl', '10.100.32.10', null, null, null, null, null, null);"
##docker exec -t son-postgres psql -h localhost -U postgres -d vimregistry -c "INSERT INTO LINK_VIM (COMPUTE_UUID, NETWORKING_UUID) VALUES ('5555-66666666-77777777-8888', '1324-acbdf1324-acbdf1324-3546');"

## 2.0
## PoP#200
docker exec -t son-postgres psql -h localhost -U sonatatest -d vimregistry -c "INSERT INTO VIM (UUID, TYPE, VENDOR, ENDPOINT, USERNAME, CONFIGURATION, CITY, COUNTRY, PASS, AUTHKEY) VALUES ('1111-22222222-33333333-4444', 'compute', 'Heat', '10.100.32.200', 'sonata.dem', '{"tenant_ext_net":"53d43a3e-8c86-48e6-b1cb-f1f2c48833de","tenant":"admin","tenant_ext_router":"e8cdd5c7-191f-4215-83f3-53ee1113db86"}', 'Athens', 'Greece', 's0nata.d3m', null);"
docker exec -t son-postgres psql -h localhost -U sonatatest -d vimregistry -c "INSERT INTO VIM (UUID, TYPE, VENDOR, ENDPOINT, USERNAME, CONFIGURATION, CITY, COUNTRY, PASS, AUTHKEY) VALUES ('aaaa-bbbbbbbb-cccccccc-dddd', 'network', 'ovs', '10.100.32.200', 'sonata.dem', '{"compute_uuid":"1111-22222222-33333333-4444"}', 'Athens', 'Greece', 's0nata.d3m', null);"
docker exec -t son-postgres psql -h localhost -U sonatatest -d vimregistry -c "INSERT INTO LINK_VIM (COMPUTE_UUID, NETWORKING_UUID) VALUES ('1111-22222222-33333333-4444', 'aaaa-bbbbbbbb-cccccccc-dddd');"

## PoP#10
docker exec -t son-postgres psql -h localhost -U sonatatest -d vimregistry -c "INSERT INTO VIM (UUID, TYPE, VENDOR, ENDPOINT, USERNAME, CONFIGURATION, CITY, COUNTRY, PASS, AUTHKEY) VALUES ('5555-66666666-77777777-8888', 'compute', 'Heat', '10.100.32.10', 'sonata.dem', '{"tenant_ext_router":"2c2a8b09-b746-47de-b0ce-dce5fa242c7e", "tenant_ext_net":"12bf4db8-0131-4322-bd22-0b1ad8333748","tenant":"sonata.dem"}', 'Athens', 'Greece', 's0n@t@.dem', null);"
docker exec -t son-postgres psql -h localhost -U sonatatest -d vimregistry -c "INSERT INTO VIM (UUID, TYPE, VENDOR, ENDPOINT, USERNAME, CONFIGURATION, CITY, COUNTRY, PASS, AUTHKEY) VALUES ('eeee-ffffffff-gggggggg-hhhh', 'network', 'ovs', '10.100.32.10', 'sonata.dem', '{"compute_uuid":"5555-66666666-77777777-8888"}', 'Athens', 'Greece', 's0n@t@.dem', null);"
docker exec -t son-postgres psql -h localhost -U sonatatest -d vimregistry -c "INSERT INTO LINK_VIM (COMPUTE_UUID, NETWORKING_UUID) VALUES ('5555-66666666-77777777-8888', 'eeee-ffffffff-gggggggg-hhhh');"



#wim-adaptor
docker run -d --name wim-adaptor --net=sonata --network-alias=vim-adaptor -e broker_host=sp.int3.sonata-nfv.eu -e broker_uri=amqp://guest:guest@sp.int3.sonata-nfv.eu:5672/%2F -e repo_host=sp.int3.sonata-nfv.eu -e repo_port=5432 -e repo_user=sonatatest -e repo_pass=sonata --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900  registry.sonata-nfv.eu:5000/wim-adaptor /docker-entrypoint.sh

while ! docker exec -t son-postgres psql -h localhost -U postgres -d wimregistry -c "SELECT * FROM WIM"; do
  sleep 2 && echo -n .; # waiting for table creation
done;

while ! docker exec -t son-postgres psql -h localhost -U postgres -d wimregistry -c "SELECT * FROM SERVICED_SEGMENTS"; do
  sleep 2 && echo -n .; # waiting for table creation
done;

#ADD THE WIM
docker exec -t son-postgres psql -h localhost -U postgres -d wimregistry -c "INSERT INTO WIM (UUID, TYPE, VENDOR, ENDPOINT, USERNAME, PASS, AUTHKEY) VALUES ('1234-12345678-12345678-1234', 'WIM', 'VTN', '10.30.0.13', 'admin', 'admin', null);"
#THIS WIM will serve PoP#1
docker exec -t son-postgres psql -h localhost -U postgres -d wimregistry -c "INSERT INTO SERVICED_SEGMENTS (NETWORK_SEGMENT, WIM_UUID) VALUES ('1111-22222222-33333333-4444', '1234-12345678-12345678-1234');"

#son-monitor
docker run -d --name son-monitor-pushgateway --net=sonata --network-alias=son-monitor-pushgateway -p 9091:9091 --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900 registry.sonata-nfv.eu:5000/son-monitor-pushgateway
docker run -d --name son-monitor-prometheus --net=sonata --network-alias=son-monitor-prometheus -p 9090:9090 -p 9089:9089 -p 8002:8001 -e RABBIT_URL=sp.int3.sonata-nfv.eu:5672 -e EMAIL_PASS=czBuQHRAX21vbl9zeXNfMTY= --add-host pushgateway:10.30.0.112 --add-host influx:10.30.0.112 --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900 registry.sonata-nfv.eu:5000/son-monitor-prometheus
docker run -d --name son-monitor-manager --net=sonata --network-alias=son-monitor-manager --add-host postgsql:10.30.0.112 --add-host prometheus:10.30.0.112 --add-host pushgateway:10.30.0.112 -p 8888:8888 -p 8000:8000 -v /tmp/monitoring/mgr:/var/log/apache2 --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900 registry.sonata-nfv.eu:5000/son-monitor-manager

#son-monitor-probe
docker run -d --name son-mon-vmprobe -e NODE_NAME=TEST-VNF -e PROM_SRV=http://sp.int3.sonata-nfv.eu:9091/metrics --net="host" --privileged=true  -v /proc:/myhost/proc -v /:/rootfs:ro --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900 registry.sonata-nfv.eu:5000/son-monitor-vmprobe
docker run -d --name son-monitor-probe -e NODE_NAME=INT-SRV-3 -e PROM_SRV=http://sp.int3.sonata-nfv.eu:9091/metrics --net="host" --privileged=true -d -v /var/run/docker.sock:/var/run/docker.sock -v /proc:/myhost/proc -v /:/rootfs:ro --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900 registry.sonata-nfv.eu:5000/son-monitor-probe

