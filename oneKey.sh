#!/bin/bash
set -x

# this shell start dir, normally original path
startDir=`pwd`
# main work directory, usually ~/myGit
mainWd=$startDir

# common install directory
commInstdir=~/.usr
ctagsInstDir=$commInstdir
javaInstDir=/usr/lib/jvm/java-8-self
tomcatInstDir=/opt/tomcat8-self
# id to run tomcat
tomcatUser=tomcat8
tomcatGrp=tomcat8
# dynamic env global name
dynamicEnvName=dynamic.env
opengrokInstanceBase=/var/opengrok

logo() {
    cat << "_EOF"
  ___  _ __   ___ _ __   __ _ _ __ ___ | | __
 / _ \| '_ \ / _ \ '_ \ / _` | '__/ _ \| |/ /
| (_) | |_) |  __/ | | | (_| | | | (_) |   <
 \___/| .__/ \___|_| |_|\__, |_|  \___/|_|\_\
      |_|               |___/

_EOF
}

usage() {
	exeName=${0##*/}
    cat << _EOF
[NAME]
	$exeName -- setup opengrok through one script

[USAGE]
	$exeName [install | help]

_EOF
	logo
}

installCtags() {
    
    cat << "_EOF"
    
------------------------------------------------------
STEP 1: INSTALLING UNIVERSAL CTAGS ...
------------------------------------------------------
_EOF
    CTAGS_HOME=$ctagsInstDir

    cd $mainWd
    dirName=ctags
    
    if [[ -d "$dirName" ]]; then
        echo [Warning]: $dirName/ already exists, Omitting this ...
        # echo Removing existing "$dirName"/ ...
        # rm -rf $dirName
    else
        cd $startDir
        git clone https://github.com/universal-ctags/ctags

        # check if wget returns successfully
        if [[ $? != 0 ]]; then
            echo [Error]: wget returns error, quiting now ...
            exit
        fi
    fi
    
    cd $dirName
    echo cd into  "$(pwd)"/ ...
    echo Begin to compile universal ctags ...
    sleep 1
    ./autogen.sh
    ./configure --prefix=$ctagsInstDir
    make -j
    sleep 1
    make install
    
    cat << _EOF
    
------------------------------------------------------
ctags path = $ctagsInstDir/bin/
------------------------------------------------------
ctags --version

$($ctagsInstDir/bin/ctags --version)

------------------------------------------------------
INSTALLING UNIVERSAL CTAGS DONE ...
------------------------------------------------------
_EOF
}

installJava8() {
    cat << "_EOF"
    
------------------------------------------------------
STEP 2: INSTALLING JAVA 8 ...
------------------------------------------------------
_EOF
    # instruction to install java8
    # wget --no-check-certificate -c --header "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/8u151-b12/e758a0de34e24606bca991d704f6dcbf/jdk-8u151-linux-x64.tar.gz
    JAVA_HOME=$javaInstDir
    local wgetLink="http://download.oracle.com/otn-pub/java/jdk/8u151-b12/e758a0de34e24606bca991d704f6dcbf"
    tarName="jdk-8u151-linux-x64.tar.gz"
    # make new directory if not exist
    sudo mkdir -p $javaInstDir

    # rename download package
    cd $startDir
    # check if already has this tar ball.
    if [[ -f $tarName ]]; then
        echo [Warning]: Tar Ball $tarName already exists, Omitting wget ...
    else
        wget --no-cookies \
        --no-check-certificate \
        --header "Cookie: oraclelicense=accept-securebackup-cookie" \
        "${wgetLink}/${tarName}" \
        -O $tarName

        # check if wget returns successfully
        if [[ $? != 0 ]]; then
            echo [Error]: wget returns error, quiting now ...
            exit
        fi
    fi

    sudo tar -zxv -f "$tarName" --strip-components=1 -C $javaInstDir
    # no more need make soft link for java, will added in PATH
    # ln -sf ${javaInstDir}/bin/java ${commInstdir}/bin/java 

    cat << _EOF
    
------------------------------------------------------
STEP 2: INSTALLING JAVA 8 DONE ...
_EOF
    echo java -version
    ${javaInstDir}/bin/java -version
    echo ------------------------------------------------------
}

writeTomcatConf() {
    # tomcat start/stop conf name
    confFile=tomcat.conf
    TOM_HOME=$tomcatInstDir
    CATALINA_HOME=$tomcatInstDir

    cd $mainWd
    cat > "$confFile" << _EOF
description "Tomcat Server"

  start on runlevel [2345]
  stop on runlevel [!2345]
  respawn
  respawn limit 10 5

  setuid tomcat
  setgid tomcat

  env JAVA_HOME=$JAVA_HOME
  env CATALINA_HOME=$TOM_HOME

  # Modify these options as needed
  env JAVA_OPTS="-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom"
  env CATALINA_OPTS="-Xms512M -Xmx1024M -server -XX:+UseParallelGC"

  exec $CATALINA_HOME/bin/catalina.sh run

  # cleanup temp directory after stop
  post-stop script
    rm -rf $CATALINA_HOME/temp/*
  end script
_EOF
    cd - &> /dev/null
}

installTomcat8() {
    cat << "_EOF"
    
------------------------------------------------------
STEP 3: INSTALLING TOMCAT 8 ...
------------------------------------------------------
_EOF
	# run tomcat using newly made user: tomcat
    tomHome=$tomcatInstDir
	newUser=$tomcatUser
	newGrp=$tomcatGrp

	# tomcat:tomcat
	# create group if not exists  
	egrep "^$newGrp" /etc/group &> /dev/null
	if [[ $? = 0 ]]; then  
		echo [Warning]: group $newGrp already exists ...
	else
		sudo groupadd $newUser
	fi

	# create user if not exists  
	egrep "^$newUser" /etc/passwd &> /dev/null
	if [[ $? = 0 ]]; then  
		echo [Warning]: group $newGrp already exists ...
	else 
		sudo useradd -s /bin/false -g $newGrp -d $tomHome $newUser
	fi
	
	wgetLink="http://mirror.jax.hugeserver.com/apache/tomcat/tomcat-8/v8.5.24/bin"
	tarName="apache-tomcat-8.5.24.tar.gz"

    cd $startDir
    # check if already has this tar ball.
    if [[ -f $tarName ]]; then
        echo [Warning]: Tar Ball $tarName already exists, Omitting wget ...
    else
        wget --no-cookies \
        --no-check-certificate \
        --header "Cookie: oraclelicense=accept-securebackup-cookie" \
        "${wgetLink}/${tarName}" \
        -O $tarName

        # check if wget returns successfully
        if [[ $? != 0 ]]; then
            echo [Error]: wget returns error, quiting now ...
            exit
        fi
    fi

	sudo rm -rf $tomHome
	sudo mkdir -p $tomHome

	# untar into /opt/tomcat and strip one level directory
	sudo tar -zxv -f apache-tomcat-8*tar.gz -C $tomHome --strip-components=1

	cd $tomHome
	echo ------------------------------------------------------
    echo cd into  "$(pwd)"/ ...

	sudo chgrp -R $newGrp conf
	sudo chmod 775 conf
	sudo chmod g+r conf/*
	sudo chown -R $newUser work/ temp/ logs/

	# echo ------------------------------------------------------
    # echo START TO MAKE TOMCAT CONF FILE ...
	# echo ------------------------------------------------------
    # writeTomcatConf
    # sudoecho  cp ${startDir}/tomcat.conf /etc/init/tomcat.conf

	echo ------------------------------------------------------
	echo change default listen port 8080 to 8081 ...
    serverXmlPath=${tomHome}/conf/server.xml
    sudo cp $serverXmlPath ${serverXmlPath}.bak
    sudo sed -i --regexp-extended 's/(<Connector port=)"8080"/\1"8081"/' \
        ${serverXmlPath}
	echo ------------------------------------------------------

    # make daemon script to start/shutdown Tomcat
    cd $startDir
    envName=$dynamicEnvName
    smpScripName=daemon.sh.sample
    # copied to name
    daeName=daemon.sh
    cp $smpScripName $daeName
    # add source command at top of script daemon.sh
    sed -i "2a source ${startDir}/${envName}" $daeName
    cd - &> /dev/null

    echo ------------------------------------------------------
    echo BEGIN TO COMPILE JSVC ...
    echo ------------------------------------------------------
    sudo chmod 755 $tomHome/bin
    cd $tomHome/bin
    tarName=commons-daemon-native.tar.gz
    untarName=commons-daemon-1.1.0-native-src
    sudo tar -zxv -f $tarName
    sudo chmod -R 777 $untarName
    cd $untarName/unix
    sh support/buildconf.sh
    ./configure --with-java=${javaInstDir}
    make -j
    sudo cp jsvc ${tomcatInstDir}/bin
    cd $tomHome/bin
    rm -rf $untarName

    cd $startDir
    echo Stop Tomcat Daemon ...
    sudo sh ./daemon.sh stop &> /dev/null
    echo Start Tomcat Daemon ...
    sudo sh ./daemon.sh run &> /dev/null &

    cat << "_EOF"
    
------------------------------------------------------
STEP 3: INSTALLING TOMCAT 8 DONE ...
------------------------------------------------------
_EOF
}

makeTecEnv() {
    # enter into dir first
    cd $startDir
    envName=dynamic.env
    TOMCAT_HOME=${tomcatInstDir}
    CATALINA_HOME=$TOMCAT_HOME

    # parse value of $var
    cat > $envName << _EOF
#!/bin/bash
export COMMON_INSTALL_DIR=$commInstdir
export JAVA_HOME=${javaInstDir}
export JRE_HOME=${JAVA_HOME}/jre
export CLASSPATH=.:${JAVA_HOME}/lib:${JRE_HOME}/lib
export TOMCAT_USER=${tomcatUser}
export TOMCAT_HOME=${TOMCAT_HOME}
export CATALINA_HOME=${TOMCAT_HOME}
export CATALINA_BASE=${TOMCAT_HOME}
export CATALINA_TMPDIR=${TOMCAT_HOME}/temp
export OPENGROK_INSTANCE_BASE=${opengrokInstanceBase}
export OPENGROK_TOMCAT_BASE=$CATALINA_HOME
_EOF

    # do not parse value of $var
    cat >> $envName << "_EOF"
export PATH=${COMMON_INSTALL_DIR}/bin:${JAVA_HOME}/bin:$PATH
_EOF

    chmod +x $envName
    cd - &> /dev/null
    # as return value of this func
    echo $envName
}

# deploy OpenGrok
installOpenGrok() {
    cat << "_EOF"
    
------------------------------------------------------
STEP 4: INSTALLING OPENGROK ...
------------------------------------------------------
_EOF

    wgetLink="https://github.com/oracle/opengrok/releases/download/1.1-rc18"
    tarName="opengrok-1.1-rc18.tar.gz"
    untarName="opengrok-1.1-rc18"

    cd $startDir
    # check if already has this tar ball.
    if [[ -f $tarName ]]; then
        echo [Warning]: Tar Ball $tarName already exists, Omitting wget ...
    else
        wget $wgetLink/$tarName -O $tarName
        # check if wget returns successfully
        if [[ $? != 0 ]]; then
            echo [Error]: wget returns error, quiting now ...
            exit
        fi
    fi
    tar -zxv -f $tarName 

    echo ------------------------------------------------------
    echo BEGIN TO MAKE ENV FILE FOR SOURCE ...
    echo ------------------------------------------------------
    # env name is the return value of func makeTecEnv
    makeTecEnv
    envName=$dynamicEnvName

    # source ./$envName
    # enter into opengrok dir
    cd $untarName/bin
    chmod +w OpenGrok

    # add source command at top of script OpenGrok
    sed -i "2a source ${startDir}/${envName}" OpenGrok
    ln -sf "`pwd`"/OpenGrok ${commInstdir}/bin/openGrok 
    # and then can run deploy well
    sudo ./OpenGrok deploy

    cd - &> /dev/null

    cat << "_EOF"
    
------------------------------------------------------
STEP 4: INSTALLING OPENGROK DONE ...
------------------------------------------------------
_EOF
}

summaryInstall() {
    set +x
    logo

    cat << _EOF

******************************************************
*                  UNIVERSAL CTAGS                   *
******************************************************

_EOF
echo export PATH=${commInstdir}:'$PATH'

    cat << _EOF
******************************************************
*                  JAVA JAVA JAVA 8                  *
******************************************************

******************************************************
*                  TOMCAT TOMCAT 8                   *
******************************************************
# start tomcat
sudo sh ./daemon.sh run &> /dev/null &
# stop tomcat
sudo sh ./daemon.sh stop

******************************************************
*                  OPENGROK 1.1-RC18                 *
******************************************************
# deploy OpenGrok
sudo sh ./OpenGrok deploy
# make index of source
sudo sh ./OpenGrok index /usr/local/src/coreutils-8.21
------------------------------------------------------

_EOF
}

install() {
    installCtags
    sleep 1
	installJava8
    sleep 1
	installTomcat8
    sleep 1
    installOpenGrok

    # show install summary
    sleep 1
    summaryInstall
}

case $1 in
    'install')
        install
    ;;

    *)
        set +x
        usage
    ;;
esac