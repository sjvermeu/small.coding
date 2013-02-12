<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
                xmlns:exslt="http://exslt.org/common"
                xmlns:func="http://exslt.org/functions"
                xmlns:dyn="http://exslt.org/dynamic"
                xmlns:str="http://exslt.org/strings"

                xmlns:feed="http://www.w3.org/2005/Atom"

                xmlns:opensearch="http://a9.com/-/spec/opensearch/1.1/"
                exclude-result-prefixes="opensearch feed"

                extension-element-prefixes="exslt func dyn str" >

<xsl:output encoding="UTF-8" method="text" indent="no" />
<xsl:preserve-space elements="li p pre" />

<xsl:template match="guide"><xsl:apply-templates />
== Acknowledgements ==

We would like to thank the following authors and editors for their contributions to this guide:
<xsl:for-each select="//guide/author">
* <xsl:value-of select="mail" />
</xsl:for-each>

[[Category:Server and Security]]
</xsl:template>

<xsl:template match="author" />

<xsl:template match="abstract" />

<xsl:template match="chapter">

== <xsl:value-of select="title" /> ==
<xsl:apply-templates />
</xsl:template>

<xsl:template match="section">
<xsl:if test="preceding-sibling::section"><xsl:text>
</xsl:text>
</xsl:if>
=== <xsl:value-of select="title" /> ===

<xsl:apply-templates />
</xsl:template>

<xsl:template match="p">
<xsl:apply-templates /><xsl:text>

</xsl:text>
</xsl:template>

<xsl:template match="uri"><xsl:choose><xsl:when test="starts-with(@link, 'http')">[<xsl:value-of select="@link" /><xsl:text> </xsl:text><xsl:value-of select="text()" />]</xsl:when><xsl:otherwise> [[INTERNAL <xsl:value-of select="@link" />]] </xsl:otherwise></xsl:choose></xsl:template>

<xsl:template match="e"> ''<xsl:apply-templates />'' </xsl:template>

<xsl:template match="ul">
<xsl:apply-templates /><xsl:text>
</xsl:text>
</xsl:template>

<xsl:template match="ol">
<xsl:apply-templates /></xsl:template>

<xsl:template match="li">
<xsl:choose><xsl:when test="name(..)='ul'">* <xsl:apply-templates /></xsl:when><xsl:when test="name(..)='ol'"># <xsl:apply-templates /></xsl:when><xsl:otherwise>OH NOES HERE IT GOES!</xsl:otherwise></xsl:choose><xsl:text>
</xsl:text>
</xsl:template>

<xsl:template match="sup">&lt;sup&gt;<xsl:apply-templates />&lt;/sup&gt;</xsl:template>

<xsl:template match="sub">&lt;sub&gt;<xsl:apply-templates />&lt;/sub&gt;</xsl:template>

<xsl:template match="title" />

<xsl:template match="date" />

<xsl:template match="version" />

<xsl:template match="c"> '''<xsl:apply-templates />''' </xsl:template>

<xsl:template match="pre"><xsl:text>
</xsl:text>
<xsl:choose>
<xsl:when test="starts-with(normalize-space(), '~$') or starts-with(normalize-space(), '$')">
{{Cmd|INTERNAL commandhere|output=&lt;pre&gt;
<xsl:apply-templates />&lt;/pre&gt;
}}
</xsl:when>
<xsl:when test="starts-with(normalize-space(), '~#') or starts-with(normalize-space(), '#')">
{{RootCmd|INTERNAL commandhere|output=&lt;pre&gt;
<xsl:apply-templates />&lt;/pre&gt;
}}
</xsl:when>
<xsl:otherwise>
{{GenericCmd|&lt;pre&gt;
<xsl:apply-templates />&lt;/pre&gt;
}}
</xsl:otherwise>
</xsl:choose><xsl:text>
</xsl:text>
</xsl:template>

<xsl:template match="comment">## <xsl:apply-templates /></xsl:template>

<xsl:template match="path"> {{Path|<xsl:apply-templates />}} </xsl:template>

<xsl:template match="b">'''<xsl:apply-templates />'''</xsl:template>

<xsl:template match="warn">
{{Warning|<xsl:apply-templates />}}
</xsl:template>

<xsl:template match="impo">
{{Important|<xsl:apply-templates />}}
</xsl:template>

<xsl:template match="brite">'''<xsl:apply-templates />'''</xsl:template>

<xsl:template match="note">
{{Note|<xsl:apply-templates />}}
</xsl:template>

<xsl:template match="table">

{| class="wikitable" style="text-align: left;" <xsl:apply-templates />
|-
|}

</xsl:template>

<xsl:template match="tr">
|- <xsl:apply-templates />
</xsl:template>

<xsl:template match="th">
! <xsl:apply-templates />
</xsl:template>
<xsl:template match="ti">
| <xsl:apply-templates />
</xsl:template>

<xsl:template match="dl">
{| class="wikitable" style="text-align: left;"
<xsl:apply-templates />
|-
|}
</xsl:template>

<xsl:template match="dt">
! <xsl:apply-templates />
</xsl:template>

<xsl:template match="dd">
| <xsl:apply-templates />
</xsl:template>

<xsl:template match="text()">
<xsl:choose>
<xsl:when test="ancestor::pre"><xsl:value-of select="." /></xsl:when>
<xsl:otherwise>
<xsl:value-of select="normalize-space()" />
</xsl:otherwise>
</xsl:choose>
</xsl:template>

</xsl:stylesheet>
