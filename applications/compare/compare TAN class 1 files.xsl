<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns="tag:textalign.net,2015:ns"
    xmlns:html="http://www.w3.org/1999/xhtml"
    xmlns:math="http://www.w3.org/2005/xpath-functions/math"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:tan="tag:textalign.net,2015:ns" exclude-result-prefixes="#all" version="2.0">
    <xsl:import href="../get%20inclusions/convert.xsl"/>
    <xsl:import href="../get%20inclusions/convert-TAN-to-HTML.xsl"/>

    <!-- Initial input: any class 1 file -->
    <!-- Calculated input: the initial input, plus other class 1 files as stipulated below -->
    <!-- Template: depends on whether requested output is html or docx -->
    <!-- Output: the comparative difference between the files, using tan:diff() if only two input files, tan:collate() for more -->

    <!-- This stylesheet make sense only when the the processed files are different versions of the same work in the same language. -->

    <xsl:output indent="no"/>

    <xsl:param name="validation-phase" select="'terse'"/>

    <!-- Do you want to restrict the comparisons to divs that match? If not, then the first input document's reference system will be the one adopted -->
    <xsl:param name="compare-on-matching-ref-basis" as="xs:boolean" select="false()"/>

    <!-- Do you want to isolate the differences to individual characters, or look at the differences word for word? -->
    <xsl:param name="snap-results-to-word" as="xs:boolean" select="true()"/>

    <xsl:param name="comparison-doc-uris-relative-to-input" as="xs:string+">
        <!--<xsl:value-of
            select="'../../pre-TAN/graeco%20arabic%20studies/tan/Arist-Gr_007.tan-t.ref-scriptum-native-by-page.xml'"
        />-->
        <!--<xsl:value-of
            select="'Arist-Ar_007.tan-t.ref-logical-native.xml'"
        />-->
        <xsl:value-of
            select="'psalms.lat.jerome-from-vetus-latina.xml'"
        />
    </xsl:param>
    <xsl:variable name="comp-doc-uris-resolved"
        select="
            for $i in $comparison-doc-uris-relative-to-input
            return
                resolve-uri($i, $doc-uri)"/>
    <xsl:param name="input-items" as="document-node()*">
        <xsl:choose>
            <xsl:when test="not($doc-class = 1)">
                <xsl:message>Initial input document is not class 1, so will be ignored</xsl:message>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy-of select="$self-expanded"/>
            </xsl:otherwise>
        </xsl:choose>
        <xsl:for-each select="$comp-doc-uris-resolved">
            <xsl:choose>
                <xsl:when test="not(doc-available(.))">
                    <xsl:message select="concat('No document available at ', .)"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:copy-of select="tan:expand-doc(tan:resolve-doc(doc(.)))"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:param>

    <xsl:variable name="input-texts" as="xs:string*"
        select="
            for $i in $input-items
            return
                tan:text-join($i/tan:TAN-T/tan:body)"/>

    <xsl:variable name="comparison-result" as="element()?">
        <xsl:choose>
            <xsl:when test="count($input-texts) = 2">
                <xsl:copy-of
                    select="tan:diff($input-texts[1], $input-texts[2], $snap-results-to-word)"/>
            </xsl:when>
            <xsl:when test="count($input-texts) gt 2">
                <xsl:copy-of select="tan:collate($input-texts)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:message select="concat(string(count($input-texts)), ' input texts detected')"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>

    <xsl:variable name="result-analyzed" select="tan:analyze-string-length($comparison-result)"
        as="element()?"/>

    <xsl:variable name="self-analyzed" select="tan:analyze-string-length($input-items[1])"/>
    <xsl:variable name="self-analyzed-leaf-divs"
        select="$self-analyzed/tan:TAN-T/tan:body//tan:div[not(tan:div)]"/>

    <xsl:variable name="diff-keyed-to-self-1" as="element()?">
        <xsl:apply-templates select="$result-analyzed" mode="diff-keyed-to-self-1"/>
    </xsl:variable>
    <xsl:template match="tan:diff" mode="diff-keyed-to-self-1">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:for-each select="$self-analyzed-leaf-divs, *">
                <xsl:sort
                    select="number((@string-pos, @s1-pos, preceding-sibling::*[1]/@s1-pos)[1])"/>
                <xsl:copy-of select="."/>
            </xsl:for-each>
        </xsl:copy>
    </xsl:template>

    <xsl:variable name="diff-keyed-to-self-2" as="document-node()">
        <xsl:document>
            <xsl:apply-templates select="$diff-keyed-to-self-1" mode="diff-keyed-to-self-2"/>
        </xsl:document>
    </xsl:variable>
    <xsl:template match="tan:diff" mode="diff-keyed-to-self-2">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:for-each-group select="*" group-starting-with="tan:div">
                <xsl:variable name="this-pos" select="xs:integer(current-group()[1]/@string-pos)"/>
                <xsl:variable name="next-pos"
                    select="$this-pos + xs:integer(current-group()[1]/@string-length) + 1"/>
                <xsl:variable name="missing-opening-text-length"
                    select="xs:integer(current-group()[2]/@s1-pos) - $this-pos"/>
                <div>
                    <xsl:copy-of select="current-group()[1]/@*"/>
                    <xsl:if test="$missing-opening-text-length gt 0">
                        <xsl:variable name="prev-diff-element"
                            select="current-group()[1]/preceding-sibling::*[name() = ('common', 'a')][1]"/>
                        <xsl:variable name="prev-b"
                            select="current-group()[1]/preceding-sibling::*[1]/self::tan:b"/>
                        <xsl:comment>adding <xsl:value-of select="$missing-opening-text-length"/> characters from <xsl:value-of select="tan:xml-to-string($prev-diff-element)"/></xsl:comment>
                        <xsl:for-each select="$prev-diff-element">
                            <xsl:copy>
                                <xsl:value-of
                                    select="substring(text(), string-length(text()) - $missing-opening-text-length + 1)"
                                />
                            </xsl:copy>
                        </xsl:for-each>
                        <xsl:copy-of select="$prev-b"/>
                    </xsl:if>
                    <xsl:for-each-group select="current-group()[position() gt 1]"
                        group-starting-with="*[@s1-pos]">
                        <xsl:variable name="next-diff-pos"
                            select="xs:integer(current-group()[1]/@s1-pos) + xs:integer(current-group()[1]/@s1-length) + 1"/>
                        <xsl:variable name="too-much-text" select="$next-diff-pos - $next-pos"/>
                        <xsl:choose>
                            <xsl:when test="$too-much-text gt 0">
                                <xsl:comment>cutting <xsl:value-of select="$too-much-text"/> characters from <xsl:value-of select="tan:xml-to-string(current-group()[1])"/></xsl:comment>
                                <xsl:for-each select="current-group()[1]">
                                    <xsl:copy>
                                        <xsl:value-of
                                            select="substring(text(), 1, string-length(text()) - $too-much-text)"
                                        />
                                    </xsl:copy>
                                </xsl:for-each>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:copy-of select="current-group()"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:for-each-group>
                </div>
            </xsl:for-each-group>
        </xsl:copy>
    </xsl:template>


    <xsl:variable name="self-infused-with-diff">
        <xsl:apply-templates select="$self-analyzed" mode="infuse-diff"/>
    </xsl:variable>
    <xsl:template match="tan:div[not(tan:div)]" mode="infuse-diff">
        <xsl:variable name="this-diff" select="tan:get-via-q-ref(@q, $diff-keyed-to-self-2)"/>
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:copy-of select="*"/>
            <xsl:copy-of select="$this-diff/*"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:variable name="input-pass-4" select="tan:tan-to-html($self-infused-with-diff)"/>
    
    <!-- TEMPLATE -->
    
    <xsl:param name="template-url-relative-to-this-stylesheet" as="xs:string?"
        select="'../../templates/template.html'"/>

    <!-- OUTPUT -->
    <xsl:variable name="output-dir-uri" select="resolve-uri('../../../output/', static-base-uri())"/>
    <xsl:param name="output-url-relative-to-input" as="xs:string?" select="concat($output-dir-uri, 'html/', tan:cfn(/), '-', $today-iso, '.html')"/>

    <!--<xsl:template match="/" priority="5">
        <!-\-<xsl:copy-of select="$self-resolved"/>-\->
        <xsl:copy-of select="$comparison-result"/>
        <!-\-<xsl:copy-of select="$self-analyzed"/>-\->
        <!-\-<xsl:copy-of select="$diff-keyed-to-self-1"/>-\->
        <!-\-<xsl:copy-of select="$diff-keyed-to-self-2"/>-\->
        <!-\-<xsl:copy-of select="$self-infused-with-diff"/>-\->
        <!-\-<xsl:copy-of select="tan:tan-to-html($self-infused-with-diff)"/>-\->
        <!-\-<xsl:copy-of select="$template-doc"/>-\->
        <!-\-<xsl:copy-of select="$template-infused-with-revised-input"/>-\->
        
    </xsl:template>-->


</xsl:stylesheet>
