# script to build http://xml.openoffice.org/saxecho/
# 

FDL=AdapterNode.java
wget -nc "http://xml.openoffice.org/source/browse/*checkout*/xml/tools/SAXEcho/source/$FDL" -O $FDL
FDL=DOMCellRenderer.java
wget -nc "http://xml.openoffice.org/source/browse/*checkout*/xml/tools/SAXEcho/source/$FDL" -O $FDL
FDL=DocumentCollector.java
wget -nc "http://xml.openoffice.org/source/browse/*checkout*/xml/tools/SAXEcho/source/$FDL" -O $FDL
FDL=DocumentDistributor.java
wget -nc "http://xml.openoffice.org/source/browse/*checkout*/xml/tools/SAXEcho/source/$FDL" -O $FDL
FDL=ErrorList.java
wget -nc "http://xml.openoffice.org/source/browse/*checkout*/xml/tools/SAXEcho/source/$FDL" -O $FDL
FDL=ErrorListModel.java
wget -nc "http://xml.openoffice.org/source/browse/*checkout*/xml/tools/SAXEcho/source/$FDL" -O $FDL
FDL=HostOpt.java
wget -nc "http://xml.openoffice.org/source/browse/*checkout*/xml/tools/SAXEcho/source/$FDL" -O $FDL
FDL=SAXEcho.bat
wget -nc "http://xml.openoffice.org/source/browse/*checkout*/xml/tools/SAXEcho/source/$FDL" -O $FDL
FDL=SAXEcho.java
wget -nc "http://xml.openoffice.org/source/browse/*checkout*/xml/tools/SAXEcho/source/$FDL" -O $FDL
FDL=makefile.mk
wget -nc "http://xml.openoffice.org/source/browse/*checkout*/xml/tools/SAXEcho/source/$FDL" -O $FDL

echo done get src. 

XALAN=xalan-j_2_7_1
wget -nc http://apache-mirror.dkuug.dk//xml/xalan-j/$XALAN-bin.zip -O $XALAN-bin.zip
unzip -n $XALAN-bin.zip

wget -nc "http://cds.sun.com/is-bin/INTERSHOP.enfinity/WFS/CDS-CDS_Developer-Site/en_US/-/USD/VerifyItem-Start/jlfgr-1_0.zip?BundledLineItemUUID=pWuJ_hCwWK8AAAEtI9cAGXdZ&OrderID=ACKJ_hCwMC4AAAEtFtcAGXdZ&ProductID=F__ACUFB2csAAAEYLlo5AXiw&FileName=/jlfgr-1_0.zip" -O jlfgr-1_0.zip
unzip -n jlfgr-1_0.zip

echo done unpack.


# classpaths include .jar files! 
export CLASSPATH=.:$PWD/jlfgr-1_0.jar:$CLASSPATH
export OOOLIBPATH=/usr/lib/openoffice/basis3.2/program/classes 
#~ for iclj in /usr/lib/openoffice/basis3.2/program/classes/* # symlinked, no work
for iclj in /usr/share/java/openoffice/*
do
	CLASSPATH=$iclj:$CLASSPATH
done

for iclj in $PWD/$XALAN/*.jar
do
	CLASSPATH=$iclj:$CLASSPATH
done

echo $CLASSPATH

# compile
javac -Xlint:unchecked SAXEcho.java

# http://xml.openoffice.org/saxecho/
# In order for the SAXEcho program to work with OOo, you must start OpenOffice with the following switches:
# %soffice -accept=socket,host=localhost,port=2002;urp;
soffice "-accept=socket,host=localhost,port=2002;urp;"

# to run: execute as below (easiest, else the classpath is messed up if calling it externally):
java SAXEcho