<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
                xmlns:exsl="http://exslt.org/common"
                extension-element-prefixes="exsl"
                version="1.0">

<xsl:output encoding="UTF-8" method="xml" indent="yes" doctype-public="-//OASIS//DTD DocBook XML V4.1.2//EN" doctype-system="http://www.oasis-open.org/docbook/xml/4.1.2/docbookx.dtd"/>

<xsl:template match="book">
<book>
  <title><xsl:value-of select="title" /></title>
  <bookinfo>
  </bookinfo>
  <preface>
  <title>Abstract</title>
  <para>
    <xsl:value-of select="abstract" />
  </para>
  </preface>

<xsl:apply-templates select="part" />

</book>
</xsl:template>

<xsl:template match="part">
<part>
<title><xsl:value-of select="title" /></title>

<xsl:apply-templates select="chapter" />

</part>
</xsl:template>

<xsl:template match="chapter">
<chapter>
<title><xsl:value-of select="title" /></title>

<xsl:apply-templates select="include" />

</chapter>
</xsl:template>

<xsl:template match="include">
<xsl:variable name="link" select="@href" />

<xsl:for-each select="document($link)/sections/section">
  <xsl:call-template name="c_section" />
</xsl:for-each>
</xsl:template>

<xsl:template name="c_section">
<section>
  <title><xsl:value-of select="title" /></title>
  <xsl:apply-templates select="subsection" />
</section>
</xsl:template>

<xsl:template match="subsection">
<section>
  <title><xsl:value-of select="title" /></title>
  <xsl:apply-templates select="body" />
</section>
</xsl:template>

<xsl:template match="body">
<xsl:apply-templates />
</xsl:template>

<xsl:template match="p">
<para><xsl:apply-templates /></para>
</xsl:template>

<xsl:template match="pre">
<example>
  <title><xsl:value-of select="@caption" /></title>
  <programlisting>
<xsl:apply-templates />
  </programlisting>
</example>
</xsl:template>

<xsl:template match="ul">
<itemizedlist>
  <xsl:apply-templates />
</itemizedlist>
</xsl:template>

<xsl:template match="ol">
<orderedlist>
  <xsl:apply-templates />
</orderedlist>
</xsl:template>

<xsl:template match="li">
  <listitem>
    <para>
<xsl:apply-templates />
    </para>
  </listitem>
</xsl:template>

<xsl:template match="dl">
<itemizedlist>
  <xsl:apply-templates />
</itemizedlist>
</xsl:template>

<xsl:template match="dt">
<xsl:text disable-output-escaping="yes">&lt;listitem&gt;&lt;para&gt;</xsl:text>
<emphasis><xsl:apply-templates /></emphasis> - 
</xsl:template>

<xsl:template match="dd">
<xsl:apply-templates />
<xsl:text disable-output-escaping="yes">&lt;/para&gt;&lt;/listitem&gt;</xsl:text>
</xsl:template>

<xsl:template match="uri">
<ulink url="{@link}"><xsl:apply-templates /></ulink>
</xsl:template>

<xsl:template match="c|i">
<command><xsl:apply-templates /></command>
</xsl:template>

<xsl:template match="e">
<emphasis><xsl:apply-templates /></emphasis>
</xsl:template>

<xsl:template match="path">
<filename><xsl:apply-templates /></filename>
</xsl:template>

<xsl:template match="table">
<table>
  <xsl:apply-templates select="thead|tr"/>
</table>
</xsl:template>

<xsl:template match="thead">
<xsl:apply-templates />
</xsl:template>

<xsl:template match="tr">
<tr>
  <xsl:apply-templates /> 
</tr>
</xsl:template>

<xsl:template match="th">
<th><xsl:apply-templates /></th>
</xsl:template>

<xsl:template match="td">
<ti><xsl:apply-templates /></ti>
</xsl:template>

</xsl:stylesheet>
