<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="tag:textalign.net,2015:ns" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:fn="http://www.w3.org/2005/xpath-functions" xmlns:tei="http://www.tei-c.org/ns/1.0"
   xmlns:math="http://www.w3.org/2005/xpath-functions/math" xmlns:functx="http://www.functx.com"
   xmlns:sch="http://purl.oclc.org/dsdl/schematron" xmlns:xhtml="http://www.w3.org/1999/xhtml"
   xmlns:mods="http://www.loc.gov/mods/v3" xmlns:map="http://www.w3.org/2005/xpath-functions/map"
   exclude-result-prefixes="#all" version="3.0">
   <!-- This is a special set of extra functions for searching outside sources for information, and processing the results of those searches -->

   <xsl:variable name="search-services" select="doc('TAN-search-services.xml')"/>

   <xsl:param name="search-record-maximum" as="xs:integer" select="10"/>

   <xsl:function name="tan:search-for-scripta" as="item()*">
      <!-- Input: a search expression, an integer indicating the number of records requested -->
      <!-- Output: that number of records using the search expression in the Library of Congress -->
      <xsl:param name="search-expression" as="xs:string?"/>
      <xsl:param name="max-records" as="xs:integer"/>
      <!--<xsl:variable name="search-parsed" select=""/>-->
      <xsl:variable name="params" as="element()+">
         <param name="query" value="{encode-for-uri($search-expression)}"/>
         <param name="recordSchema"/>
         <param name="maximumRecords"
            value="{max((1, min(($search-record-maximum, $max-records))))}"/>
      </xsl:variable>
      <xsl:copy-of select="tan:search-for-entities('loc', $params)"/>
   </xsl:function>

   <xsl:function name="tan:search-for-persons" as="item()*">
      <!-- Input: a search expression, an integer indicating the number of records requested -->
      <!-- Output: that number of records using the search expression in the Virtual International Authority File -->
      <xsl:param name="search-expression" as="xs:string?"/>
      <xsl:param name="max-records" as="xs:integer"/>
      <xsl:variable name="params" as="element()+">
         <param name="query"
            value="{concat('cql.any+%3D+%22',encode-for-uri($search-expression),'+%22')}"/>
         <param name="recordSchema"/>
         <param name="maximumRecords"
            value="{max((1, min(($search-record-maximum, $max-records))))}"/>
      </xsl:variable>
      <xsl:copy-of select="tan:search-for-entities('viaf', $params)"/>
   </xsl:function>

   <xsl:function name="tan:search-wikipedia" as="item()*">
      <!-- Input: a search expression, an integer indicating the number of records requested -->
      <!-- Output: that number of records using the search expression in Wikipedia -->
      <xsl:param name="search-expression" as="xs:string?"/>
      <xsl:param name="max-records" as="xs:integer"/>
      <xsl:variable name="params" as="element()+">
         <param name="search" value="{replace($search-expression,'\s+','+')}"/>
         <param name="limit" value="{max((1, min(($search-record-maximum, $max-records))))}"/>
         <param name="fulltext"/>
      </xsl:variable>
      <xsl:copy-of select="tan:search-for-entities('wikipedia', $params)"/>
   </xsl:function>

   <xsl:function name="tan:search-morpheus" as="document-node()?">
      <!-- Input: a token in Greek or Latin -->
      <!-- Output: lexico-morphological data using Morpheus's service -->
      <xsl:param name="search-expression" as="xs:string?"/>
      <xsl:variable name="lang-code" as="xs:string">
         <xsl:choose>
            <xsl:when test="matches($search-expression, '[\p{IsGreek}\p{IsGreekExtended}]')"
               >grc</xsl:when>
            <xsl:otherwise>lat</xsl:otherwise>
         </xsl:choose>
      </xsl:variable>
      <xsl:variable name="params" as="element()+">
         <param name="lang" value="{$lang-code}"/>
         <param name="engine" value="morpheus{$lang-code}"/>
         <param name="word" value="{$search-expression}"/>
      </xsl:variable>
      <xsl:variable name="morpheus-json" select="tan:search-for-entities('morpheus', $params)"/>
      <xsl:copy-of select="json-to-xml($morpheus-json)"/>
   </xsl:function>

   <xsl:variable name="internet-available" as="xs:boolean"
      select="unparsed-text-available('http://www.google.com')"/>
   <xsl:function name="tan:search-for-entities" as="item()*">
      <!-- Input: a sequence of strings (search keywords), a string (options: loc), a string (options: marcxml, dc, mods), a positive integer -->
      <!-- Output: up to N records (N = integer parameter) in the protocol of the 3rd paramater, using the SRU protocol of the library catalog specified in the 2nd parameter based on search words in the 1st -->
      <xsl:param name="server-idref" as="xs:string"/>
      <xsl:param name="params" as="element()+"/>
      <xsl:variable name="diagnostics" select="true()"/>
      <xsl:variable name="server-info" select="$search-services/*/service[name = $server-idref]"/>
      <xsl:variable name="server-url-base" select="$server-info/url-base"/>
      <xsl:variable name="server-params"
         select="$server-info/(param, root()/*/protocol[@xml:id = $server-info/protocol]/param)"/>
      <!--<xsl:message select="$server-info"/>-->
      <!--<xsl:message select="$server-info/*"></xsl:message>-->
      <!--<xsl:message select="$server-info/root()/*/protocol[@xml:id = $server-info/protocol]"/>-->
      <xsl:variable name="these-params" as="xs:string*">
         <xsl:for-each select="$params">
            <xsl:variable name="this-param-name" select="@name"/>
            <xsl:variable name="this-param-val" select="@value"/>
            <xsl:variable name="this-param-rule" select="$server-params[name = $this-param-name]"/>
            <xsl:choose>
               <xsl:when test="not(exists($this-param-rule))">
                  <xsl:message
                     select="concat($this-param-name, ' is not an expected parameter for this service')"
                  />
               </xsl:when>
               <xsl:when test="exists($this-param-rule/val[@type = 'regex'])">
                  <!-- cases where the expected input should match a regular expression -->
                  <xsl:choose>
                     <xsl:when test="string-length($this-param-val) lt 1">
                        <xsl:message select="'empty string cannot be evaluated'"/>
                     </xsl:when>
                     <xsl:when test="not(matches($this-param-val, $this-param-rule/val[1]))">
                        <xsl:message
                           select="concat($this-param-val, ' does not match expression ', ($this-param-rule/val/@regex)[1])"
                        />
                     </xsl:when>
                     <xsl:otherwise>
                        <xsl:value-of select="concat($this-param-name, '=', $this-param-val)"/>
                     </xsl:otherwise>
                  </xsl:choose>
               </xsl:when>
               <xsl:otherwise>
                  <!-- cases where the expected input is meant to match specific options -->
                  <xsl:choose>
                     <xsl:when test="not(exists($this-param-val))">
                        <xsl:value-of
                           select="concat($this-param-name, '=', $this-param-rule/val[1])"/>
                     </xsl:when>
                     <xsl:when test="not($this-param-val = $this-param-rule/val)">
                        <xsl:message
                           select="concat($this-param-val, ' is invalid option; must be: ', string-join($this-param-rule/val, ', '))"
                        />
                     </xsl:when>
                     <xsl:otherwise>
                        <xsl:value-of select="concat($this-param-name, '=', $this-param-val)"/>
                     </xsl:otherwise>
                  </xsl:choose>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:for-each>
      </xsl:variable>
      <xsl:variable name="this-search-url"
         select="concat($server-url-base, string-join($these-params,'&amp;'))"/>

      <xsl:choose>
         <xsl:when test="not($internet-available)"/>
         <xsl:when test="doc-available($this-search-url)">
            <xsl:message select="concat('Success: ', $this-search-url)"/>
            <xsl:copy-of select="doc($this-search-url)"/>
         </xsl:when>
         <xsl:when test="unparsed-text-available($this-search-url)">
            <xsl:message
               select="'XML not returned, but unparsed text available from', $this-search-url"/>
            <xsl:copy-of select="unparsed-text($this-search-url)"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:message select="concat('Nothing retrieved from ', $this-search-url)"/>
         </xsl:otherwise>
      </xsl:choose>

   </xsl:function>

   <xsl:function name="tan:search-results-to-IRI-name-pattern" as="item()*">
      <!-- One-parameter version of the fuller one, below -->
      <xsl:param name="search-results" as="item()*"/>
      <xsl:copy-of select="tan:search-results-to-IRI-name-pattern($search-results, true())"/>
   </xsl:function>
   <xsl:function name="tan:search-results-to-IRI-name-pattern" as="item()*">
      <!-- Input: search results from tan:search-for-entities() -->
      <!-- Output: for every entity found, an <item> with <IRI>, <name>, and perhaps <desc> -->
      <!-- Note, this is intended to format results from searches that result in identifiers and descriptions of entities, not claims. -->
      <xsl:param name="search-results" as="item()*"/>
      <xsl:param name="format-results" as="xs:boolean"/>
      <xsl:variable name="iri-name-results" as="item()*">
         <xsl:apply-templates select="$search-results/*" mode="get-IRI-name"/>
      </xsl:variable>
      <xsl:choose>
         <xsl:when test="$format-results">
            <xsl:text>&#xa;</xsl:text>
            <xsl:comment>Search results</xsl:comment>
            <xsl:text>&#xa;</xsl:text>
            <xsl:for-each select="$iri-name-results">
               <xsl:text>&#xa;</xsl:text>
               <xsl:comment><xsl:text>Result #</xsl:text><xsl:value-of select="position()"/></xsl:comment>
               <xsl:copy-of select="*"/>
               <xsl:text>&#xa;</xsl:text>
            </xsl:for-each>
         </xsl:when>
         <xsl:otherwise>
            <xsl:copy-of select="$iri-name-results"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>

   <!-- get-IRI-name uses shallow skip by default -->
   <xsl:template match="text() | processing-instruction() | comment()" mode="get-IRI-name"/>
   <xsl:template match="document-node() | *" mode="get-IRI-name">
      <xsl:apply-templates mode="#current"/>
   </xsl:template>

   <!--<xsl:template match="*:a" mode="get-IRI-name" priority="1">
      <xsl:message select="namespace-uri(.)"/>
      <xsl:message select="local-name(.), name(.)"></xsl:message>
   </xsl:template>-->
   <xsl:template match="xhtml:a | a[@href]" mode="get-IRI-name" priority="2">
      <!-- viaf results yield html in no namespace -->
      <!--<xsl:message>xhtml:a found</xsl:message>
      <xsl:message select="tan:shallow-copy(.)"/>-->
      <xsl:choose>
         <xsl:when test="matches(@href, '/viaf/\d+')">
            <xsl:variable name="possible-desc"
               select="parent::*:td/following-sibling::*:td[@class = 'recAnnotation']"/>
            <item>
               <IRI>
                  <xsl:analyze-string select="@href" regex="/viaf/\d+">
                     <xsl:matching-substring>
                        <xsl:value-of select="concat('http://viaf.org', .)"/>
                     </xsl:matching-substring>
                  </xsl:analyze-string>
               </IRI>
               <xsl:for-each select="text()[matches(., '\S')]">
                  <name>
                     <xsl:value-of select="normalize-space(normalize-unicode(.))"/>
                  </name>
               </xsl:for-each>
               <xsl:if test="exists($possible-desc)">
                  <desc>
                     <xsl:value-of
                        select="normalize-space(normalize-unicode(string-join(distinct-values($possible-desc//text()), ' ')))"
                     />
                  </desc>
               </xsl:if>
            </item>
         </xsl:when>
         <xsl:otherwise>
            <xsl:apply-templates mode="#current"/>
         </xsl:otherwise>
      </xsl:choose>

   </xsl:template>
   <xsl:template match="mods:mods" mode="get-IRI-name" priority="2">
      <item>
         <xsl:for-each select="mods:identifier[@type = 'lccn']">
            <IRI>
               <xsl:value-of select="concat('http://lccn.loc.gov/', .)"/>
            </IRI>
         </xsl:for-each>
         <xsl:for-each select="mods:identifier[@type = 'isbn']">
            <xsl:variable name="this-isbn">
               <xsl:analyze-string select="." regex="[\dxX-]+">
                  <xsl:matching-substring>
                     <xsl:value-of select="."/>
                  </xsl:matching-substring>
               </xsl:analyze-string>
            </xsl:variable>
            <IRI>
               <xsl:value-of select="concat('urn:isbn:', $this-isbn)"/>
            </IRI>
         </xsl:for-each>
         <xsl:variable name="possible-names" as="xs:string*">
            <xsl:for-each select="mods:titleInfo/(self::*, mods:title)">
               <xsl:value-of
                  select="normalize-space(normalize-unicode((string-join(.//text(), ' '))))"/>
            </xsl:for-each>
         </xsl:variable>
         <xsl:for-each select="distinct-values($possible-names)">
            <name>
               <xsl:value-of select="."/>
            </name>
         </xsl:for-each>
         <xsl:variable name="possible-desc"
            select="mods:abstract, mods:tableOfContents, mods:note, mods:subject"/>
         <xsl:if test="exists($possible-desc)">
            <desc>
               <xsl:value-of
                  select="normalize-space(normalize-unicode(string-join(distinct-values($possible-desc//text()), ' ')))"
               />
            </desc>
         </xsl:if>
      </item>

   </xsl:template>
   <xsl:template match="ul[@class = 'mw-search-results']/li" mode="get-IRI-name">
      <!-- wikipedia hits -->
      <xsl:variable name="first-best-link" select="(.//a[matches(@href, '/wiki/')])[1]"/>
      <item>
         <IRI>
            <xsl:value-of
               select="concat('http://dbpedia.org', replace($first-best-link/@href, '/wiki/', '/resource/'))"
            />
         </IRI>
         <name>
            <xsl:value-of select="div[1]"/>
         </name>
         <desc>
            <xsl:value-of select="div[2]"/>
         </desc>
      </item>
   </xsl:template>

   <xsl:function name="tan:search-results-to-claims" as="item()*">
      <!-- Input: XML representing a search result that is a claim; a string indicating which vendor supplied the results -->
      <!-- Output: the claim represented in TAN elements -->
      <!-- This experimental function, so far only supporting results from tan:search-morpheus() -->
      <xsl:param name="search-results" as="item()*"/>
      <xsl:param name="results-vendor" as="xs:string"/>
      <xsl:choose>
         <xsl:when test="$results-vendor = ('morpheus', 'perseus')">
            <xsl:apply-templates select="$search-results" mode="claims-morpheus"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:message select="'Vendor not supported for these results; try: morpheus'"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>

   <xsl:variable name="morpheus-map" as="map(xs:string, xs:string)">
      <xsl:map>
         <xsl:map-entry key="'verb participle'" select="'verb'"/>
         <xsl:map-entry key="'dative'" select="'case dative'"/>
         <xsl:map-entry key="'genitive'" select="'case genitive'"/>
         <xsl:map-entry key="'vocative'" select="'case vocative'"/>
         <xsl:map-entry key="'active'" select="'voice active'"/>
         <xsl:map-entry key="'middle'" select="'voice middle'"/>
         <xsl:map-entry key="'passive'" select="'voice passive'"/>
         <xsl:map-entry key="'mediopassive'" select="'middle-passive'"/>
         <xsl:map-entry key="'imperative'" select="'verb imperative'"/>
         <xsl:map-entry key="'pluperfect'" select="'tense pluperfect'"/>
         <xsl:map-entry key="'indicative'" select="'mood indicative'"/>
         <xsl:map-entry key="'optative'" select="'mood optative'"/>
         <xsl:map-entry key="'subjunctive'" select="'modality subjunctive'"/>
         <xsl:map-entry key="'masculine/feminine'" select="'gender common'"/>
         <xsl:map-entry key="'irregular'" select="'noun'"/>
      </xsl:map>
   </xsl:variable>
   <xsl:template match="node()" mode="claims-morpheus">
      <xsl:apply-templates mode="#current"/>
   </xsl:template>
   <xsl:template match="/*" mode="claims-morpheus">
      <xsl:variable name="this-tok"
         select="replace((.//fn:map[@key = 'hasTarget']/fn:map[@key = 'Description']/fn:string)[1], 'urn:word:', '')"/>
      <claims>
         <!-- We use the element name that will appear in the <definitions>, to expedite processing. -->
         <algorithm>
            <IRI>
               <xsl:value-of
                  select="concat('tag:textalign.net,2015:algorithm:', .//fn:map[@key = 'Agent']/fn:string[@key = 'about'])"
               />
            </IRI>
            <name>Tufts morphology service</name>
         </algorithm>
         <claim-when>
            <xsl:value-of select=".//fn:map[@key = 'created']/fn:string[@key = '$']"/>
         </claim-when>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="this-tok" select="$this-tok" tunnel="yes"/>
         </xsl:apply-templates>
      </claims>
   </xsl:template>
   <xsl:template match="fn:map[@key = 'entry']" mode="claims-morpheus">
      <xsl:param name="this-tok" tunnel="yes"/>
      <ana>
         <tok val="{$this-tok}"/>
         <lm>
            <xsl:apply-templates mode="#current"/>
         </lm>
      </ana>
   </xsl:template>
   <xsl:template match="fn:map[@key = 'dict']" mode="claims-morpheus">
      <xsl:variable name="this-headword" select="fn:map[@key = 'hdwd']/fn:string[@key = '$']"/>
      <l>
         <xsl:value-of select="$this-headword"/>
      </l>
      <lem xml:id="{$this-headword}">
         <lex>
            <name>
               <xsl:value-of select="replace($this-headword, '\d+$', '')"/>
            </name>
            <xsl:apply-templates mode="#current"/>
            <xsl:variable name="this-decl" select="..//fn:map[@key = 'decl']/fn:string"/>
            <xsl:variable name="this-stem-type" select="..//fn:map[@key = 'stemtype']/fn:string"/>
            <xsl:variable name="this-deriv-type" select="..//fn:map[@key = 'derivtype']/fn:string"/>
            <desc>
               <xsl:for-each-group select="($this-decl, $this-stem-type, $this-deriv-type)" group-by="../@key">
                  <xsl:variable name="this-type" select="current-grouping-key()"/>
                  <xsl:value-of select="concat(current-grouping-key(), ': ')"/>
                  <xsl:for-each-group select="current-group()" group-by=".">
                     <xsl:value-of select="concat(current-grouping-key(), ' ')"/>
                  </xsl:for-each-group> 
                  <xsl:text>; </xsl:text>
               </xsl:for-each-group> 
            </desc>
         </lex>
      </lem>
   </xsl:template>
   <xsl:template match="fn:array[@key = 'infl']/fn:map | fn:map[@key = 'infl']"
      mode="claims-morpheus">
      <m>
         <xsl:apply-templates mode="#current"/>
      </m>
   </xsl:template>
   <xsl:template match="fn:map[@key = 'dial']" mode="claims-morpheus">
      <xsl:variable name="this-lang"
         select="preceding-sibling::fn:map[@key = 'term']/fn:string[@key = 'lang']"/>
      <xsl:variable name="these-dialects" select="tokenize(fn:string, ' ')"/>
      <xsl:for-each select="$these-dialects">
         <for-lang>
            <xsl:value-of select="string-join(($this-lang, .), '-')"/>
         </for-lang>
      </xsl:for-each>
   </xsl:template>
   <xsl:template match="fn:map[@key = ('pofs', 'case', 'gend', 'num', 'mood', 'tense', 'voice')]"
      mode="claims-morpheus">
      <xsl:variable name="this-val" select="fn:string[@key = '$']"/>
      <xsl:variable name="has-multiple-vals" select="false()"/>
      <xsl:variable name="these-vals"
         select="
            if ($has-multiple-vals) then
               tokenize($this-val, ' ')
            else
               $this-val"/>
      <xsl:variable name="this-key" select="@key"/>
      <xsl:variable name="these-vals-norm"
         select="
            for $i in $these-vals
            return
               (map:get($morpheus-map, $i), $i)[1]"/>
      <xsl:for-each select="$these-vals-norm">
         <xsl:variable name="this-glossary" select="tan:glossary('feature', .)"/>
         <feature>
            <xsl:copy-of select="$this-glossary[1]/(* except tan:desc)"/>
         </feature>
         <xsl:if test="count($this-glossary) gt 1">
            <xsl:message select="'Ambiguous meaning of', ., ':', $this-glossary/tan:name[1]/text()"
            />
         </xsl:if>
         <xsl:if test="not(exists($this-glossary))">
            <xsl:message select="'Uncertain meaning of', ."/>
         </xsl:if>

      </xsl:for-each>
   </xsl:template>


   <!-- http://gso.gbv.de/sru/DB=2.1/?version=1.1&operation=searchRetrieve
&query=dinosaur&recordSchema=dc&sortKeys=YOP%2Cpica%2C0%2C%2C -->
   <!-- http://services.dnb.de/sru/dnb?operation=searchRetrieve&version=1.1&query=hund -->
   <!-- http://lx2.loc.gov:210/LCDB?version=1.1&operation=searchRetrieve
&query="Marv Throneberry"
&startRecord=1&maximumRecords=5&recordSchema=mods -->
   <!-- http://www.worldcat.org/webservices/catalog/search/sru?query={CQLQuery} -->
   <!-- https://viaf.org/viaf/search?query=cql.any+%3D+%22kalvesmaki%22&recordSchema=http%3A%2F%2Fviaf.org%2FVIAFCluster&maximumRecords=100&startRecord=1&resultSetTTL=300&recordPacking=xml&recordXPath=&sortKeys= -->
   <!-- https://viaf.org/viaf/search?query=cql.any+%3D+%22kalvesmaki%22&recordSchema=http%3A%2F%2Fviaf.org%2FBriefVIAFCluster&maximumRecords=100&startRecord=1&resultSetTTL=300&recordPacking=xml&recordXPath=&sortKeys= -->
   <!-- http://services.perseids.org/bsp/morphologyservice/analysis/word?lang=lat&engine=morpheuslat&word=novum -->
   <!-- http://services.perseids.org/bsp/morphologyservice/analysis/word?lang=grc&engine=morpheusgrc&word=Ἰησοῦν -->

</xsl:stylesheet>
