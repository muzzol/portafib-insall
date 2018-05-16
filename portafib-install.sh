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

VER="0.3"

# cream un log amb la sortida de tot l'script (dona problemes amb
# els retorns de carro en cas d'esperar entrada per STDIN)
# DATA=`date +%d-%m-%Y-%H%M%S` && FLOG="${0##*/}" && FLOG="${FLOG%.*}"
# exec > >(tee -i "${FLOG}-${DATA}.log")
# exec 2>&1 | tee "${FLOG}-${DATA}.log"

echo "`date` - $0 - v$VER"

# directori actual
CDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# comprovam que s'estigui executant com a root"
USCRIPT=`id -run`

if [ "$USCRIPT" != "root" ]; then
    echo "ERROR: aquest script està pensat per ser executat com a root."
    echo "Haureu de modificar els valors per defecte del fitxer de configuració"
    echo "perquè no apuntin a directoris on no teniu permís d'escriptura."
    echo -n "Si estau segurs de voler continuar escriviu OK: "
    read OK
    if [ "$OK" == "ok" ] || [ "$OK" == "OK" ]; then
	echo "Continuant amb usuari [$USCRIPT]..."
    else
	echo "Sortint..."
	exit 1
    fi
fi


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

# crea una plantilla de configuració amb valors per defecte
f_template(){
    FTEMPLATE="$1"
    echo "### Creant la plantilla [$FTEMPLATE]"
    ( cat << 'EOF'

####
#### VARIABLES GENERALS
####

# entitat (normalment el nom de l'ajuntament/entitat)
ENTITAT="ticmallorca"
# directori arrel de tota la instal·lació
DIR_BASE="/opt/portafib-$ENTITAT"
# usuari amb el que s'executarà el servei
USUARI="portafib"
# nom de la instància
INSTANCIA="$ENTITAT"
# nom del servidor. pot esser també una IP, però hauria d'esser
# el FQDN que se resol públicament
SERVIDOR="portafibpre01.test.com"
# SERVIDOR="172.26.67.167"

####
#### PROPIETATS PORTAFIB I PLUGINS
####

# Propietat que indica als projectes que activin les caracteristiques
# especials requerides en l'entorn de la CAIB (Govern Balear) si val true
PORTAFIB_ISCAIB="false"

# Dialecte de Hibernate. Pot tenir els valors: 
# org.hibernate.dialect.PostgreSQLDialect
# org.hibernate.dialect.MySQLDialect
# org.hibernate.dialect.DB2Dialect
# org.hibernate.dialect.SQLServerDialect
# net.sf.hibernate.dialect.Oracle9Dialect
# org.hibernate.dialect.Oracle10gDialect
HIB_DIALECT="org.hibernate.dialect.PostgreSQLDialect"

# es.caib.portafib.hibernate.query.substitutions=true 1, false 0

# Directori on es guardaran tots els fitxers de PortaFIB-->
PORTAFIB_FILES="/opt/portafibfiles"

# Clau per encriptar l'identificador del fitxers a descarregar via web (IMPORTANT la 
# mida ha de ser de 16 caràcters)
PORTAFIB_ENCRYPTKEY="abcdefgh12345678"

# plugin d'informació de l'usuari (es.caib.portafib.userinformationplugin). pot ser
# pot ser: bbdd, ldap
PORTAFIB_PLUGIN_INFOUSER="ldap"

# BBDD per la informació de l'usuari (s'ignoren aquestes dades en cas
# d'utilitzar un altre plugin a la variable PORTAFIB_INFOUSER)


# LDAP per la informació del l'usuari (s'ignoren aquestes dades en cas
# d'utilitzar un altre plugin a la variable PORTAFIB_INFOUSER)
PLUGIN_USERINFOLDAP_HOST="ldap://ldap.ticmallorca.net:389"
PLUGIN_USERINFOLDAP_PRINCIPAL="uid=app002,ou=users,dc=consorci,dc=global"
PLUGIN_USERINFOLDAP_CREDENTIALS="SuPerPa44"
PLUGIN_USERINFOLDAP_USERSDN="ou=users,dc=consorci,dc=global"
PLUGIN_USERINFOLDAP_FILTER="(|(memberof=cn=rol-app3,ou=rols,ou=groups,dc=consorci,dc=global)(memberof=cn=RSC_OPER,ou=rolsac,ou=rols,ou=groups,dc=consorci,dc=global))"
PLUGIN_USERINFOLDAP_ATTR_USERNAME="uid"
PLUGIN_USERINFOLDAP_ATTR_NAME="cn"
PLUGIN_USERINFOLDAP_ATTR_SURNAME="sn"
PLUGIN_USERINFOLDAP_ATTR_MEMBEROF="memberof"
PLUGIN_USERINFOLDAP_PREFIX_MEMBEROF="cn="
PLUGIN_USERINFOLDAP_SUFIX_MEMBEROF=",ou=rols,ou=groups,dc=consorci,dc=global"

# 2.3.4.- Configurar Servidor de Correu
CORREU_USUARI="e-admin@ticmallorca.net"
CORREU_POP3="smtp.ticmallorca.net"
CORREU_SMTP="smtp.ticmallorca.net"
CORREU_ORIGEN="portafib@ticmallorca.net"

####
#### Autenticació
####

# 2.3.5.- Autenticació i Autorització per Usuaris Persona
# aquests són els usuaris d'administració i gestió del
# sistema, no els usuaris de la pròpia aplicació portafib

# sistema d'autenticació. pot ser bbdd o ldap. en cas de
# utilitzar ldap s'utilitzaran les dades del plugin userinfo
AUTH_PERSONA="bbdd"

AUTH_PERSONA_DS_URL="jdbc:postgresql://localhost:5432/seycon"
AUTH_PERSONA_DS_DRIVER="org.postgresql.Driver"
AUTH_PERSONA_DS_USER="seycon"
AUTH_PERSONA_DS_PASS="seycon"

# 2.5.- DataSources
# ds per la bbdd portafib d'usuaris d'aplicació
DS_PORTAFIB_URL="jdbc:postgresql://localhost:5432/portafib"
DS_PORTAFIB_DRIVER="org.postgresql.Driver"
DS_PORTAFIB_USER="portafib"
DS_PORTAFIB_PASS="portafib"

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
POSTGRESQL_JAR="${DIR_PAQUETS}/postgresql-9.3-1102-jdbc3.jar"	# comentar o deixar en blanc si no se fa servir
HTTP_POSTGRESQL_JAR="http://central.maven.org/maven2/org/postgresql/postgresql/9.3-1102-jdbc3/postgresql-9.3-1102-jdbc3.jar" # OPCIONAL: URL des d'on baixar el paquet

# biblioteca jboss-metadata.jar
PAQUET_METADATA="${DIR_PAQUETS}/jboss-metadata.jar"
HTTP_PAQUET_METADATA="https://repository.jboss.org/nexus/content/repositories/root_repository/jboss/metadata/1.0.6.GA-brew/lib/jboss-metadata.jar"

# biblioteca CXF
PAQUET_CXF="${DIR_PAQUETS}/jbossws-cxf-3.4.0.GA.zip"
HTTP_PAQUET_CXF="http://download.jboss.org/jbossws/jbossws-cxf-3.4.0.GA.zip"

# altres fitxers
SCRIPT_INICI="/etc/init.d/jboss-portafib-${ENTITAT}"

# biblioteca LDAP login
LDAPLOGIN_JAR="${DIR_PAQUETS}/loginmodule-jboss-ldap-1.0.0.jar"
HTTP_LDAPLOGIN_JAR="https://github.com/GovernIB/maven/raw/gh-pages/maven/org/fundaciobit/plugins/loginmodule-jboss-ldap/1.0.0/loginmodule-jboss-ldap-1.0.0.jar"

# biblioteca utils LDAP
LDAPUTILS_JAR="${DIR_PAQUETS}/plugins-utils-ldap-1.0.0.jar"
HTTP_LDAPUTILS_JAR="https://github.com/GovernIB/maven/raw/gh-pages/maven/org/fundaciobit/plugins/plugins-utils-ldap/1.0.0/plugins-utils-ldap-1.0.0.jar"

# ears
EAR_PORTAFIB="${DIR_PAQUETS}/portafib.ear"
HTTP_EAR_PORTAFIB="https://github.com/GovernIB/portafib/releases/download/portafib-1.1.4_2018-03-12/portafib.ear"


EOF
	) >> "$FTEMPLATE"

    pause
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
	f_template "$FCONF"
	exit 1
    fi

    # llegim el fitxer de configuració
    . "$FCONF"

    # comprovam que existeixin les variables necessàries al fitxer conf
    # en cas contrari probablement tenim un conf antic.
    CONVARS="ENTITAT DIR_BASE USUARI INSTANCIA SERVIDOR
PORTAFIB_ISCAIB HIB_DIALECT PORTAFIB_FILES PORTAFIB_ENCRYPTKEY PORTAFIB_PLUGIN_INFOUSER
PLUGIN_USERINFOLDAP_HOST PLUGIN_USERINFOLDAP_PRINCIPAL PLUGIN_USERINFOLDAP_CREDENTIALS PLUGIN_USERINFOLDAP_USERSDN
PLUGIN_USERINFOLDAP_FILTER PLUGIN_USERINFOLDAP_ATTR_USERNAME PLUGIN_USERINFOLDAP_ATTR_NAME PLUGIN_USERINFOLDAP_ATTR_SURNAME
PLUGIN_USERINFOLDAP_ATTR_MEMBEROF PLUGIN_USERINFOLDAP_PREFIX_MEMBEROF PLUGIN_USERINFOLDAP_SUFIX_MEMBEROF
CORREU_USUARI CORREU_POP3 CORREU_SMTP CORREU_ORIGEN 
AUTH_PERSONA AUTH_PERSONA_DS_URL AUTH_PERSONA_DS_DRIVER AUTH_PERSONA_DS_USER AUTH_PERSONA_DS_PASS
DS_PORTAFIB_URL DS_PORTAFIB_DRIVER DS_PORTAFIB_USER DS_PORTAFIB_PASS
DIR_PAQUETS
PAQUET_JAVA_JDK DIR_JAVA_JDK HTTP_PAQUET_JAVA_JDK
PAQUET_JBOSS DIR_JBOSS HTTP_PAQUET_JBOSS
ORACLE_JAR HTTP_ORACLE_JAR POSTGRESQL_JAR HTTP_POSTGRESQL_JAR 
PAQUET_METADATA HTTP_PAQUET_METADATA PAQUET_CXF HTTP_PAQUET_CXF
SCRIPT_INICI EAR_PORTAFIB HTTP_EAR_PORTAFIB
LDAPLOGIN_JAR HTTP_LDAPLOGIN_JAR LDAPUTILS_JAR HTTP_LDAPUTILS_JAR
"

    for c in $CONVARS ; do
	# echo "DEBUG: comprovant [$c]"
	grep -q "${c}=" "$FCONF"
	if [ "$?" != "0" ]; then
	    echo "ERROR: No s'ha trobat l'atribut [$c] a la configuració."
	    echo "Probablement el fitxer [$FCONF] s'ha creat amb una versió antiga de l'script."
	    echo "Utilitzeu la plantilla següent per comprovar els canvis."
	    f_template "${FCONF}.template"
	    exit 1
	fi
    done

    # comprovam que s'hagi configurat mínimament
    if [ "$ENTITAT" == "" ]; then
	echo "ERROR: configuració errònia. Revisa el fitxer [$FCONF]"
	exit 1
    fi

    pause
}


# comprovacions vàries
precheck(){
echo -n "### comprovacions de sistema: "
if ! id $USUARI > /dev/null ; then
    echo "ERROR: No s'ha trobat l'usuari $USUARI"
    echo "Comproveu la configuració al fitxer [$FCONF]"
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
DEBS="$DEBS libxtst6 libxi6 ant unzip"
if type -t dpkg > /dev/null ; then
    for d in $DEBS ; do
	# echo "DEBUG: comprovant $d"
	# dpkg -s "$d" > /dev/null 2>&1
	dpkg -l "$d" | grep -q "^ii"
	if [ "$?" != "0" ]; then
    	    export DEBIAN_FRONTEND=noninteractive
    	    apt-get -q -y install $d
	fi
    done
fi

# redhat/centos
RPMS="$RPMS ant"
## NO ESTÀ PROVAT!!!
if type -t yum > /dev/null ; then
    rpm -qa | grep -q libxtst6
    if [ "$?" != "0" ]; then
	yum install libXext.i686
    fi
fi

echo "OK"
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

# canviam l'index.html per defecte (això no és cap mesura de seguretat
# tan sols és per simplificar l'accés a l'aplicació)
mv "${DIR_BASE}/jboss/server/default/deploy/ROOT.war/index.html" "${DIR_BASE}/jboss/server/default/deploy/ROOT.war/index.html.orig"
echo '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
  <title>PortaFIB</title>
<META HTTP-EQUIV="Refresh" CONTENT="1; URL=/portafib/">

  </head>
  <body>

    <p style="text-align:center">PortaFIB</p>

</body>
</html>
' > "${DIR_BASE}/jboss/server/default/deploy/ROOT.war/index.html"

# feim propietari a l'usuari especificat
chown -R "$USUARI" "$DIR_BASE"

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
export JAVA_OPTS="-Djava.awt.headless=true -Xoss128m -Xms512m -Xmx1024m -XX:MaxPermSize=256m"

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



echo -n "### configurant CXF [$PAQUET_CXF]: "
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


# biblioteques commons d'apache.
# ATENCIÓ!!! AIXÒ HA D'ANAR DESPRÉS DE LA COMPILACIÓ CXF!!!
echo -n "### copiant biblioteca metadata [$PAQUET_METADATA]: "
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
cp -f "$PAQUET_METADATA" "${DIR_BASE}/jboss/common/lib/"
cp -f "$PAQUET_METADATA" "${DIR_BASE}/jboss/client/"
echo "OK"



# 2.3.1.- Fitxer JDBC d'accés a BBDD

# ORACLE: si la variable està definida asumim que se vol utilitzar
if [ "$ORACLE_JAR" != "" ]; then
    echo -n "### copiant biblioteca de bbdd d'oracle: "
    if [ ! -e "$ORACLE_JAR" ]; then
	if [ "$HTTP_ORACLE_JAR" == "" ]; then
	    echo "ERROR: No s'ha trobat el paquet [$ORACLE_JAR]"
	    exit 1
	else
	    echo "### baixant el paquet des de [$HTTP_ORACLE_JAR]"
	    wget --no-check-certificate --no-cookies -nv -O "$ORACLE_JAR" "$HTTP_ORACLE_JAR"
	    check_err "$?"
	fi
    fi
    cp -vf "$ORACLE_JAR" "${DIR_BASE}/jboss/common/lib/"
fi

# POSTGRESQL: si la variable està definida asumim que se vol utilitzar
if [ "$POSTGRESQL_JAR" != "" ]; then
    echo -n "### copiant biblioteca de postgresql: "
    if [ ! -e "$POSTGRESQL_JAR" ]; then
	if [ "$HTTP_POSTGRESQL_JAR" == "" ]; then
	    echo "ERROR: No s'ha trobat el paquet [$POSTGRESQL_JAR]"
	    exit 1
	else
	    echo "### baixant el paquet des de [$HTTP_POSTGRESQL_JAR]"
	    wget --no-check-certificate --no-cookies -nv -O "$POSTGRESQL_JAR" "$HTTP_POSTGRESQL_JAR"
	    check_err "$?"
	fi
    fi
    cp -vf "$POSTGRESQL_JAR" "${DIR_BASE}/jboss/common/lib/"
fi


pause

}


instancia(){
# ATENCIÓ: és convenient deixar la creació de la instància pel després 
# de la configuració del CXF i altres biblioteques ja que se sobreescriuen
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



conf_jboss(){
# configuracions dins del jboss


# opcions vàries de java dins el jboss
echo -n "### configurant opcions de java: "
echo 'export DISPLAY=":0.0"' >> "${DIR_BASE}/jboss/bin/run.conf"
JAVA_PATH="${DIR_BASE}/java/bin/java"
echo "JAVA=\"$JAVA_PATH\"" >> "${DIR_BASE}/jboss/bin/run.conf"
echo "OK"



echo -n "### configurant directori de desplegament: "
# F_DESPLEGAMENT="${DIR_BASE}/jboss/server/${INSTANCIA}/conf/jboss-service.xml"
F_DESPLEGAMENT="${DIR_BASE}/jboss/server/${INSTANCIA}/conf/bootstrap/profile.xml"
# <value>${jboss.server.home.url}deployportafib</value>
grep -q deployportafib "$F_DESPLEGAMENT"
if [ "$?" != "0" ]; then
    sed -i 's;url}deploy</value>;url}deploy</value>\n\t\t\t\t<value>${jboss.server.home.url}deployportafib</value>;' "$F_DESPLEGAMENT"
    mkdir "${DIR_BASE}/jboss/server/${INSTANCIA}/deployportafib"
fi
echo "OK"




# 2.2.5.- Permetre consultes sobre múltiples Datasources
echo -n "### configurant consultes sobre múltiples datasources: "
F_TSPROP="${DIR_BASE}/jboss/server/${INSTANCIA}/conf/jbossts-properties.xml"
grep -q com.arjuna.ats.jta.allowMultipleLastResources "$F_TSPROP"
if [ "$?" != "0" ]; then
    sed -i 's;arjuna" name="jta">;arjuna" name="jta">\n\t<property name="com.arjuna.ats.jta.allowMultipleLastResources" value="true" />;' "$F_TSPROP"
fi
echo "OK"


# 2.2.6.- Autenticador WSBASIC
echo -n "### configurant Autenticador WSBASIC: "
F_WSBASIC="${DIR_BASE}/jboss/server/${INSTANCIA}/deployers/jbossweb.deployer/META-INF/war-deployers-jboss-beans.xml"
grep -q '<key>WSBASIC</key>' "$F_WSBASIC"
if [ "$?" != "0" ]; then

    sed -i 's;<key>BASIC</key>;\t<key>WSBASIC</key>\n\t\t<value>org.apache.catalina.authenticator.BasicAuthenticator</value>\n\t</entry>\n\t<entry>\n\t\t<key>BASIC</key>;' "$F_WSBASIC"

fi
echo "OK"



pause
}



conf_properties(){

# 2.3.2.- Fitxer de Propietats
echo -n "### creant fitxer de propietats: "

case $PORTAFIB_PLUGIN_INFOUSER in
    ldap|org.fundaciobit.plugins.userinformation.ldap.LdapUserInformationPlugin)
	echo ""
	# POSTGRESQL: si la variable està definida asumim que se vol utilitzar
	if [ "$LDAPLOGIN_JAR" != "" ]; then
	    echo -n "##### baixant jar per autenticació LDAP"
	    if [ ! -e "$LDAPLOGIN_JAR" ]; then
		if [ "$HTTP_LDAPLOGIN_JAR" == "" ]; then
	    	    echo "ERROR: No s'ha trobat el paquet [$LDAPLOGIN_JAR]"
		    exit 1
		else
		    echo "### baixant el paquet des de [$HTTP_LDAPLOGIN_JAR]"
		    wget --no-check-certificate --no-cookies -nv -O "$LDAPLOGIN_JAR" "$HTTP_LDAPLOGIN_JAR"
		    check_err "$?"
		fi
	    fi
	    cp -vf "$LDAPLOGIN_JAR" "${DIR_BASE}/jboss/common/lib/"
	fi
	echo "OK"

	if [ "$LDAPUTILS_JAR" != "" ]; then
	    echo -n "##### baixant plugin utils per autenticació LDAP"
	    if [ ! -e "$LDAPUTILS_JAR" ]; then
		if [ "$HTTP_LDAPUTILS_JAR" == "" ]; then
	    	    echo "ERROR: No s'ha trobat el paquet [$LDAPUTILS_JAR]"
		    exit 1
		else
		    echo "### baixant el paquet des de [$HTTP_LDAPUTILS_JAR]"
		    wget --no-check-certificate --no-cookies -nv -O "$LDAPUTILS_JAR" "$HTTP_LDAPUTILS_JAR"
		    check_err "$?"
		fi
	    fi
	    cp -vf "$LDAPUTILS_JAR" "${DIR_BASE}/jboss/common/lib/"
	fi
	echo "OK"


	# plugin ldap info user
	PLUGIN_INFO_LDAP="
      <!-- ======== PLUGIN USER-INFORMATION - LDAP ======= -->
      es.caib.portafib.userinformationplugin=org.fundaciobit.plugins.userinformation.ldap.LdapUserInformationPlugin
      es.caib.portafib.plugins.userinformation.ldap.host_url=$PLUGIN_USERINFOLDAP_HOST
      es.caib.portafib.plugins.userinformation.ldap.security_principal=$PLUGIN_USERINFOLDAP_PRINCIPAL
      es.caib.portafib.plugins.userinformation.ldap.security_authentication=simple
      es.caib.portafib.plugins.userinformation.ldap.security_credentials=$PLUGIN_USERINFOLDAP_CREDENTIALS
      es.caib.portafib.plugins.userinformation.ldap.users_context_dn=$PLUGIN_USERINFOLDAP_USERSDN
      es.caib.portafib.plugins.userinformation.ldap.search_scope=subtree
      es.caib.portafib.plugins.userinformation.ldap.search_filter=$PLUGIN_USERINFOLDAP_FILTER
      es.caib.portafib.plugins.userinformation.ldap.attribute.username=$PLUGIN_USERINFOLDAP_ATTR_USERNAME
      es.caib.portafib.plugins.userinformation.ldap.attribute.mail=mail
      es.caib.portafib.plugins.userinformation.ldap.attribute.administration_id=employeeNumber
      es.caib.portafib.plugins.userinformation.ldap.attribute.name=$PLUGIN_USERINFOLDAP_ATTR_NAME
      # Has de triar:
      #       - surname1 i surname2
      #       - surname
      es.caib.portafib.plugins.userinformation.ldap.attribute.surname=$PLUGIN_USERINFOLDAP_ATTR_SURNAME

      es.caib.portafib.plugins.userinformation.ldap.attribute.surname1=sn1
      es.caib.portafib.plugins.userinformation.ldap.attribute.surname2=sn2

      es.caib.portafib.plugins.userinformation.ldap.attribute.telephone=telephoneNumber
      es.caib.portafib.plugins.userinformation.ldap.attribute.memberof=$PLUGIN_USERINFOLDAP_ATTR_MEMBEROF
      es.caib.portafib.plugins.userinformation.ldap.prefix_role_match_memberof=$PLUGIN_USERINFOLDAP_PREFIX_MEMBEROF
      es.caib.portafib.plugins.userinformation.ldap.suffix_role_match_memberof=$PLUGIN_USERINFOLDAP_SUFIX_MEMBEROF

	"

    ;;
    bbdd|org.fundaciobit.plugins.userinformation.database.DataBaseUserInformationPlugin)
	# plugin bbdd info user
	PLUGIN_INFO_BBDD="
	<!-- ======== PLUGIN USER-INFORMATION - DATABASE ======= -->
      es.caib.portafib.userinformationplugin=org.fundaciobit.plugins.userinformation.database.DataBaseUserInformationPlugin
      es.caib.portafib.plugins.userinformation.database.jndi=java:/es.caib.seycon.db.wl
      es.caib.portafib.plugins.userinformation.database.users_table=SC_WL_USUARI
      es.caib.portafib.plugins.userinformation.database.username_column=USU_CODI
      es.caib.portafib.plugins.userinformation.database.administrationid_column=USU_NIF
      es.caib.portafib.plugins.userinformation.database.name_column=USU_NOM
      #es.caib.portafib.plugins.userinformation.database.surname_1_column
      #es.caib.portafib.plugins.userinformation.database.surname_2_column      
      #es.caib.portafib.plugins.userinformation.database.language_column
      #es.caib.portafib.plugins.userinformation.database.telephone_column
      #es.caib.portafib.plugins.userinformation.database.email_column=USU_CODI
      #es.caib.portafib.plugins.userinformation.database.gender_column
      #es.caib.portafib.plugins.userinformation.database.password_column
      es.caib.portafib.plugins.userinformation.database.userroles_table=SC_WL_USUGRU
      es.caib.portafib.plugins.userinformation.database.userroles_rolename_column=UGR_CODGRU
      es.caib.portafib.plugins.userinformation.database.userroles_username_column=UGR_CODUSU

	"
    ;;
    *)
	# no hauria d'arribar mai aquí
	echo "ERROR: No s'ha trobat la configuració del plugin d'informació d'usuari"
	exit 1
    ;;
esac

F_PROPS="${DIR_BASE}/jboss/server/${INSTANCIA}/deployportafib/portafib-properties-service.xml"
( cat << EOF
<?xml version="1.0" encoding="UTF-8"?>
<server>
  <mbean code="org.jboss.varia.property.SystemPropertiesService" name="jboss:type=Service,name=PortaFIBSystemProperties">
    <attribute name="Properties">
      <!-- Propietat que indica als projectes que activin les caracteristiques
           especials requerides en l'entorn de la CAIB (Govern Balear) si val true ' -->
      es.caib.portafib.iscaib=$PORTAFIB_ISCAIB

      # Dialecte de Hibernate
      es.caib.portafib.hibernate.dialect=$HIB_DIALECT
      # es.caib.portafib.hibernate.query.substitutions=true 1, false 0

      <!-- Directori on es guardaran tots els fitxers de PortaFIB-->
      es.caib.portafib.filesdirectory="$PORTAFIB_FILES"

      es.caib.portafib.defaultlanguage=ca

      es.caib.portafib.development=false

      <!-- Clau per encriptar l'identificador del fitxers a descarregar via web'(IMPORTANT tamany de 16 caràcters) -->
      es.caib.portafib.encryptkey=$PORTAFIB_ENCRYPTKEY

      <!-- Llistat de Plugins per l'exportació de dades en els llistats (excel, ods, csv, ...)' -->
      es.caib.portafib.exportdataplugins=org.fundaciobit.plugins.exportdata.cvs.CSVPlugin,org.fundaciobit.plugins.exportdata.ods.ODSPlugin,org.fundaciobit.plugins.exportdata.excel.ExcelPlugin

      <!--  Opcional. Indica si s'ha de validar el certificat emprant el Plugin de CheckCertificate
             quan l'autenticació es realitza emprant ClientCert. Valor per defecte false. -->
      #es.caib.portafib.checkcertificateinclientcert=true 


      <!-- ======== PLUGIN DE CONVERSIO DE DOCUMENTS - OPENOFFICE ======= -->
      es.caib.portafib.documentconverterplugin=org.fundaciobit.plugins.documentconverter.openoffice.OpenOfficeDocumentConverterPlugin
      es.caib.portafib.plugins.documentconverter.openoffice.host=localhost
      es.caib.portafib.plugins.documentconverter.openoffice.port=8100

      <!-- ======== PLUGIN CHECK CERTIFICATE - FAKE ======= -->
      es.caib.portafib.certificateplugin=org.fundaciobit.plugins.certificate.fake.FakeCertificatePlugin

      <!-- ======== PLUGIN CHECK CERTIFICATE - @FIRMA ======= -->

      <!--
      es.caib.portafib.certificateplugin=org.fundaciobit.plugins.certificate.afirmacxf.AfirmaCxfCertificatePlugin

      # MODE_VALIDACIO_SIMPLE = 0;
      # MODE_VALIDACIO_AMB_REVOCACIO = 1;
      # MODE_VALIDACIO_CADENA = 2;      
      es.caib.portafib.plugins.certificate.afirma.validationmode=1

      #es.caib.portafib.plugins.certificate.afirma.endpoint=http://afirma.redsara.es/afirmaws/services/
      es.caib.portafib.plugins.certificate.afirma.endpoint=http://des-afirma.redsara.es/afirmaws/services/
      es.caib.portafib.plugins.certificate.afirma.applicationid=

      # USERNAME-PASSWORD Token
      #es.caib.portafib.plugins.certificate.afirma.authorization.username=
      #es.caib.portafib.plugins.certificate.afirma.authorization.password=

      # CERTIFICATE Token
      es.caib.portafib.plugins.certificate.afirma.authorization.ks.path=D:/dades/dades/CarpetesPersonals/Programacio/PortaFIB/plugins/plugins-certificate/afirma/proves-dgidt.jks
      es.caib.portafib.plugins.certificate.afirma.authorization.ks.type=JKS
      es.caib.portafib.plugins.certificate.afirma.authorization.ks.password=
      es.caib.portafib.plugins.certificate.afirma.authorization.ks.cert.alias=1
      es.caib.portafib.plugins.certificate.afirma.authorization.ks.cert.password=
      -->

	$PLUGIN_INFO_BBDD

	$PLUGIN_INFO_LDAP

      <!--  Afegir aqui altres propietats -->

    </attribute>
  </mbean>
</server>
EOF

) > "$F_PROPS"
echo "OK"

# directori del magatzem de fitxers
if [ ! -e "$PORTAFIB_FILES" ]; then
    echo -n "creant directori de magatzem de fitxers [$PORTAFIB_FILES]: "
    mkdir -vp "$PORTAFIB_FILES"
fi

pause
}


conf_plugins(){
echo "##### configuracions de plugins "

# 2.3.3.- Configurar Coes
echo -n "### configurant coes de correu: "
F_CORREU_QUEUE="${DIR_BASE}/jboss/server/${INSTANCIA}/deployportafib/portafib-mailsqueue-service.xml"
( cat << EOF
<?xml version="1.0" encoding="UTF-8"?>

<mbean code="org.jboss.jms.server.destination.QueueService" name="jboss.messaging.destination:service=Queue,name=jms/es.caib.portafib.PortaFIBMailsQueue" xmbean-dd="xmdesc/Queue-xmbean.xml">
    <depends optional-attribute-name="ServerPeer">jboss.messaging:service=ServerPeer</depends>
    <depends>jboss.messaging:service=PostOffice</depends>
    <attribute name="JNDIName">jms/es.caib.portafib.PortaFIBMailsQueue</attribute>
    <attribute name="RedeliveryDelay">10000</attribute>
    <attribute name="MaxDeliveryAttempts">3</attribute>
</mbean>

EOF
) > "$F_CORREU_QUEUE"
echo "OK"

# 2.3.4.- Configurar Servidor de Correu
echo -n "### configurant servidor de correu: "
F_CORREU_SERVER="${DIR_BASE}/jboss/server/${INSTANCIA}/deployportafib/portafib-mail-service.xml"
( cat << EOF
<?xml version="1.0" encoding="UTF-8"?>
<server>

  <!-- ==================================================================== -->
  <!-- Mail Connection Factory                                              -->
  <!-- ==================================================================== -->

  <mbean code="org.jboss.mail.MailService" name="jboss:service=portafibMail">
    <attribute name="JNDIName">java:/es.caib.portafib.mail</attribute>
    <attribute name="Configuration">
      <!-- A test configuration -->
      <configuration>
        <!-- Change to your mail server prototocol -->
        <property name="mail.store.protocol" value="pop3"/>
        <property name="mail.transport.protocol" value="smtp"/>

        <!-- Change to the user who will receive mail  -->
        <property name="mail.user" value="$CORREU_USUARI"/>

        <!-- Change to the mail server  -->
        <property name="mail.pop3.host" value="$CORREU_POP3"/>

        <!-- Change to the SMTP gateway server -->
        <property name="mail.smtp.host" value="$CORREU_SMTP"/>

        <!-- The mail server port -->
        <property name="mail.smtp.port" value="25"/>

        <!-- Change to the address mail will be from  -->
        <property name="mail.from" value="$CORREU_ORIGEN"/>

        <!-- Enable debugging output from the javamail classes -->
        <property name="mail.debug" value="false"/>
      </configuration>
    </attribute>
    <depends>jboss:service=Naming</depends>
  </mbean>
</server>
EOF
) > "$F_CORREU_SERVER"
echo "OK"


pause
}


conf_auth(){

# comprovam que s'hagi configurat ja el login-config.xml
grep -q '<application-policy name = "seycon">' "${DIR_BASE}/jboss/server/${INSTANCIA}/conf/login-config.xml"
if [ "$?" == "0" ]; then
    echo "### ja s'ha configurat login-config.xml "
else

case $AUTH_PERSONA in
    bbdd)
	echo -n "### Comprovant accés a la bbdd d'usuaris persona"
	CHECK_URI=`echo "${AUTH_PERSONA_DS_URL//jdbc:/}"`
	PGUSER="$AUTH_PERSONA_DS_USER"
	PGPASSWORD="$AUTH_PERSONA_DS_PASS"
	# el psql necessita les variables exportades explícitament
	export PGUSER PGPASSWORD
	psql -d "$CHECK_URI" -A -t -c "select count(*) from sc_wl_usuari"
	if [ "$?" != "0" ]; then
	    echo "ERROR: problemes en connectar a la BBDD"
	    echo "Estau segurs que voleu continuar? s/n: "
	    read BBDDOK
	    if [ "$BBDDOK" == "s" ] || [ "$OK" == "S" ]; then
		echo "Continuant sense comprovació de la bbdd..."
	    else
		echo "Comprova la connexió a la bbdd i torna a executar l'script"
	        echo "Sortint..."
		exit 1
    	    fi
	fi

	echo -n "### Creant DS per autenticació Persona: "
	# 2.3.5.- Autenticació i Autorització per Usuaris Persona

	( cat << EOF
<?xml version="1.0" encoding="UTF-8"?>
<datasources>
  <local-tx-datasource>
    <jndi-name>es.caib.seycon.db.wl</jndi-name>
    <connection-url>$AUTH_PERSONA_DS_URL</connection-url>
    <driver-class>$AUTH_PERSONA_DS_DRIVER</driver-class>
    <user-name>$AUTH_PERSONA_DS_USER</user-name>
    <password>$AUTH_PERSONA_DS_PASS</password>
  </local-tx-datasource>
</datasources>
EOF
	) > "${DIR_BASE}/jboss/server/${INSTANCIA}/deployportafib/seyconds-ds.xml"

	echo "OK"
	echo -n "### modificant login-config.xml per autenticació Persona amb BBDD: "

	# sed -i "s;^JBOSS_HOME=.*;JBOSS_HOME=\"${DIR_BASE}/jboss\";" "$SCRIPT_INICI"

	POLTEXT="    <!-- Directori BBDD per usuaris Persona -->
    <application-policy name = \"seycon\">

	<authentication>
	<!-- 2.3.5.- Autenticació i Autorització per Usuaris Persona
	    <login-module code=\"es.caib.portafib.back.security.BaseCertLoginModule\"  flag = \"sufficient\">
	    </login-module>
	    -->
	    <login-module code=\"org.jboss.security.auth.spi.DatabaseServerLoginModule\" flag=\"sufficient\"> 
		<module-option name=\"dsJndiName\">java:/es.caib.seycon.db.wl</module-option>
	        <module-option name=\"principalsQuery\">
	    	    select USU_PASS from SC_WL_USUARI where USU_CODI = ?
        	</module-option>
        	<module-option name=\"rolesQuery\">
		    select UGR_CODGRU, 'Roles' from SC_WL_USUGRU where UGR_CODUSU = ?
        	</module-option>
	    </login-module>
"

    ;;
    ldap)
	echo -n "### modificant login-config.xml per autenticació Persona amb LDAP: "
	# utilitzam les mateixes dades que pel plugin de userinfo
	POLTEXT="<!-- Directori LDAP per usuaris Persona -->

    <application-policy name = \"seycon\">
	<authentication>
         <login-module code=\"org.fundaciobit.plugins.loginmodule.ldap.LdapLoginModule\" flag=\"sufficient\" >
	    <module-option name=\"ldap.host_url\">$PLUGIN_USERINFOLDAP_HOST</module-option>
	    <module-option name=\"ldap.security_principal\">$PLUGIN_USERINFOLDAP_PRINCIPAL</module-option>
	    <module-option name=\"ldap.security_credentials\">$PLUGIN_USERINFOLDAP_CREDENTIALS</module-option>
	    <module-option name=\"ldap.security_authentication\">simple</module-option>
	    <module-option name=\"ldap.users_context_dn\">$PLUGIN_USERINFOLDAP_USERSDN</module-option>
	    <module-option name=\"ldap.search_scope\">subtree</module-option>
	    <module-option name=\"ldap.search_filter\">$PLUGIN_USERINFOLDAP_FILTER</module-option>
	    <module-option name=\"ldap.prefix_role_match_memberof\">$PLUGIN_USERINFOLDAP_PREFIX_MEMBEROF</module-option>
	    <module-option name=\"ldap.suffix_role_match_memberof\">$PLUGIN_USERINFOLDAP_SUFIX_MEMBEROF</module-option>
	    <module-option name=\"ldap.attribute.username\">$PLUGIN_USERINFOLDAP_ATTR_USERNAME</module-option>
	    <module-option name=\"ldap.attribute.mail\">mail</module-option>
	    <module-option name=\"ldap.attribute.administration_id\">employeeNumber</module-option>
	    <module-option name=\"ldap.attribute.name\">$PLUGIN_USERINFOLDAP_ATTR_NAME</module-option>
	    <module-option name=\"ldap.attribute.surname\">$PLUGIN_USERINFOLDAP_ATTR_SURNAME</module-option>
	    <module-option name=\"ldap.attribute.telephone\">telephoneNumber</module-option>
	    <module-option name=\"ldap.attribute.memberof\">$PLUGIN_USERINFOLDAP_ATTR_MEMBEROF</module-option>
	    <module-option name=\"ldap.attribute.surname1\">$PLUGIN_USERINFOLDAP_ATTR_SURNAME</module-option>
	    <module-option name=\"ldap.attribute.surname2\">$PLUGIN_USERINFOLDAP_ATTR_SURNAME</module-option>
	  </login-module>

"
    ;;
    *)
	# no hauria d'arribar mai aquí
	echo "ERROR: no s'ha configurat correctament"
	exit 1
    ;;
esac

# afegim també la part d'autenticació d'usuaris Aplicació
POLTEXT="$POLTEXT

	<!-- BBDD Usuaris Aplicació -->
	<login-module code=\"org.jboss.security.auth.spi.DatabaseServerLoginModule\" flag=\"sufficient\">
	    <module-option name=\"dsJndiName\">java:/es.caib.portafib.db</module-option>
	    <module-option name=\"principalsQuery\">
		SELECT contrasenya FROM pfi_usuariaplicacio WHERE usuariaplicacioid = ?
	    </module-option>
	    <module-option name=\"rolesQuery\">
		SELECT roleid, 'Roles' FROM pfi_roleusuariaplicacio where usuariaplicacioid = ?
	    </module-option>
	</login-module>

	</authentication>
    </application-policy>
</policy>"

# POLTEXT=`echo "$POLTEXT" | sed -E ':a;N;$!ba;s/\r{0,1}\n/\\\n/g'`
POLTEXT=`echo "$POLTEXT" | sed 's/$/\\\n/' | tr -d '\n'`

sed -i "s;</policy>;$POLTEXT;" "${DIR_BASE}/jboss/server/${INSTANCIA}/conf/login-config.xml"

echo "OK"

fi

}

conf_ds(){

echo -n "### Comprovant accés a la bbdd: "
# jdbc:postgresql://localhost:5432/portafib
CHECK_URI=`echo "${DS_PORTAFIB_URL//jdbc:/}"`
PGUSER="$DS_PORTAFIB_USER"
PGPASSWORD="$DS_PORTAFIB_PASS"
# el psql necessita les variables exportades explícitament
export PGUSER PGPASSWORD
psql -d "$CHECK_URI" -A -t -c "select count(*) from pfi_role"
if [ "$?" != "0" ]; then
    echo "ERROR: problemes en connectar a la BBDD"
    echo "Estau segurs que voleu continuar? s/n: "
    read BBDDOK
    if [ "$BBDDOK" == "s" ] || [ "$OK" == "S" ]; then
	echo "Continuant sense comprovació de la bbdd..."
    else
	echo "Comprova la connexió a la bbdd i torna a executar l'script"
	echo "Sortint..."
	exit 1
    fi
fi


echo -n "### Creant DS portafib per usuaris de la aplicació: "

# 2.5.- DataSources
( cat << EOF
<?xml version="1.0" encoding="UTF-8"?>
<datasources>
    <local-tx-datasource>
        <jndi-name>es.caib.portafib.db</jndi-name>
        <connection-url>$DS_PORTAFIB_URL</connection-url>
        <driver-class>$DS_PORTAFIB_DRIVER</driver-class>
        <user-name>$DS_PORTAFIB_USER</user-name>
        <password>$DS_PORTAFIB_PASS</password>
    </local-tx-datasource>
</datasources>
EOF
) > "${DIR_BASE}/jboss/server/${INSTANCIA}/deployportafib/portafib-ds.xml"

echo "OK"

pause

}


bin_ear(){
# baixar/copiar les ear

echo -n "### copiant ear PORTAFIB: "
if [ ! -e "$EAR_PORTAFIB" ]; then
	if [ "$HTTP_EAR_PORTAFIB" == "" ]; then
	    echo "ERROR: No s'ha trobat el paquet [$EAR_PORTAFIB]"
	    exit 1
	else
	    echo "### baixant el paquet des de [$HTTP_EAR_PORTAFIB]"
	    wget --no-check-certificate --no-cookies -nv -O "$EAR_PORTAFIB" "$HTTP_EAR_PORTAFIB"
	    check_err "$?"
	fi
fi
cp -v "$EAR_PORTAFIB" "${DIR_BASE}/jboss/server/${INSTANCIA}/deployportafib/"

pause

}

custom(){
    # espai per personalitzar l'script
    VARIABLE="1"
    # configuració LDAP

    # pujam la verbositat del log de seguritat
    sed -i 's|   <!-- Limit the org.apache category|\t<category name="org.jboss.security">\n\t\t<priority value="TRACE"/>\n\t</category>\n\n   <!-- Limit the org.apache category|' "${DIR_BASE}/jboss/server/${INSTANCIA}/conf/jboss-log4j.xml"

pause

}



help(){
    # 
    echo "Instal·lador Portafib"
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
	    script_inici
	    lib_extras
	    # lib_caib
	    instancia
	    conf_jboss
	    conf_properties
	    conf_plugins
	    conf_auth
	    conf_ds
	    # echo "DEBUG - `date` - surt" ; exit 0
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
	    # a portafib no se fa servir
	    exit 1
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

