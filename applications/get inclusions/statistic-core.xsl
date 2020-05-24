<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns="tag:textalign.net,2015:ns"
    xmlns:html="http://www.w3.org/1999/xhtml"
    xmlns:math="http://www.w3.org/2005/xpath-functions/math"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:tan="tag:textalign.net,2015:ns" exclude-result-prefixes="#all" version="2.0">
    
    <!-- This stylesheet is the core to various statistical analyses. It was written primarily to support 
        stylesheets in the /applications/analyze folder.
    -->
    
    <xsl:import href="../display/display%20TAN%20as%20HTML.xsl"/>
    


    <xsl:param name="validation-phase" select="'terse'"/>
    <xsl:param name="group-sources-by-work" as="xs:boolean" select="false()"/>
    
    <xsl:param name="stop-after-level" as="xs:integer?" select="4"/>
    <xsl:param name="only-first-work" as="xs:boolean" select="false()"/>
    
    <!-- Upon what basis should a datum be calculated? -->
    <xsl:param name="basis-of-datum" as="xs:string" select="'token count'"/>
    
    <!-- How should the top of the HTML page be rendered? -->
    <xsl:param name="html-preamble" as="element()*">
        <h1 xmlns="http://www.w3.org/1999/xhtml">Statistical Analysis of TAN files</h1>
        <div xmlns="http://www.w3.org/1999/xhtml">For more on the TAN XML format, see <a href="http://textalign.net">textalign.net</a></div>
    </xsl:param>
    
    <!-- how should the columns be labeled? -->
    <xsl:param name="column-label-1" as="xs:string?">tokens </xsl:param>

    <!-- how should resultant data be formatted? -->
    <xsl:param name="datum-format-picture" as="xs:string">0.00</xsl:param>
    <!-- how should percentages be formatted? -->
    <xsl:param name="percentage-format-picture" as="xs:string">0.0%</xsl:param>
    
    <!-- INPUT -->
    <xsl:param name="input-items"
        select="
            $self-expanded[position() gt 1][if ($only-first-work) then
                */@work = '1'
            else
                true()]"
        as="document-node()*"/>

    <!-- Pass 1: tokenize the sources -->
    <xsl:template match="document-node()" mode="input-pass-1">
        <xsl:variable name="this-src-id" select="*/@src"/>
        <xsl:variable name="this-token-definition" select="$self-expanded[1]/*/tan:head/tan:token-definition[tan:src = $this-src-id]"/>
        <xsl:apply-templates select="." mode="tokenize-div">
            <xsl:with-param name="token-definition" tunnel="yes" select="$this-token-definition"/>
            <xsl:with-param name="add-q-attr" select="true()" tunnel="yes"/>
            <xsl:with-param name="add-pos-attr" select="true()" tunnel="yes"/>
        </xsl:apply-templates>
    </xsl:template>
    <xsl:template match="processing-instruction()" mode="tokenize-div"/>

    <!-- A pass 1b, 1c, etc. might be necessary before going to pass 2. In that case, use something
        like the following in any master xslt that includes this one:
        <xsl:param name="input-pass-2" as="item()*"
      select="tan:build-intermediate-step($input-pass-1b, $uris-input-pass-2, 'input pass 2')"/>
    -->

    <!-- Pass 2: get statistics -->
    <xsl:function name="tan:get-tok-data" as="xs:double*">
        <!-- Input: an element -->
        <!-- Output: a series of data points, depending upon the value of $basis of datum -->
        <xsl:param name="element-to-query" as="element()"/>
        <xsl:variable name="token-holders" select="$element-to-query/descendant-or-self::tan:div[tan:tok]"/>
        <xsl:choose>
            <xsl:when test="$basis-of-datum = 'token count'">
                <xsl:copy-of
                    select="
                        for $i in $token-holders
                        return
                            count($i/tan:tok)"
                />
            </xsl:when>
            <xsl:when test="$basis-of-datum = 'distinct tokens per token count'">
                <xsl:variable name="distinct-token-count" select="count(distinct-values($token-holders/tan:tok))"/>
                <!-- normalize token holder count to avoid dividing by zero -->
                <xsl:variable name="token-count"
                    select="
                        if (not(exists($token-holders))) then
                            0.00000000000000001
                        else
                            count($token-holders/tan:tok)"
                />
                <xsl:copy-of
                    select="($distinct-token-count div $token-count) * 100"
                />
            </xsl:when>
            <xsl:otherwise>
                <xsl:message select="'No data calculation has been programmed for $basis-of-datum: ', $basis-of-datum"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    <xsl:template match="tan:body | tan:div" mode="input-pass-2">
        <xsl:variable name="this-src" select="root()/tan:TAN-T/@src"/>
        <xsl:variable name="is-leaf-div" select="not(exists(tan:div))"/>
        <xsl:variable name="this-level" select="count(ancestor-or-self::tan:div) + 1"/>
        <xsl:variable name="data-points" as="xs:double*" select="tan:get-tok-data(.)"/>
        <xsl:variable name="data-stats" select="tan:analyze-stats($data-points)" as="element()"/>
        <xsl:variable name="diagnostics-on" select="false()"/>
        <xsl:if test="$diagnostics-on">
            <xsl:message select="'diagnostics on for template mode: input-pass-2'"/>
            <xsl:message select="'this element:', tan:shallow-copy(.)"/>
            <xsl:message select="'this src id: ', string($this-src)"/>
            <xsl:message select="'this level: ', $this-level"/>
            <xsl:message select="'data points: ', $data-points"/>
            <xsl:message select="'data stats: ', $data-stats"/>
        </xsl:if>
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:if test="$this-level le $stop-after-level">
                <xsl:for-each select="$data-stats">
                    <xsl:copy>
                        <xsl:copy-of select="@*"/>
                        <src>
                            <xsl:value-of select="$this-src"/>
                        </src>
                        <xsl:copy-of select="node()"/>
                    </xsl:copy>
                </xsl:for-each>
            </xsl:if>
            <xsl:apply-templates mode="#current"/>
        </xsl:copy>
    </xsl:template>

    <!-- Pass 3: group sources into works and merge them -->
    <xsl:variable name="input-pass-3" as="document-node()*">
        <xsl:for-each-group select="$input-pass-2"
            group-by="
                if ($group-sources-by-work) then
                    */@work
                else
                    true()">
            <xsl:copy-of select="tan:merge-expanded-docs(current-group())"/>
        </xsl:for-each-group>
    </xsl:variable>

    <!-- Pass 3b: consolidate and expand the statistics -->
    <xsl:variable name="input-pass-3b" as="document-node()*">
        <xsl:apply-templates select="$input-pass-3" mode="compare-stats"/>
    </xsl:variable>
    <!-- clean up white space -->
    <xsl:template match="text()" mode="compare-stats">
        <xsl:value-of select="normalize-space(.)"/>
    </xsl:template>
    <!-- We omit stats that have been generated purely on the version level -->
    <xsl:template match="tan:div[@type = '#version']" mode="compare-stats" priority="1"/>
    
    <xsl:template match="*[tan:stats]" mode="compare-stats">
        <!-- Sometimes a non-leaf div is broken up, so its statistics are as well. We need to synthesize the results. -->
        <xsl:variable name="stats-grouped" as="element()+">
            <xsl:for-each-group select="tan:stats" group-by="tan:src">
                <xsl:choose>
                    <xsl:when test="count(current-group()) gt 1">
                        <xsl:for-each select="tan:merge-analyzed-stats(current-group(), true())">
                            <xsl:copy>
                                <xsl:copy-of select="@*"/>
                                <xsl:copy-of select="current-group()[1]/tan:src"/>
                                <xsl:copy-of select="node()"/>
                            </xsl:copy>
                        </xsl:for-each>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:copy-of select="current-group()"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:for-each-group>
        </xsl:variable> 
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <!-- Don't bother doing anything with stats if there aren't two or more stats to compare to each other -->
            <xsl:if test="count($stats-grouped) gt 1">
                <xsl:copy-of select="$stats-grouped[1]"/>
                <xsl:for-each select="$stats-grouped[position() gt 1]">
                    <xsl:copy-of select="."/>
                    <xsl:variable name="this-src" select="tan:src"/>
                    <xsl:for-each select="tan:merge-analyzed-stats(($stats-grouped[1], .), false())">
                        <stats-diff>
                            <xsl:copy-of select="@*"/>
                            <xsl:copy-of select="$this-src"/>
                            <xsl:copy-of select="node()"/>
                        </stats-diff>
                    </xsl:for-each>
                </xsl:for-each>
            </xsl:if> 
            <xsl:apply-templates select="* except tan:stats" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    

    <!-- Pass 4: convert to html -->
    <xsl:param name="input-pass-4" select="tan:tan-to-html($input-pass-3b)" as="document-node()*"/>
    <xsl:template match="@diff" mode="tan-to-html-pass-1">
        <xsl:copy/>
    </xsl:template>
    <xsl:template match="tan:TAN-T-merge" mode="tan-to-html-pass-2">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <h2 xmlns="http://www.w3.org/1999/xhtml">
                <xsl:value-of select="tan:head[1]//tan:work/tan:name[1]"/>
            </h2>
            <xsl:apply-templates mode="#current"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="tan:body" mode="tan-to-html-pass-2">
        <div xmlns="http://www.w3.org/1999/xhtml" class="filter">Filter
            <input class="search" type="search" data-column="all"/>
        </div>
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:for-each-group select=".//(tan:stats, tan:stats-diff)"
                group-by="count(ancestor::tan:div)">
                <xsl:variable name="stats-for-table" select="current-group()"/>
                <xsl:variable name="these-srcs" as="xs:string+">
                    <xsl:for-each  select="distinct-values(current-group()/tan:src)">
                        <xsl:sort select="index-of($src-ids, .)"/>
                        <xsl:value-of select="."/>
                    </xsl:for-each>
                </xsl:variable>
                <xsl:variable name="stats-of-stats-diff" as="element()*">
                    <xsl:for-each select="$these-srcs[position() gt 1]">
                        <xsl:variable name="this-src" select="."/>
                        <xsl:variable name="these-stats-for-table" select="$stats-for-table[self::tan:stats-diff][tan:src = $this-src]"/>
                        <xsl:if test="count($these-stats-for-table) gt 1">
                            <xsl:variable name="these-stats-analyzed"
                                select="tan:analyze-stats($these-stats-for-table/tan:sum/@diff)"
                                as="element()?"/>
                            <xsl:variable name="these-stats-without-outliers-analyzed"
                                select="tan:add-attribute(tan:analyze-stats(tan:no-outliers($these-stats-for-table/tan:sum/@diff)), 'no-outliers', '')"
                            />
                            <xsl:for-each select="$these-stats-analyzed, $these-stats-without-outliers-analyzed">
                                <xsl:copy>
                                    <xsl:copy-of select="@*"/>
                                    <src>
                                        <xsl:value-of select="$this-src"/>
                                    </src>
                                    <xsl:copy-of select="node()"/>
                                </xsl:copy>
                            </xsl:for-each>
                        </xsl:if>
                    </xsl:for-each>
                </xsl:variable>
                <hr xmlns="http://www.w3.org/1999/xhtml"/>
                <h3 xmlns="http://www.w3.org/1999/xhtml">Level <xsl:value-of select="current-grouping-key() + 1"/></h3>
                <table class="tablesorter" xmlns="http://www.w3.org/1999/xhtml">
                    <thead>
                        <tr>
                            <td class="ref">ref</td>
                            <xsl:for-each select="$these-srcs">
                                <xsl:variable name="this-src" select="."/>
                                <xsl:variable name="this-attr-class" as="element()">
                                    <attr class="src--{$this-src} src--{position()}"/>
                                </xsl:variable>
                                <xsl:apply-templates
                                    select="$stats-for-table[tan:src = $this-src][self::tan:stats][1]"
                                    mode="stat-head">
                                    <xsl:with-param name="attr-to-add" select="$this-attr-class" tunnel="yes"/>
                                </xsl:apply-templates>
                                <xsl:apply-templates
                                    select="$stats-for-table[tan:src = $this-src][self::tan:stats-diff][1]"
                                    mode="stat-head">
                                    <xsl:with-param name="attr-to-add" select="$this-attr-class" tunnel="yes"/>
                                </xsl:apply-templates>
                            </xsl:for-each>
                        </tr>
                    </thead>
                    <tbody>
                        <xsl:for-each-group select="current-group()"
                            group-by="
                                if (exists(parent::tan:div/tan:ref)) then
                                    parent::tan:div/tan:ref[1]/text()
                                else
                                    'all'">
                            <xsl:variable name="stats-for-row" select="current-group()"/>
                            <tr>
                                <td class="ref">
                                    <xsl:value-of select="current-grouping-key()"/>
                                </td>
                                <xsl:for-each select="$these-srcs">
                                    <xsl:variable name="this-src" select="."/>
                                    <xsl:variable name="this-pos" select="position()"/>
                                    <xsl:variable name="this-cluster"
                                        select="$stats-for-row[tan:src = $this-src]"/>
                                    <xsl:apply-templates select="$this-cluster" mode="stat-body">
                                        <xsl:with-param name="stats-of-stats-diff" select="$stats-of-stats-diff[not(@no-outliers)]" tunnel="yes"/>
                                    </xsl:apply-templates>
                                    <!-- Defective <div>s need to have empty cells filled out for them; the choose-when below does so -->
                                    <xsl:choose>
                                        <xsl:when test="$this-pos = 1">
                                            <xsl:if test="not(exists($this-cluster))">
                                                <xsl:for-each select="1 to 1">
                                                    <td>
                                                        <xsl:copy-of select="$stats-for-table[tan:src = $this-src][1]/@*"/>
                                                    </td>
                                                </xsl:for-each>
                                            </xsl:if>
                                        </xsl:when>
                                        <xsl:otherwise>
                                            <xsl:if test="not(exists($this-cluster/self::tan:stats))">
                                                <xsl:for-each select="1 to 1">
                                                    <td>
                                                        <xsl:copy-of select="$stats-for-table[tan:src = $this-src][self::tan:stats][1]/@*"/>
                                                    </td>
                                                </xsl:for-each>
                                            </xsl:if>
                                            <xsl:if test="not(exists($this-cluster/self::tan:stats-diff))">
                                                <xsl:for-each select="1 to 2">
                                                    <td>
                                                        <xsl:copy-of select="$stats-for-table[tan:src = $this-src][self::tan:stats-diff][1]/@*"/>
                                                    </td>
                                                </xsl:for-each>
                                            </xsl:if>
                                        </xsl:otherwise>
                                    </xsl:choose>
                                </xsl:for-each>
                            </tr>
                        </xsl:for-each-group>
                    </tbody>
                </table>
                <xsl:for-each-group select="$stats-of-stats-diff" group-by="exists(@no-outliers)">
                    <xsl:choose>
                        <xsl:when test="current-grouping-key() = false()">
                            <div xmlns="http://www.w3.org/1999/xhtml">Analysis of data relative to
                                    <xsl:value-of select="$these-srcs[1]"/></div>
                        </xsl:when>
                        <xsl:otherwise>
                            <div xmlns="http://www.w3.org/1999/xhtml">As above, but without
                                outliers</div>
                        </xsl:otherwise>
                    </xsl:choose>

                    <table class="tablesorter" xmlns="http://www.w3.org/1999/xhtml">
                        <thead>
                            <tr>
                                <xsl:apply-templates select="current-group()[1]" mode="stat-diff-head"/>
                            </tr>
                        </thead>
                        <tbody>
                            <xsl:apply-templates select="current-group()" mode="stat-diff-body">
                                <xsl:with-param name="src-order" select="$these-srcs"/>
                            </xsl:apply-templates>
                        </tbody>
                    </table>
                </xsl:for-each-group>
            </xsl:for-each-group>
        </xsl:copy>
    </xsl:template>
    <!-- add 'label' class to the src ids -->
    <xsl:template match="tan:src[@class = 'src']" mode="tan-to-html-pass-2">
        <xsl:copy>
            <xsl:attribute name="class" select="string-join((@class, 'label'), ' ')"/>
            <xsl:apply-templates mode="#current"/>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="*" mode="stat-head stat-body stat-diff-head stat-diff-body">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>
    <xsl:template match="tan:d | tan:src | tan:count | tan:avg | tan:max | tan:min | tan:var | tan:std" mode="stat-head stat-body"/>
    <xsl:template match="tan:sum[not(@diff)]" mode="stat-head">
        <xsl:param name="attr-to-add" tunnel="yes" as="element()*"/>
        <td xmlns="http://www.w3.org/1999/xhtml">
            <!--<xsl:copy-of select="parent::*/@*"/>-->
            <xsl:copy-of select="$attr-to-add/@*"/>
            <xsl:value-of select="$column-label-1"/>
            <xsl:value-of select="../tan:src"/>
        </td>
    </xsl:template>
    <xsl:template match="tan:sum[@diff]" mode="stat-head">
        <xsl:param name="attr-to-add" tunnel="yes" as="element()*"/>
        <td xmlns="http://www.w3.org/1999/xhtml">
            <xsl:copy-of select="parent::*/@*"/>
            <xsl:copy-of select="$attr-to-add/@*"/>
            <xsl:text>±</xsl:text>
        </td>
        <td xmlns="http://www.w3.org/1999/xhtml">
            <xsl:copy-of select="parent::*/@*"/>
            <xsl:copy-of select="$attr-to-add/@*"/>
            <xsl:text>(%)</xsl:text>
        </td>
    </xsl:template>
    
    <xsl:template match="tan:sum" mode="stat-body">
        <xsl:param name="stats-of-stats-diff" tunnel="yes"/>
        <td xmlns="http://www.w3.org/1999/xhtml">
            <xsl:copy-of select="parent::*/@*"/>
            <xsl:choose>
                <xsl:when test=". castable as xs:double">
                    <xsl:value-of select="format-number(., $datum-format-picture)"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="."/>
                </xsl:otherwise>
            </xsl:choose>
        </td>
        <xsl:if test="exists(@diff)">
            <xsl:variable name="this-src" select="../tan:src"/>
            <xsl:variable name="this-val" select="@diff"/>
            <xsl:variable name="this-stat-context" select="$stats-of-stats-diff[tan:src = $this-src]"/>
            <xsl:variable name="this-d" select="$this-stat-context/tan:d[. = $this-val][1]"/>
            <xsl:variable name="this-dev" select="$this-d/@dev"/>
            <xsl:variable name="max-dev" select="$this-stat-context/tan:d[@max][1]/@dev"/>
            <xsl:variable name="this-ratio" select="$this-dev div $max-dev"/>
            <xsl:variable name="is-above-avg" select="number($this-d) gt number($this-stat-context/tan:avg)"/>
            <xsl:variable name="this-color"
                select="
                    if ($is-above-avg) then
                        'green'
                    else
                        'red'"
            />
            <xsl:variable name="this-percent" select="format-number($this-ratio, $percentage-format-picture)"/>
            <td xmlns="http://www.w3.org/1999/xhtml"
                style="background-image:linear-gradient(to right, {$this-color}, rgba(255, 255, 255, 0) {$this-percent})">
                <xsl:copy-of select="parent::*/@*"/>
                <xsl:value-of select="format-number(@diff, $percentage-format-picture)"/>
            </td>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="tan:d | tan:sum" mode="stat-diff-head stat-diff-body"/>
    
    <xsl:template match="tan:src | tan:count | tan:avg | tan:max | tan:min | tan:var | tan:std" mode="stat-diff-head">
        <xsl:variable name="this-name" select="name(.)"/>
        <td xmlns="http://www.w3.org/1999/xhtml">
            <xsl:choose>
                <xsl:when test="$this-name = 'count'">divs in common</xsl:when>
                <xsl:when test="$this-name = 'avg'">avg % ± <xsl:value-of select="$column-label-1"/></xsl:when>
                <xsl:when test="$this-name = 'max'">greatest increase</xsl:when>
                <xsl:when test="$this-name = 'min'">greatest decrease</xsl:when>
                <xsl:when test="$this-name = 'var'">variance</xsl:when>
                <xsl:when test="$this-name = 'std'">standard deviation</xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="$this-name"/>
                </xsl:otherwise>
            </xsl:choose>
        </td>
    </xsl:template>
    
    <xsl:template match="tan:stats" mode="stat-diff-body">
        <xsl:param name="src-order"/>
        <tr xmlns="http://www.w3.org/1999/xhtml"
            class="src--{tan:src} src--{index-of($src-order, tan:src)}">
            <xsl:apply-templates mode="#current"/>
        </tr>
    </xsl:template>
    
    <xsl:template match="tan:src | tan:count" mode="stat-diff-body">
        <td xmlns="http://www.w3.org/1999/xhtml">
            <xsl:value-of select="."/>
        </td>
    </xsl:template>
    <xsl:template match="tan:avg | tan:max | tan:min" mode="stat-diff-body">
        <td xmlns="http://www.w3.org/1999/xhtml">
            <xsl:choose>
                <xsl:when test=". castable as xs:double">
                    <xsl:value-of select="format-number(., $percentage-format-picture)"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="."/>
                </xsl:otherwise>
            </xsl:choose>
        </td>
    </xsl:template>
    <xsl:template match="tan:var | tan:std" mode="stat-diff-body">
        <td xmlns="http://www.w3.org/1999/xhtml">
            <xsl:choose>
                <xsl:when test=". castable as xs:double">
                    <xsl:value-of select="format-number(., $datum-format-picture)"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="."/>
                </xsl:otherwise>
            </xsl:choose>
        </td>
    </xsl:template>


    <!-- TEMPLATE -->

    <xsl:template match="html:body" mode="revise-infused-template">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:copy-of select="$html-preamble"/>
            <xsl:apply-templates mode="#current"/>
        </xsl:copy>
    </xsl:template>

    <!-- OUTPUT -->
    <xsl:param name="output-filename" select="concat(tan:cfne(/), '-analysis-', $today-iso, '.html')"/>
    <!--<xsl:variable name="output-dir-uri" select="resolve-uri('../../../output/', static-base-uri())"/>-->
    <!--<xsl:param name="output-url-relative-to-actual-input" as="xs:string?"
        select="concat($output-dir-uri, 'html/', tan:cfn(/), '-', $today-iso, '.html')"/>-->

    <!--<xsl:template match="/" priority="5">
        <!-\-<xsl:copy-of select="tan:merge-expanded-docs($self-expanded[position() gt 1])"/>-\->
        <!-\-<xsl:copy-of select="$sources-resolved[2]"/>-\->
        <!-\-<xsl:copy-of select="$self-resolved"/>-\->
        <!-\-<xsl:copy-of select="$self-expanded"/>-\->
        <xsl:copy-of select="$input-items"/>
        <!-\-<xsl:copy-of select="$input-pass-1"/>-\->
        <!-\-<xsl:copy-of select="$input-pass-2"/>-\->
        <!-\-<xsl:copy-of select="$input-pass-3"/>-\->
        <!-\-<xsl:copy-of select="$input-pass-3b"/>-\->
        <!-\-<xsl:copy-of select="$input-pass-4"/>-\->
        <!-\-<xsl:copy-of select="$template-infused-with-revised-input"/>-\->
        <!-\-<xsl:copy-of select="$infused-template-revised"/>-\->
    </xsl:template>-->


</xsl:stylesheet>
