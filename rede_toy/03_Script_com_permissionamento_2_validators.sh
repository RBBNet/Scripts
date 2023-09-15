# Script com permissionamento (2 validators)
# baixa o diretório
{
projectname="NomeDoProjeto"

PortaBoot="10071"
PortaValidator1="10072"
PortaValidator2="10073"
PortaWriter="10074"






echo "Dica: Usar o node a partir da versão 16"
sleep 3

curl -#SL https://github.com/RBBNet/start-network/releases/download/v0.4.0-permv1/start-network.tar.gz | tar xz
mv start-network $projectname
cd $projectname
# cria os nós especificados.
./rbb-cli node create validator1, boot, writer , validator2
# define as portas do container
./rbb-cli config set nodes.boot.ports+=[\"$(echo $PortaBoot):8545\"]
./rbb-cli config set nodes.validator1.ports+=[\"$(echo $PortaValidator1):8545\"]
./rbb-cli config set nodes.validator2.ports+=[\"$(echo $PortaValidator2):8545\"]
./rbb-cli config set nodes.writer.ports+=[\"$(echo $PortaWriter):8545\"]
# cria o genesis
./rbb-cli genesis create --validators validator1,validator2
# desabilita o discovery nos nós especificados 
./rbb-cli config set nodes.validator1.environment.BESU_DISCOVERY_ENABLED=false
./rbb-cli config set nodes.writer.environment.BESU_DISCOVERY_ENABLED=false
./rbb-cli config set nodes.validator2.environment.BESU_DISCOVERY_ENABLED=false
# ajusta os static nodes apontando para o boot
bootkey=$(./rbb-cli config dump | grep 0x | sed -n '2 p' |sed 's/"publicKey": "0x//' | sed 's/",//')
validator1key=$(./rbb-cli config dump | grep 0x | sed -n '4 p' |sed 's/"publicKey": "0x//' | sed 's/",//')
validator2key=$(./rbb-cli config dump | grep 0x | sed -n '6 p' |sed 's/"publicKey": "0x//' | sed 's/",//')
writerkey=$(./rbb-cli config dump | grep 0x | sed -n '8 p' |sed 's/"publicKey": "0x//' | sed 's/",//')
echo "[
\"enode://$(echo $bootkey)@boot:30303\",
\"enode://$(echo $validator2key)@validator2:30303\"
]" > volumes/validator1/static-nodes.json
echo "[
\"enode://$(echo $bootkey)@boot:30303\"
]" > volumes/writer/static-nodes.json
echo "[
\"enode://$(echo $bootkey)@boot:30303\",
\"enode://$(echo $validator1key)@validator1:30303\"
]" > volumes/validator2/static-nodes.json
./rbb-cli config render-templates
docker-compose up -d validator1 validator2



# permissionamento
cd ..

curl -#SL https://github.com/RBBNet/Permissionamento/releases/download/v1.0.1%2Bmigrations/Permissionamento.tar.gz | tar xz
cd Permissionamento
yarn install
yarn linuxcompiler

# get validator1 container ip
validator1container=$(docker ps --format "{{.Names}}" | grep validator1)
docker inspect $validator1container
validator1ip=$(docker inspect $validator1container | grep IPAddr |  sed -n '3 p' | awk '{ print $2 }' | sed "s/\"//" | sed "s/\"//" | sed "s/,//")

echo "NODE_INGRESS_CONTRACT_ADDRESS=0x0000000000000000000000000000000000009999
ACCOUNT_INGRESS_CONTRACT_ADDRESS=0x0000000000000000000000000000000000008888
BESU_NODE_PERM_ACCOUNT=627306090abaB3A6e1400e9345bC60c78a8BEf57
BESU_NODE_PERM_KEY=c87509a1c067bbde78beb793e6fa76530b6382a4c0241e5e4a9ec0a0f44dc0d3
BESU_NODE_PERM_ENDPOINT=http://$(echo $validator1ip):8545
CHAIN_ID=648629
INITIAL_ALLOWLISTED_NODES=enode://$(echo $bootkey)|0|0x000000000000|Boot|BNDES,enode://$(echo $validator1key)|1|0x000000000000|Validator|BNDES,enode://$(echo $validator2key)|1|0x000000000000|Validator|BNDES,enode://$(echo $writerkey)|2|0x000000000000|Writer|BNDES" > .env
yarn truffle migrate --reset --network besu
cd .. && cd $projectname
docker-compose up -d boot writer
docker-compose restart validator1 validator2


docker-compose logs -f
}
