#!/bin/bash

# script per instal·lar/desplegar PORTAFIB de manera desatesa
# està pensat per JBOSS 5.1 amb jre1.6
#
# no és necessari editar res d'aquest fitxer. en executar-se
# comprova si existeix un fitxer de configuració i el crea
# si no el troba.
#
# els fitxers de propietats se crean FORA del directori base
# i no es modifiquen si ja exiteixen.
#
# si establim la variable PAUSE a qualsevol valor diferent
# de 0 (zero), l'script anirà aturant després de cada passa
#
# àngel "mussol" bosch - 2018
#

VER="0.2"

# cream un log amb la sortida de tot l'script (dona problemes amb
# els retorns de carro en cas d'esperar entrada per STDIN)
# DATA=`date +%d-%m-%Y-%H%M%S` && FLOG="${0##*/}" && FLOG="${FLOG%.*}"
# exec > >(tee -i "${FLOG}-${DATA}.log")
# exec 2>&1 | tee "${FLOG}-${DATA}.log"

echo "`date` - $0 - v$VER"

# directori actual
CDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# petita funció d'error"
check_err(){
if [ "$1" == "0" ]; then
    E="OK"
    # echo "OK"
else
    echo "S'ha produït un error"
    exit 1
fi
}

# funció de pausa
if [ "$PAUSE" == "" ]; then
    PAUSE="0"
fi
pause(){
if [ "$PAUSE" != "0" ]; then
    echo "Polsa intro per continuar..."
    read ENJOANPETITQUANBALLABALLABALLABALLA
fi
}

# fitxer de configuració d'aquest mateix script
# cercam el fitxer de propietats al mateix directori on hi ha el script
# i si no existeix el cream
f_conf(){
    F="$(basename $0)"
    FCONF="${CDIR}/${F%.*}.conf"
    # echo "### comprovant fitxer de configuració [$FCONF]"
    if [ ! -e "$FCONF" ]; then
	echo "No s'ha trobat el fitxer de configuració"
	echo "S'ha creat el fitxer [$FCONF]"
	( cat << 'EOF'

####
#### VARIABLES GENERALS
####

# entitat (normalment el nom de l'ajuntament/entitat)
ENTITAT="ticmallorca"
# directori arrel de tota la instal·lació
DIR_BASE="/opt/proves/portafib-$ENTITAT"
# usuari amb el que s'executarà el servei
USUARI="portafib"
# nom de la instància
INSTANCIA="$ENTITAT"
# nom del servidor. pot esser també una IP, però hauria d'esser
# el FQDN que se resol públicament
SERVIDOR="portafibpre01.test.com"
# SERVIDOR="172.26.67.167"

####
#### PAQUETS
####

# directori general dels paquets
DIR_PAQUETS="/opt/paquets"

# ruta del paquet java i nom del directori que se crea quan se descoprimeix
PAQUET_JAVA_JDK="${DIR_PAQUETS}/jdk-6u45-linux-x64.bin"
DIR_JAVA_JDK="jdk1.6.0_45"
HTTP_PAQUET_JAVA_JDK="http://mirrors.linuxeye.com/jdk/jdk-6u45-linux-x64.bin" # OPCIONAL: URL des d'on baixar el paquet

# ruta del paquet JBoss i nom del directori que se crea quan se descoprimeix
PAQUET_JBOSS="${DIR_PAQUETS}/jboss-5.1.0.GA.zip"
DIR_JBOSS="jboss-5.1.0.GA"
HTTP_PAQUET_JBOSS="https://downloads.sourceforge.net/project/jboss/JBoss/JBoss-5.1.0.GA/jboss-5.1.0.GA.zip" 	# OPCIONAL: URL des d'on baixar el paquet

# biblioteques extra
# ORACLE_JAR="${DIR_PAQUETS}/ojdbc14-10.2.0.3.0.jar"	# comentar o deixar en blanc si no se fa servir
# HTTP_ORACLE_JAR="http://central.maven.org/maven2/com/oracle/ojdbc14/10.2.0.3.0/ojdbc14-10.2.0.3.0.jar" 	# OPCIONAL: URL des d'on baixar el paquet
POSTRESQL_JAR="${DIR_PAQUETS}/postgresql-9.3-1102-jdbc3.jar"	# comentar o deixar en blanc si no se fa servir
HTTP_POSTRESQL_JAR="http://central.maven.org/maven2/org/postgresql/postgresql/9.3-1102-jdbc3/postgresql-9.3-1102-jdbc3.jar" # OPCIONAL: URL des d'on baixar el paquet

# biblioteca jboss-metadata.jar
PAQUET_METADATA="${DIR_PAQUETS}/jboss-metadata.jar"
HTTP_PAQUET_METADATA="https://repository.jboss.org/nexus/content/repositories/root_repository/jboss/metadata/1.0.6.GA-brew/lib/jboss-metadata.jar"

# biblioteca CXF
PAQUET_CXF="${DIR_PAQUETS}/jbossws-cxf-3.4.1.GA.zip"
HTTP_PAQUET_CXF="http://download.jboss.org/jbossws/jbossws-cxf-3.4.1.GA.zip"

# altres fitxers
SCRIPT_INICI="/etc/init.d/jboss-portafib-${ENTITAT}"

# ears
EAR_PORTAFIB="${DIR_PAQUETS}/portafib.ear"
HTTP_EAR_PORTAFIB=""

EOF
	) >> "$FCONF"
	exit 1
    fi

    # llegim el fitxer de configuració
    . "$FCONF"

    # comprovam que s'hagi configurat mínimament
    if [ "$ENTITAT" == "" ]; then
	echo "ERROR: configuració errònia. Revisa el fitxer [$FCONF]"
	exit 1
    fi
#    pause
}
# f_conf

# comprovacions vàries
precheck(){
echo "### comprovacions de sistema: "
if ! id $USUARI > /dev/null ; then
    echo "ERROR: No s'ha trobat l'usuari $USUARI"
    exit 1
fi

# eines de sistema
if ! type -t wget > /dev/null ; then
    # echo "ERROR: aquest script necessita wget per funcionar"
    # echo "per favor instal·la wget amb les eines de sistema"
    # exit 1
    DEBS="$DEBS wget"
    RPMS="$RPMS wget"
fi


# per la versió 5.1 de JBoss se necessiten uns paquets
# de sistema

# debian/ubuntu
DEBS="$DEBS libxtst6 libxi6 ant"
if type -t dpkg > /dev/null ; then
    for d in $DEBS ; do
	echo "DEBUG: comprovant $d"
	dpkg -l $d > /dev/null 2>&1
	if [ "$?" == "1" ]; then
    	    export DEBIAN_FRONTEND=noninteractive
    	    apt-get -q -y install $d
	fi
    done
fi

# redhat/centos
RPMS="$RPMS ant"
## NO ESTÀ PROVAT!!!
if type -t yum > /dev/null ; then
    # dpkg -l | grep -q libxtst6
    rpm -qa | grep -q libxtst6
    if [ "$?" != "0" ]; then
	yum install libXext.i686
    fi
fi

pause
}
# precheck


paquets(){
# comprovam si existeix el directori base
if [ -e "$DIR_BASE" ]; then
    echo "ATENCIÓ:	El directori [$DIR_BASE] ja existeix"
    echo "		Elimineu el directori o configurau-ne un altre al"
    echo "		fitxer [$FCONF]"
    exit 1
fi

# dir base
echo -n "### directori base: "
mkdir -vp "$DIR_BASE"
check_err "$?"
cd "$DIR_BASE"

# dir paquets
mkdir -vp "${DIR_PAQUETS}"
check_err "$?"

# java jdk
echo -n "### instal·lant java: "
if [ ! -e "$PAQUET_JAVA_JDK" ]; then
    if [ "$HTTP_PAQUET_JAVA_JDK" == "" ]; then
	echo "ERROR: No s'ha trobat el paquet [$PAQUET_JAVA_JDK]"
	exit 1
    else
	echo "### baixant el paquet des de [$HTTP_PAQUET_JAVA_JDK]"
	# oracle és molt torracollons per baixar directament coses
	# wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/6u45-b06/jdk-6u45-linux-x64.bin
	wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" -nv -O "$PAQUET_JAVA_JDK" "$HTTP_PAQUET_JAVA_JDK"
	check_err "$?"
    fi
fi

chmod +x "$PAQUET_JAVA_JDK"
# echo "yes" | "$PAQUET_JAVA_JDK" #>/dev/null
"$PAQUET_JAVA_JDK" > /dev/null
check_err "$?"
# ln -vs "${DIR_BASE}/${DIR_JAVA_JDK}" "${DIR_BASE}/java"
ln -vs "${DIR_JAVA_JDK}" "java"


# jboss
echo -n "### instal·lant JBoss: "
if [ ! -e "$PAQUET_JBOSS" ]; then
    if [ "$HTTP_PAQUET_JBOSS" == "" ]; then
	echo "ERROR: No s'ha trobat el paquet [$PAQUET_JBOSS]"
	exit 1
    else
	echo "### baixant el paquet des de [$HTTP_PAQUET_JBOSS]"
	wget --no-check-certificate --no-cookies -nv -O "$PAQUET_JBOSS" "$HTTP_PAQUET_JBOSS"
	check_err "$?"
    fi
fi

unzip -q "${PAQUET_JBOSS}"
# tar -xzf "${PAQUET_JBOSS}"
check_err "$?"
ln -vs "${DIR_JBOSS}" "jboss"

# donam execució a run.sh
chmod +x "${DIR_BASE}/jboss/bin/run.sh"

# feim propietari a l'usuari especificat
chown -R "$USUARI" "$DIR_BASE"

pause
}

instancia(){
# configurant instància
echo -n "### configurant instància $INSTANCIA [${DIR_BASE}/jboss/server/${INSTANCIA}]: "
case $INSTANCIA in
    all|default|minimal|standard)
	echo "OK"
    ;;
    *)
	cp -pr "${DIR_BASE}/jboss/server/default" "${DIR_BASE}/jboss/server/${INSTANCIA}"
	echo "OK"
	chown -R "$USUARI" "${DIR_BASE}/jboss/server/${INSTANCIA}"
    ;;
esac
pause
}

script_inici(){
# script inici
if [ -e "$SCRIPT_INICI" ]; then
    echo "ERROR: Ja existeix un script d'inici per a l'entitat [$ENTITAT]"
    echo "	$SCRIPT_INICI"
    exit 0
fi

echo -n "### creant script d'inici [$SCRIPT_INICI]: "
(
cat << 'EOF'
#!/bin/bash
#
# JBoss Control Script
#
# chkconfig: 3 80 20
# description: JBoss EJB Container
# 
# To use this script
# run it as root - it will switch to the specified user
# It loses all console output - use the log.
#
# Here is a little (and extremely primitive) 
# startup/shutdown script for RedHat systems. It assumes 
# that JBoss lives in /usr/local/jboss, it's run by user 
# 'jboss' and JDK binaries are in /usr/local/jdk/bin. All 
# this can be changed in the script itself. 
# Bojan 
#
# Either amend this script for your requirements
# or just ensure that the following variables are set correctly 
# before calling the script

# [ #420297 ] JBoss startup/shutdown for RedHat

export DISPLAY=:0.0
export JAVA_OPTS="-Djava.awt.headless=true -Xms512m -Xmx1024m -XX:MaxPermSize=256m"

#define where jboss is - this is the directory containing directories log, bin, conf etc
JBOSS_HOME="/opt/jboss"
JAVA_HOME="/opt/java"

#make java is on your path
JAVAPTH="$JAVA_HOME/bin"

# Variables nostres
# instancia
JBOSSCONF="default"

# usuari
JBOSSUS="root"

# ip des de la que escolta
JBOSSHOST=${JBOSSHOST:-"0.0.0.0"}

# Adreça multicast per defecte de jboss(no està suportat a la versió 3.2.8)
#JBOSSMC=${JBOSSMC:-"228.1.2.3"}
# JBOSSMC=${JBOSSMC:-"228.1.2.50"}

#Partició de Cluster
#JBOSSPART=${JBOSSPART:-"PartProduccio"}

#define the classpath for the shutdown class
JBOSSCP=${JBOSSCP:-"$JBOSS_HOME/bin/shutdown.jar:$JBOSS_HOME/client/jnet.jar"}

#define the script to use to start jboss
#JBOSSSH=${JBOSSSH:-"$JBOSS_HOME/bin/run.sh -c $JBOSSCONF -b $JBOSSHOST -u $JBOSSMC -g $JBOSSPART"}
# JBOSSSH=${JBOSSSH:-"$JBOSS_HOME/bin/run.sh -c $JBOSSCONF -b $JBOSSHOST -u $JBOSSMC"}
JBOSSSH=${JBOSSSH:-"$JBOSS_HOME/bin/run.sh -c $JBOSSCONF -b $JBOSSHOST"}

if [ -n "$JBOSS_CONSOLE" -a ! -d "$JBOSS_CONSOLE" ]; then
  # ensure the file exists
  touch $JBOSS_CONSOLE
fi
 
if [ -n "$JBOSS_CONSOLE" -a ! -f "$JBOSS_CONSOLE" ]; then
  echo "WARNING: location for saving console log invalid: $JBOSS_CONSOLE"
  echo "WARNING: ignoring it and using /dev/null"
  JBOSS_CONSOLE="/dev/null"
fi

#define what will be done with the console log
JBOSS_CONSOLE=${JBOSS_CONSOLE:-"/dev/null"}

if [ -z "`echo $PATH | grep $JAVAPTH`" ]; then
  export PATH=$PATH:$JAVAPTH
fi

#define the user under which jboss will run, or use RUNASIS to run as the current user
#JBOSSUS=${JBOSSUS:-"jboss"}
JBOSSUS=${JBOSSUS:-"RUNASIS"}

CMD_START="PATH=\"$PATH\" ; cd $JBOSS_HOME/bin; $JBOSSSH" 
CMD_STOP="java -classpath $JBOSSCP org.jboss.Shutdown --shutdown -s $JBOSSHOST"

if [ "$JBOSSUS" = "RUNASIS" ] || [ "$JBOSSUS" = "root" ]; then
  SUBIT=""
else
  SUBIT="su - $JBOSSUS -c "
fi

if [ ! -d "$JBOSS_HOME" ]; then
  echo JBOSS_HOME does not exist as a valid directory : $JBOSS_HOME
  exit 1
fi

jstatus(){
    [ "$JBOSSUS" == "RUNASIS" ] && JBOSSUS="root"
    JPID=`pgrep -u $JBOSSUS -f "java.*$JBOSSCONF"`
    if [ -z "$JPID" ]; then
	echo "La instancia $JBOSSCONF de JBoss no s'esta executant"
	return 1
    else
	echo "JBoss executant-se amb usuari [$JBOSSUS] i PID: $JPID"
    fi
    export JPID
}

stop_wait(){
    STOP_PROC="$1"
    WAIT_COUNT="30"
    echo -n "stopping process $STOP_PROC: "
    while [ $WAIT_COUNT != "0" ]; do
	kill $STOP_PROC 2> /dev/null
	pgrep -f "java.*$JBOSSCONF" > /dev/null
	if [ "$?" != "0" ]; then
    	    break
	else
    	    echo -n "."
    	    sleep 1
	fi
    done
    echo " OK"
}

case "$1" in
start)
    jstatus && exit 2
    echo -n "Iniciant instancia ${JBOSSCONF}: "
    echo CMD_START = $CMD_START

    cd $JBOSS_HOME/bin
    if [ -z "$SUBIT" ]; then
        eval $CMD_START >${JBOSS_CONSOLE} 2>&1 &
    else
        $SUBIT "$CMD_START >${JBOSS_CONSOLE} 2>&1 &" 
    # $SUBIT "$CMD_START &" 
    fi
    sleep 5
    jstatus
    ;;
stop)
    jstatus || exit 3
    echo "Aturant instancia $JBOSSCONF"
    stop_wait $JPID
    ;;
restart)
    $0 stop
    $0 start
    ;;
status)
    jstatus
    ;;
*)
    echo "usage: $0 (start|stop|restart|status|help)"
esac

EOF
) >> "$SCRIPT_INICI"

sed -i "s;^JBOSS_HOME=.*;JBOSS_HOME=\"${DIR_BASE}/jboss\";" "$SCRIPT_INICI"
sed -i "s;^JAVA_HOME=.*;JAVA_HOME=\"${DIR_BASE}/java\";" "$SCRIPT_INICI"
sed -i "s;^JBOSSCONF=.*;JBOSSCONF=\"${INSTANCIA}\";" "$SCRIPT_INICI"
sed -i "s;^JBOSSUS=.*;JBOSSUS=\"${USUARI}\";" "$SCRIPT_INICI"

chmod 755 "$SCRIPT_INICI"
echo "OK"
pause
}
# script_inici


lib_extras(){

# biblioteques commons d'apache
echo -n "### copiant JBOSS_METADATA_JAR: "
if [ ! -e "$PAQUET_METADATA" ]; then
	if [ "$HTTP_PAQUET_METADATA" == "" ]; then
	    echo "ERROR: No s'ha trobat el paquet [$PAQUET_METADATA]"
	    exit 1
	else
	    echo "### baixant el paquet des de [$HTTP_PAQUET_METADATA]"
	    wget --no-check-certificate --no-cookies -nv -O "$PAQUET_METADATA" "$HTTP_PAQUET_METADATA"
	    check_err "$?"
	fi
fi
cp -v "$PAQUET_METADATA" "${DIR_BASE}/jboss/common/lib/"
cp -v "$PAQUET_METADATA" "${DIR_BASE}/jboss/client/"

echo -n "### configurant CXF: "
# necessitam la variable del home de java per executar ant
export JAVA_HOME="${DIR_BASE}/java"
if [ ! -e "$PAQUET_CXF" ]; then
	if [ "$HTTP_PAQUET_CXF" == "" ]; then
	    echo "ERROR: No s'ha trobat el paquet [$PAQUET_CXF]"
	    exit 1
	else
	    echo "### baixant el paquet des de [$HTTP_PAQUET_CXF]"
	    wget --no-check-certificate --no-cookies -nv -O "$PAQUET_CXF" "$HTTP_PAQUET_CXF"
	    check_err "$?"
	fi
fi
# generam un fitxer temporal i descomprimim el cxf
DCXFTEMP=`mktemp -d`
cd "$DCXFTEMP"
unzip -q "$PAQUET_CXF"
cd jbossws-cxf-bin-dist/

echo "jboss510.home=${DIR_BASE}/jboss
jbossws.integration.target=jboss510
jboss.server.instance=default
jboss.bind.address=localhost
javac.debug=no
javac.deprecation=no
javac.fail.onerror=yes
javac.verbose=no" > ant.properties
ant -q deploy-jboss510
rm -rf "$DCXFTEMP"

cd "$DIR_BASE"
pause

}


conf_jboss(){
# configuracions dins del jboss

echo -n "### configurant directori de desplegament: "
# F_DESPLEGAMENT="${DIR_BASE}/jboss/server/${INSTANCIA}/conf/jboss-service.xml"
F_DESPLEGAMENT="${DIR_BASE}/jboss/server/${INSTANCIA}/conf/bootstrap/profile.xml"
# <value>${jboss.server.home.url}deployportafib</value>
grep deployportafib "$F_DESPLEGAMENT"
if [ "$?" != "0" ]; then
    sed -i 's;url}deploy</value>;url}deploy</value>\n\t\t<value>${jboss.server.home.url}deployportafib</value>;' "$F_DESPLEGAMENT"
    mkdir "${DIR_BASE}/jboss/server/${INSTANCIA}/deployportafib"
fi
echo "OK"

echo "DEBUG: [$LINEO]" && exit 1

# opcions de java dins el jboss
echo -n "### configurant opcions de java: "
echo 'export DISPLAY=":0.0"' >> "${DIR_BASE}/jboss/bin/run.conf"
echo 'JAVA_OPTS="$JAVA_OPTS -Djava.awt.headless=true -Xmx512m -Xoss128m -XX:MaxPermSize=128m"' >> "${DIR_BASE}/jboss/bin/run.conf"
JAVA_PATH="${DIR_BASE}/java/bin/java"
echo "JAVA=\"$JAVA_PATH\"" >> "${DIR_BASE}/jboss/bin/run.conf"
echo "OK"

# Indicar la ubicació dels fitxers de propietats. 
#F_DS="${DIR_BASE}/jboss/server/${INSTANCIA}/conf/jboss-service.xml"
F_DS="${DIR_BASE}/jboss/server/${INSTANCIA}/deploysistra/sistra-properties-service.xml"
echo -n "### configurant ubicació dels fitxers de propietats: "
( cat << EOF
<?xml version="1.0" encoding="UTF-8"?>
<server>
<mbean code="org.jboss.varia.property.SystemPropertiesService"
name="jboss:type=Service,name=BootProperties">
<attribute name="Properties">
<!-- Dins ${DIR_CONF}/sistra estaran els arxius de configuració -->
ad.path.properties=${DIR_CONF}
</attribute>
</mbean>
</server>

EOF
) > "$F_DS"
echo "OK"

# servei de missatges Avisador BTE
echo -n "### configurant cua de missatges: "
mkdir -vp "${DIR_BASE}/jboss/server/${INSTANCIA}/deploysistra/sistra.sar/META-INF"

( cat << EOF
<?xml version="1.0" encoding="UTF-8"?>
<server>
   <mbean code="org.jboss.jms.server.destination.QueueService"
  name="jboss.messaging.destination:service=Queue,name=AvisadorBTE"
  xmbean-dd="xmdesc/Queue-xmbean.xml">
    <depends optional-attribute-name="ServerPeer">jboss.messaging:service=ServerPeer</depends>
    <depends>jboss.messaging:service=PostOffice</depends>
    <attribute name="JNDIName">queue/AvisadorBTE</attribute>
    <attribute name="RedeliveryDelay">30000</attribute>
    <attribute name="MaxDeliveryAttempts">3</attribute>
   </mbean>
   <mbean code="org.jboss.varia.property.SystemPropertiesService"
    name="jboss:type=Service,name=sistraProperties">
    <attribute name="Properties">
     <!-- A ${DIR_CONF}/sistra estaran els arxius de configuració -->
        ad.path.properties=${DIR_CONF}/
    </attribute>
   </mbean>
</server>

EOF
) >> "${DIR_BASE}/jboss/server/${INSTANCIA}/deploysistra/sistra.sar/META-INF/sistra-service.xml"
echo "OK"


echo -n "### configurant servei de correu: "
F_CORREU="${DIR_BASE}/jboss/server/${INSTANCIA}/deploysistra/mobtratel-mailTest-service.xml"
( cat << EOF
<server>
  <mbean code="org.jboss.mail.MailService"
      name="jboss:service=MobtratelMailTest">
     <attribute name="JNDIName">java:/es.caib.mobtratel.mailTest</attribute>
    <attribute name="User">${SMTP_USUARI}</attribute>
    <attribute name="Password">${SMTP_PASS}</attribute>
   <attribute name="Configuration">
       <configuration>
            <property name="mail.transport.protocol" value="smtp"/>
            <property name="mail.smtp.host" value="${SMTP_SERVIDOR}"/>
            <property name="mail.from" value="${USUARI}@`hostname -f`"/>
            <property name="mail.debug" value="false"/>
            <property name="mail.smtp.auth" value="true"/> 
        </configuration>
    </attribute>
  </mbean>
</server>
EOF
) > "$F_CORREU"
echo "OK"


# Modificar el Tomcat per habilitar el single sign on entre les aplicacions.
# Per això hi ha que descomentar el valve que l'implementa el fitxer $JBOSS/server/default/deploy/jbossweb-tomcat50.sar/server.xml
echo -n "### configurant SingleSignOn : "
F_DS="${DIR_BASE}/jboss/server/${INSTANCIA}/deploy/jbossweb.sar/server.xml"
sed -i 's|<Valve className="org.apache.catalina.authenticator.SingleSignOn" />|-->\n\t\t<Valve className="org.apache.catalina.authenticator.SingleSignOn" />\n\t<!--|g' "$F_DS"
echo "OK"

# return 0
pause

}
# conf_jboss



conf_properties(){
# aquestes configuracions estan fora del directori de JBoss
# i per tant NO les sobre-escrivim si ja existeixen, sempre respectam el que hi hagi

echo "### creant directoris config: "
mkdir -vp "${DIR_CONF}/sistra/plugins"

if [ -e "${DIR_CONF}/sistra/audita.properties" ]; then
    echo "### Ja existeix el fitxer de propietats [${DIR_CONF}/sistra/audita.properties]"
else
echo "### creant plantilla de propietats de [audita]"
F_AUDITA="${DIR_CONF}/sistra/audita.properties"
( cat << 'EOF'
# Path de las imatges generades
pathImages=/tmp/

# Datos para el Job del admin.
scheduler.schedule=true
scheduler.cron.expression=0 0 1 * * ?

EOF
) > "$F_AUDITA"
fi

F_BANTEL="${DIR_CONF}/sistra/bantel.properties"
if [ -e "${F_BANTEL}" ]; then
    echo "### Ja existeix el fitxer de propietats [${F_BANTEL}]"
else
echo "### creant plantilla de propietats de [bantel]"
( cat << EOF
# Intervalo de seguridad (minutos) para evitar superposicion de aviso inmediato con aviso periodico
avisoPeriodico.intervaloSeguridad=2
# Numero de trabajos
scheduler.jobs.number=3
# Nombre Trabajo 1: Planificacion de Job de Aviso a BackOffices
scheduler.job.1.name=Aviso a BackOffices
# Clase implementadora
scheduler.job.1.classname=es.caib.bantel.admin.scheduler.jobs.AvisoBackOfficesJob
# Expresion cron que determina periodicidad trabajo
scheduler.job.1.cron.expression=0 * * * * ?
# Indica si se ejecuta
scheduler.job.1.schedule=true
# Nombre trabajo 2: Planificacion de Job de Aviso a Gestores
scheduler.job.2.name=Aviso a Gestores
# Clase implementadora
scheduler.job.2.classname=es.caib.bantel.admin.scheduler.jobs.AvisoGestoresJob
# Expresion cron que determina periodicidad trabajo (deberia ser despues del proceso de rechazar notifs en zonaper)
scheduler.job.2.cron.expression=0 0 7 * * ?
# Indica si se ejecuta
scheduler.job.2.schedule=true
# Nombre trabajo 3: Planificacion de Job de Aviso Monitorizacion a Gestores
scheduler.job.3.name=Aviso monitorizacion a Gestores
# Clase implementadora
scheduler.job.3.classname=es.caib.bantel.admin.scheduler.jobs.AvisoMonitorizacionJob
# Expresion cron que determina periodicidad trabajo
scheduler.job.3.cron.expression=0 0 * * * ?
# Indica si se ejecuta
scheduler.job.3.schedule=true
# M�ximo n�mero de entradas por aviso
avisoPeriodico.maxEntradas=100
#Id cuenta para envio de avisos a gestores
avisosGestores.cuentaEnvio=TEST
#Indica si se realiza la llamada al WS de forma asincrona
webService.cliente.asincrono=true
# Indica numero de dias tras el cual se marcara como procesada con error un entrada sino se ha conseguido procesar
# La fecha de comparacion sera la de cuando esta preparada para procesar (al crearse o cuando pasa a estado 'No procesada')
# Si es 0 no se tiene en cuenta y no caducaran la entradas sin procesarse.
avisoPeriodico.maxDiasAviso=30
# Indica si en el modulo de gestion de expedientes se obliga a que los expedientes que se creen a traves de este modulo tengan activados los avisos
gestionExpedientes.avisosObligatorios=true


EOF
) > "$F_BANTEL"
fi

F_FORMS="${DIR_CONF}/sistra/forms.properties"
if [ -e "${F_FORMS}" ]; then
    echo "### Ja existeix el fitxer de propietats [${F_FORMS}]"
else
echo "### creant plantilla de propietats de [forms]"
( cat << EOF
# Tiempo en cache de los dominios sistra
tiempoEnCache=60
# Indica si se deben aplicar permisos de acceso sobre la programaci�n de formularios
habilitar.permisos=false


EOF
) > "$F_FORMS"
fi

F_GLOBAL="${DIR_CONF}/sistra/global.properties"
if [ -e "${F_GLOBAL}" ]; then
    echo "### Ja existeix el fitxer de propietats [${F_GLOBAL}]"
else
echo "### creant plantilla de propietats de [global]"
( cat << EOF
# -------------- Info organismo ----------------------------------------------
# Nombre organismo
organismo.nombre=Ajuntament de Ses Salines
# Sello registro
organismo.sello=Ajuntament de Ses Salines
# Url logo organismo (Url web). Tambi�n ser� utilizada tambi�n en la generaci�n de correos
organismo.logo=http://www.ajsessalines.net/img/portada/cabecera.png
# Url logo dins Login (Url web). Solo utilizada en login.jsp de sistra i zonaper
organismo.logo.login=../images/logoMOCK.gif
# Url a portal organismo. Ser� la salida por defecto al acabar un tr�mite
organismo.portal.url=http://www.ajsessalines.net
# Informaci�n del pie para contacto (permite HTML)
organismo.footer.contacto=Major, 1 - 07640
# Url para resolucion de incidencias (se establecera soporte por url o por email, solo uno de ellos). Permite las variables @idioma@, @asunto@ (se reemplazar� por un texto descriptivo)
organismo.soporteTecnico.url=/sistrafront/protected/init.do?modelo=IN0014CON&version=1&centre=WEB&tipus_escrit=PTD&language=@idioma@&asunto=@asunto@
# Email para resolucion de incidencias (se establecera soporte por url o por email, solo uno de ellos).
organismo.soporteTecnico.email=
# Telefono de resolucion de incidencias (opcional)
organismo.soporteTecnico.telefono=012
# Url css para customizacion
#organismo.cssCustom=http://172.19.0.115:8080/sistrafront/estilos/noexiste.css
# Url css para customizacion en login.jsp de sistra i zonaper
organismo.cssLoginCustom=../estilos/loginMOCK.css
# Zona personal: t�tulo de la zona personal (p.e.: Carpeta de tramitaci�n)
organismo.zonapersonal.titulo.es=Mi portal
organismo.zonapersonal.titulo.ca=El meu portal
organismo.zonapersonal.titulo.en=My web page
# Zona personal: referencia en frase (por si lleva alg�n art�culo: p.e. "su carpeta de tramitaci�n")
organismo.zonapersonal.referencia.es=Mi portal
organismo.zonapersonal.referencia.ca=El meu portal
organismo.zonapersonal.referencia.en=My web page
# Textos relativos a la LOPD que se incorporan al paso Debe Saber del asistente de tramitaci�n
organismo.lopd.aviso.es=Texto LOPD
organismo.lopd.aviso.ca=Text LOPD
organismo.lopd.aviso.en=Text LOPD

# ------------ Plugins --------------------------------------------------------
#plugin.registro=es.caib.sistra.plugins.regtel.impl.mock.PluginRegtelMock

plugin.registro=es.caib.sistra.plugins.regtel.impl.caib.PluginRegweb3
plugin.envioSMS=es.caib.sistra.plugins.sms.impl.mock.PluginSmsMock
plugin.envioEmail=es.caib.sistra.plugins.sms.impl.mock.PluginEmailMock
plugin.pagos=es.caib.sistra.plugins.pagos.impl.mock.PluginPagosMock
plugin.pagos.OTRO=es.caib.sistra.plugins.pagos.impl.mock.PluginPagosMock
plugin.firma=es.caib.sistra.plugins.firma.impl.mock.PluginFirmaMock
plugin.login=es.caib.sistra.plugins.login.impl.mock.PluginLoginMOCK
plugin.autenticacionExplicita=es.caib.sistra.plugins.login.impl.mock.PluginAutenticacionExplicitaMock
plugin.custodia=es.caib.sistra.plugins.custodia.impl.mock.PluginCustodiaMock
plugin.gestionDocumental=es.caib.sistra.plugins.gestorDocumental.impl.mock.PluginGestorDocumentalMock

# ------------ Usuario procesos automaticos ----------------------------------
auto.user=auto
auto.pass=auto

# ----------- Url de sistra --------------------------------------------------
# Contexto raiz a partir del cual iran el resto de modulos de sistra
sistra.contextoRaiz.front=/sistrafront
sistra.contextoRaiz.back=/sistraback
# Url de los fronts publicos (internet) de sistra (sistrafront, formfront, zonaperfront y redosefront)
sistra.url=http://${SERVIDOR}:8080
# Url de los backs internos de sistra (intranet)
sistra.url.back=http://${SERVIDOR}:8080

# ---------- Entorno: DESARROLLO / PRODUCCION --------------------------------
entorno=DESARROLLO

# --------- Clave para cifrar usuarios/passwords en BBDD (debe tener 8 caracteres) ---------------------
clave.cifrado=XXXXX

#-------------  Variable (@backoffice.url@) que puede ser usada para establecer la url de los backoffices (dominios, procesamiento, etc.)  ----------------
backoffice.url=http://${SERVIDOR}:8080

#-------------  Indica si se ejecuta en un iframe  ---------------------------------------
sistra.iframe=false

#-------------  Opciones generales avisos  ---------------------------------------
#  Indica si son obligatorios los avisos para las notificaciones (se debera habilitar avisos por expediente)
sistra.avisoObligatorioNotificaciones=true

# ------------- Establece opciones de autenticacion a nivel del api de webservices  ---------------------------------------
# Indica si se usa autenticacion basica basada en cabeceras HTTP (BASIC) o ws-security usernameToken (USERNAMETOKEN)
sistra.ws.authenticacion=BASIC
#sistra.ws.authenticacion=USERNAMETOKEN
# Para autenticacion por usernameToken indica si genera timestamp
sistra.ws.authenticacion.usernameToken.generateTimestamp=true
# Indica si realiza log de las llamadas invocadas por sistra
# (ademas se debera establecer en el log4j: org.apache.cxf a INFO o DEBUG)
sistra.ws.client.logCalls=true
# Indica si realiza log de las llamadas servidas por sistra
# (ademas se debera establecer en el log4j: org.apache.cxf a INFO o DEBUG)
sistra.ws.server.logCalls=true
# Indica si no valida el certificado del servidor al que se invoca en comunicacion https
sistra.ws.client.disableCnCheck=false
# Indica si deshabilita el modo chunked en las llamadas invocadas por sistra
sistra.ws.client.disableChunked=false


EOF
) > "$F_GLOBAL"
fi

F_MOBTRATEL="${DIR_CONF}/sistra/mobtratel.properties"
if [ -e "${F_MOBTRATEL}" ]; then
    echo "### Ja existeix el fitxer de propietats [${F_MOBTRATEL}]"
else
echo "### creant plantilla de propietats de [mobtratel]"
( cat << EOF
# Numero de trabajos automaticos
scheduler.jobs.number=3
# Trabajo 1: Realizar envios programados
scheduler.job.1.name=Realizar Envios Programados
# Clase implementadora
scheduler.job.1.classname=es.caib.mobtratel.admin.scheduler.jobs.EnviosJob
# Expresi�n cron que indica periodicidad trabajo
scheduler.job.1.cron.expression=0 0 * * * ?
# Indica si se debe ejecutar el trabajo
scheduler.job.1.schedule=true
# Trabajo 2: Realizar envios inmediatos
scheduler.job.2.name=Realizar Envios Inmediatos
# Clase implementadora
scheduler.job.2.classname=es.caib.mobtratel.admin.scheduler.jobs.EnviosInmediatosJob
# Expresi�n cron que indica periodicidad trabajo
scheduler.job.2.cron.expression=0 * * * * ?
# Indica si se debe ejecutar el trabajo
scheduler.job.2.schedule=true
# Trabajo 3: Realizar verificacion envios
scheduler.job.3.name=Realizar verificacion envios
# Clase implementadora
scheduler.job.3.classname=es.caib.mobtratel.admin.scheduler.jobs.VerificarEnviosJob
# Expresi�n cron que indica periodicidad trabajo
scheduler.job.3.cron.expression=0 0 * * * ?
# Indica si se debe ejecutar el trabajo
scheduler.job.3.schedule=false
# Limite de tiempo (min) que puede durar el proceso de envio
envio.limiteTiempo=45
# Maximo de errores en envios SMS antes de cancelar envio (0 no cancela)
sms.maxErroresSMS=2
# Maximo numero de caracteres en mensaje SMS
sms.maxCaracteres=160
# Envio paginado de emails (divididos en n paginas segun numero de destinatarios)
email.pagina=100
# Numero maximo de destinatarios permitidos (0 no hay limite)
sms.maxDestinatarios=1000
# Numero maximo de destinatarios permitidos (0 no hay limite)
email.maxDestinatarios=0
# Delay (segs) entre un sms y el siguiente
sms.delay=0
# Indica si se deben simular los envios email
envio.simularEnvioEmail=true
# Indica si se deben simular los envios sms
envio.simularEnvioSms=true
# En caso de que se simulen los envios indica la duracion que simula tarda un envio (segs)
envio.simularEnvio.duracion=10
# Indica el limite de dias de intento de envio para env�os sin fecha caducidad (sino se establece, por defecto 15)
envio.limite.sin.fecha.caducidad=10
# Indica el limite de dias para intentar verificar el envio (sino se establece, por defecto 5)
envio.verificarEnvio.limite=5
# Indica sufijo que tendra el titulo del mensaje email para que se pueda verificar a posteri si se ha enviado. El ? se sustituira por el id del mensaje.
envio.verificarEnvio.sufijoEmail=(Codi: ?)

EOF
) > "$F_MOBTRATEL"
fi

F_REDOSE="${DIR_CONF}/sistra/redose.properties"
if [ -e "${F_REDOSE}" ]; then
    echo "### Ja existeix el fitxer de propietats [${F_REDOSE}]"
else
echo "### creant plantilla de propietats de [redose]"

( cat << EOF
# Texto asociado al barcode verificador
verifier.text=Adre�a per a la comprovaci� de la validesa del document

# Conexion con el open office 3.1 para la conversion de documentos a pdf
openoffice.host=${SERVIDOR}
openoffice.port=8100

# Root path para plugin de almacenamiento en fichero
# Los documentos se almacenar�n en este path con la  siguiente estructura de directorios:
# <RootPath>/modelo/version/a�o/mes/fichero
plugin.filesystem.rootPath=/temp/rds-data

# Habilitar proceso automatico consolidacion gestor documental
scheduler.jobConsolidacionGestorDocumental.schedule=true
# Cron que indica cuando se ejecuta proceso automatico
scheduler.jobConsolidacionGestorDocumental.cron.expression=0 0/10 * * * ?
# Limite documentos a consolidar en cada intervalo
scheduler.jobConsolidacionGestorDocumental.limite=1000

# Habilitar proceso automatico de purgado documentos
scheduler.jobPurgadoDocumentos.schedule=true
# Cron que indica cuando se ejecuta proceso automatico
scheduler.jobPurgadoDocumentos.cron.expression=0 0 5 * * ?
#Indica los meses que estara un documento marcado para borrar antes de borrarse definitivamente
scheduler.jobPurgadoDocumentos.mesesAntesBorradoDefinitivo=12
# Indica numero de documentos maximo a purgar en cada proceso
# (se aplica el limite cada vez en cada caso: docs sin usos, docs eliminar definitivamente, docs custodia y docs externos)
scheduler.jobPurgadoDocumentos.limite=5000

# Indica si se establece barcode en la url de verificacion
urlVerificacion.barcode.mostrar=true

# Indica si se usa CSV (en lugar del localizador)
urlVerificacion.csv=false


EOF
) > "$F_REDOSE"
fi

F_REGTEL="${DIR_CONF}/sistra/regtel.properties"
if [ -e "${F_REGTEL}" ]; then
    echo "### Ja existeix el fitxer de propietats [${F_REGTEL}]"
else
echo "### creant plantilla de propietats de [regtel]"

( cat << EOF
# Indica si el registro debe firmar el justificante para un registro de entrada
#firmar.entrada=true
firmar.entrada=false

# Indica si el registro debe firmar el justificante para un registro de salida
#firmar.salida=true
firmar.salida=false

# Certificado de registro (el pin solo sera necesario para firma caib)
certificado.name=TEST: Usuario Prueba Prueba
certificado.pin=12341234 


EOF
) > "$F_REGTEL"
fi

F_SARCONFIG="${DIR_CONF}/sistra/sar-config.properties"
if [ -e "${F_SARCONFIG}" ]; then
    echo "### Ja existeix el fitxer de propietats [${F_SARCONFIG}]"
else
echo "### creant plantilla de propietats de [sar-config]"

( cat << EOF
# Indica si las propiedades van por SAR
es.caib.sistra.configuracion.sistra.sar=false

EOF
) > "$F_SARCONFIG"
fi

F_SISTRA="${DIR_CONF}/sistra/sistra.properties"
if [ -e "${F_SISTRA}" ]; then
    echo "### Ja existeix el fitxer de propietats [$F_SISTRA]"
else
echo "### creant plantilla de propietats de [sistra]"

( cat << EOF
# Indica si se resetea sesion web al iniciar (forzar sso caib)
front.resetearSesionInicio=false
# Indica si se deben aplicar permisos de acceso sobre la programaci�n de tramites
habilitar.permisos=false

EOF
) > "$F_SISTRA"
fi

F_ZONAPER="${DIR_CONF}/sistra/zonaper.properties"
if [ -e "$F_ZONAPER" ]; then
    echo "### Ja existeix el fitxer de propietats [$F_ZONAPER]"
else
echo "### creant plantilla de propietats de [zonaper]"
( cat << EOF
# Indica si se resetea sesion web al iniciar (forzar sso caib)
front.resetearSesionInicio=false

# Permite enlazar zonaperback con la aplicacion de registro (link inicio zonaperback apuntaria a esta url). Sino se establece se redirige a la pagina de inicio de zonaperback
#back.urlAplicacionRegistro=https://intranet.caib.es/regweb/index.jsp

#Id cuenta para envio de avisos expediente (eventos expediente y avisos notificacion)
avisos.cuentaEnvio.avisosExpediente=TEST
#Id cuenta para envio de avisos delegacion (zona personal delegada)
avisos.cuentaEnvio.delegacion=TEST

# Indica si se realizara la confirmacion de envio para las notificaciones
avisos.confirmacionEnvio.notificaciones.email=false
avisos.confirmacionEnvio.notificaciones.sms=false
# Indica si se realizara la confirmacion de envio para los eventos de expediente
avisos.confirmacionEnvio.eventosExpediente.email=false
avisos.confirmacionEnvio.eventosExpediente.sms=false
# Indica si se permite generar sms para alertas sobre expedientes (si se deshabilitan los sms solo se generaran a nivel de avisos especificos de expediente)
avisos.smsAlertas=false
# Indica si esta habilitado el apartado de alertas en la zona personal
avisos.apartadoAlertas=true

#Indica si el proceso automatico de borrado de tramites caducados (persistencia y preregistro sin confirmacion) esta activado
scheduler.backup.schedule=true

#Expresion para indicar cuando se ejecuta el proceso automatico
scheduler.backup.cron.expression=0 0 4 * * ?

#Indica si en el proceso de borrado de tramites caducados se borran los tramites de preregistro que tras finalizar su fecha limite de entrega no estan confirmados
scheduler.backup.schedule.borradoPreregistro=false

#Indica los meses que estara un tramite antes de considerarse caducado si no estan confirmados
scheduler.backup.borradoPreregistro.meses=12

#Indica numero maximo de elementos a tratar
scheduler.backup.maxElementos=5000

#Expresion para indicar cuando se ejecuta el proceso automatico de revisar registros
scheduler.revisarRegistrosEfectuados.cron.expression=0 0 * * * ?

#Indica si en el proceso de revisar registro
scheduler.revisarRegistrosEfectuados.schedule=true

#Indica si en el proceso de borrar los tramites de la tabla de backup de tramites
scheduler.borradoBackup.schedule=true

#Expresion para indicar cuando se ejecuta el proceso automatico
scheduler.borradoBackup.cron.expression=0 0 4 * * ?

#Indica los meses que estara un tramite en la tabla de backup de tramites
scheduler.borradoBackup.meses=12

#Indica numero maximo de elementos a tratar
scheduler.borradoBackup.maxElementos=5000

#Indica si se deben firmar las delegaciones de representante por parte del funcionario
delega.firmarDelegacionRepresentante=true

# Control entrega notificacion que requiere firma de acuse (requiere especificacion dias festivos)
notificaciones.controlEntrega.habilitar=false


# Dias festivos: buscara en el directorio indicado un fichero anyo.properties (p.e. 2012.properties)
#  El fichero tendra el siguiente formato: una linea por mes y para cada mes los dias festivos separados por coma
#  mes.1=1,6
#  mes.2=
#  ...
#  mes.12=6,8,24,25,31
# No hace falta especificar los domingos como d�a inh�bil, ya que se detectar� autom�ticamente.
# IMPORTANTE: EL CALCULO DEL FIN DE PLAZO DE LA NOTIFICACION SE REALIZA EN EL MOMENTO DE REALIZAR LA NOTIFICACION, ASI QUE
#	EL FICHERO DE FESTIVOS DEL A�O SIGUIENTE DEBE ESTAR PREPARADO EN DICIEMBRE
notificaciones.calendarioDiasFestivos=/app//caib/sistra/plugins/calendario

# Indica si los acuses de recibo firmados con clave de acceso se sellan digitalmente en servidor con una firma de certificado de aplicacion
notificaciones.sellarAcuses.firmaClave.habilitar=false
notificaciones.sellarAcuses.certificado.name=TEST: Usuario Prueba Prueba
notificaciones.sellarAcuses.certificado.pin=12341234

#Indica si el proceso automatico de control de entrega de notificaciones esta activado
scheduler.entregaNotificaciones.schedule=false

#Expresion para indicar cuando se ejecuta el proceso automatico
scheduler.entregaNotificaciones.cron.expression=0 0 4 * * ?

#Indica si el proceso automatico de alertas de tramitacion esta activado. Las alertas de tramitaci�n son alertas sobre incidencias detectadas antes del registro definitivo de la solicitud (incluye fase de preregistro hasta que se confirma).
scheduler.alertasTramitacion.schedule=true

#Expresion para indicar cuando se ejecuta el proceso automatico
scheduler.alertasTramitacion.cron.expression=0 0 * * * ?

#Indica cuando se alerta de que hay un pago telematico finalizado y no se ha finalizado el tr�mite (horas). Si es igual a 0, no se generara alerta.
scheduler.alertasTramitacion.pagoFinalizado.avisoInicial=1

#Indica cada cuanto se repite el aviso de que hay un pago telematico finalizado y no se ha finalizado el tr�mite (horas). Si intervalo repeticion es menor o igual a 0, no generamos alertas repeticion.
scheduler.alertasTramitacion.pagoFinalizado.repeticion=48

#Indica cuando se alerta de que hay un pago telematico finalizado y no se ha finalizado el tr�mite, si se avisa a los gestores por mail.
scheduler.alertasTramitacion.pagoFinalizado.avisarGestores=false

#Indica cuando se empieza a alertar de que hay un preregistro pendiente de entregar una vez preregistrado (horas). Si es igual a 0, no se generara alerta.
scheduler.alertasTramitacion.preregistroPendiente.avisoInicial=24

#Indica cada cuanto se repite el aviso de que hay un preregistro pendiente (horas). Si intervalo repeticion es menor o igual a 0, no generamos alertas repeticion.
scheduler.alertasTramitacion.preregistroPendiente.repeticion=48

#Prefijo alta automatica de usuarios (se a�adir� el nif a este prefijo)
usuario.prefijoAuto=TMP-

EOF
) > "$F_ZONAPER"
fi

# plugins
## PENDENT CONSULTA SOBRE PLUGIN REGWEB3!!!


F_PCUSTODIA="${DIR_CONF}/sistra/plugins/plugin-custodia.properties"
if [ -e "$F_PCUSTODIA" ]; then
    echo "### Ja existeix el fitxer de propietats [$F_PCUSTODIA]"
else
echo "### creant plantilla de propietats de [plugin-custodia]"

( cat << EOF
# Identificacion aplicacion sistra en custodia
ClienteCustodia=CustodiaSistra

# Url consulta custodia (PRO)
#urlConsultaCustodia=http://vd.caib.es/

# Url consulta custodia (PRE)
urlConsultaCustodia=https://proves.caib.es/signatura/sigpub/

# Mapeo de modelos RDS a modelos custodia
# -- Habra que ir a�adiendo el mapeo de los documentos conforme haga falta (modeloRDS=modeloCustodia).
# -- Para GE0001JUSTIF y GE0002ASIENTO hay un tratamiento especial, ya que se detecta el tipo del
# -- asiento: si son de entrada, acuse, etc.
GE0001JUSTIF_ENTRADA=SISTRA_JUSTIFICANT_ENTRADA
GE0002ASIENTO_ENTRADA=SISTRA_REGISTRE_ENTRADA
GE0002ASIENTO_ACUSE=SISTRA_REBUT_NOTIFICACIO
GE0005ANEXGEN=SISTRA_ANNEX_GENERIC
GE0011NOTIFICA=SISTRA_NOTIFICACIO
GE0012DELEGA=SISTRA_DELEGACIO

EOF
) > "$F_PCUSTODIA"
fi


F_PFIRMA="${DIR_CONF}/sistra/plugins/plugin-firma.properties"
if [ -e "$F_PFIRMA" ]; then
    echo "### Ja existeix el fitxer de propietats [$F_PFIRMA]"
else
echo "### creant plantilla de propietats de [plugin-firma]"

( cat << EOF
# Content types de firma utilizados
contentType.registroEntrada=application/caib-resgitreentrada
contentType.acuseNotificacion=application/caib-acusenotificacio
# CAI 578090
#contentType.justificanteEntrada=application/x-caib-rebutregistre
#contentType.justificanteSalida=application/x-caib-rebutregistre
contentType.justificanteEntrada=application/signaturaTest
contentType.justificanteSalida=application/signaturaTestNR

contentType.documentoNotificacion=application/signaturaTestNR

EOF
) > "$F_PFIRMA"
fi

F_PLOGIN="${DIR_CONF}/sistra/plugins/plugin-login.properties"
if [ -e "$F_PLOGIN" ]; then
    echo "### Ja existeix el fitxer de propietats [$F_PLOGIN]"
else
echo "### creant plantilla de propietats de [plugin-login]"

( cat << EOF
# Nombre de la cookie de autenticacion (despues de "/" viene si es preproducci�n o producci�n )
#auth.cookiename=es.caib.loginModule/
auth.cookiename=es.caib.loginModule/Desarrollo

#DOMINIO.EC_GBPAIS.user=caibenred
#DOMINIO.EC_GBPAIS.pass=indra032012

# Usuario/Password a usar en la autenticaci�n explicita. Parametrizado por procedimiento/iddominio.
# Si no se especifica usuario / password se usara el de los procesos automaticos.

# Se puede especificar para cada elemento el usr/pwd.
# PROCEDIMIENTO.IDPROCEDIMIENTO.user=usuario 
# PROCEDIMIENTO.IDPROCEDIMIENTO.pass=password 
# DOMINIO.IDDOMINIO.user=usuario
# DOMINIO.IDDOMINIO.pass=password

# Se puede agrupar la informacion de login
LOGIN.LOGIN1.user=test
LOGIN.LOGIN1.pass=test
PROCEDIMIENTO.TS0007INTE.login=LOGIN1
DOMINIO.TS_PROVIN.login=LOGIN1
DOMINIO.TS_MUNICI.login=LOGIN1
DOMINIO.TS_DOMINIS.login=LOGIN1

EOF
) > "$F_PLOGIN"
fi

F_PPAGOS="${DIR_CONF}/sistra/plugins/plugin-pagos.properties"
if [ -e "$F_PPAGOS" ]; then
    echo "### Ja existeix el fitxer de propietats [$F_PPAGOS]"
else
echo "### creant plantilla de propietats de [plugin-pagos]"

( cat << EOF
# Indica si la confirmaci�n de un pago tiene que ser simulada o real.
pago.simular=true

pago.entidad.BM=true
pago.entidad.LC=true
pago.entidad.SN=true
pago.entidad.BB=true

# Fase (pruebas / produccion)
fase=produccion


# URLs pruebas
#url.pruebas=http://www.tributsCaib.com/services

# URLs produccion
url.produccion=http://www.atib.es/servicios/service_tasa.asmx

# valores para SOAPHeader
usuarioWs=indrauser
passwordWs=INDRA

EOF
) > "$F_PPAGOS"
fi

# sensible a capitalització?
F_PPAGOSTPV="${DIR_CONF}/sistra/plugins/plugin-pagosTPV.properties"
if [ -e "$F_PPAGOSTPV" ]; then
    echo "### Ja existeix el fitxer de propietats [$F_PPAGOSTPV]"
else
echo "### creant plantilla de propietats de [plugin-pagostpv]"

( cat << EOF
# URLs intercambio informacion y redireccion
tpv.urlAsistenteInicio=http://${SERVIDOR}:28080/pagosTPVFront/init.do?token=
tpv.urlTPV=https://sis-t.redsys.es:25443/sis/realizarPago
tpv.urlRetornoOK=http://${SERVIDOR}:28080/pagosTPVFront/retornoTPV.jsp
tpv.urlRetornoKO=http://${SERVIDOR}:28080/pagosTPVFront/retornoTPV.jsp
tpv.urlNotificacion=http://caibter.indra.es/NotificadorTPV/provescaib

# Modelo RDS de documento de pago presencial
tpv.documentoPagoPresencial.modelo=GE0006PAGO
tpv.documentoPagoPresencial.version=1
tpv.documentoPagoPresencial.plantilla=PRE

# Prefijo orden (PARA ENTORNOS DE TEST) 
# Por si hay distintos entornos de test usando el TPV se establece un prefijo
# para evitar duplicidades en numeros de pedido.
# Un prefijo distinto por entorno.
# Para produccion, debe estar vacio
tpv.orderPrefix=A

# Moneda: euros
tpv.merchantCurrency=978

# Transaccion: pago online
tpv.merchantTransactionTypeAut=0

# Idiomas
tpv.idioma.es=001
tpv.idioma.ca=003
tpv.idioma.en=002

# Alta de organismos que pueden usar el TPV. 
# Se identificaran por el id organismo: tpv.idorganismo.propiedad )
tpv.ieb.merchantName=INSTITUT ESTUDIS BALEARIC
tpv.ieb.merchantCode=329058705
tpv.ieb.merchantTerminal=1
tpv.ieb.merchantPassword=sq7HjrUOBfKmC576ILgskD5srU870gJ7
tpv.ieb.documentoPagoPresencial.entidad1.nombre=Sa Nostra
tpv.ieb.documentoPagoPresencial.entidad1.cuenta=2051 0005 45 1035505293
tpv.ieb.documentoPagoPresencial.entidad2.nombre=La Caixa
tpv.ieb.documentoPagoPresencial.entidad2.cuenta=2100 2715 55 0200036911
tpv.ieb.documentoPagoPresencial.entidad3.nombre=Banca March
tpv.ieb.documentoPagoPresencial.entidad3.cuenta=0061 0003 80 0166750113
tpv.ieb.documentoPagoPresencial.instrucciones.es=Obligaciones legales en materia de protecci�n de datos de car�cter personal (Ley org�nica 15/1999, de 13 de diciembre, de protecci�n de car�cter personal). Sus datos personales se trataran y se incorporaran en un fichero escrito en la Agencia Espa�ola de Protecci�n de Datos, del cual es responsable l'Institut d'Estudis Bal�arics (IEB), para tramitar su solicitud y llevar a cabo la gesti�n administrativa y econ�mica de las acciones formativas organizadas por el IEB. Puede ejercer el derecho de acceso, rectificaci�n, cancelaci�n y oposici�n mediante un escrito, acompa�ado de una copia del DNI dirigido al IEB(calle Alfons el Magn�nim, n�m 29., 1�, puerta 4: 07004 Palma, Mallorca, Illes Balears).
tpv.ieb.documentoPagoPresencial.instrucciones.ca=Obligacions legals en m�teria de protecci� de dades de car�cter personal (Llei org�nica 15/1999, de 13 de desembre, de protecci� de dades de car�cter personal). Les vostres dades personals es tractaran i s'incorporaran en un fitxer escrit a l'Ag�ncia Espanyola de Protecci� de Dades, del qual �s responsable l'Institut d'Estudis Bale�rics (IEB), per tramitar la vostra sol�licitud i dur a terme la gesti� administrativa i econ�mica de les accions formatives organitzades per l'IEB. Podeu exercir els drets d'acc�s, rectificaci�, cancel�laci� i oposici� mitjan�ant un escrit, acompanyat d'una c�pia del DNI dirigit a l'IEB (carres Alfons el Magn�nim, n�m 29., 1�, porta 4: 07004 Palma, Mallorca, Illes Balears).
tpv.ieb.documentoPagoPresencial.instrucciones.en=Lo mismo que antes, pero en ingles

tpv.ibavi.merchantName=IBAVI
tpv.ibavi.merchantCode=333390318
tpv.ibavi.merchantTerminal=1
tpv.ibavi.merchantPassword=qwertyasdf0123456789


EOF
) > "$F_PPAGOSTPV"
fi

F_PREGTEL="${DIR_CONF}/sistra/plugins/plugin-regtel.properties"
if [ -e "$F_PREGTEL" ]; then
    echo "### Ja existeix el fitxer de propietats [$F_PREGTEL]"
else
echo "### creant plantilla de propietats de [plugin-regtel]"

( cat << EOF
# Indica si hace log de las peticiones
plugin.regweb.print.peticio=false

# Propiedades del AS/400
as400=sirio
biblioteca=objreg
programaVPO=rwbvpo00
programaCSS=rwbcss00 

# Implementaci�n acceso a registro regweb
registroDAOImpl=es.caib.regtel.plugincaib.persistence.dao.registro.impl.RegistroDAOImpl
parametrosDAOImpl=es.caib.regtel.plugincaib.persistence.dao.parametros.ParametrosDAOImpl
 
# Codigos de idioma
plugin.regweb.idioma.es=1
plugin.regweb.idioma.ca=2
plugin.regweb.idioma.default=X

# Validacion de la oficina del usuario
validaOfRegEnt=false
validaOfRegSal=false
 
# Usuario de conexion a registro
# Si auto=true usa el usuario auto definido en sistra (global.properties)
# Si auto=false usa el usuario / password indicado
plugin.regweb.auth.auto=false
plugin.regweb.auth.username=$$bantel$$
plugin.regweb.auth.password=bantel

# Indica modo EJB / WS
plugin.regweb.modo=WS
#plugin.regweb.modo=EJB
 
# Url a Regweb EJB
#plugin.regweb.url=https://proves.caib.es/invoker-regweb/ReadOnlyJNDIFactory
# Url a Regweb WS
plugin.regweb.url=https://proves.caib.es/regweb2/WS/services/RegwebFacade?wsdl

# Oficina unica telematica de registro. Si esta alimentada se devolvera esta y si esta vacia se devolveran todas.
# - Codigo: codOficina.codOficinaFisica
plugin.regweb.oficinaTelematicaUnica.codigo=99.0
# - Descripcion: desOficina.desOficinaFisica
plugin.regweb.oficinaTelematicaUnica.descripcion=PRINCIPAL.Registre Telematic

EOF
) > "$F_PREGTEL"
fi

F_PSMS="${DIR_CONF}/sistra/plugins/plugin-sms.properties"
if [ -e "$F_PSMS" ]; then
    echo "### Ja existeix el fitxer de propietats [$F_PSMS]"
else
echo "### creant plantilla de propietats de [plugin-sms]"

( cat << EOF
# Url de provato 
sms.url=http://XXXXXXXXX:18080/provato/soap
# Numero movil remitente
sms.remitent=XXXXXXXXX
# Usuario provato
sms.username=XXXXXXXXX
# Pass provato
sms.password=XXXXXXXXX

EOF
) > "$F_PSMS"
fi


# NO!!! cp  "$REGWEB3_PROPIETATS/"*.properties "${DIR_BASE}/config_sistra/sistra/plugins/"

echo "OK"
pause
}
# conf_properties



conf_ds(){
echo "### Creant Datasources del tipus local-tx-datasource"

echo -n "##### configurant audita amb "
case $DS_AUDITA_DRIVER in
    org.postgresql.Driver)
	echo -n "Postgresql: "
	( cat << EOF
<?xml version="1.0" encoding="UTF-8"?>
<datasources>
  <local-tx-datasource>
    <jndi-name>es.caib.audita.db</jndi-name>
    <connection-url>$DS_AUDITA_URL</connection-url>
    <driver-class>$DS_AUDITA_DRIVER</driver-class>
    <user-name>$DS_AUDITA_USER</user-name>
    <password>$DS_AUDITA_PASS</password>
    <min-pool-size>1</min-pool-size>
    <max-pool-size>20</max-pool-size>
  </local-tx-datasource>
</datasources>
EOF
	) > "${DIR_BASE}/jboss/server/${INSTANCIA}/deploysistra/audita-postgresql-ds.xml"
    ;;
    oracle.jdbc.driver.OracleDriver)
	echo -n "Oracle: "
	( cat << EOF
<?xml version="1.0" encoding="UTF-8"?>
<datasources>
  <local-tx-datasource>
    <jndi-name>es.caib.audita.db</jndi-name>
    <connection-url>$DS_AUDITA_URL</connection-url>
    <driver-class>$DS_AUDITA_DRIVER</driver-class>
    <user-name>$DS_AUDITA_USER</user-name>
    <password>$DS_AUDITA_PASS</password>
    <min-pool-size>1</min-pool-size>
    <max-pool-size>20</max-pool-size>
    <valid-connection-checker-class-name>org.jboss.resource.adapter.jdbc.vendor.OracleValidConnectionChecker</valid-connection-checker-class-name>
    <exception-sorter-class-name>org.jboss.resource.adapter.jdbc.vendor.OracleExceptionSorter</exception-sorter-class-name>
  </local-tx-datasource>
</datasources>
EOF
	) > "${DIR_BASE}/jboss/server/${INSTANCIA}/deploysistra/audita-oracle-ds.xml"
    ;;
    *)
	echo ""
	echo "ERROR: Driver no suportat [$DS_AUDITA_DRIVER]"
	exit 1
    ;;
esac
echo "OK"

echo -n "##### configurant form amb "
case $DS_FORM_DRIVER in
    org.postgresql.Driver)
	echo -n "Postgresql: "
	( cat << EOF
<?xml version="1.0" encoding="UTF-8"?>
<datasources>
  <local-tx-datasource>
    <jndi-name>es.caib.rolforms.db</jndi-name>
    <connection-url>$DS_FORM_URL</connection-url>
    <driver-class>$DS_FORM_DRIVER</driver-class>
    <user-name>$DS_FORM_USER</user-name>
    <password>$DS_FORM_PASS</password>
    <min-pool-size>1</min-pool-size>
    <max-pool-size>20</max-pool-size>
  </local-tx-datasource>
</datasources>
EOF
	) > "${DIR_BASE}/jboss/server/${INSTANCIA}/deploysistra/form-postgresql-ds.xml"
    ;;
    oracle.jdbc.driver.OracleDriver)
	echo -n "Oracle: "
	( cat << EOF
<?xml version="1.0" encoding="UTF-8"?>
<datasources>
  <local-tx-datasource>
    <jndi-name>es.caib.rolforms.db</jndi-name>
    <connection-url>$DS_FORM_URL</connection-url>
    <driver-class>$DS_FORM_DRIVER</driver-class>
    <user-name>$DS_FORM_USER</user-name>
    <password>$DS_FORM_PASS</password>
    <min-pool-size>1</min-pool-size>
    <max-pool-size>20</max-pool-size>
    <valid-connection-checker-class-name>org.jboss.resource.adapter.jdbc.vendor.OracleValidConnectionChecker</valid-connection-checker-class-name>
    <exception-sorter-class-name>org.jboss.resource.adapter.jdbc.vendor.OracleExceptionSorter</exception-sorter-class-name>
  </local-tx-datasource>
</datasources>
EOF
	) > "${DIR_BASE}/jboss/server/${INSTANCIA}/deploysistra/form-oracle-ds.xml"
    ;;
    *)
	echo ""
	echo "ERROR: Driver no suportat [$DS_FORM_DRIVER]"
	exit 1
    ;;
esac
echo "OK"


echo -n "##### configurant loginmock amb "
case $DS_LOGINMOCK_DRIVER in
    org.postgresql.Driver)
	echo -n "Postgresql: "
	( cat << EOF
<?xml version="1.0" encoding="UTF-8"?>
<datasources>
  <local-tx-datasource>
    <jndi-name>es.caib.mock.loginModule.db</jndi-name>
    <connection-url>$DS_LOGINMOCK_URL</connection-url>
    <driver-class>$DS_LOGINMOCK_DRIVER</driver-class>
    <user-name>$DS_LOGINMOCK_USER</user-name>
    <password>$DS_LOGINMOCK_PASS</password>
    <min-pool-size>1</min-pool-size>
    <max-pool-size>20</max-pool-size>
  </local-tx-datasource>
</datasources>
EOF
	) > "${DIR_BASE}/jboss/server/${INSTANCIA}/deploysistra/loginmock-postgresql-ds.xml"
    ;;
    oracle.jdbc.driver.OracleDriver)
	echo -n "Oracle: "
	( cat << EOF
<?xml version="1.0" encoding="UTF-8"?>
<datasources>
  <local-tx-datasource>
    <jndi-name>es.caib.mock.loginModule.db</jndi-name>
    <connection-url>$DS_FORM_URL</connection-url>
    <driver-class>$DS_FORM_DRIVER</driver-class>
    <user-name>$DS_FORM_USER</user-name>
    <password>$DS_FORM_PASS</password>
    <min-pool-size>1</min-pool-size>
    <max-pool-size>20</max-pool-size>
    <valid-connection-checker-class-name>org.jboss.resource.adapter.jdbc.vendor.OracleValidConnectionChecker</valid-connection-checker-class-name>
    <exception-sorter-class-name>org.jboss.resource.adapter.jdbc.vendor.OracleExceptionSorter</exception-sorter-class-name>
  </local-tx-datasource>
</datasources>
EOF
	) > "${DIR_BASE}/jboss/server/${INSTANCIA}/deploysistra/form-oracle-ds.xml"
    ;;
    *)
	echo ""
	echo "ERROR: Driver no suportat [$DS_LOGINMOCK_DRIVER]"
	exit 1
    ;;
esac
echo "OK"


echo "### Creant Datasources del tipus xa-datasource"
echo -n "##### configurant bantel amb "
case $DS_BANTEL_CLASS in
    org.postgresql.xa.PGXADataSource)
	echo -n "Postgresql: "
	( cat << EOF
<?xml version="1.0" encoding="UTF-8"?>
<datasources>
  <xa-datasource>
    <jndi-name>es.caib.bantel.db</jndi-name>
    <track-connection-by-tx/>
    <isSameRM-override-value>false</isSameRM-override-value>
    <xa-datasource-class>org.postgresql.xa.PGXADataSource</xa-datasource-class>
     <xa-datasource-property name="ServerName">$DS_BANTEL_SERVER</xa-datasource-property>
     <xa-datasource-property name="PortNumber">$DS_BANTEL_PORT</xa-datasource-property>
     <xa-datasource-property name="DatabaseName">$DS_BANTEL_DATABASE</xa-datasource-property>
    <xa-datasource-property name="User">$DS_BANTEL_USER</xa-datasource-property>
    <xa-datasource-property name="Password">$DS_BANTEL_PASS</xa-datasource-property>
    <no-tx-separate-pools/>
      <metadata>
         <type-mapping>$DS_BANTEL_TYPEMAPPING</type-mapping>
      </metadata>
  </xa-datasource>
</datasources>
EOF
	) > "${DIR_BASE}/jboss/server/${INSTANCIA}/deploysistra/bantel-postgresql-ds.xml"
    ;;
    oracle.jdbc.xa.client.OracleXADataSource)
	echo -n "Oracle: "
	( cat << EOF
<?xml version="1.0" encoding="UTF-8"?>
<datasources>
  <xa-datasource>
    <jndi-name>es.caib.bantel.db</jndi-name>
    <track-connection-by-tx/>
    <isSameRM-override-value>false</isSameRM-override-value>
    <xa-datasource-class>oracle.jdbc.xa.client.OracleXADataSource</xa-datasource-class> 
    <xa-datasource-property name="URL">$DS_BANTER_URL</xa-datasource-property>
    <xa-datasource-property name="User">$DS_BANTEL_USER</xa-datasource-property>
    <xa-datasource-property name="Password">$DS_BANTEL_PASS</xa-datasource-property>
    <exception-sorter-class-name>org.jboss.resource.adapter.jdbc.vendor.OracleExceptionSorter</exception-sorter-class-name>
    <no-tx-separate-pools/>
      <metadata>
         <type-mapping>$DS_BANTEL_TYPEMAPPING</type-mapping>
      </metadata>
  </xa-datasource>
</datasources>
EOF
	) > "${DIR_BASE}/jboss/server/${INSTANCIA}/deploysistra/bantel-oracle-ds.xml"
    ;;
    *)
	echo ""
	echo "ERROR: Driver no suportat [$DS_BANTEL_CLASS]"
	exit 1
    ;;
esac
echo "OK"

echo -n "##### configurant mobtratel amb "
case $DS_MOBTRATEL_CLASS in
    org.postgresql.xa.PGXADataSource)
	echo -n "Postgresql: "
	( cat << EOF
<?xml version="1.0" encoding="UTF-8"?>
<datasources>
  <xa-datasource>
    <jndi-name>es.caib.mobtratel.db</jndi-name>
    <track-connection-by-tx/>
    <isSameRM-override-value>false</isSameRM-override-value>
    <xa-datasource-class>org.postgresql.xa.PGXADataSource</xa-datasource-class>
     <xa-datasource-property name="ServerName">$DS_MOBTRATEL_SERVER</xa-datasource-property>
     <xa-datasource-property name="PortNumber">$DS_MOBTRATEL_PORT</xa-datasource-property>
     <xa-datasource-property name="DatabaseName">$DS_MOBTRATEL_DATABASE</xa-datasource-property>
    <xa-datasource-property name="User">$DS_MOBTRATEL_USER</xa-datasource-property>
    <xa-datasource-property name="Password">$DS_MOBTRATEL_PASS</xa-datasource-property>
    <no-tx-separate-pools/>
      <metadata>
         <type-mapping>$DS_MOBTRATEL_TYPEMAPPING</type-mapping>
      </metadata>
  </xa-datasource>
</datasources>
EOF
	) > "${DIR_BASE}/jboss/server/${INSTANCIA}/deploysistra/mobtratel-postgresql-ds.xml"
    ;;
    oracle.jdbc.xa.client.OracleXADataSource)
	echo -n "Oracle: "
	( cat << EOF
<?xml version="1.0" encoding="UTF-8"?>
<datasources>
  <xa-datasource>
    <jndi-name>es.caib.mobtratel.db</jndi-name>
    <track-connection-by-tx/>
    <isSameRM-override-value>false</isSameRM-override-value>
    <xa-datasource-class>oracle.jdbc.xa.client.OracleXADataSource</xa-datasource-class> 
    <xa-datasource-property name="URL">$DS_MOBTRATEL_URL</xa-datasource-property>
    <xa-datasource-property name="User">$DS_MOBTRATEL_USER</xa-datasource-property>
    <xa-datasource-property name="Password">$DS_MOBTRATEL_PASS</xa-datasource-property>
    <exception-sorter-class-name>org.jboss.resource.adapter.jdbc.vendor.OracleExceptionSorter</exception-sorter-class-name>
    <no-tx-separate-pools/>
      <metadata>
         <type-mapping>$DS_MOBTRATEL_TYPEMAPPING</type-mapping>
      </metadata>
  </xa-datasource>
</datasources>
EOF
	) > "${DIR_BASE}/jboss/server/${INSTANCIA}/deploysistra/mobtratel-oracle-ds.xml"
    ;;
    *)
	echo ""
	echo "ERROR: Driver no suportat [$DS_MOBTRATEL_CLASS]"
	exit 1
    ;;
esac
echo "OK"

echo -n "##### configurant redose amb "
case $DS_REDOSE_CLASS in
    org.postgresql.xa.PGXADataSource)
	echo -n "Postgresql: "
	( cat << EOF
<?xml version="1.0" encoding="UTF-8"?>
<datasources>
  <xa-datasource>
    <jndi-name>es.caib.redose.db</jndi-name>
    <track-connection-by-tx/>
    <isSameRM-override-value>false</isSameRM-override-value>
    <xa-datasource-class>org.postgresql.xa.PGXADataSource</xa-datasource-class>
     <xa-datasource-property name="ServerName">$DS_REDOSE_SERVER</xa-datasource-property>
     <xa-datasource-property name="PortNumber">$DS_REDOSE_PORT</xa-datasource-property>
     <xa-datasource-property name="DatabaseName">$DS_REDOSE_DATABASE</xa-datasource-property>
    <xa-datasource-property name="User">$DS_REDOSE_USER</xa-datasource-property>
    <xa-datasource-property name="Password">$DS_REDOSE_PASS</xa-datasource-property>
    <no-tx-separate-pools/>
      <metadata>
         <type-mapping>$DS_REDOSE_TYPEMAPPING</type-mapping>
      </metadata>
  </xa-datasource>
</datasources>
EOF
	) > "${DIR_BASE}/jboss/server/${INSTANCIA}/deploysistra/redose-postgresql-ds.xml"
    ;;
    oracle.jdbc.xa.client.OracleXADataSource)
	echo -n "Oracle: "
	( cat << EOF
<?xml version="1.0" encoding="UTF-8"?>
<datasources>
  <xa-datasource>
    <jndi-name>es.caib.redose.db</jndi-name>
    <track-connection-by-tx/>
    <isSameRM-override-value>false</isSameRM-override-value>
    <xa-datasource-class>oracle.jdbc.xa.client.OracleXADataSource</xa-datasource-class> 
    <xa-datasource-property name="URL">$DS_REDOSE_URL</xa-datasource-property>
    <xa-datasource-property name="User">$DS_REDOSE_USER</xa-datasource-property>
    <xa-datasource-property name="Password">$DS_REDOSE_PASS</xa-datasource-property>
    <exception-sorter-class-name>org.jboss.resource.adapter.jdbc.vendor.OracleExceptionSorter</exception-sorter-class-name>
    <no-tx-separate-pools/>
      <metadata>
         <type-mapping>$DS_REDOSE_TYPEMAPPING</type-mapping>
      </metadata>
  </xa-datasource>
</datasources>
EOF
	) > "${DIR_BASE}/jboss/server/${INSTANCIA}/deploysistra/redose-oracle-ds.xml"
    ;;
    *)
	echo ""
	echo "ERROR: Driver no suportat [$DS_REDOSE_CLASS]"
	exit 1
    ;;
esac
echo "OK"

echo -n "##### configurant sistra amb "
case $DS_SISTRA_CLASS in
    org.postgresql.xa.PGXADataSource)
	echo -n "Postgresql: "
	( cat << EOF
<?xml version="1.0" encoding="UTF-8"?>
<datasources>
  <xa-datasource>
    <jndi-name>es.caib.sistra.db</jndi-name>
    <track-connection-by-tx/>
    <isSameRM-override-value>false</isSameRM-override-value>
    <xa-datasource-class>org.postgresql.xa.PGXADataSource</xa-datasource-class>
     <xa-datasource-property name="ServerName">$DS_SISTRA_SERVER</xa-datasource-property>
     <xa-datasource-property name="PortNumber">$DS_SISTRA_PORT</xa-datasource-property>
     <xa-datasource-property name="DatabaseName">$DS_SISTRA_DATABASE</xa-datasource-property>
    <xa-datasource-property name="User">$DS_SISTRA_USER</xa-datasource-property>
    <xa-datasource-property name="Password">$DS_SISTRA_PASS</xa-datasource-property>
    <no-tx-separate-pools/>
      <metadata>
         <type-mapping>$DS_SISTRA_TYPEMAPPING</type-mapping>
      </metadata>
  </xa-datasource>
</datasources>
EOF
	) > "${DIR_BASE}/jboss/server/${INSTANCIA}/deploysistra/sistra-postgresql-ds.xml"
    ;;
    oracle.jdbc.xa.client.OracleXADataSource)
	echo -n "Oracle: "
	( cat << EOF
<?xml version="1.0" encoding="UTF-8"?>
<datasources>
  <xa-datasource>
    <jndi-name>es.caib.sistra.db</jndi-name>
    <track-connection-by-tx/>
    <isSameRM-override-value>false</isSameRM-override-value>
    <xa-datasource-class>oracle.jdbc.xa.client.OracleXADataSource</xa-datasource-class> 
    <xa-datasource-property name="URL">$DS_SISTRA_URL</xa-datasource-property>
    <xa-datasource-property name="User">$DS_SISTRA_USER</xa-datasource-property>
    <xa-datasource-property name="Password">$DS_SISTRA_PASS</xa-datasource-property>
    <exception-sorter-class-name>org.jboss.resource.adapter.jdbc.vendor.OracleExceptionSorter</exception-sorter-class-name>
    <no-tx-separate-pools/>
      <metadata>
         <type-mapping>$DS_SISTRA_TYPEMAPPING</type-mapping>
      </metadata>
  </xa-datasource>
</datasources>
EOF
	) > "${DIR_BASE}/jboss/server/${INSTANCIA}/deploysistra/sistra-oracle-ds.xml"
    ;;
    *)
	echo ""
	echo "ERROR: Driver no suportat [$DS_SISTRA_CLASS]"
	exit 1
    ;;
esac
echo "OK"

echo -n "##### configurant zonaper amb "
case $DS_ZONAPER_CLASS in
    org.postgresql.xa.PGXADataSource)
	echo -n "Postgresql: "
	( cat << EOF
<?xml version="1.0" encoding="UTF-8"?>
<datasources>
  <xa-datasource>
    <jndi-name>es.caib.zonaper.db</jndi-name>
    <track-connection-by-tx/>
    <isSameRM-override-value>false</isSameRM-override-value>
    <xa-datasource-class>org.postgresql.xa.PGXADataSource</xa-datasource-class>
     <xa-datasource-property name="ServerName">$DS_ZONAPER_SERVER</xa-datasource-property>
     <xa-datasource-property name="PortNumber">$DS_ZONAPER_PORT</xa-datasource-property>
     <xa-datasource-property name="DatabaseName">$DS_ZONAPER_DATABASE</xa-datasource-property>
    <xa-datasource-property name="User">$DS_ZONAPER_USER</xa-datasource-property>
    <xa-datasource-property name="Password">$DS_ZONAPER_PASS</xa-datasource-property>
    <no-tx-separate-pools/>
      <metadata>
         <type-mapping>$DS_ZONAPER_TYPEMAPPING</type-mapping>
      </metadata>
  </xa-datasource>
</datasources>
EOF
	) > "${DIR_BASE}/jboss/server/${INSTANCIA}/deploysistra/zonaper-postgresql-ds.xml"
    ;;
    oracle.jdbc.xa.client.OracleXADataSource)
	echo -n "Oracle: "
	( cat << EOF
<?xml version="1.0" encoding="UTF-8"?>
<datasources>
  <xa-datasource>
    <jndi-name>es.caib.zonaper.db</jndi-name>
    <track-connection-by-tx/>
    <isSameRM-override-value>false</isSameRM-override-value>
    <xa-datasource-class>oracle.jdbc.xa.client.OracleXADataSource</xa-datasource-class> 
    <xa-datasource-property name="URL">$DS_ZONAPER_URL</xa-datasource-property>
    <xa-datasource-property name="User">$DS_ZONAPER_USER</xa-datasource-property>
    <xa-datasource-property name="Password">$DS_ZONAPER_PASS</xa-datasource-property>
    <exception-sorter-class-name>org.jboss.resource.adapter.jdbc.vendor.OracleExceptionSorter</exception-sorter-class-name>
    <no-tx-separate-pools/>
      <metadata>
         <type-mapping>$DS_ZONAPER_TYPEMAPPING</type-mapping>
      </metadata>
  </xa-datasource>
</datasources>
EOF
	) > "${DIR_BASE}/jboss/server/${INSTANCIA}/deploysistra/zonaper-oracle-ds.xml"
    ;;
    *)
	echo ""
	echo "ERROR: Driver no suportat [$DS_ZONAPER_CLASS]"
	exit 1
    ;;
esac
echo "OK"

pause

}
# conf_ds


bin_ear(){
# baixar/copiar les ear
# DEMANAR SI SÓN OBLIGATORIS TOTS. ATURAR SI FALLA? CONTINUAR AMB UN AVÍS?

echo -n "### copiant ear SISTRA: "
if [ ! -e "$EAR_SISTRA" ]; then
	if [ "$HTTP_EAR_SISTRA" == "" ]; then
	    echo "ERROR: No s'ha trobat el paquet [$EAR_SISTRA]"
	    exit 1
	else
	    echo "### baixant el paquet des de [$HTTP_EAR_SISTRA]"
	    wget --no-check-certificate --no-cookies -nv -O "$EAR_SISTRA" "$HTTP_EAR_SISTRA"
	    check_err "$?"
	fi
fi
cp -v "$EAR_SISTRA" "${DIR_BASE}/jboss/server/${INSTANCIA}/deploysistra/"

echo -n "### copiant ear CLIENTCERT: "
if [ ! -e "$EAR_CLIENTCERT" ]; then
	if [ "$HTTP_EAR_CLIENTCERT" == "" ]; then
	    echo "ERROR: No s'ha trobat el paquet [$EAR_CLIENTCERT]"
	    exit 1
	else
	    echo "### baixant el paquet des de [$HTTP_EAR_CLIENTCERT]"
	    wget --no-check-certificate --no-cookies -nv -O "$EAR_CLIENTCERT" "$HTTP_EAR_CLIENTCERT"
	    check_err "$?"
	fi
fi
cp -v "$EAR_CLIENTCERT" "${DIR_BASE}/jboss/server/${INSTANCIA}/deploysistra/"

echo -n "### copiant ear PLUGINMOCK: "
if [ ! -e "$EAR_PLUGINMOCK" ]; then
	if [ "$HTTP_EAR_PLUGINMOCK" == "" ]; then
	    echo "ERROR: No s'ha trobat el paquet [$EAR_PLUGINMOCK]"
	    exit 1
	else
	    echo "### baixant el paquet des de [$HTTP_EAR_PLUGINMOCK]"
	    wget --no-check-certificate --no-cookies -nv -O "$EAR_PLUGINMOCK" "$HTTP_EAR_PLUGINMOCK"
	    check_err "$?"
	fi
fi
cp -v "$EAR_PLUGINMOCK" "${DIR_BASE}/jboss/server/${INSTANCIA}/deploysistra/"

echo -n "### copiant ear SISTRACONSOLA: "
if [ ! -e "$EAR_SISTRACONSOLA" ]; then
	if [ "$HTTP_EAR_SISTRACONSOLA" == "" ]; then
	    echo "ERROR: No s'ha trobat el paquet [$EAR_SISTRACONSOLA]"
	    exit 1
	else
	    echo "### baixant el paquet des de [$HTTP_EAR_SISTRACONSOLA]"
	    wget --no-check-certificate --no-cookies -nv -O "$EAR_SISTRACONSOLA" "$HTTP_EAR_SISTRACONSOLA"
	    check_err "$?"
	fi
fi
cp -v "$EAR_SISTRACONSOLA" "${DIR_BASE}/jboss/server/${INSTANCIA}/deploysistra/"
pause

}

custom(){
    # espai per personalitzar l'script
    VARIABLE="VALOR"
    # configuració LDAP
#Configurar accés dels usuaris. Afegir al final del fitxer $JBOSS/server/default/conf/login-config.xml
echo -n "### configurant autenticació ldap: "
F_AUTH="${DIR_BASE}/jboss/server/${INSTANCIA}/conf/login-config.xml"
grep "ldap.imasmallorca.net" "$F_AUTH"
if [ "$?" != "0" ]; then
    sed -i 's|^</policy>.*||' "$F_AUTH"
(
cat << EOF

<application-policy name = "seycon">
	<authentication>
		<login-module code = "es.caib.mock.loginModule.MockCertificateLoginModule" flag = "sufficient">
			<module-option name="roleTothom">tothom</module-option>
		</login-module>
		<login-module code = "es.caib.mock.loginModule.MockDatabaseLoginModule" flag = "sufficient">
			<module-option name="unauthenticatedIdentity">nobody</module-option>
			<module-option name = "dsJndiName">java:/es.caib.mock.loginModule.db</module-option>
			<module-option name = "principalsQuery">SELECT USU_PASS,USU_NOM,USU_NIF FROM SC_WL_USUARI WHERE USU_CODI = ?</module-option>
			<module-option name = "rolesQuery">SELECT UGR_CODGRU, 'Roles' FROM SC_WL_USUGRU WHERE UGR_CODUSU = ?</module-option>
		</login-module>
	</authentication>
</application-policy>
</policy>
EOF
) >> "$F_AUTH"
fi
echo "OK"



    # baixar/copiar certificats

    # pujam la verbositat del log de seguritat
    sed -i 's|   <!-- Limit the org.apache category|\t<category name="org.jboss.security">\n\t\t<priority value="TRACE"/>\n\t</category>\n\n   <!-- Limit the org.apache category|' "${DIR_BASE}/jboss/server/${INSTANCIA}/conf/log4j.xml" 

pause

}



help(){
    # 
    echo "Instal·lador Sistra"
    echo "Aquest instal·lador respecta els fitxers de configuració FORA del"
    echo "directori arrel del JBoss/Java. És a dir, els fitxers de propeties"
    echo "i la configuració del propi script"
    echo ""
    echo "Arguments:"
    echo "-all: executa totes les passes"
    echo "-p: instal·la els paquets de dependències"
    echo "-i: crea la instància de JBoss"
    echo "-s: crea script d'inici"
    echo "-e: instal·la les biblioteques extres"
    echo "-c: instal·la les biblioteques CAIB"
    echo "-j: configura les opcions de JBoss"
    echo "-r: crea els fitxers de properties"
    echo "-d: crea els fitxers de DataSources"
    echo "-b: instal·la els paquets ear"
    echo "-u: executa el bloc personalitzat (custom)"
    echo ""
    echo "En una instal·lació nova s'ha d'executar <-all>"
    echo "Per ex: $0 -all"
}


### MAIN
[ "$1" == "" ] && help
for i in "$@"; do
    case $i in
	-all)
	    f_conf
	    precheck
	    paquets
	    instancia
	    script_inici
	    lib_extras
	    lib_caib
	    conf_jboss
	    conf_properties
	    conf_ds
	    bin_ear
	    custom
	    # ja no executam res més
	    echo "`date` - finalitzat"
	    exit 0
	;;
	-p)
	    f_conf
	    precheck
	    paquets
	;;
	-i)
	    f_conf
	    precheck
	    instancia
	;;
	-s)
	    f_conf
	    precheck
	    script_inici
	;;
	-e)
	    f_conf
	    precheck
	    lib_extras
	;;
	-c)
	    f_conf
	    precheck
	    lib_caib
	;;
	-j)
	    f_conf
	    precheck
	    conf_jboss
	;;
	-r)
	    f_conf
	    precheck
	    conf_properties
	;;
	-d)
	    f_conf
	    precheck
	    conf_ds
	;;
	-u)
	    f_conf
	    precheck
	    custom
	;;
	-b)
	    f_conf
	    precheck
	    bin_ear
	;;
	*)
	    help
	;;
    esac
done

echo "`date` - finalitzat"
exit 0

#####################################################################
#####################################################################
########################### REPASSAR!!!! ############################
#####################################################################
# vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv #

#Copia de binaris
echo -n "	# Copiant Binaris: " 
# PENDENT DE CONFIRMACIÓ
cp -v "$MOCK_JAR"   "${DIR_BASE}/jboss/server/${INSTANCIA}/lib/"


# PENDENT DE CONFIRMACIÓ
# la part de certificats la deix deshabilitada per ara
conf_certs(){
echo -n "### creant : "

cp  "$CLIENTECERT_PROPIETATS" -r "${DIR_BASE}/config_sistra/sistra/"

echo "OK"
}
# conf_certs
