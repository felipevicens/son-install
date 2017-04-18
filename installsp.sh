#!/bin/bash
# SONATA QUICK DEPLOYMENT SCRIPT

#TODO:
# 1. CHECK IF SUDO
# 2. CHECK PACKAGES LIST DOCKER
# 3. VERIFY IF CERTIFICATES EXISTS
# 4. VERIFY HOSTNAME AND HOSTIP
# 5. ADD HELP FOR THE COMMAND
# 6. ADD VIM AND WIM?

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


HOSTNAME=$1
HOSTIP=$2

#Databases:
#Postgres
echo "DEPLOYING POSTGRES"
docker run -d -p 5432:5432 --name son-postgres --net=sonata --network-alias=son-postgres -e POSTGRES_DB=gatekeeper -e POSTGRES_USER=sonatatest -e POSTGRES_PASSWORD=sonata ntboes/postgres-uuid
while ! nc -z localhost 5432; do
  sleep 1 && echo -n .; # waiting for postgres
done;
#Mongo
echo "DEPLOYING MONGO"
docker run -d -p 27017:27017 --name son-mongo --net=sonata --network-alias=son-mongo mongo
while ! nc -z localhost 27017; do
  sleep 1 && echo -n .; # waiting for mongo
done;
# Deploying Postgres for Monitoring
echo "DEPLOYING POSTGRES FOR MONITORING"
docker run -d -p 5433:5432 --name son-monitor-postgres --net=sonata --network-alias=son-monitos-postgres -e POSTGRES_DB=monitoring -e POSTGRES_USER=monitoringuser -e POSTGRES_PASSWORD=sonata ntboes/postgres-uuid
# Deploying influxdb for Monitoring
echo "DEPLOYING INFLUXDB FOR MONITORING"
docker run -d --name son-monitor-influxdb --net=sonata --network-alias=son-monitor-influxdb -p 8086:8086 sonatanfv/son-monitor-influxdb:dev

#Broker 
#Rabbitmq
echo "DEPLOYING BROKER"
docker run -d -p 5672:5672 -p 8080:15672 --name son-broker --net=sonata --network-alias=son-broker -e RABBITMQ_CONSOLE_LOG=new rabbitmq:3-management
while ! nc -z localhost 5672; do
  sleep 1 && echo -n .; # waiting for rabbitmq
done;

#Keycloak
echo "DEPLOYING KEYCLOAK"
docker run --name son-keycloak -d -p 5601:5601 --net=sonata --network-alias=son-keycloak -e KEYCLOAK_USER=admin -e KEYCLOAK_PASSWORD=admin sonatanfv/son-keycloak:dev

#GUI
echo "DEPLOYING SON-GUI"
docker run -d --name son-gui --net=sonata --network-alias=son-gui -P -e "MON_URL=$HOSTNAME:8000" -e "GK_URL=$HOSTNAME:32001/api/v2" -e "LOGS_URL=$HOSTNAME:12900" sonatanfv/son-gui:dev

#BSS
echo "DEPLOYING BSS"
docker run -d -t -i --name son-bss --net=sonata --network-alias=son-bss -h $HOSTNAME -p 25001:1337 -p 25002:1338 -v /etc/ssl/private/sonata/:/usr/local/yeoman/SonataBSS/app/certs/ sonatanfv/son-yo-gen-bss:dev sudo grunt serve:integration --gkApiUrl=https://$HOSTNAME/api/v2 --hostname=$HOSTNAME --userManagementEnabled=false --licenseManagementEnabled=false --protocol=https --debug

#Gatekeeper
echo "DEPLOYING GK-PKG"
docker run --name son-gtkpkg --net=sonata --network-alias=son-gtkpkg -d -p 5100:5100 -e CATALOGUES_URL=http://$HOSTNAME:4002/catalogues/api/v2 -e RACK_ENV=integration sonatanfv/son-gtkpkg:dev
echo "DEPLOYING GK-SRV"
echo "POPULATING GK-SRV DATABASE"
docker run -i --net=sonata -e DATABASE_HOST=$HOSTNAME -e MQSERVER=amqp://guest:guest@$HOSTNAME:5672 -e RACK_ENV=integration -e CATALOGUES_URL=http://$HOSTNAME:4002/catalogues/api/v2 -e DATABASE_HOST=$HOSTNAME -e DATABASE_PORT=5432 -e POSTGRES_PASSWORD=sonata -e POSTGRES_USER=sonatatest --rm=true sonatanfv/son-gtksrv:dev bundle exec rake db:migrate
echo "STARTING GK-SRV"
docker run --name son-gtksrv --net=sonata --network-alias=son-gtksrv -d -p 5300:5300 -e MQSERVER=amqp://guest:guest@$HOSTNAME:5672 -e CATALOGUES_URL=http://$HOSTNAME:4002/catalogues/api/v2 -e RACK_ENV=integration -e DATABASE_HOST=$HOSTNAME -e DATABASE_PORT=5432 -e POSTGRES_PASSWORD=sonata -e POSTGRES_USER=sonatatest -e MQSERVER=amqp://guest:guest@$HOSTNAME:5672 -e RACK_ENV=integration sonatanfv/son-gtksrv:dev
echo "DEPLOYING GK-FNCT"
docker run --name son-gtkfnct --net=sonata --network-alias=son-gtkfnct -d -p 5500:5500 -e RACK_ENV=integration -e CATALOGUES_URL=http://$HOSTNAME:4002/catalogues/api/v2 sonatanfv/son-gtkfnct:dev
echo "DEPLOYING GK-REC"
docker run --name son-gtkrec --net=sonata --network-alias=son-gtkrec -d -p 5800:5800 -e RACK_ENV=integration -e REPOSITORIES_URL=http://$HOSTNAME:4002/records sonatanfv/son-gtkrec:dev
echo "DEPLOYING GK-VIM"
echo "POPULATING GK-VIM DATABASE"
docker run --net=sonata -i -e DATABASE_HOST=$HOSTNAME -e MQSERVER=amqp://guest:guest@$HOSTNAME:5672 -e RACK_ENV=integration -e DATABASE_PORT=5432 -e POSTGRES_PASSWORD=sonata -e POSTGRES_USER=sonatatest --rm=true sonatanfv/son-gtkvim:dev bundle exec rake db:migrate
echo "STARTING GK-VIM"
docker run --name son-gtkvim --net=sonata --network-alias=son-gtkvim  -d -p 5700:5700 -e MQSERVER=amqp://guest:guest@$HOSTNAME:5672 -e RACK_ENV=integration -e DATABASE_HOST=$HOSTNAME -e DATABASE_PORT=5432 -e POSTGRES_PASSWORD=sonata -e POSTGRES_USER=sonatatest -e MQSERVER=amqp://guest:guest@$HOSTNAME:5672 -e RACK_ENV=integration sonatanfv/son-gtkvim:dev
echo "DEPLOYING GK-LIC"
echo "POPULATING GTK-LIC DATABASE"
docker run --name son-gtklic --net=sonata --network-alias=son-gtklic -i -e DATABASE_HOST=$HOSTNAME -e DATABASE_PORT=5432 -e POSTGRES_PASSWORD=sonata -e POSTGRES_USER=sonatatest -e POSTGRES_DB=gatekeeper --rm=true sonatanfv/son-gtklic:dev python manage.py db upgrade
echo "STARTING GTK-LIC"
docker run --name son-gtklic --net=sonata --network-alias=son-gtklic -d -p 5900:5900 -e PORT=5900 -e DATABASE_HOST=$HOSTNAME -e DATABASE_PORT=5432 -e POSTGRES_PASSWORD=sonata -e POSTGRES_USER=sonatatest -e POSTGRES_DB=gatekeeper sonatanfv/son-gtklic:dev
echo "DEPLOYING GK-KPI"
docker run --name son-gtkkpi --net=sonata --network-alias=son-gtkkpi -d -p 5400:5400 -e PUSHGATEWAY_HOST=$HOSTNAME -e PUSHGATEWAY_PORT=9091 -e PROMETHEUS_PORT=9090 -e RACK_ENV=integration sonatanfv/son-gtkkpi:dev
echo "DEPLOYING GK-USR"
docker run --name son-gtkusr --net=sonata --network-alias=son-gtkusr -d -p 5600:5600 -e KEYCLOAK_ADDRESS=son-keycloak -e KEYCLOAK_PORT=5601 -e KEYCLOAK_PATH=auth -e SONATA_REALM=sonata -e CLIENT_NAME=adapter sonatanfv/son-gtkusr:dev
echo "DEPLOYING GK-API"
docker run --name son-gtkapi --net=sonata --network-alias=son-gtkapi -d -p 32001:5000 -e RACK_ENV=integration -e PACKAGE_MANAGEMENT_URL=http://$HOSTNAME:5100 -e SERVICE_MANAGEMENT_URL=http://$HOSTNAME:5300 -e FUNCTION_MANAGEMENT_URL=http://$HOSTNAME:5500 -e VIM_MANAGEMENT_URL=http://$HOSTNAME:5700 -e RECORD_MANAGEMENT_URL=http://$HOSTNAME:5800 -e KPI_MANAGEMENT_URL=http://$HOSTNAME:5400 -e USER_MANAGEMENT_URL=http://son-gtkusr:5600 sonatanfv/son-gtkapi:dev
echo "DEPLOYING SECURITY GATEWAY"
docker run --name son-sec-gw --net=sonata --network-alias=son-sec-gw -d -p 80:80 -p 443:443 -v /etc/ssl/private/sonata/:/etc/nginx/cert/ sonatanfv/son-sec-gw:dev

#Catalogues
echo "DEPLOYING CATALOGUES"
docker run --name son-catalogue-repos --net=sonata --network-alias=son-catalogue-repos -d -p 4002:4011 --add-host mongo:$HOSTIP sonatanfv/son-catalogue-repos:dev
sleep 15
#docker run --name son-catalogue-repos1 -i --rm=true --add-host mongo:$HOSTNAME sonatanfv/son-catalogue-repos rake init:load_samples[integration]

#son-mano-framework
echo "DEPLOYING MANO-FRAMEWORK"
echo "DEPLOYING PLUGINMANAGER"
docker run -d --name pluginmanager --net=sonata --network-alias=pluginmanager -p 8001:8001 -e mongo_host=$HOSTNAME -e broker_host=amqp://guest:guest@$HOSTNAME:5672/%2F sonatanfv/pluginmanager:dev /bin/bash /delayedstart.sh 10 son-mano-pluginmanager
sleep 10
echo "DEPLOYING SMR"
docker run -d --name specificmanagerregistry --net=sonata --network-alias=specificmanagerregistry -e broker_name=son-broker,broker -e broker_host=amqp://guest:guest@$HOSTNAME:5672/%2F -v '/var/run/docker.sock:/var/run/docker.sock' sonatanfv/specificmanagerregistry:dev
echo "DEPLOYING SLM"
docker run -d --name servicelifecyclemanagement --net=sonata --network-alias=servicelifecyclemanagement -e url_nsr_repository=http://$HOSTNAME:4002/records/nsr/ -e url_vnfr_repository=http://$HOSTNAME:4002/records/vnfr/ -e url_monitoring_server=http://$HOSTNAME:8000/api/v1/ -e broker_host=amqp://guest:guest@$HOSTNAME:5672/%2F sonatanfv/servicelifecyclemanagement:dev /bin/bash /delayedstart.sh 10 son-mano-service-lifecycle-management
#docker run -d --name functionlifecyclemanagement -e broker_host=amqp://guest:guest@sp.int3-sonata-nfv.eu:5672/%2F sonatanfv/functionlifecyclemanagement /bin/bash /delayedstart.sh 10 son-mano-function-lifecycle-management
echo "DEPLOYING PLACEMENTEXECUTIVE PLUGIN"
docker run -d --name placementexecutive --net=sonata --network-alias=placementexecutive -e broker_host=amqp://guest:guest@$HOSTNAME:5672/%2F --log-driver=gelf --log-opt gelf-address=udp://10.30.0.219:12900 registry.sonata-nfv.eu:5000/placementexecutive:dev /bin/bash /delayedstart.sh 10 son-mano-placement

#son-sp-infrabstract
echo "DEPLOYING INFRASTRUCTURE ABSTRACTION"
docker run -d --name son-sp-infrabstract --net=sonata --network-alias=son-sp-infrabstract -e broker_host=$HOSTNAME -e broker_uri=amqp://guest:guest@$HOSTNAME:5672/%2F -e repo_host=$HOSTNAME -e repo_port=5432 -e repo_user=sonatatest -e repo_pass=sonata  sonatanfv/son-sp-infrabstract:dev /docker-entrypoint.sh
#docker run -d --name son-sp-infrabstract -e broker_host=$HOSTNAME -e broker_uri=amqp://guest:guest@$HOSTNAME:5672/%2F sonatanfv/son-sp-infrabstract 

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
#docker exec -t son-postgres psql -h localhost -U sonatatest -d vimregistry -c "INSERT INTO VIM (UUID, TYPE, VENDOR, ENDPOINT, USERNAME, CONFIGURATION, CITY, COUNTRY, PASS, AUTHKEY) VALUES ('1111-22222222-33333333-4444', 'compute', 'Heat', '10.100.32.200', 'sonata.dem', '{"tenant_ext_net":"53d43a3e-8c86-48e6-b1cb-f1f2c48833de","tenant":"admin","tenant_ext_router":"e8cdd5c7-191f-4215-83f3-53ee1113db86"}', 'Athens', 'Greece', 's0nata.d3m', null);"
#docker exec -t son-postgres psql -h localhost -U sonatatest -d vimregistry -c "INSERT INTO VIM (UUID, TYPE, VENDOR, ENDPOINT, USERNAME, CONFIGURATION, CITY, COUNTRY, PASS, AUTHKEY) VALUES ('aaaa-bbbbbbbb-cccccccc-dddd', 'network', 'ovs', '10.100.32.200', 'sonata.dem', '{"compute_uuid":"1111-22222222-33333333-4444"}', 'Athens', 'Greece', 's0nata.d3m', null);"
#docker exec -t son-postgres psql -h localhost -U sonatatest -d vimregistry -c "INSERT INTO LINK_VIM (COMPUTE_UUID, NETWORKING_UUID) VALUES ('1111-22222222-33333333-4444', 'aaaa-bbbbbbbb-cccccccc-dddd');"

## PoP#10
#docker exec -t son-postgres psql -h localhost -U sonatatest -d vimregistry -c "INSERT INTO VIM (UUID, TYPE, VENDOR, ENDPOINT, USERNAME, CONFIGURATION, CITY, COUNTRY, PASS, AUTHKEY) VALUES ('5555-66666666-77777777-8888', 'compute', 'Heat', '10.100.32.10', 'sonata.dem', '{"tenant_ext_router":"2c2a8b09-b746-47de-b0ce-dce5fa242c7e", "tenant_ext_net":"12bf4db8-0131-4322-bd22-0b1ad8333748","tenant":"sonata.dem"}', 'Athens', 'Greece', 's0n@t@.dem', null);"
#docker exec -t son-postgres psql -h localhost -U sonatatest -d vimregistry -c "INSERT INTO VIM (UUID, TYPE, VENDOR, ENDPOINT, USERNAME, CONFIGURATION, CITY, COUNTRY, PASS, AUTHKEY) VALUES ('eeee-ffffffff-gggggggg-hhhh', 'network', 'ovs', '10.100.32.10', 'sonata.dem', '{"compute_uuid":"5555-66666666-77777777-8888"}', 'Athens', 'Greece', 's0n@t@.dem', null);"
#docker exec -t son-postgres psql -h localhost -U sonatatest -d vimregistry -c "INSERT INTO LINK_VIM (COMPUTE_UUID, NETWORKING_UUID) VALUES ('5555-66666666-77777777-8888', 'eeee-ffffffff-gggggggg-hhhh');"

#wim-adaptor
echo "DEPLOYING WIM ADAPTOR"
docker run -d --name wim-adaptor --net=sonata --network-alias=vim-adaptor -e broker_host=$HOSTNAME -e broker_uri=amqp://guest:guest@$HOSTNAME:5672/%2F -e repo_host=$HOSTNAME -e repo_port=5432 -e repo_user=sonatatest -e repo_pass=sonata  sonatanfv/wim-adaptor:dev /docker-entrypoint.sh

while ! docker exec -t son-postgres psql -h localhost -U postgres -d wimregistry -c "SELECT * FROM WIM"; do
  sleep 2 && echo -n .; # waiting for table creation
done;

while ! docker exec -t son-postgres psql -h localhost -U postgres -d wimregistry -c "SELECT * FROM SERVICED_SEGMENTS"; do
  sleep 2 && echo -n .; # waiting for table creation
done;

#ADD THE WIM
#docker exec -t son-postgres psql -h localhost -U postgres -d wimregistry -c "INSERT INTO WIM (UUID, TYPE, VENDOR, ENDPOINT, USERNAME, PASS, AUTHKEY) VALUES ('1234-12345678-12345678-1234', 'WIM', 'VTN', '10.30.0.13', 'admin', 'admin', null);"
#THIS WIM will serve PoP#1
#docker exec -t son-postgres psql -h localhost -U postgres -d wimregistry -c "INSERT INTO SERVICED_SEGMENTS (NETWORK_SEGMENT, WIM_UUID) VALUES ('1111-22222222-33333333-4444', '1234-12345678-12345678-1234');"

#son-monitor
echo "DEPLOYING MONITORING"
echo "DEPLOYING PUSHGATEWAY"
docker run -d --name son-monitor-pushgateway --net=sonata --network-alias=son-monitor-pushgateway -p 9091:9091 sonatanfv/son-monitor-pushgateway:dev
echo "DEPLOYING PROMETHEUS"
docker run -d --name son-monitor-prometheus --net=sonata --network-alias=son-monitor-prometheus -p 9090:9090 -p 9089:9089 -p 8002:8001 -e RABBIT_URL=$HOSTNAME:5672 -e EMAIL_PASS=czBuQHRAX21vbl9zeXNfMTY= --add-host pushgateway:$HOSTIP --add-host influx:$HOSTIP sonatanfv/son-monitor-prometheus:dev
echo "DEPLOYING MONITORING MANAGER"
docker run -d --name son-monitor-manager --net=sonata --network-alias=son-monitor-manager --add-host postgsql:$HOSTIP --add-host prometheus:$HOSTIP --add-host pushgateway:$HOSTIP -p 8888:8888 -p 8000:8000 -v /tmp/monitoring/mgr:/var/log/apache2 sonatanfv/son-monitor-manager:dev

#son-monitor-probe
docker run -d --name son-mon-vmprobe -e NODE_NAME=TEST-VNF -e PROM_SRV=http://$HOSTNAME:9091/metrics --net="host" --privileged=true  -v /proc:/myhost/proc -v /:/rootfs:ro sonatanfv/son-monitor-vmprobe:dev
docker run -d --name son-monitor-probe -e NODE_NAME=DEMO -e PROM_SRV=http://$HOSTNAME:9091/metrics --net="host" --privileged=true -d -v /var/run/docker.sock:/var/run/docker.sock -v /proc:/myhost/proc -v /:/rootfs:ro sonatanfv/son-monitor-probe:dev
