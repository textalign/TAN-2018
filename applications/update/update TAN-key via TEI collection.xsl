<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="tag:textalign.net,2015:ns" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:fn="http://www.w3.org/2005/xpath-functions"
    xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:ti="http://chs.harvard.edu/xmlns/cts"
    xmlns:tan="tag:textalign.net,2015:ns" exclude-result-prefixes="#all" version="3.0">

    <xsl:import href="../get%20inclusions/convert.xsl"/>

    <!-- Triggering input: a TAN-key file -->
    <!-- Actual input: a collection of TEI files, parameter-defined -->
    <!-- Template: the triggering input -->
    <!-- Output: the triggering input, with data refreshed -->
    <!-- We do *:<element> instead of tei:<element> because TEI version 2 files are in no namespace -->


    <xsl:variable name="stylesheet-iri"
        select="'tag:textalign.net,2015:stylesheet:convert-perseus-catalog-to-tan-key'"/>
    <xsl:variable name="change-message" select="'Populated with metadata from DCGAS files.'"/>

    <xsl:param name="tei-catalog-file-url-relative-to-input" select="'../orig/catalog.xml'"/>
    
    <xsl:param name="max-search-records" as="xs:integer" select="10"/>

    <xsl:param name="input-items"
        select="collection(resolve-uri($tei-catalog-file-url-relative-to-input, $doc-uri) || '?on-error=ignore')"/>

    <xsl:template match="node() | document-node()" mode="input-pass-1">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>
    <!--<xsl:template match="text()" mode="input-pass-1"/>-->
    <xsl:template match="*:author | *:editor" mode="input-pass-1">
        <item affects-element="person">
            <name>
                <xsl:value-of select="normalize-space(normalize-unicode(string-join(.//text(),' ')))"/>
            </name>
        </item>
    </xsl:template>
    <xsl:template match="*:funder" mode="input-pass-1">
        <item affects-element="organization">
            <name>
                <xsl:value-of select="normalize-space(normalize-unicode(string-join(.//text(),' ')))"/>
            </name>
        </item>
    </xsl:template>
    <xsl:template match="*:titleStmt" mode="input-pass-1">
        <xsl:variable name="this-author" select="normalize-space(normalize-unicode(string-join(descendant::*:author//text(),' ')))"/>
        <xsl:variable name="this-title" select="normalize-space(normalize-unicode(string-join(descendant::*:title//text(),' ')))"/>
        <item affects-element="work">
            <name>
                <xsl:value-of select="concat($this-author, ', ', $this-title)"/>
            </name>
            <name>
                <xsl:value-of select="$this-title"/>
            </name>
        </item>
        <xsl:apply-templates mode="#current"/>
    </xsl:template>
    <xsl:template match="*:sourceDesc/*" mode="input-pass-1">
        <xsl:variable name="item-main-text"
            select="normalize-space(normalize-unicode(string-join((descendant::*:author//text(), descendant::*:title//text(), descendant::*:date//text(), descendant::*:editor//text()), ' ')))"/>
        <xsl:if test="string-length($item-main-text) gt 1">
            <item affects-element="source scriptum">
                <name>
                    <xsl:value-of select="tan:possible-bibliography-id($item-main-text)"/>
                </name>
                <name>
                    <xsl:value-of select="$item-main-text"/>
                </name>
            </item>
        </xsl:if>
        <xsl:apply-templates mode="#current"/>
    </xsl:template>
    
    <xsl:param name="input-pass-2" as="element()*">
        <xsl:for-each-group select="$input-pass-1" group-by="@affects-element">
            <group affects-element="{current-grouping-key()}">
                <xsl:for-each-group select="current-group()" group-by="tan:name[1]">
                    <item>
                        <xsl:copy-of select="tan:distinct-items(current-group()/tan:name)"/>
                    </item>
                </xsl:for-each-group> 
            </group>
        </xsl:for-each-group> 
    </xsl:param>


    <xsl:param name="template-url-relative-to-input" as="xs:string?" select="$doc-uri"/>

    <xsl:param name="output-url-relative-to-template" as="xs:string?"
        select="tan:cfn(/) || '-' || format-date(current-date(), '[Y0001]-[M01]-[D01]') || '.xml'"/>

    <xsl:function name="tan:input-items-by-type" as="element()*">
        <!-- Input: a string with TAN element name or names (space-delimited) -->
        <!-- Output: the relevant fragments of the input, grouped by element name -->
        <xsl:param name="element-names" as="xs:string*"/>
        <xsl:variable name="elements-names-norm"
            select="
                distinct-values(for $i in $element-names
                return
                    tokenize(normalize-space($i), ' '))"/>
        <xsl:for-each select="$elements-names-norm">
            <group affects-element="{.}">
                <xsl:if test=". = 'person'">
                    <!--<xsl:copy-of select="$tei-persons"/>-->
                </xsl:if>
                <xsl:if test=". = 'organization'">
                    <!--<xsl:copy-of select="$tei-organizations"/>-->
                </xsl:if>
                <xsl:if test=". = 'work'">
                    <!--<xsl:copy-of select="$tei-works"/>-->
                </xsl:if>
                <xsl:if test=". = 'scriptum'">
                    <!--<xsl:copy-of select="$tei-scripta"/>-->
                </xsl:if>
            </group>
        </xsl:for-each>
    </xsl:function>

    <xsl:variable name="input-items-grouped"
        select="tan:input-items-by-type(/tan:TAN-key/tan:body/descendant-or-self::*/@affects-element)"
        as="element()*"/>

    <xsl:template match="tan:body" mode="infuse-template">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <!-- Step one: look for template's items that are missing from the input -->
            <xsl:apply-templates mode="#current"/>
            <!-- Step two: compare the template items to the input to look for new input items -->
            <xsl:variable name="template-items-normalized" as="element()">
                <xsl:apply-templates select="." mode="core-expansion-terse"/>
            </xsl:variable>
            <xsl:variable name="groups-of-input-items-not-yet-listed" as="element()*">
                <xsl:for-each-group select="$template-items-normalized//tan:item, self::*"
                    group-by="tokenize((ancestor-or-self::*/@affects-element)[last()], ' ')">
                    <xsl:variable name="this-affected-element-name" select="current-grouping-key()"/>
                    <xsl:variable name="current-template-group" select="current-group()"/>
                    <xsl:variable name="relevant-input" select="$input-pass-2[tokenize(@affects-element, ' ') = $this-affected-element-name]"/>
                    <xsl:variable name="missing-input" as="element()*">
                        <xsl:for-each select="$relevant-input/tan:item">
                            <xsl:variable name="this-text-norm"
                                select="tan:normalize-text(tan:name, true())"/>
                            <xsl:if test="not($this-text-norm = $current-template-group/tan:name)">
                                <xsl:copy-of select="."/>
                            </xsl:if>
                        </xsl:for-each>
                    </xsl:variable>
                    <xsl:if test="exists($missing-input)">
                        <group>
                            <xsl:copy-of select="$relevant-input/@*"/>
                            <xsl:copy-of select="$missing-input"/>
                        </group>
                    </xsl:if>
                </xsl:for-each-group>
            </xsl:variable>
            <xsl:variable name="this-indent" select="node()[1]/self::text()"/>
            <xsl:for-each select="$groups-of-input-items-not-yet-listed">
                <xsl:variable name="these-elements-affected" select="tokenize(@affects-element, ' ')"/>
                <xsl:value-of select="$this-indent"/>
                <xsl:comment><xsl:value-of select="@affects-element"/></xsl:comment>
                <xsl:comment>ITEMS BELOW HAVE NOT BEEN FOUND IN THE ORIGINAL TAN-KEY FILE</xsl:comment>
                <xsl:value-of select="$this-indent"/>
                <xsl:for-each select="tan:item">
                    <xsl:copy>
                        <xsl:value-of select="$this-indent"/>
                        <xsl:comment>IRI needs to be found</xsl:comment>
                        <xsl:copy-of select="tan:name"/>
                        <!-- specific searches -->
                        <xsl:if test="$these-elements-affected = 'person'">
                            <xsl:variable name="viaf-search"
                                select="tan:search-for-persons(tan:name[1], $max-search-records)"/>
                            <xsl:variable name="viaf-results"
                                select="tan:search-results-to-IRI-name-pattern($viaf-search)"/>
                            <xsl:copy-of select="$viaf-results"/>
                            <!--<xsl:if test="exists($viaf-results)">
                                <xsl:value-of select="$this-indent"/>
                                <xsl:comment>Viaf checks</xsl:comment>
                                <xsl:value-of select="$this-indent"/>
                                <xsl:for-each select="$viaf-results">
                                    <xsl:value-of select="$this-indent"/>
                                    <xsl:comment><xsl:text>Viaf result #</xsl:text><xsl:value-of select="position()"/></xsl:comment>
                                    <xsl:copy-of select="*"/>
                                    <xsl:value-of select="$this-indent"/>
                                </xsl:for-each>
                            </xsl:if>-->
                        </xsl:if>
                        <xsl:if test="$these-elements-affected = 'scriptum'">
                            <xsl:variable name="loc-search"
                                select="tan:search-for-scripta(tan:name[1], $max-search-records)"/>
                            <xsl:variable name="loc-results"
                                select="tan:search-results-to-IRI-name-pattern($loc-search)"/>
                            <xsl:copy-of select="$loc-results"/>
                            <!--<xsl:if test="exists($loc-results)">
                                <xsl:value-of select="$this-indent"/>
                                <xsl:comment>Library of Congress checks</xsl:comment>
                                <xsl:value-of select="$this-indent"/>
                                <xsl:for-each select="$loc-results">
                                    <xsl:value-of select="$this-indent"/>
                                    <xsl:comment><xsl:text>Library of Congress result #</xsl:text><xsl:value-of select="position()"/></xsl:comment>
                                    <xsl:copy-of select="*"/>
                                    <xsl:value-of select="$this-indent"/>
                                </xsl:for-each>
                            </xsl:if>-->
                        </xsl:if>
                        <!-- general search -->
                        <xsl:if test="not($these-elements-affected = 'scriptum')">
                            <xsl:variable name="wikipedia-search"
                                select="tan:search-wikipedia(tan:name[1], $max-search-records)"/>
                            <xsl:variable name="wikipedia-results"
                                select="tan:search-results-to-IRI-name-pattern($wikipedia-search)"/>
                            <xsl:copy-of select="$wikipedia-results"/>
                            <!--<xsl:if test="exists($wikipedia-results)">
                                <xsl:value-of select="$this-indent"/>
                                <xsl:comment>Wikipedia checks</xsl:comment>
                                <xsl:value-of select="$this-indent"/>
                                <xsl:for-each select="$wikipedia-results">
                                    <xsl:value-of select="$this-indent"/>
                                    <xsl:comment><xsl:text>Wikipedia result #</xsl:text><xsl:value-of select="position()"/></xsl:comment>
                                    <xsl:copy-of select="*"/>
                                    <xsl:value-of select="$this-indent"/>
                                </xsl:for-each>
                            </xsl:if>-->
                        </xsl:if>

                    </xsl:copy>
                    

                </xsl:for-each>
            </xsl:for-each>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="tan:item" mode="infuse-template">
        <xsl:variable name="these-affected-elements" select="tokenize((ancestor-or-self::*/@affects-element)[last()],' ')"/>
        <!--<xsl:variable name="these-affected-elements"
            select="tan:input-items-by-type((ancestor-or-self::*/@affects-element)[last()])"/>-->
        <!--<xsl:variable name="relevant-input" as="xs:string*">
            <xsl:for-each select="$these-affected-elements">
                <xsl:value-of select="tan:normalize-text(., true())"/>
            </xsl:for-each>
        </xsl:variable>-->
        <xsl:variable name="relevant-input" select="$input-pass-2[every $i in tokenize(@affects-element,' ') satisfies $i = $these-affected-elements]"/>
        <xsl:variable name="these-names" select="tan:normalize-text(tan:name, true())"/>
        <xsl:if test="not($these-names = $relevant-input//tan:name)">
            <xsl:message select="'Nothing in input matches item named ' || tan:name[1]"/>
        </xsl:if>
        <xsl:copy-of select="."/>
    </xsl:template>



    <!-- diagnostics only -->
    <xsl:template match="/" priority="5">
        <diagnostics xmlns="">
            <!--<xsl:variable name="test1" select="tan:search-wikipedia('Aristotle, De sensu et sensibilibus', 5)"/>-->
            <!--<xsl:variable name="test2" select="tan:search-results-to-IRI-name-pattern($test1)"/>-->
            <!--<xsl:copy-of select="count($input-items)"/>-->
            <!--<xsl:copy-of select="distinct-values($tei-persons)"/>-->
            <!--<xsl:copy-of select="distinct-values($tei-organizations)"/>-->
            <!--<xsl:copy-of select="distinct-values($tei-works)"/>-->
            <!--<xsl:copy-of select="$tei-scripta"/>-->
            <!--<xsl:copy-of select="tan:find-scripta('Joel Kalvesmaki')"/>-->
            <xsl:copy-of select="$input-pass-1"/>
            <!--<xsl:copy-of select="$input-pass-2"/>-->
            <!--<xsl:copy-of select="$input-items-grouped"/>-->
            <!--<xsl:copy-of select="doc('http://lx2.loc.gov:210/lcdb?version=1.1&amp;operation=searchRetrieve&amp;query=Aristotle%20Man%E1%B9%ADiq%201948&amp;recordSchema=mods&amp;maximumRecords=10')"/>-->
            <!--<xsl:copy-of select="$template-infused-with-revised-input"/>-->
            <!--<xsl:copy-of select="doc('https://en.wikipedia.org/wiki/Special:Search?search=aristotle+categories&amp;go=Go&amp;searchToken=brufgb8pa41qynp92z200h650')"/>-->
            <!--<xsl:copy-of select="tan:search-wikipedia('Roger Godell', 5)"/>-->
            <!--<test31a><xsl:copy-of select="$test1"/></test31a>-->
            <!--<test31b><xsl:copy-of select="$test2"/></test31b>-->
        </diagnostics>
    </xsl:template>

</xsl:stylesheet>
