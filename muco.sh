#!/bin/bash

VERSION="1.0.0"  # basierend auf pegmenu_1.0.9
coin=1

if [ $coin == 1 ] ; then
  coin_name="Pegasus"
  coin_daemon="pegasusd"
  coin_cli="pegasus-cli"
  coin_repo="https://github.com/peg-dev/pegasus/releases/download/V3.0.0.2/peg-linux-daemon-64Bit-v3.0.0.2.tar.gz"
  coin_file="peg-linux-daemon-64Bit-v3.0.0.2.tar.gz"
  coin_unpack="tar xvzf "
  coin_port="1515"
  home_dir="muco"
  coin_user="root"
  coin_datadir_prefix="pegasus"
  coin_confname="pegasus.conf"
fi

new_number=1

ip link | awk -F: '$0 !~ "lo|vir|wl|^[^0-9]"{print $2;getline}' | cut -c 2- >interfaces.txt
network_interfacename=$(head -n 1 interfaces.txt | tail -n 1)

if [ ! -f "/usr/local/bin/$coin_daemon" ] ;  then
  apt-get -y install wget nano htop jq dialog unrar
  apt-get -y install libzmq3-dev
  apt-get -y install libboost-system-dev libboost-filesystem-dev libboost-chrono-dev libboost-program-options-dev libboost-test-dev libboost-thread-dev
  apt-get -y install libevent-dev
  apt -y install software-properties-common
  add-apt-repository ppa:bitcoin/bitcoin -y
  apt-get -y update
  apt-get -y install libdb4.8-dev libdb4.8++-dev
  apt-get -y install libminiupnpc-dev
  rm $coin_file
  wget $coin_repo
  $coin_unpack $coin_file
  cp $coin_daemon /usr/local/bin
  cp $coin_cli /usr/local/bin
  chmod +x  /usr/local/bin/$coin_daemon
  chmod +x  /usr/local/bin/$coin_cli

  if [ ! -f "/usr/local/bin/$coin_daemon" ] ; then
    echo "$coin_daemon installation failed"
    exit 1
  fi

  if [ ! -f "/usr/local/bin/$coin_cli" ] ; then
     echo "$coin_cli installation failed"
     exit 1
  fi

  ufw allow $coin_port
fi

INPUT=/tmp/menu.sh.$$
export NCURSES_NO_UTF8_ACS=1
# Storage file for displaying cal and date command output
OUTPUT=/tmp/output.sh.$$
# get text editor or fall back to vi_editor
vi_editor=${EDITOR-vi}
# trap and delete temp files
trap "rm $OUTPUT; rm $INPUT; exit" SIGHUP SIGINT SIGTERM



###########################################
# make pre-conf  for ipv4 masternode
###########################################
function make_preconf(){
CONFIGFOLDER="/$coin_user/$home_dir/${coin_datadir_prefix}1"
mkdir $CONFIGFOLDER 

# create <coin_confname>
RPCUSER=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w10 | head -n1)
RPCPASSWORD=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w22 | head -n1)
RPCPORT=$(($coin_port+1))
cat << EOF > $CONFIGFOLDER/$coin_confname
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcallowip=127.0.0.1
rpcport=$RPCPORT
listen=0
server=1
daemon=1
port=$coin_port
logintimestamps=1
maxconnections=32
masternode=0
bind=$IPV4
externalip=$IPV4
EOF
} 
##  end of pre_conf #######################

###########################################
# make *.conf
###########################################
function make_conf(){
CONFIGFOLDER="/$coin_user/$home_dir/${coin_datadir_prefix}$new_number"
mkdir $CONFIGFOLDER 

# create <coin_name>.conf
RPCUSER=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w10 | head -n1)
RPCPASSWORD=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w22 | head -n1)
RPCPORT=$(($coin_port+$new_number))

cat << EOF > $CONFIGFOLDER/$coin_confname
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcallowip=127.0.0.1
rpcport=$RPCPORT
listen=1
server=1
daemon=1
port=$coin_port
logintimestamps=1
maxconnections=32
masternode=1
bind=[$IP]
externalip=[$IP]
masternodeprivkey=$privkey
EOF
} 
##  end of make_conf#######################
###########################################
# get privkey
###########################################
function get_privkey(){
privkey=$($coin_cli -conf=/$coin_user/$home_dir/${coin_datadir_prefix}1/$coin_confname -datadir=/$coin_user/$home_dir/${coin_datadir_prefix}1  createmasternodekey)
#echo "privkey: $privkey"
#echo "<enter>"
#read
}  
## end of get_privkey#######################
###########################################
# get ipv6 address
###########################################
function get_ip(){

rm user.txt
touch user.txt  
rm ip_in_use.txt
touch ip_in_use.txt
folder=( $(find /$coin_user/$home_dir/${coin_datadir_prefix}*  -maxdepth 0  -type d) )
for i in "${folder[@]}"; do
  IFS="_"
  set -- $i
  echo "$1"  >> user.txt
done

fs=$(stat -c %s user.txt)
if  [ $fs -gt 0 ] ;  then 
  while read line
  do
    conf=$line/$coin_confname
    lc1=$(wc -l $conf | cut -d " " -f 1)
    ((lc1++))
    for((i=1; i<$lc1; i++))
    do
      z1=$(head -n $i $conf | tail -n 1)
      if [[ $z1 == *"bind"* ]]; then
         echo "$z1"  >> ip_in_use.txt
      fi
    done

    #IP=$(head -n 12 $line/$coin_datadir/$coin_confname | tail -n 1)
    #echo "$IP"  >> ip_in_use.txt
  done < <(cat user.txt)
  #cat ip_in_use.txt
fi

#echo "press enter"
#read


ip addr show $network_interfacename | grep -vw "inet" | grep "global" | grep -w "inet6" | cut -d/ -f1 | awk '{ print $2 }'  >ipv6_addresses.txt

i=1
ersatz_ip="NoIP"
clear
###  list of ipv6 addresses
#echo "Free IPv6 addresses:"
lc1=$(wc -l ipv6_addresses.txt | cut -d " " -f 1)
((lc1++))
for((i=1; i<$lc1; i++))
do
   z1=$(head -n $i ipv6_addresses.txt | tail -n 1)
   #echo "$i. Zeile ipv6_addresses:  $z1"
   lc2=$(wc -l ip_in_use.txt | cut -d " " -f 1)
   ((lc2++))
   in_use=0

   len=$(echo -n $z1 | wc -m)
   #echo "Länge von z1 ($z2) = $len"
   if [ $len -lt 5 ] ; then
      in_use=1
   fi

   for((j=1; j<$lc2; j++))
   do
     z2=$(head -n $j ip_in_use.txt | tail -n 1)
     #echo "  $j. Zeile  ip_in_use.txt: $z2"
     if [[ $z2 == *"$z1"* ]]; then
        #echo "$z1 is already in use"
        in_use=1
     fi

   done   ## end of j-loop ##

   if [ $in_use == 0 ] ; then
        #echo "$i: $z1"
        ersatz_ip=$z1
   fi

done
echo 
### end of list ####

if [ $ersatz_ip == "NoIP" ] ; then
  echo "Sorry, you dont have any free IPv6 address."
  IP="NoIP"
  echo "Press ENTER to continue."
  read
else
  echo "Free IPv6  [$ersatz_ip] will be taken"
  IP=$ersatz_ip
fi

}   
#####  end  of get_ip   ###################
###########################################
# install new masternode
###########################################
function new_masternode(){
clear
get_ip
if [ $IP == "NoIP" ] ; then
  return
fi

#echo "Ende get ip"
#echo "IP: $IP"
#echo "press  enter"
#read

# set new linux user
rm user.txt
touch user.txt
folder=( $(find /$coin_user/$home_dir/${coin_datadir_prefix}*  -maxdepth 0  -type d) )
for i in "${folder[@]}"; do
  IFS="_"
  set -- $i
  echo "$1"  >> user.txt
done
i=$(wc -l user.txt | cut -d " " -f 1)
#clear
#echo "$i user"
((i++))
new_number=$i
#new_user=${coin_name}$i
#new_user=${new_user,,}
#echo "next user: $new_user"

new_folder="/$coin_user/$home_dir/${coin_datadir_prefix}$new_number"
if  [ -d $new_folder ] ; then
  echo "Your data are inconsistent. New data folder already exists."
  echo "Press enter to abort installing new masternode"
  exit 1
fi

privkey="PRIVKEY"
get_privkey

# make  coin_name.conf
make_conf

cp -r -v  /$coin_user/$home_dir/${coin_datadir_prefix}1/blocks /$coin_user/$home_dir/${coin_datadir_prefix}$new_number/blocks 
cp -r -v  /$coin_user/$home_dir/${coin_datadir_prefix}1/chainstate /$coin_user/$home_dir/${coin_datadir_prefix}$new_number/chainstate
cp -r -v  /$coin_user/$home_dir/${coin_datadir_prefix}1/database /$coin_user/$home_dir/${coin_datadir_prefix}$new_number/database
cp -r -v  /$coin_user/$home_dir/${coin_datadir_prefix}1/sporks /$coin_user/$home_dir/${coin_datadir_prefix}$new_number/sporks
cp -r -v  /$coin_user/$home_dir/${coin_datadir_prefix}1/zerocoin /$coin_user/$home_dir/${coin_datadir_prefix}$new_number/zerocoin
cp   -v /$coin_user/$home_dir/${coin_datadir_prefix}1/peers.dat /$coin_user/$home_dir/${coin_datadir_prefix}$new_number/peers.dat


# create /ect/systemd/system service 
cat << EOF > /etc/systemd/system/${coin_datadir_prefix}$new_number.service
[Unit]
Description=${coin_datadir_prefix}$new_number service
After=network.target
[Service]
User=$coin_user
Group=$coin_user
Type=forking
ExecStart=/usr/local/bin/$coin_daemon -conf=/$coin_user/$home_dir/${coin_datadir_prefix}$new_number/$coin_confname -datadir=/$coin_user/$home_dir/${coin_datadir_prefix}$new_number
ExecStop=-/usr/local/bin/$coin_cli  -conf=/$coin_user/$home_dir/${coin_datadir_prefix}$new_number/$coin_confname -datadir=/$coin_user/$home_dir/${coin_datadir_prefix}$new_number stop
Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5
[Install]
WantedBy=multi-user.target
EOF


 echo "Please wait...service is registered and starting"
 systemctl daemon-reload
 sleep 3
 systemctl enable ${coin_datadir_prefix}$new_number.service   
 sleep 5
 systemctl start ${coin_datadir_prefix}$new_number.service

 echo
 echo "Choose your own alias for $coin_name masternode number $new_number on this VPS. Then put the line below in your masternode.conf on your PC"
 echo 
 echo your-alias-here [$IP]:$coin_port $privkey
 echo
 echo "Then goto your PC wallet, make a new address and send your collateral payment.  Add the txid and outputindex to the line"
 echo "Save the file and restart your wallet on the PC."
 echo "Goto to Debug Console and type:" 
 echo 
 echo "startmasternode alias false your-alias-here"
 echo
 echo "Press <ENTER> if all done."
 read input
 ALIAS="/$coin_user/$home_dir/${coin_datadir_prefix}$new_number"
}
### End of functions ##################
### Start of main    ##################
### check for first IPv4 masternode ###

IPV4=$(ip addr show $network_interfacename | grep -vw "inet6" | grep "global" | grep -w "inet" | cut -d/ -f1 | awk '{ print $2 }')

if [ -f /$coin_user/$home_dir/${coin_datadir_prefix}1/$coin_confname ] ; then
	echo "IPv4 masternode already installed."
        echo "If menu is not starting, press CTRL C and then"
        echo "type:  apt install dialog"
else
  echo "IPv4 masternode not yet installed. Please wait...installation is going on."
  new_number=1
  mkdir "/$coin_user/$home_dir"
  make_preconf
  echo "Please wait 10 seconds..."
  $coin_daemon -conf=/$coin_user/$home_dir/${coin_datadir_prefix}$new_number/$coin_confname -datadir=/$coin_user/$home_dir/${coin_datadir_prefix}$new_number
  sleep 10
  privkey="PRIVKEY"
  get_privkey
  echo "Please wait 10 seconds..."
  $coin_cli -conf=/$coin_user/$home_dir/${coin_datadir_prefix}$new_number/$coin_confname -datadir=/$coin_user/$home_dir/${coin_datadir_prefix}$new_number stop
  sleep 10
  RPCUSER=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w10 | head -n1)
  RPCPASSWORD=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w22 | head -n1)
  RPCPORT=$(($coin_port+1))

cat << EOF > /$coin_user/$home_dir/${coin_datadir_prefix}1/$coin_confname
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcallowip=127.0.0.1
rpcport=$RPCPORT
listen=1
server=1
daemon=1
port=$coin_port
logintimestamps=1
maxconnections=32
masternode=1
bind=$IPV4
externalip=$IPV4
masternodeprivkey=$privkey
EOF


# create /ect/systemd/system service 
new_number=1    
cat << EOF > /etc/systemd/system/${coin_datadir_prefix}$new_number.service
[Unit]
Description=${coin_datadir_prefix}$new_number Service
After=network.target
[Service]
User=$coin_user
Group=$coin_user
Type=forking
ExecStart=/usr/local/bin/$coin_daemon -conf=/$coin_user/$home_dir/${coin_datadir_prefix}$new_number/$coin_confname -datadir=/$coin_user/$home_dir/${coin_datadir_prefix}$new_number
ExecStop=-/usr/local/bin/$coin_cli  -conf=/$coin_user/$home_dir/${coin_datadir_prefix}$new_number/$coin_confname -datadir=/$coin_user/$home_dir/${coin_datadir_prefix}$new_number stop
Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5
[Install]
WantedBy=multi-user.target
EOF

echo "Please wait...service is registered and starting"
systemctl daemon-reload
sleep 3
systemctl enable ${coin_datadir_prefix}$new_number.service   
sleep 5
systemctl start ${coin_datadir_prefix}$new_number.service

echo
echo "Choose your own alias for IPv4 masternode and put the line below in your masternode.conf on your PC"
echo 
echo  your-ipv4-alias-here $IPV4:1515 $privkey
echo
echo "Then goto your PC wallet, make a new address and send your collateral payment.  Add the txid and outputindex to the line"
echo "Save the file and restart your wallet on the PC."
echo "Goto to Debug Console and type:" 
echo 
echo "startmasternode alias false your-alias-name"
echo
echo "Press <ENTER> if all done."
read input  

fi   
###  end of  check for first IPv4 masternode  ###

ALIAS="/$coin_user/$home_dir/${coin_datadir_prefix}$new_number"


#
# set infinite loop
#
while true
do

sys_status="(stopped)"
sys_code=0
A="$(cut -d'/' -f4 <<<$ALIAS)"
#echo "Systemstatus A=$A"
systemctl status $A >systemctl_status.txt
s=$(grep -c  "(running)" systemctl_status.txt)
if [ $s == 1 ] ; then
  sys_status="(started)"
  sys_code=1
fi

A="$(cut -d'/' -f4 <<<$ALIAS)" 


### display main menu ###
dialog --clear  \
--title "Pegasus Menu $VERSION [ Masternode: $A ]" \
--menu "" 20 80 20 \
1  "Server Getinfo" \
2  "Server Masternode Status" \
3  "Start/Stop Masternode $sys_status" \
4  "Edit $ALIAS/$coin_confname" \
5  "Select masternode" \
6  "Install IPv6 masternode" \
7  "Masternode resync" \
8  "Overview Masternodes" \
9  "Show Services" \
A  "Show IPs" \
0  "Exit" 2>"${INPUT}"

menuitem=$(<"${INPUT}")


# ALIAS = /$coin_user/$home_dir/$coin_datadir
case $menuitem in
        1) rm ~/mnstatus.txt   # getinfo
           rm ~/failed.txt
           $coin_cli  -conf=$ALIAS/$coin_confname -datadir=$ALIAS  getinfo >> mnstatus.txt 2> failed.txt
           #echo -e "Press <ENTER> to continue "
           #read input
           fs=$(stat -c %s mnstatus.txt)
           if  [ $fs -gt 0 ] ;  then 
             dialog --textbox "mnstatus.txt" 0 0
           fi
           fs=$(stat -c %s failed.txt)
           if  [ $fs -gt 0 ] ;  then
             dialog --textbox "failed.txt" 0 0
           fi
           ;;
        2) rm ~/mnstatus.txt
           rm ~/failed.txt
             $coin_cli  -conf=$ALIAS/$coin_confname -datadir=$ALIAS  masternode status >> mnstatus.txt 2> failed.txt
           fs=$(stat -c %s mnstatus.txt)
           if  [ $fs -gt 0 ] ;  then 
             dialog --textbox "mnstatus.txt" 0 0
           fi
           fs=$(stat -c %s failed.txt)
           if  [ $fs -gt 0 ] ;  then
             dialog --textbox "failed.txt" 0 0
           fi
           #echo -e "Press <ENTER> to continue "
           #read input
           ;;
        3) cd ~
           if [ $sys_code == 0 ] ; then
             systemctl start $A
           else 
             systemctl stop $A
           fi 
           ;;
        4) nano "${ALIAS}/$coin_confname"
           ;;
        5) rm user.txt
           touch user.txt
           folder=( $(find /$coin_user/$home_dir/${coin_datadir_prefix}*  -maxdepth 0  -type d) )
           for i in "${folder[@]}"; do
            IFS="_"
            set -- $i
            echo "$1"  >> user.txt
           done
           declare -a array
           i=1 #Index counter for adding to array
           j=1 #Option menu value generator
           while read line
           do
             array[ $i ]=$j
             (( j++ ))
             array[ ($i + 1) ]=$line
             (( i=($i+2) ))
          done < <(cat user.txt)

          #Define parameters for menu
          TERMINAL=$(tty) #Gather current terminal session for appropriate redirection
          HEIGHT=20
          WIDTH=76
          CHOICE_HEIGHT=16
          BACKTITLE=""
          TITLE="Select a masternode"
          MENU=""

          #Build the menu with variables & dynamic content
          CHOICE=$(dialog --clear \
                 --backtitle "$BACKTITLE" \
                 --title "$TITLE" \
                 --menu "$MENU" \
                 $HEIGHT $WIDTH $CHOICE_HEIGHT \
                 "${array[@]}" \
                 2>&1 >$TERMINAL)
          i=$CHOICE
          k=$(($i+$i))
          ALIAS=${array[ $k ]}
          ;;
       6) dialog --title "Install new Masternode" \
          --backtitle "" \
          --yesno "Are you sure you want to install new Masternode ?" 7 40

          # Get exit status
          # 0 means user hit [yes] button.
          # 1 means user hit [no] button.
          # 255 means user hit [Esc] key.
          response=$?
          case $response in
            0) new_masternode  ;;
          esac
          ;;
       7) dialog --title "Masternode  -resync" \
          --backtitle "" \
          --yesno "Are you sure you want to resnyc Masternode (rebuild blocks from scratch) ?" 7 40

          # Get exit status
          # 0 means user hit [yes] button.
          # 1 means user hit [no] button.
          # 255 means user hit [Esc] key.
          response=$?
          case $response in
            0) systemctl stop $A
               rm -r -v  $ALIAS/blocks 
               rm -r -v  $ALIAS/chainstate 
               rm -r -v  $ALIAS/database
               rm -r -v  $ALIAS/sporks
               rm -r -v  $ALIAS/zerocoin
               systemctl start $A
               ;;
          esac
          ;;
       8) echo "Overview Masternodes Status" >overview.txt
           echo "---------------------------" >>overview.txt 
           rm user.txt
           touch user.txt
           folder=( $(find /$coin_user/$home_dir/${coin_datadir_prefix}*  -maxdepth 0  -type d) )
           for i in "${folder[@]}"; do
            IFS="_"
            set -- $i
            echo "$1"  >> user.txt
           done
           while read line
           do
             echo $line
             A="$(cut -d'/' -f4 <<<$line)"
             echo $A
             systemctl status $A >systemctl_status.txt
             s=$(grep -c  "(running)" systemctl_status.txt)
             sys_status="stopped"      
             if [ $s == 1 ] ; then
                sys_status="started"
             fi
             echo "$A: $sys_status" >>overview.txt
           done < <(cat user.txt)
           #echo "enter"
           #read
           dialog --textbox "overview.txt" 0 0
           ;; 
        9) rm -f services.txt
           folder=( $(find /etc/systemd/system/*.service  -maxdepth 0  -type f) )
           for i in "${folder[@]}"; do
           IFS="_"
           set -- $i
           echo "$1" >> services.txt
           done
           dialog --textbox "services.txt" 0 0  
           ;;
        A) echo "IPV4 Address: ($network_interfacename)" > ip_address
           ip addr show $network_interfacename | grep -vw "inet6" | grep "global" | grep -w "inet" | cut -d/ -f1 | awk '{ print $2 }'  >> ip_address 
           echo " " >>ip_address
           echo "IPV6 Address:" >> ip_address
           ip addr show $network_interfacename | grep -vw "inet" | grep "global" | grep -w "inet6" | cut -d/ -f1 | awk '{ print $2 }'  >> ip_address
           dialog --textbox "ip_address" 0 0
           ;;
        0) break;;
esac

done

# if temp files found, delete em
[ -f $OUTPUT ] && rm $OUTPUT
[ -f $INPUT ] && rm $INPUT 
