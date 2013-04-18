<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
                xmlns:exslt="http://exslt.org/common"
                xmlns:func="http://exslt.org/functions" 
                xmlns:date="http://exslt.org/dates-and-times"
                xmlns:str="http://exslt.org/strings"
		xmlns:dyn="http://exslt.org/dynamic"
		xmlns:xl="http://www.w3.org/1999/xlink"
		xmlns="http://docbook.org/ns/docbook"
                extension-element-prefixes="exslt func date dyn str">

<!-- <xsl:output encoding="UTF-8" method="xml" indent="yes" doctype-public="-//OASIS//DTD DocBook XML V4.1.2//EN" doctype-system="http://www.oasis-open.org/docbook/xml/4.1.2/docbookx.dtd"/> -->
<xsl:output encoding="UTF-8" method="xml" indent="yes" />

<xsl:template match="guide">
<article>
  <info>
    <title><xsl:value-of select="title" /></title>
  </info>

<xsl:for-each select="chapter">
  <xsl:call-template name="gchapter"/>
</xsl:for-each>

</article>
</xsl:template>

<xsl:template name="gchapter">
<section>
  <title><xsl:value-of select="title" /></title>
  <xsl:for-each select="section">
    <xsl:call-template name="gsection" />
  </xsl:for-each>
</section>
</xsl:template>

<xsl:template name="gsection">
<xsl:if test="not(@test) or dyn:evaluate(@test)">
<section>
  <xsl:if test="@id">
    <xsl:attribute name="xml:id"><xsl:value-of select="@id" /></xsl:attribute>
  </xsl:if>
  <title><xsl:value-of select="title" /></title>
<xsl:apply-templates select="body"/>

</section>
</xsl:if>
</xsl:template>

<xsl:template match="book">
<book>
  <xsl:attribute name="version">5.0</xsl:attribute>
  <title><xsl:value-of select="title" /></title>
  <info>
  <authorgroup>
    <xsl:for-each select="author">
      <xsl:choose>
        <xsl:when test="@title='Author'">
          <author>
            <personname><xsl:value-of select="." /></personname>
          </author>
	</xsl:when>
	<xsl:when test="@title='Editor'">
          <editor>
            <personname><xsl:value-of select="." /></personname>
	  </editor>
	</xsl:when>
	<xsl:otherwise>
          <othercredit>
	    <personname><xsl:value-of select="." /></personname>
	  </othercredit>
	</xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </authorgroup>
  </info>
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

<xsl:choose>
  <xsl:when test="document($link)/sections">
    <xsl:for-each select="document($link)/sections/section">
      <xsl:call-template name="c_section" />
    </xsl:for-each>
  </xsl:when>
  <xsl:when test="document($link)/included/body">
    <xsl:for-each select="document($link)/included/body">
      <xsl:apply-templates />
    </xsl:for-each>
  </xsl:when>
  <xsl:when test="document($link)/included/section">
    <xsl:for-each select="document($link)/included/section">
      <xsl:call-template name="c_section" />
    </xsl:for-each>
  </xsl:when>
  <xsl:otherwise>
    TODO-2
  </xsl:otherwise>
</xsl:choose>
</xsl:template>

<xsl:template name="c_section">
<xsl:if test="not(@test) or dyn:evaluate(@test)">
<section>
  <xsl:if test="@id">
    <xsl:attribute name="xml:id"><xsl:value-of select="@id" /></xsl:attribute>
  </xsl:if>
  <title><xsl:value-of select="title" /></title>
  <xsl:apply-templates select="subsection|body" />
</section>
</xsl:if>
</xsl:template>

<xsl:template match="subsection">
<xsl:choose>
  <xsl:when test="title">
    <section>
      <title><xsl:value-of select="title" /></title>
      <xsl:apply-templates select="body" />
    </section>
  </xsl:when>
  <xsl:when test="include">
    <xsl:apply-templates />
  </xsl:when>
  <xsl:when test="body">
    <xsl:apply-templates />
  </xsl:when>
  <xsl:otherwise>
    TODO-1
  </xsl:otherwise>
</xsl:choose>
</xsl:template>

<xsl:template match="body">
<xsl:if test="not(@test) or dyn:evaluate(@test)">
  <xsl:apply-templates />
</xsl:if>
</xsl:template>

<xsl:template match="p">
<xsl:if test="not(@test) or dyn:evaluate(@test)">
  <para><xsl:apply-templates /></para>
</xsl:if>

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
<link xl:href="{@link}"><xsl:apply-templates /></link>
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
<xsl:variable name="numcol" select="count(tr[3]/*)"/>
<informaltable>
  <tbody>
  <xsl:apply-templates select="thead|tr"/>
  </tbody>
</informaltable>
</xsl:template>

<xsl:template match="thead">
<xsl:apply-templates />
</xsl:template>

<xsl:template match="tr">
<xsl:if test="not(@test) or dyn:evaluate(@test)">
  <tr><xsl:apply-templates /></tr>
</xsl:if>
</xsl:template>

<xsl:template match="th">
<th><xsl:apply-templates /></th>
</xsl:template>

<xsl:template match="ti">
<xsl:choose>
  <xsl:when test="@colspan">
    <td colspan="{@colspan}"><xsl:apply-templates /></td>
  </xsl:when>
  <xsl:otherwise>
    <td><xsl:apply-templates /></td>
  </xsl:otherwise>
</xsl:choose>
</xsl:template>

<xsl:template match="note">
<xsl:if test="not(@test) or dyn:evaluate(@test)">
  <note><para><xsl:apply-templates /></para></note>
</xsl:if>
</xsl:template>

<xsl:template match="impo">
<xsl:if test="not(@test) or dyn:evaluate(@test)">
  <important><para><xsl:apply-templates /></para></important>
</xsl:if>
</xsl:template>

<xsl:template match="warn">
<xsl:if test="not(@test) or dyn:evaluate(@test)">
  <warning><para><xsl:apply-templates /></para></warning>
</xsl:if>
</xsl:template>

<xsl:template match="brite">
<emphasis><xsl:apply-templates /></emphasis>
</xsl:template>

<!-- inserts.xsl -->

<xsl:variable name="alllang" select="'|ar|bg|ca|cs|da|de|el|en|es|fa|fi|fr|he|hu|id|it|ko|ja|lt|nl|pl|pt_br|ro|ru|sr|sv|tr|vi|zh_cn|zh_tw|'"/>

<func:function name="func:gettext">
  <xsl:param name="str"/>
  <xsl:param name="PLANG"/>
  
<!-- For Debugging:
<xsl:message>PLANG=<xsl:value-of select="$PLANG"/> || str=<xsl:value-of select="$str"/> || gLang=<xsl:value-of select="$glang"/></xsl:message>
-->

  <!-- Default to English version when $LANG is undefined, the lang does not
       exist, or is improperly set.  Default to 'UNDEFINED STRING' when the
       requested text is unavailable.

       Use either the passed parameter (e.g. from metadoc.xsl)
       or the Global $glang that was initialized when loading a guide or a book or part of uri for book parts
  -->
  <xsl:variable name="LANG">
    <xsl:choose>
      <xsl:when test="$PLANG"><xsl:value-of select="$PLANG"/></xsl:when>
      <xsl:when test="$glang"><xsl:value-of select="$glang"/></xsl:when>
    </xsl:choose>
  </xsl:variable>

  <xsl:choose>
    <xsl:when test="contains($alllang, concat('|', $LANG,'|'))">
      <xsl:variable name="insert" select="document(concat('/doc/', $LANG, '/inserts.xml'))/inserts/insert[@name=$str]"/>
      <xsl:choose>
        <xsl:when test="$insert">
          <func:result select="$insert"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:variable name="insert-en" select="document('/doc/en/inserts.xml')/inserts/insert[@name=$str]"/>
          <xsl:choose>
            <xsl:when test="$insert-en">
              <func:result select="$insert-en"/>
            </xsl:when>
            <xsl:otherwise>
              <func:result select="'UNDEFINED STRING'"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:otherwise>
      <xsl:variable name="insert-en" select="document('/doc/en/inserts.xml')/inserts/insert[@name=$str]"/>
      <xsl:choose>
        <xsl:when test="$insert-en">
          <func:result select="$insert-en" />
        </xsl:when>
        <xsl:otherwise>
          <func:result select="'UNDEFINED STRING'"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:otherwise>
  </xsl:choose>
</func:function>


<!-- D A T E   F O R M A T T I N G   R O U T I N E S -->

<func:function name="func:today">
  <func:result select="substring(date:date(),1,10)"/>
</func:function>

<func:function name="func:format-date">
  <xsl:param name="datum" />
  <xsl:param name="lingua" select="//*[1]/@lang"/>

  <xsl:variable name="mensis" select="document('/xsl/months.xml')"/>

  <xsl:variable name="NormlzD">
    <xsl:choose>
    <xsl:when test="translate(normalize-space($datum),'TODAY','today')='today'">
      <xsl:value-of select="func:today()"/>
    </xsl:when>
    <xsl:when test="starts-with($datum,'&#36;Date: ') and 'YES'=func:is-date(translate(substring($datum,8,10),'/','-'))">
      <xsl:value-of select="translate(substring($datum,8,10),'/','-')"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="normalize-space($datum)"/>
    </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:choose>
    <xsl:when test="func:is-date($NormlzD)='YES'">
      <xsl:variable name="Y"><xsl:value-of select="number(substring($NormlzD,1,4))"/></xsl:variable>
      <xsl:variable name="M"><xsl:value-of select="number(substring($NormlzD,6,2))"/></xsl:variable>
      <xsl:variable name="D"><xsl:value-of select="number(substring($NormlzD,9,2))"/></xsl:variable>
      <xsl:choose>
        <!-- Formatting per language happens here -->

        <!-- For complex and/or repeated cases, better use a dedicated function -->

        <!-- RFC-822 -->
        <xsl:when test="$lingua='RFC822'">
          <func:result select="func:format-date-rfc822($mensis, $Y, $M, $D)"/>
        </xsl:when>

        <!-- English -->
        <xsl:when test="$lingua='en'">
          <func:result select="func:format-date-en($mensis, $Y, $M, $D)"/>
        </xsl:when>

        <!-- Danish / German / Finnish / Serbian -->
        <xsl:when test="$lingua='da' or $lingua='de' or $lingua='fi' or $lingua='cs' or $lingua='sr'">
          <func:result select="concat($D, '. ', $mensis//months[@lang=$lingua]/month[position()=$M], ' ', $Y)"/>
        </xsl:when>

        <!-- Spanish -->
        <xsl:when test="$lingua='es' or $lingua='ca'">
          <func:result select="concat($D, ' de ', $mensis//months[@lang=$lingua]/month[position()=$M], ', ', $Y)"/>
        </xsl:when>
        
        <!-- Brazilian Portuguese -->
        <xsl:when test="$lingua='pt_br'">
          <func:result select="concat($D, ' de ', $mensis//months[@lang=$lingua]/month[position()=$M], ' de ', $Y)"/>
        </xsl:when>
        
        <!-- Hungarian -->
        <xsl:when test="$lingua='hu'">
          <func:result select="concat($Y, '. ', $mensis//months[@lang=$lingua]/month[position()=$M], ' ', $D, '.')"/>
        </xsl:when>

        <!-- Chinese / Japanese -->
        <xsl:when test="$lingua='zh_cn' or $lingua='zh_tw' or $lingua='ja'">
          <func:result select="concat($Y, '年 ', $M, '月 ', $D, '日 ')"/>
        </xsl:when>

        <!-- Korean -->
        <xsl:when test="$lingua='ko'">
          <func:result select="concat($Y, '년 ', $M, '월 ', $D, '일')"/>
        </xsl:when>

        <!-- French -->
        <xsl:when test="$lingua='fr'">
          <func:result select="func:format-date-fr($mensis, $Y, $M, $D)" />
        </xsl:when>

        <!-- Lithuanian -->
        <xsl:when test="$lingua='lt'">
          <func:result select="concat($Y, ' ', $mensis//months[@lang=$lingua]/month[position()=$M], ' ', $D)"/>
        </xsl:when>

        <!-- Hebrew -->
        <xsl:when test="$lingua='he'">
          <func:result select="concat($D, ' ב', $mensis//months[@lang=$lingua]/month[position()=$M], ', ', $Y)"/>
        </xsl:when>

        <!-- Bulgarian / Dutch / Greek / Indonesian / Italian / Polish / Romanian / Russian / Swedish / Turkish / Vietnamese -->
        <xsl:when test="$lingua='bg' or $lingua='nl' or $lingua='el' or $lingua='id' or $lingua='it' or $lingua='pl' or $lingua='ro' or $lingua='ru' or $lingua='sv' or $lingua='tr' or $lingua='vi'">
          <func:result select="concat($D, ' ', $mensis//months[@lang=$lingua]/month[position()=$M], ' ', $Y)"/>
        </xsl:when>

        <xsl:otherwise> <!-- Default to English -->
          <func:result select="func:format-date-en($mensis, $Y, $M, $D)" />
        </xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:otherwise>
      <func:result select="$datum" />
    </xsl:otherwise>
  </xsl:choose>
</func:function>

<!-- Validate date, 1000<=YYYY<=9999, 01<=MM<=12, 01<=DD<={days in month} -->
<func:function name="func:is-date">
  <xsl:param name="YMD" />

  <func:result>
    <xsl:if test="string-length($YMD)=10 and substring($YMD,5,1)='-' and substring($YMD,8,1)='-' and contains('|01|02|03|04|05|06|07|08|09|10|11|12|',concat('|',substring($YMD,6,2),'|'))">
      <xsl:variable name="Y"><xsl:value-of select="number(substring($YMD,1,4))"/></xsl:variable>
      <xsl:variable name="M"><xsl:value-of select="number(substring($YMD,6,2))"/></xsl:variable>
      <xsl:variable name="D"><xsl:value-of select="number(substring($YMD,9,2))"/></xsl:variable>
      <xsl:if test="$Y &gt;= 1000 and $Y &lt;= 9999 and $D &gt;= 1 and $D &lt;= 31">
        <xsl:choose>
          <xsl:when test="$M=4 or $M=6 or $M=9 or $M=11">
            <xsl:if test="$D&lt;=30">YES</xsl:if>
          </xsl:when>
          <xsl:when test="$M=2 and ((($Y mod 4 = 0) and ($Y mod 100 != 0))  or  ($Y mod 400 = 0))">
            <xsl:if test="$D&lt;=29">YES</xsl:if>
          </xsl:when>
          <xsl:when test="$M=2">
            <xsl:if test="$D&lt;=28">YES</xsl:if>
          </xsl:when>
          <xsl:otherwise>YES</xsl:otherwise>
        </xsl:choose>
      </xsl:if>
    </xsl:if>
  </func:result>
</func:function>

<!-- Return number of days between YYYY-MM-DD formatted dates
     Nan if invalid or ill-formatted dates are passed
     Negative if D0 > D1
-->
<func:function name="func:days-between">
  <xsl:param name="D0"/>
  <xsl:param name="D1"/>
  <xsl:choose>
    <xsl:when test="func:is-date($D0)='YES' and func:is-date($D1)='YES'">
      <xsl:variable name="Y0"><xsl:value-of select="substring($D0,1,4)"/></xsl:variable>
      <xsl:variable name="Y1"><xsl:value-of select="substring($D1,1,4)"/></xsl:variable>
      <xsl:choose>
        <xsl:when test="$Y0 = $Y1">
          <func:result select="date:day-in-year($D1) - date:day-in-year($D0)" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:variable name="ndays" xmlns="">
            <xsl:choose>
              <xsl:when test="number($Y0) &lt; number($Y1)">
                <!-- Days left in first year -->
                <d><xsl:value-of select="365 - date:day-in-year($D0)"/></d>
                <!-- Extra day in 1st year? -->
                <xsl:if test="date:leap-year($D0)"><d>1</d></xsl:if>
                <!-- Days into last year -->
                <d><xsl:value-of select="date:day-in-year($D1)"/></d>
                <!-- Years in ]y0,y1[ -->
                <xsl:if test="(number($Y1)-number($Y0)) > 1">
                  <!-- Add all 29/02 -->
                  <xsl:call-template name="add-leap-years-in-between">
                   <xsl:with-param name="y0" select="$Y0+1"/>
                   <xsl:with-param name="y1" select="$Y1"/>
                  </xsl:call-template>
                  <!-- 365 * years -->
                  <d><xsl:value-of select="(number($Y1)-number($Y0)-1)*365"/></d>
                </xsl:if>
              </xsl:when>
              <xsl:otherwise>
                <!-- Same thing, but swap dates & change sign -->
                <d><xsl:value-of select="date:day-in-year($D1) - 365"/></d>
                <xsl:if test="date:leap-year($D1)"><d>-1</d></xsl:if>
                <d><xsl:value-of select="-date:day-in-year($D0)"/></d>
                <xsl:if test="(number($Y0)-number($Y1)) > 1">
                  <xsl:call-template name="add-leap-years-in-between">
                   <xsl:with-param name="y0" select="$Y1+1"/>
                   <xsl:with-param name="y1" select="$Y0"/>
                   <xsl:with-param name="plusmin" select="-1"/>
                  </xsl:call-template>
                  <d><xsl:value-of select="(number($Y1)-number($Y0)+1)*365"/></d>
                </xsl:if>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:variable>
          <func:result select="sum(exslt:node-set($ndays)/d)"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:otherwise>
      <func:result select="number('NaN')" />
    </xsl:otherwise>
  </xsl:choose>
</func:function>

<xsl:template name="add-leap-years-in-between">
  <xsl:param name="y0"/>
  <xsl:param name="y1"/>
  <xsl:param name="plusmin" select="1"/>
  <xsl:if test="number($y1)>number($y0)">
    <xsl:if test="date:leap-year($y0)"><d xmlns=""><xsl:value-of select="$plusmin"/></d></xsl:if>
    <xsl:call-template name="add-leap-years-in-between">
       <xsl:with-param name="y0" select="$y0+1"/>
       <xsl:with-param name="y1" select="$y1"/>
       <xsl:with-param name="plusmin" select="$plusmin"/>
    </xsl:call-template>
  </xsl:if>
</xsl:template>


<!-- Format date according to RFC822, time is set to 00:00:00 UTC,
     Day of the week is optional, we do not output it
     RFC says YY but YYYY is widely accepted
  -->
<func:function name="func:format-date-rfc822">
  <xsl:param name="mensis" />
  <xsl:param name="Y" />
  <xsl:param name="M" />
  <xsl:param name="D" />
  <func:result select="concat($D, ' ', substring($mensis//months[@lang='en']/month[position()=$M],1,3), ' ', $Y, ' 00:00:00 GMT')" />
</func:function>

<!-- Format date in  ENGLISH -->
<func:function name="func:format-date-en">
  <xsl:param name="mensis" />
  <xsl:param name="Y" />
  <xsl:param name="M" />
  <xsl:param name="D" />
  <func:result select="concat($mensis//months[@lang='en']/month[position()=$M], ' ', $D, ', ', $Y)" />
</func:function>

<!-- Format date in  FRENCH -->
<func:function name="func:format-date-fr">
  <xsl:param name="mensis" />
  <xsl:param name="Y" />
  <xsl:param name="M" />
  <xsl:param name="D" />
  <func:result>
    <xsl:value-of select="$D"/>
    <xsl:if test="$D=1"><sup>er</sup></xsl:if>
    <xsl:value-of select="concat(' ', $mensis//months[@lang='fr']/month[position()=$M], ' ', $Y)"/>
  </func:result>
</func:function>


<!-- Eval dynamic test on conditional tags -->
<func:function name="func:keyval">
  <xsl:param name="key"/>
  <xsl:if test="not(exslt:node-set($VALUES)/values/key[@id=$key])">
   <xsl:message><xsl:value-of select="concat('Missing value for key ', $key)"/></xsl:message>
  </xsl:if>
  <func:result select="exslt:node-set($VALUES)/values/key[@id=$key]"/>
</func:function>

<!-- Handle key values -->
<xsl:variable name="VALUES">
  <xsl:if test="/*[1]/values">
    <xsl:copy-of select="/*[1]/values"/>
  </xsl:if>
</xsl:variable>

<xsl:template match="keyval">
  <xsl:variable name="id" select="@id"/>
  <xsl:choose>
   <xsl:when test="exslt:node-set($VALUES)/values/key[@id=$id]">
    <xsl:value-of select="exslt:node-set($VALUES)/values/key[@id=$id]"/>
   </xsl:when>
   <xsl:otherwise>
    <span class="missing-value">${<xsl:value-of select="$id"/>}</span>
    <xsl:message><xsl:value-of select="concat('Missing value for key ', $id)"/></xsl:message>
   </xsl:otherwise>
  </xsl:choose>
</xsl:template>


<!-- Use as many ../ as necessary to go back to / from current dir -->
<xsl:template name="relative-root">
<xsl:param name="path"/>
  <xsl:for-each select="str:tokenize($path, '/')">
    <xsl:choose>
      <xsl:when test="position()=1 and position()=last()">
        <xsl:text>/</xsl:text>
      </xsl:when>
      <xsl:when test="position()>1">
        <xsl:text>../</xsl:text>
      </xsl:when>
    </xsl:choose>
  </xsl:for-each>
</xsl:template>


<!-- Define some globals that can be used throughout the stylesheets -->

<!-- Top element name e.g. "book" -->
<xsl:variable name="TTOP"><xsl:value-of select="name(//*[1])" /></xsl:variable>

<!-- Value of top element's link attribute e.g. "handbook.xml" -->
<xsl:param name="link"><xsl:value-of select="//*[1]/@link" /></xsl:param>

<!-- Value of top element's lang attribute e.g. "pt_br" -->
<xsl:variable name="glang">
  <xsl:choose>
    <xsl:when test="//*[1]/@lang and contains($alllang, concat('|', //*[1]/@lang,'|'))">
      <xsl:value-of select="//*[1]/@lang" />
    </xsl:when>
    <!-- Default to language in path when @lang is undefined -->
    <xsl:when test="contains($alllang, concat('|', substring-before(substring-after(substring-after($link,'/'),'/'),'/'), '|'))">
      <xsl:value-of select="substring-before(substring-after(substring-after($link,'/'),'/'),'/')" />
    </xsl:when>
    <xsl:otherwise>en</xsl:otherwise>
  </xsl:choose>
</xsl:variable>

<xsl:variable name="RTL"><xsl:if test="$glang='he' or $glang='ar'">Y</xsl:if></xsl:variable>

<xsl:variable name="ROOT">
  <xsl:choose>
    <xsl:when test="not(starts-with($link, '/errors/'))">
      <xsl:call-template name="relative-root">
        <xsl:with-param name="path" select="$link"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise>
      <xsl:text>/</xsl:text>
    </xsl:otherwise>
  </xsl:choose>
</xsl:variable>

<xsl:template match="/">
  <xsl:apply-templates/>
</xsl:template>

</xsl:stylesheet>
