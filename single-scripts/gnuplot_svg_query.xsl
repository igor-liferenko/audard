<?xml version="1.0"?>
<xsl:stylesheet version="1.0"
  xmlns:str="http://exslt.org/strings"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<!-- call with: xsltproc select_query.xsl gnuplot.svg -->

<xsl:output omit-xml-declaration="yes" indent="no"/>
<xsl:param name="inputFile">-</xsl:param>

<!-- added from
RE: [xsl] How can I get the XPATH of the current node with MSXML?
http://oxygenxml.com/archives/xsl-list/200207/msg01704.html  -->
<xsl:template name="generateXPath">
  <xsl:for-each select="ancestor::*">/<xsl:value-of select="name()"/>[<xsl:number/>]</xsl:for-each>/<xsl:value-of select="name()"/>[<xsl:number/>]</xsl:template>


<xsl:template match="/">
  <xsl:call-template name="t1"/>
</xsl:template>


<!-- "actual" plots have XPath /svg/g/g[@id]/g/g/text
copy-of select="../../.." seems to work below - dumps entire node -->

<xsl:template name="t1">
  <xsl:for-each select="//*[local-name()='svg']/*[local-name()='g']/*[local-name()='g' and @id]/*[local-name()='g']/*[local-name()='g']/*[local-name()='text']">
    <xsl:call-template name="generateXPath"/> <!-- added -->
    <xsl:text>: </xsl:text>                   <!-- added -->
    <xsl:value-of select="name()"/>
    <xsl:text>: </xsl:text>
    <xsl:value-of select="text()"/>
    <xsl:text> -- </xsl:text>
    <xsl:value-of select="../../../@id"/>
    <xsl:text> -- </xsl:text>
    <xsl:value-of select="../../@style"/>
    <xsl:text> -- </xsl:text>
    <xsl:value-of select="'&#10;'"/>
    <xsl:call-template name="genXPathC">
      <xsl:with-param name="count" select="1"/>
    </xsl:call-template>
    <xsl:value-of select="'&#10;'"/>
  </xsl:for-each>
</xsl:template>




<!--
 use this template to printout selection and children for /svg/g/g[@id]

<xsl:comment>
xsl:comment doesn't do much - make sure the
insides of comments never contain double-hyphen!!
http://stackoverflow.com/questions/1324821/nested-comments-in-xml

<xsl:template name="t1">
<!- -   <xsl:for-each select="//*[@id]"> - ->
<!- -   <xsl:for-each select="/svg[1]/g/g">  NOPE;
should be /svg/g/g[@id], but because of namespace for .svg,
must use via `local-name()` and `and`;
and cannot just use child::title/text()
- ->
  <xsl:for-each select="//*[local-name()='svg']/*[local-name()='g']/*[local-name()='g' and @id]">
    <xsl:call-template name="generateXPath"/> <!- - added - ->
    <xsl:text>: </xsl:text>                   <!- - added - ->
    <xsl:value-of select="name()"/>
    <xsl:text>: </xsl:text>
    <xsl:value-of select="@id"/>
    <xsl:text> - - </xsl:text>
    <xsl:value-of select="child::*[local-name()='title']/text()"/>
    <!- - <xsl:param name="count" select="1"/> CANNOT - ->
    <xsl:value-of select="'&#10;'"/>
    <xsl:call-template name="genXPathC">
      <xsl:with-param name="count" select="1"/>
    </xsl:call-template>
    <xsl:value-of select="'&#10;'"/>
  </xsl:for-each>
</xsl:template>

</xsl:comment>
-->


<!-- xsl:param will work in genXPathC,
only if genXPathC as a whole is placed after t1!
else either "Variable 'count' has not been declared.";
or if trying to declare global at start,
the value doesn't change from 1 !!
Btw the 1 below here doesn't matter;
the caller set above does! -->
<xsl:template name="genXPathC">
  <xsl:param name="count" select="1"/>
  <xsl:for-each select="child::*">
    <!-- <xsl:value-of select="$count"/> -->
<!--     <xsl:call-template name="str:padding">
       <xsl:with-param name="length" select="$count" />
       <xsl:with-param name="chars" select="*" />?
    </xsl:call-template> -->
    <xsl:value-of select="str:padding($count*2, '.')" /> /<xsl:value-of select="name()"/>[<xsl:number/>]
<xsl:call-template name="genXPathC">
  <xsl:with-param name="count" select="$count + 1"/>
</xsl:call-template>
  </xsl:for-each>
</xsl:template>


</xsl:stylesheet>
