<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns="http://www.w3.org/1999/xhtml" xmlns:html="http://www.w3.org/1999/xhtml"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:tan="tag:textalign.net,2015:ns" exclude-result-prefixes="#all" version="2.0">

    <!-- Basic conversion utility for TAN to html -->
    <!-- Companion stylesheet to convert.xsl -->

    <xsl:param name="tables-via-css" as="xs:boolean" select="true()"/>

    <xsl:param name="attributes-to-add-to-class-attribute" as="xs:string*" select="('')"/>
    <xsl:param name="elements-to-add-to-class-attribute" as="xs:string*" select="('type')"/>
    <xsl:param name="elements-to-be-labeled" as="xs:string*" select="()"/>

    <!-- pass 1: get rid of unnecessary things, and start building @class -->

    <!-- generally speaking, TAN comments, p-i's, and attributes may be ignored (expansion converts overloaded attributes into elements) -->
    <xsl:template match="attribute::* | comment() | processing-instruction()"
        mode="input-pass-1"/>
    <xsl:template match="tan:cf | tan:see-q" mode="input-pass-1"/>
    
    <xsl:template match="@q | @id" mode="input-pass-1">
        <xsl:attribute name="id" select="."/>
    </xsl:template>
    
    <xsl:template match="*" mode="input-pass-1">
        <!-- Prepare html @class -->
        <xsl:variable name="this-namespace" select="namespace-uri(.)"/>
        <xsl:variable name="parent-namespace" select="namespace-uri(..)"/>
        <xsl:variable name="class-attributes"
            select="@*[name(.) = $attributes-to-add-to-class-attribute]"/>
        <xsl:variable name="class-elements"
            select="*[name(.) = $elements-to-add-to-class-attribute]"/>
        <xsl:variable name="other-class-values-to-add" as="xs:string*">
            <xsl:value-of select="name(.)"/>
            <xsl:choose>
                <xsl:when test="$tables-via-css">
                    <xsl:choose>
                        <xsl:when test="@type = '#version'">
                            <xsl:value-of select="'td'"/>
                        </xsl:when>
                        <!--<xsl:when test="tan:div/@type = '#version'">
                            <!-\- this is the mark of a TAN-T-merge file <div> that has at least one leaf div, and should be formatted like a table row -\->
                            <xsl:value-of select="'tr'"/>
                        </xsl:when>-->
                        <!--<xsl:when test="tan:div/tan:div/@type = '#version'">
                            <xsl:value-of select="'table'"/>
                        </xsl:when>-->
                    </xsl:choose>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:if test="tan:div/@type = '#version'">
                        <!-- this is the mark of a TAN-T-merge file <div> that has at least one leaf div, and should be formatted like a table row -->
                        <!--<xsl:value-of select="'tr'"/>-->
                        <xsl:value-of select="'make-html-table'"/>
                    </xsl:if>
                </xsl:otherwise>
            </xsl:choose>
            <!--<xsl:value-of select="tan:cf"/>-->
            <xsl:for-each select="tan:cf, tan:see-q">
                <xsl:value-of select="concat('idref--', .)"/>
            </xsl:for-each>
            <xsl:if test="self::tan:TAN-T-merge">
                <!-- This allows TAN-T-merge output to be used by JQuery's Sortable library -->
                <xsl:value-of select="'sortable'"/>
            </xsl:if>
            <xsl:if test="not($this-namespace = $parent-namespace)">
                <xsl:value-of select="tan:namespace($this-namespace)"/>
            </xsl:if>
            <xsl:for-each select="tan:src">
                <xsl:value-of select="concat('src--', .)"/>
            </xsl:for-each>
        </xsl:variable>
        <xsl:variable name="all-class-attribute-values"
            select="$class-attributes, $class-elements, $other-class-values-to-add"/>
        <xsl:copy>
            <xsl:apply-templates select="@*" mode="#current"/>
            <xsl:if test="exists($all-class-attribute-values)">
                <xsl:attribute name="class" select="string-join($all-class-attribute-values, ' ')"/>
            </xsl:if>
            <xsl:if test="name(.) = $elements-to-be-labeled">
                <label class="label">
                    <xsl:value-of select="name(.)"/>
                </label>
            </xsl:if>
            <xsl:apply-templates select="node()" mode="#current"/>
        </xsl:copy>
    </xsl:template>


    <!-- pass 3: convert everything to html <div> -->
    
    <xsl:template match="*" mode="input-pass-3">
        <div>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates mode="#current"/>
        </div>
    </xsl:template>

    <!--<xsl:template match="/tan:TAN-T-merge" mode="input-pass-3">
        
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates mode="tan-merge-to-html-tables">
                <xsl:with-param name="src-order" select="$src-order" tunnel="yes"/>
            </xsl:apply-templates>
        </xsl:copy>
    </xsl:template>-->

    <xsl:template match="/*" mode="input-pass-3">
        <xsl:variable name="src-order" select="tan:head/tan:src"/>
        <!-- add a label to the root elements -->
        <div>
            <xsl:copy-of select="@*"/>
            <div class="label"><xsl:value-of select="name(.)"/></div>
            <xsl:apply-templates mode="#current">
                <xsl:with-param name="src-order" select="$src-order" tunnel="yes"/>
            </xsl:apply-templates>
        </div>
    </xsl:template>
    <xsl:template match="tan:head | tei:teiHeader" mode="input-pass-3">
        <!-- Some children items should be grouped and labeled, to make it easier to understand the data -->
        <div>
            <xsl:copy-of select="@*"/>
            <xsl:if test="parent::tan:TAN-T-merge">
                <xsl:attribute name="draggable" select="true()"/>
            </xsl:if>
            <xsl:apply-templates select="tan:src" mode="#current"/>
            <xsl:for-each-group select="* except tan:src" group-adjacent="name(.)">
                <xsl:variable name="this-count" select="count(current-group())"/>
                <xsl:variable name="this-suffix"
                    select="
                        if ($this-count gt 1) then
                            concat('s (', string($this-count), ')')
                        else
                            ()"/>
                <div class="group">
                    <div class="label"><xsl:value-of select="current-grouping-key()"/><xsl:value-of
                            select="$this-suffix"/></div>
                    <xsl:apply-templates select="current-group()" mode="#current"/></div>
            </xsl:for-each-group>
        </div>
    </xsl:template>
    
    <xsl:template match="tan:head/tan:src" mode="input-pass-3">
        <!-- Primarily for TAN-T-merge files, which have multiple <head>s, and can be used for filtering and reording the merged contents -->
        <div class="switch"><div class="on">☑</div><div class="off" style="display:none">☐</div></div>
        <div class="label"><xsl:value-of select="."/></div>
    </xsl:template>
    
    <xsl:template match="tan:div[tan:div[tokenize(@class, ' ') = 'td']]" mode="input-pass-3">
        <!--<xsl:param name="src-order" tunnel="yes"/>-->
        <!--<xsl:variable name="content-text" select="tan:text-join(.)"/>-->
        <xsl:variable name="content-text" select="normalize-space(tan:value-of(.))"/>
        <xsl:variable name="content-string-length" select="max((string-length($content-text), 1))"/>
        <div>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates select="* except tan:div" mode="#current"/>
            <xsl:for-each-group select="tan:div" group-adjacent="tokenize(@class, ' ') = 'td'">
                <xsl:choose>
                    <xsl:when test="current-grouping-key()">
                        <xsl:apply-templates select="current-group()" mode="#current">
                            <xsl:with-param name="context-string-length" select="$content-string-length"/>
                        </xsl:apply-templates>
                    </xsl:when>
                    <xsl:otherwise>
                        <div class="td">
                            <!-- we wrap in a div with class td, for easier CSS formatting -->
                            <xsl:apply-templates select="current-group()" mode="#current"/>
                        </div>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:for-each-group>
        </div> 
    </xsl:template>
    <xsl:template match="tan:div[tokenize(@class, ' ') = 'td']" mode="input-pass-3">
        <xsl:param name="context-string-length"/>
        <!--<xsl:variable name="this-text" select="tan:text-join(.)"/>-->
        <xsl:variable name="this-text" select="normalize-space(tan:value-of(.))"/>
        <xsl:variable name="this-text-length" select="string-length($this-text)"/>
        <div style="width: {format-number(($this-text-length div $context-string-length), '0.0%')}">
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates mode="#current"></xsl:apply-templates>
        </div>
    </xsl:template>
    
    <xsl:template match="*[tokenize(@class, ' ') = 'make-html-table']" mode="input-pass-3">
        <xsl:param name="src-order" tunnel="yes"/>
        <table>
            <caption>
                <xsl:apply-templates select="* except tan:div" mode="#current"/>
            </caption>
            <tbody>
                <xsl:variable name="these-tds-pass-1" as="element()*">
                    <xsl:for-each-group select=".//tan:div[tan:type = 'version']" group-by="tan:src">
                        <xsl:sort select="index-of($src-order, current-grouping-key())"/>
                        <group class="{current-grouping-key()}">
                            <xsl:for-each select="current-group()">
                                <td pos="{position()}">
                                    <xsl:apply-templates mode="#current"/>
                                </td>
                            </xsl:for-each>
                        </group>
                    </xsl:for-each-group>
                </xsl:variable>
                <xsl:variable name="max-leaf-divs"
                    select="
                        max((for $i in $these-tds-pass-1
                        return
                            count($i/*)))"/>
                <xsl:variable name="these-tds-pass-2" as="element()*">
                    <xsl:for-each select="$these-tds-pass-1">
                        <xsl:variable name="this-group" select="."/>
                        <xsl:variable name="number-of-tds" select="count(*)"/>
                        <xsl:copy>
                            <xsl:copy-of select="@*"/>
                            <xsl:for-each select="1 to $max-leaf-divs">
                                <xsl:variable name="this-ratio" select=". div $max-leaf-divs"/>
                                <xsl:variable name="this-position"
                                    select="max((round(($number-of-tds * $this-ratio)), 1))"/>
                                <xsl:variable name="this-td"
                                    select="$this-group/*[position() = $this-position]"/>
                                <td max-pos="{.}">
                                    <xsl:copy-of select="$this-td/@*"/>
                                    <xsl:copy-of select="$this-td/node()"/>
                                </td>
                            </xsl:for-each>
                        </xsl:copy>
                    </xsl:for-each>
                </xsl:variable>
                <xsl:variable name="these-tds-pass-3" as="element()*">
                    <xsl:for-each select="$these-tds-pass-2">
                        <xsl:copy>
                            <xsl:copy-of select="@*"/>
                            <xsl:for-each-group select="*" group-adjacent="@pos">
                                <td rowspan="{count(current-group())}">
                                    <xsl:copy-of select="current-group()[1]/(@* except @pos)"/>
                                    <xsl:copy-of select="current-group()[1]/node()"/>
                                </td>
                            </xsl:for-each-group>
                        </xsl:copy>
                    </xsl:for-each>
                </xsl:variable>
                <xsl:for-each select="1 to $max-leaf-divs">
                    <xsl:variable name="this-max-pos" select="."/>
                    <tr>
                        <xsl:copy-of
                            select="tan:copy-of-except($these-tds-pass-3/*[@max-pos = $this-max-pos], (), 'max-pos', ())"
                        />
                    </tr>
                </xsl:for-each>
                <!--<test13a><xsl:copy-of select="$these-tds-pass-1"/></test13a>-->
                <!--<test13b><xsl:copy-of select="$these-tds-pass-2"/></test13b>-->
                <!--<test13c><xsl:copy-of select="$these-tds-pass-3"/></test13c>-->
            </tbody>
        </table>
    </xsl:template>
    <!--<xsl:template match="tan:div[@type = '#version']" mode="input-pass-3">
        <td>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates mode="#current"/>
        </td>
    </xsl:template>-->
    <xsl:template match="tan:ref | tan:div/tan:n" mode="input-pass-3">
        <div>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates mode="#current"/>
        </div>
        <xsl:apply-templates select="tan:orig-ref, tan:orig-n" mode="#current"/>
        <!--<!-\- remove duplicate refs and ns -\->
        <xsl:if
            test="
                every $i in preceding-sibling::*
                    satisfies not(deep-equal(., $i))">
            <div>
                <xsl:copy-of select="@*"/>
                <xsl:apply-templates mode="#current"/>
            </div>
            <!-\- In many HTML pages, we want in the version node to suppress a reference, but not its original reference -\->
            <xsl:apply-templates select="tan:orig-ref" mode="#current"/>
        </xsl:if>-->
    </xsl:template>

</xsl:stylesheet>
