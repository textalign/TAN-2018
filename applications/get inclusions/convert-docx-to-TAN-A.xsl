<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="tag:textalign.net,2015:ns" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:html="http://www.w3.org/1999/xhtml" xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
    xmlns:tan="tag:textalign.net,2015:ns" exclude-result-prefixes="#all" version="2.0">

    <!-- Basic rules for converting docx to tan-a -->
    <!-- Companion stylesheet to dependent core stylesheet -->

    <xsl:template match="/w:comments" priority="1" mode="input-pass-1">

        <xsl:variable name="this-base-uri" select="@xml:base"/>
        <xsl:variable name="this-base-uri-without-percentage"
            select="replace($this-base-uri, '%\d+', '')"/>
        <xsl:variable name="this-homily-number"
            select="replace($this-base-uri-without-percentage, '.+([1-9]\d*)\D+$', '$1')"/>
        <xsl:variable name="this-source-idref"
            select="tan:clio-scripta-idrefs($this-base-uri-without-percentage, 'source')"/>
        <xsl:variable name="this-source-pass-1" as="document-node()*">
            <xsl:apply-templates select="$input-items[w:document/@xml:base = $this-base-uri]"
                mode="input-pass-1">
                <xsl:with-param name="target-root-element-name" select="'TAN-T'"/>
                <xsl:with-param name="keep-anchors" select="true()" tunnel="yes"/>
            </xsl:apply-templates>
        </xsl:variable>
        <xsl:variable name="this-source-pass-2" as="document-node()">
            <xsl:apply-templates select="$this-source-pass-1" mode="input-pass-2"/>
        </xsl:variable>
        <xsl:variable name="this-source-pass-3" as="document-node()">
            <xsl:apply-templates select="$this-source-pass-2" mode="input-pass-3"/>
        </xsl:variable>
        <xsl:variable name="this-source-pass-4" as="document-node()">
            <xsl:apply-templates select="$this-source-pass-3" mode="input-pass-4"/>
        </xsl:variable>

        <xsl:variable name="this-source-tokenized">
            <xsl:apply-templates select="$this-source-pass-4" mode="tokenize-without-anchors"/>
        </xsl:variable>

        <!--<xsl:variable name="this-source-analyzed" select="tan:analyze-leaf-div-string-length($this-source-tokenized)"/>-->

        <xsl:variable name="anchors-marked" as="element()*">
            <xsl:apply-templates select="$this-source-pass-4/*" mode="mark-anchors"/>
        </xsl:variable>

        <xsl:variable name="anchors-to-loci" as="element()*">
            <xsl:for-each-group select="$anchors-marked" group-by="@w:id">
                <xsl:variable name="opening-anchor"
                    select="current-group()/self::w:commentRangeStart"/>
                <xsl:variable name="closing-anchor" select="current-group()/self::w:commentRangeEnd"/>
                <xsl:variable name="opening-ref" select="$opening-anchor/@ref"/>
                <xsl:variable name="opening-pos" select="xs:integer($opening-anchor/@string-pos)"/>
                <xsl:variable name="closing-ref" select="$closing-anchor/@ref"/>
                <xsl:variable name="closing-pos" select="xs:integer($closing-anchor/@string-pos)"/>
                <xsl:variable name="is-in-same-div" select="$opening-ref = $closing-ref"/>
                <xsl:variable name="target-opening-leaf-div"
                    select="$this-source-tokenized//*:div[@ref = $opening-ref]"/>
                <xsl:variable name="target-closing-leaf-div"
                    select="
                        if ($is-in-same-div) then
                            $target-opening-leaf-div
                        else
                            $this-source-tokenized//*:div[@ref = $closing-ref]"/>
                <xsl:variable name="target-opening-tok"
                    select="$target-opening-leaf-div/*[xs:integer(@string-pos) ge $opening-pos][1]"/>
                <xsl:variable name="target-closing-tok"
                    select="$target-closing-leaf-div/*[xs:integer(@string-pos) lt $closing-pos][last()]"/>
                <xsl:variable name="opening-is-non-tok"
                    select="$target-opening-tok/self::tan:non-tok"/>
                <xsl:variable name="closing-is-non-tok"
                    select="$target-closing-tok/self::tan:non-tok"/>
                <xsl:variable name="target-opening-tok-norm"
                    select="
                        if ($opening-is-non-tok) then
                            $target-opening-tok/following-sibling::tan:tok[1]
                        else
                            $target-opening-tok"/>
                <xsl:variable name="target-closing-tok-norm"
                    select="
                        if ($closing-is-non-tok) then
                            $target-closing-tok/preceding-sibling::tan:tok[1]
                        else
                            $target-closing-tok"/>
                <xsl:variable name="target-opening-char-pos" as="xs:integer?">
                    <xsl:if test="not($opening-is-non-tok)">
                        <xsl:if test="not($opening-pos = $target-opening-tok/@string-pos)">
                            <xsl:copy-of
                                select="xs:integer($opening-pos) - xs:integer($target-opening-tok/@string-pos) + 1"
                            />
                        </xsl:if>
                    </xsl:if>
                </xsl:variable>
                <xsl:variable name="target-closing-char-pos" as="xs:integer?">
                    <xsl:if test="not($closing-is-non-tok)">
                        <xsl:if
                            test="not($closing-pos = ($target-closing-tok/@string-pos + string-length($target-closing-tok)))">
                            <xsl:copy-of
                                select="xs:integer($closing-pos) - xs:integer($target-closing-tok/@string-pos)"
                            />
                        </xsl:if>
                    </xsl:if>
                </xsl:variable>
                <xsl:variable name="is-not-tok-range"
                    select="deep-equal($target-opening-tok-norm, $target-closing-tok-norm)"/>
                <xsl:variable name="target-opening-tok-pos"
                    select="count($target-opening-tok-norm/preceding-sibling::tan:tok[. = $target-opening-tok-norm]) + 1"/>
                <xsl:variable name="target-closing-tok-pos"
                    select="
                        if ($is-not-tok-range) then
                            $target-opening-tok-pos
                        else
                            (count($target-closing-tok-norm/preceding-sibling::tan:tok[. = $target-closing-tok-norm]) + 1)"/>
                <locus claim-id="{current-grouping-key()}" src="{$this-source-idref}">
                    <tok>
                        <xsl:if test="$is-in-same-div">
                            <xsl:attribute name="ref" select="$opening-ref"/>
                        </xsl:if>
                        <xsl:choose>
                            <xsl:when test="$is-not-tok-range">
                                <xsl:attribute name="val" select="$target-opening-tok-norm"/>
                                <xsl:if test="$target-opening-tok-pos gt 1">
                                    <xsl:attribute name="pos" select="$target-opening-tok-pos"/>
                                </xsl:if>
                                <xsl:if
                                    test="exists($target-opening-char-pos) or exists($target-closing-char-pos)">
                                    <xsl:attribute name="chars">
                                        <xsl:value-of select="($target-opening-char-pos, '1')[1]"/>
                                        <xsl:text>-</xsl:text>
                                        <xsl:value-of select="($target-closing-char-pos, 'last')[1]"
                                        />
                                    </xsl:attribute>
                                </xsl:if>
                            </xsl:when>
                            <xsl:otherwise>
                                <from>
                                    <xsl:if test="not($is-in-same-div)">
                                        <xsl:attribute name="ref" select="$opening-ref"/>
                                    </xsl:if>
                                    <xsl:attribute name="val" select="tan:escape($target-opening-tok-norm)"/>
                                    <xsl:if test="$target-opening-tok-pos gt 1">
                                        <xsl:attribute name="pos" select="$target-opening-tok-pos"/>
                                    </xsl:if>
                                    <xsl:if test="exists($target-opening-char-pos)">
                                        <xsl:attribute name="chars">
                                            <xsl:value-of select="$target-opening-char-pos"/>
                                            <xsl:text>-last</xsl:text>
                                        </xsl:attribute>
                                    </xsl:if>
                                </from>
                                <to>
                                    <xsl:if test="not($is-in-same-div)">
                                        <xsl:attribute name="ref" select="$closing-ref"/>
                                    </xsl:if>
                                    <xsl:attribute name="val" select="tan:escape($target-closing-tok-norm)"/>
                                    <xsl:if test="$target-closing-tok-pos gt 1">
                                        <xsl:attribute name="pos" select="$target-closing-tok-pos"/>
                                    </xsl:if>
                                    <xsl:if test="exists($target-closing-char-pos)">
                                        <xsl:attribute name="chars">
                                            <xsl:text>1-</xsl:text>
                                            <xsl:value-of select="$target-closing-char-pos"/>
                                        </xsl:attribute>
                                    </xsl:if>
                                </to>
                            </xsl:otherwise>
                        </xsl:choose>
                    </tok>
                    <!-- diagnostics -->
                    <!--<xsl:copy-of select="$opening-pos"/>-->
                    <!--<xsl:copy-of select="$closing-pos"/>-->
                    <!--<xsl:copy-of select="$target-opening-leaf-div"/>-->
                    <!--<xsl:copy-of select="$target-closing-leaf-div"/>-->
                    <!--<xsl:copy-of select="$target-opening-tok"/>-->
                    <!--<xsl:copy-of select="$target-closing-tok"/>-->
                    <!--<xsl:copy-of select="$target-opening-tok-norm"/>-->
                    <!--<xsl:copy-of select="$target-closing-tok-norm"/>-->
                    <!--<xsl:copy-of select="xs:integer($opening-pos) - xs:integer($target-opening-tok/@string-pos) + 1"/>-->
                    <!--<xsl:copy-of select="$target-opening-char-pos"/>-->
                    <!--<xsl:copy-of select="$target-closing-char-pos"/>-->
                </locus>

            </xsl:for-each-group>
        </xsl:variable>


        <!-- diagnostics, results -->
        <!--<xsl:copy-of select="$this-source-pass-1"/>-->
        <!--<xsl:copy-of select="$this-source-pass-2"/>-->
        <!--<xsl:copy-of select="$this-source-pass-3"/>-->
        <!--<xsl:copy-of select="$this-source-pass-4"/>-->
        <!--<xsl:copy-of select="$this-source-tokenized"/>-->
        <!--<xsl:copy-of select="$this-source-plain-text-with-anchors"/>-->
        <!--<xsl:copy-of select="$anchors-marked"/>-->
        <!--<xsl:copy-of select="$anchors-to-loci"/>-->
        <!--<xsl:copy-of select="$this-source-tokenized"/>-->
        
        <TAN-A>
            <xsl:apply-templates mode="#current">
                <xsl:with-param name="loci" select="$anchors-to-loci"/>
            </xsl:apply-templates>
        </TAN-A>

    </xsl:template>

    <xsl:template match="w:comment" mode="input-pass-1">
        <xsl:param name="loci"/>
        <xsl:variable name="this-id" select="@w:id"/>
        <xsl:variable name="this-locus" select="tan:copy-of-except($loci[@claim-id = $this-id], (), 'claim-id', ())"/>
        <xsl:variable name="this-claim" select="string-join(.//w:t, '')"/>

        <xsl:for-each select="tokenize($this-claim, ';\s*')">
            <xsl:variable name="these-scripta" select="string-join(tan:clio-scripta-idrefs(., 'scriptum'),' ')"/>
            <xsl:variable name="these-scripta-norm"
                select="
                    if (string-length($these-scripta) lt 1) then
                        concat('scripta unknown in ', .)
                    else
                        $these-scripta"
            />
            <claim subject="{$these-scripta-norm}">
                <xsl:choose>
                    <xsl:when test="matches(., '^\[|fol\.|\]$')">
                        <!-- page, folio breaks -->
                        <xsl:variable name="ref-analyzed" as="element()">
                            <analysis>
                                <xsl:analyze-string select="replace(., '[\[\]]', '')"
                                    regex="(\w+)\.\s*(\w+)">
                                    <xsl:matching-substring>
                                        <object units="{regex-group(1)}">
                                            <xsl:value-of select="regex-group(2)"/>
                                        </object>
                                    </xsl:matching-substring>
                                </xsl:analyze-string>
                            </analysis>
                        </xsl:variable>
                        <xsl:attribute name="verb" select="'resumes-at'"/>
                        <xsl:copy-of select="$ref-analyzed/tan:object"/>
                        <xsl:copy-of select="$this-locus"/>
                    </xsl:when>
                    <xsl:when test="matches(., ' om\.')">
                        <!-- scriptum omits -->
                        <xsl:attribute name="verb" select="'omits'"/>
                        <xsl:copy-of select="$this-locus"/>
                    </xsl:when>
                    <xsl:when test="matches(., '^[\w/]+:')">
                        <xsl:attribute name="verb" select="'reads'"/>
                        <object>
                            <xsl:value-of select="replace(., '^\w+:\s*', '')"/>
                        </object>
                        <xsl:copy-of select="$this-locus"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:comment><xsl:value-of select="concat('unclear how to interpret ', .)"/></xsl:comment>
                        <xsl:copy-of select="$this-locus"/>
                    </xsl:otherwise>
                </xsl:choose>
            </claim>
        </xsl:for-each>

    </xsl:template>

    <xsl:function name="tan:clio-scripta-idrefs" as="xs:string*">
        <!-- Input: two strings -->
        <!-- Output: the normalized idrefs for scripta identified in the string based on the entity type in the second-->
        <xsl:param name="string-to-analyze" as="xs:string?"/>
        <xsl:param name="entity-type" as="xs:string"/>
        <xsl:variable name="expected-entity-types" select="('source', 'work', 'scriptum')"/>
        <xsl:choose>
            <xsl:when test="$entity-type = $expected-entity-types[position() = (1, 2)]">
                <xsl:if test="matches($string-to-analyze, 'Explanatio')">burg</xsl:if>
                <xsl:if test="matches($string-to-analyze, 'Omelia')">grif</xsl:if>
                <xsl:if test="matches($string-to-analyze, 'Commentarius')">mont</xsl:if>

            </xsl:when>
            <xsl:when test="$entity-type = $expected-entity-types[3]">
                <xsl:if test="matches($string-to-analyze, '^fol\.')">bnf15284</xsl:if>
                <xsl:if test="matches($string-to-analyze, '1470')">grif1470</xsl:if>
                <xsl:if test="matches($string-to-analyze, '1486')">grif1486</xsl:if>
                <xsl:if test="matches($string-to-analyze, '1530')">eras1530</xsl:if>
                <xsl:if test="matches($string-to-analyze, '1728')">mont1728</xsl:if>
                <xsl:if test="matches($string-to-analyze, '1862')">PG-44</xsl:if>
            </xsl:when>
        </xsl:choose>
    </xsl:function>

    <xsl:template match="tei:p | tei:ab" mode="plain-text-with-anchors">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>

    <xsl:template match="*" mode="mark-anchors">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>
    <xsl:template match="text()" mode="mark-anchors"/>
    <xsl:template match="w:commentRangeStart | w:commentRangeEnd" mode="mark-anchors">
        <xsl:variable name="preceding-text" select="string-join(preceding-sibling::text(), '')"/>
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:attribute name="ref" select="string-join(ancestor::*/@n, ' ')"/>
            <xsl:attribute name="string-pos">
                <xsl:choose>
                    <xsl:when test="parent::tei:*">
                        <xsl:copy-of select="string-length(string-join((preceding-sibling::text(), ../preceding-sibling::*/text()), '')) + 1"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:copy-of select="string-length(string-join(preceding-sibling::text(),'')) + 1"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:attribute>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="*:div" mode="tokenize-without-anchors">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:attribute name="ref" select="string-join(ancestor-or-self::*/@n, ' ')"/>
            <xsl:choose>
                <xsl:when test="exists(*:div)">
                    <xsl:apply-templates mode="#current"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:variable name="this-text" select="string-join(.//text(), '')"/>
                    <xsl:copy-of
                        select="tan:tok-pos(tan:tokenize-text($this-text, $token-definition-letters-and-punctuation, true())/*, 1)"
                    />
                </xsl:otherwise>
            </xsl:choose>
        </xsl:copy>
    </xsl:template>


    <xsl:function name="tan:tok-pos" as="element()*">
        <!-- Input: a series of <tok> and <non-tok>s -->
        <!-- Output: the same elements with @string-pos, identifying the attribute's starting place in the leaf <div>   -->
        <xsl:param name="elements-to-process" as="element()*"/>
        <xsl:param name="current-starting-position" as="xs:integer"/>
        <xsl:choose>
            <xsl:when test="count($elements-to-process) lt 1"/>
            <xsl:otherwise>
                <xsl:variable name="this-element" select="$elements-to-process[1]"/>
                <xsl:variable name="this-length" select="string-length($this-element)"/>
                <xsl:copy-of
                    select="tan:add-attribute($this-element, 'string-pos', $current-starting-position)"/>
                <xsl:copy-of
                    select="tan:tok-pos($elements-to-process[position() gt 1], $current-starting-position + $this-length)"
                />
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>


    <!-- PASSES 2-4 -->
    <xsl:template match="tan:TAN-A" mode="input-pass-2 input-pass-3 input-pass-4">
        <xsl:copy-of select="."/>
    </xsl:template>


</xsl:stylesheet>
