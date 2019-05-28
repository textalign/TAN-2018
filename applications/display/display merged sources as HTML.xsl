<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns="http://www.w3.org/1999/xhtml" xmlns:html="http://www.w3.org/1999/xhtml"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:tan="tag:textalign.net,2015:ns" exclude-result-prefixes="#all" version="2.0">
    <xsl:import href="display%20TAN%20as%20HTML.xsl"/>
    <!--<xsl:output method="html" indent="yes"/>-->
    <xsl:output method="html" indent="no"/>
    <xsl:param name="validation-phase" select="'terse'"/>
    <!--<xsl:param name="input-items" select="tan:merge-expanded-docs($self-expanded[position() gt 1])"/>-->
    <!--<xsl:param name="input-items" select="$sources-resolved"/>-->
    <xsl:param name="input-items" select="$self-expanded"/>

    <!-- Parameters for input pass 1 -->
    <xsl:param name="src-ids-must-match-regex" as="xs:string?"><!--grc|eng-1934--></xsl:param>
    <xsl:param name="src-or-alias-ids-must-not-match-regex" as="xs:string?">-eng$</xsl:param>
    <xsl:param name="main-langs-must-match-regex" as="xs:string?"/>
    <xsl:param name="main-langs-must-not-match-regex" as="xs:string?"/>
    <!-- For the following parameters, you may find the process more efficient if you code them at <adjustments> in the class 2 file -->
    <xsl:param name="div-types-must-match-regex" as="xs:string?"/>
    <xsl:param name="div-types-must-not-match-regex" as="xs:string?"/>
    <xsl:param name="level-1-div-ns-must-match-regex" as="xs:string?"
        ><!--^(3|90|112)$--></xsl:param>
    <xsl:param name="level-1-div-ns-must-not-match-regex" as="xs:string?"/>
    <xsl:param name="leaf-div-refs-must-match-regex" as="xs:string?"/>
    <xsl:param name="leaf-div-refs-must-not-match-regex" as="xs:string?"
        ><!--^3 ([1-36-9]|4[01]|5[89])--></xsl:param>
    <xsl:param name="leaf-div-must-have-at-least-how-many-versions" as="xs:integer?" select="()"/>

    <xsl:param name="suppress-adjustment-actions" select="true()"/>
    <xsl:param name="tei-should-be-plain-text" as="xs:boolean" select="false()"/>
    <xsl:param name="marker-for-tei-app-without-lem" as="xs:string?">+</xsl:param>
    <xsl:param name="tei-note-signal-default" as="xs:string?">n</xsl:param>
    <xsl:param name="tei-add-signal-default" as="xs:string?">+</xsl:param>

    <!-- Parameters for input pass 3 (i.e., after merging) -->
    <xsl:param name="levels-to-convert-to-aaa" as="xs:integer*" select="()"/>
    <xsl:param name="suppress-refs" as="xs:boolean?" select="true()"/>
    <xsl:param name="add-display-n" as="xs:boolean" select="true()"/>
    <xsl:param name="fill-defective-merges" select="true()"/>
    <xsl:param name="version-wrapper-class-name" select="'version-wrapper'"/>
    <xsl:param name="sort-and-group-by-what-alias" as="xs:string*" select="('cpg_4425')"/>

    <xsl:variable name="alias-based-group-and-sort-pattern" as="element()?">
        <xsl:apply-templates select="$head/tan:vocabulary-key"
            mode="build-source-group-and-sort-pattern">
            <xsl:with-param name="idrefs-to-process" select="$sort-and-group-by-what-alias"/>
        </xsl:apply-templates>
    </xsl:variable>

    <xsl:variable name="valid-src-ids"
        select="$src-ids[tan:satisfies-regexes(., $src-ids-must-match-regex, $src-or-alias-ids-must-not-match-regex)]"/>

    <xsl:variable name="source-group-and-sort-pattern" as="element()*">
        <!-- This variable creates a master pattern that will be used to group and sort table columns -->
        <group xmlns="tag:textalign.net,2015:ns">
            <xsl:apply-templates select="$alias-based-group-and-sort-pattern"
                mode="build-source-group-and-sort-pattern"/>
            <xsl:for-each
                select="$valid-src-ids[not(. = $alias-based-group-and-sort-pattern//tan:idref)]">
                <idref>
                    <xsl:value-of select="."/>
                </idref>
            </xsl:for-each>
        </group>
    </xsl:variable>

    <!--<xsl:variable name="source-group-and-sort-pattern" as="element()?">
        <!-\- This variable consists of a perhaps deep hierarchy of <group> + <alias> and <idref>s or a flat hierarchy of <head> with children <source> -\->
        <xsl:choose>
            <xsl:when test="string-length($sort-and-group-by-what-alias) gt 0">
                <!-\- If an <alias> id has been chosen, build a hierarchy and sort order from that -\->
                <xsl:apply-templates select="$head/tan:vocabulary-key" mode="build-source-group-and-sort-pattern">
                    <xsl:with-param name="idrefs-to-process" select="$sort-and-group-by-what-alias"
                    />
                </xsl:apply-templates>
            </xsl:when>
            <xsl:otherwise>
                <!-\- Otherwise, use the <head>'s flat list of <sources> -\->
                <xsl:apply-templates select="$head" mode="build-source-group-and-sort-pattern"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>-->
    <xsl:variable name="alias-ids" select="$source-group-and-sort-pattern//tan:alias"/>

    <xsl:template match="tan:vocabulary-key" mode="build-source-group-and-sort-pattern">
        <!-- This template turns the <alias>es in a <vocabulary-key> into a structured hierarchy consisting of <group> + <alias> and <idref> -->
        <xsl:param name="idrefs-to-process" as="xs:string*"/>
        <xsl:param name="idrefs-already-processed" as="xs:string*"/>
        <xsl:variable name="this-element" select="."/>
        <xsl:variable name="these-aliases" select="tan:alias"/>
        <xsl:for-each select="$idrefs-to-process">
            <xsl:variable name="this-idref" select="."/>
            <xsl:variable name="next-alias" select="$these-aliases[@xml:id = $this-idref][1]"/>
            <xsl:variable name="next-idrefs"
                select="tokenize(normalize-space($next-alias/@idrefs), ' ')"/>
            <xsl:choose>
                <xsl:when test="not(exists($next-alias)) and $this-idref = $valid-src-ids">
                    <idref xmlns="tag:textalign.net,2015:ns">
                        <xsl:value-of select="."/>
                    </idref>
                </xsl:when>
                <xsl:when test="not(exists($next-alias))"/>
                <xsl:when test="exists($next-idrefs)">
                    <group xmlns="tag:textalign.net,2015:ns">
                        <alias>
                            <xsl:value-of select="$this-idref"/>
                        </alias>
                        <xsl:apply-templates select="$this-element" mode="#current">
                            <xsl:with-param name="idrefs-to-process" select="$next-idrefs"/>
                            <xsl:with-param name="idrefs-already-processed"
                                select="$idrefs-already-processed, $this-idref"/>
                        </xsl:apply-templates>
                    </group>
                </xsl:when>
            </xsl:choose>
        </xsl:for-each>
    </xsl:template>
    <!-- Deeply skip groups that have no idrefs -->
    <xsl:template match="tan:group[not(descendant::tan:idref)]"
        mode="build-source-group-and-sort-pattern"/>

    <!--<xsl:template match="tan:head" mode="build-source-group-and-sort-pattern">
        <group xmlns="tag:textalign.net,2015:ns">
            <xsl:apply-templates select="tan:source" mode="#current"/>
        </group>
    </xsl:template>-->
    <!--<xsl:template match="tan:source" mode="build-source-group-and-sort-pattern">
        <xsl:if
            test="tan:satisfies-regexes(@xml:id, $src-ids-must-match-regex, $src-or-alias-ids-must-not-match-regex)">
            <idref xmlns="tag:textalign.net,2015:ns">
                <xsl:value-of select="@xml:id"/>
            </idref>
        </xsl:if>
    </xsl:template>-->


    <!-- Parameters for input pass 4 -->
    <!-- Changes in the second pass of tan:tan-to-html() -->
    <xsl:param name="add-bibliography" select="true()"/>
    <xsl:param name="tables-via-css" as="xs:boolean" select="false()"/>
    <xsl:param name="table-layout-fixed" as="xs:boolean" select="true()"/>

    <!-- Post-infusion changes -->
    <xsl:param name="td-widths-proportionate-to-td-count" as="xs:boolean" select="false()"/>
    <xsl:param name="td-widths-proportionate-to-string-length" as="xs:boolean" select="false()"/>


    <!-- SPECIAL FUNCTIONS -->

    <xsl:function name="tan:satisfies-regexes" as="xs:boolean">
        <!-- Input: a string value; an optional regex the string must match; an optional regex the string must not match -->
        <!-- Output: whether the string satisfies the two regex conditions; if either regex is empty, true will be returned -->
        <!-- If the input string is less than zero length, the function returns false -->
        <xsl:param name="string-to-test" as="xs:string?"/>
        <xsl:param name="string-must-match-regex" as="xs:string?"/>
        <xsl:param name="string-must-not-match-regex" as="xs:string?"/>
        <xsl:variable name="test-1" as="xs:boolean">
            <xsl:choose>
                <xsl:when test="string-length($string-to-test) lt 1">
                    <xsl:value-of select="false()"/>
                </xsl:when>
                <xsl:when
                    test="not(exists($string-must-match-regex)) or string-length($string-must-match-regex) lt 1">
                    <xsl:value-of select="true()"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="matches($string-to-test, $string-must-match-regex)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="test-2" as="xs:boolean">
            <xsl:choose>
                <xsl:when test="string-length($string-to-test) lt 1">
                    <xsl:value-of select="false()"/>
                </xsl:when>
                <xsl:when
                    test="not(exists($string-must-not-match-regex)) or string-length($string-must-not-match-regex) lt 1">
                    <xsl:value-of select="true()"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of
                        select="not(matches($string-to-test, $string-must-not-match-regex))"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:value-of select="$test-1 and $test-2"/>
    </xsl:function>

    <!-- PASS 1 -->
    <!-- This pass is devoted to anything that needs to be dealt with before merging: filtering out 
        content; dealing with TEI; making the sources look like the original. If you have to filter stuff
        out you might want to consider using <adjustments> in the class 2 file.
    -->

    <xsl:template match="processing-instruction()" mode="input-pass-1"/>
    <xsl:template match="/" mode="input-pass-1">
        <xsl:variable name="diagnostics" select="false()"/>
        <xsl:variable name="this-src-id" select="*/@src"/>
        <xsl:variable name="this-lang" select="*/tan:body/@xml:lang"/>
        <xsl:variable name="src-is-ok"
            select="tan:satisfies-regexes($this-src-id, $src-ids-must-match-regex, $src-or-alias-ids-must-not-match-regex)"/>
        <xsl:variable name="lang-is-ok"
            select="tan:satisfies-regexes($this-lang, $main-langs-must-match-regex, $main-langs-must-not-match-regex)"/>
        <xsl:variable name="this-class" select="tan:class-number(.)"/>
        <xsl:if test="$diagnostics">
            <xsl:message select="'src id: ', $this-src-id"/>
            <xsl:message select="'lang: ', $this-lang"/>
            <xsl:message select="'src is ok: ', $src-is-ok"/>
            <xsl:message select="'lang is ok: ', $lang-is-ok"/>
        </xsl:if>
        <xsl:if test="$src-is-ok and $lang-is-ok and ($this-class = 1)">
            <xsl:document>
                <xsl:apply-templates mode="#current"/>
            </xsl:document>
        </xsl:if>
    </xsl:template>
    <xsl:template match="tan:source[not(*)]" mode="input-pass-1">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:copy-of
                select="tan:element-vocabulary(.)/tan:item/(tan:IRI, tan:name[not(@norm)], tan:desc)"
            />
        </xsl:copy>
    </xsl:template>
    <xsl:template match="tan:vocabulary" mode="input-pass-1">
        <xsl:comment><xsl:value-of select="concat(name(.), ' has been truncated')"/></xsl:comment>
        <xsl:text>&#xa;</xsl:text>
        <xsl:copy-of select="tan:shallow-copy(.)"/>
    </xsl:template>
    <xsl:template match="tan:skip | tan:rename | tan:equate | tan:reassign" mode="input-pass-1">
        <xsl:if test="not($suppress-adjustment-actions = true())">
            <xsl:copy>
                <xsl:copy-of select="@*"/>
                <xsl:apply-templates mode="#current"/>
            </xsl:copy>
        </xsl:if>
    </xsl:template>
    <xsl:template match="tan:body/tan:div" mode="input-pass-1">
        <xsl:variable name="diagnostics" select="false()"/>
        <xsl:variable name="these-ns" select="tan:n"/>
        <xsl:variable name="these-div-types"
            select="tan:type, tokenize(normalize-space(@type), ' ')"/>
        <xsl:variable name="ns-are-ok"
            select="
                some $i in $these-ns
                    satisfies tan:satisfies-regexes($i, $level-1-div-ns-must-match-regex, $level-1-div-ns-must-not-match-regex)"/>
        <xsl:variable name="div-types-are-ok"
            select="
                (some $i in $these-div-types
                    satisfies tan:satisfies-regexes($i, $div-types-must-match-regex, ()))
                and
                (every $j in $these-div-types
                    satisfies tan:satisfies-regexes($j, (), $div-types-must-not-match-regex))"/>
        <xsl:if test="$diagnostics">
            <xsl:message select="'ns: ', $these-ns"/>
            <xsl:message select="'div types: ', $these-div-types"/>
            <xsl:message select="'some @n is ok: ', $ns-are-ok"/>
            <xsl:message select="'some @type is ok: ', $div-types-are-ok"/>
        </xsl:if>
        <xsl:if test="$ns-are-ok and $div-types-are-ok">
            <xsl:copy>
                <xsl:copy-of select="@*"/>
                <xsl:copy-of select="ancestor-or-self::*[@xml:lang][1]/@xml:lang"/>
                <xsl:apply-templates mode="#current"/>
            </xsl:copy>
        </xsl:if>
    </xsl:template>
    <xsl:template match="tan:div" mode="input-pass-1">
        <xsl:variable name="these-div-types"
            select="tan:type, tokenize(normalize-space(@type), ' ')"/>
        <xsl:variable name="div-types-are-ok"
            select="
                (some $i in $these-div-types
                    satisfies tan:satisfies-regexes($i, $div-types-must-match-regex, ()))
                and
                (every $j in $these-div-types
                    satisfies tan:satisfies-regexes($j, (), $div-types-must-not-match-regex))"/>
        <xsl:variable name="is-leaf" select="not(exists(tan:div))"/>
        <xsl:variable name="these-refs" select="tan:ref/text()"/>
        <xsl:variable name="refs-are-ok"
            select="
                if ($is-leaf) then
                    (some $i in $these-refs
                        satisfies tan:satisfies-regexes($i, $leaf-div-refs-must-match-regex, ())
                        and
                        (every $j in $these-refs
                            satisfies tan:satisfies-regexes($j, (), $leaf-div-refs-must-not-match-regex)))
                else
                    true()"/>
        <xsl:if test="$div-types-are-ok and $refs-are-ok">
            <xsl:copy>
                <xsl:copy-of select="@*"/>
                <xsl:copy-of select="ancestor-or-self::*[@xml:lang][1]/@xml:lang"/>
                <xsl:apply-templates mode="#current"/>
            </xsl:copy>
        </xsl:if>
    </xsl:template>

    <xsl:template match="tan:license" mode="input-pass-1">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <!--<test09a><xsl:copy-of select="tan:element-vocabulary(.)"/></test09a>-->
            <xsl:apply-templates mode="#current"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="tei:*" mode="input-pass-1">
        <xsl:if test="not($tei-should-be-plain-text)">
            <xsl:copy>
                <xsl:copy-of select="@*"/>
                <xsl:apply-templates mode="#current"/>
            </xsl:copy>
        </xsl:if>
    </xsl:template>
    <xsl:template match="tan:div[tei:*]/text()" mode="input-pass-1">
        <xsl:if test="$tei-should-be-plain-text">
            <xsl:value-of select="."/>
        </xsl:if>
    </xsl:template>
    <xsl:template match="tei:app[not(tei:lem)]" mode="input-pass-1">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <lem xmlns="http://www.tei-c.org/ns/1.0">
                <xsl:value-of select="$marker-for-tei-app-without-lem"/>
            </lem>
            <xsl:apply-templates mode="#current"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="tei:note | tei:add" mode="input-pass-1">
        <wrapper xmlns="http://www.tei-c.org/ns/1.0">
            <signal>
                <xsl:choose>
                    <xsl:when test="name(.) = 'add'">
                        <xsl:value-of select="$tei-add-signal-default"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="$tei-note-signal-default"/>
                    </xsl:otherwise>
                </xsl:choose>
            </signal>
            <xsl:copy>
                <xsl:copy-of select="@*"/>
                <xsl:apply-templates mode="#current"/>
            </xsl:copy>
        </wrapper>
    </xsl:template>

    <!-- PASS 1b: eliminate any divs whose leaf divs have been eliminated -->
    <xsl:variable name="input-pass-1b" as="document-node()*">
        <xsl:apply-templates select="$input-pass-1" mode="delete-divs-without-leaf-divs"/>
    </xsl:variable>
    <xsl:template match="tan:div | tan:body" mode="delete-divs-without-leaf-divs">
        <xsl:variable name="divs-from-here-down" select="descendant-or-self::tan:div"/>
        <xsl:variable name="tei-marker" select="descendant::tei:*"/>
        <xsl:variable name="text-marker" select="matches(., '\S')"/>
        <xsl:variable name="is-or-has-leaf-div" select="exists($tei-marker) or exists($text-marker)"/>
        <xsl:variable name="diagnostics-on" select="false()"/>
        <xsl:if test="$diagnostics-on">
            <xsl:message select="'processing: ', tan:shallow-copy(.)"/>
            <xsl:message select="'is or has leaf div: ', $is-or-has-leaf-div"/>
            <xsl:message select="'tei marker: ', $tei-marker"/>
            <xsl:message select="'text marker: ', $text-marker"/>
        </xsl:if>
        <xsl:if test="$is-or-has-leaf-div">
            <xsl:copy>
                <xsl:copy-of select="@*"/>
                <xsl:apply-templates mode="#current"/>
            </xsl:copy>
        </xsl:if>
    </xsl:template>
    
    <!-- ad hoc changes for Chrysostom -->
    <xsl:template match="/*[@src = 'grc-mont']" mode="delete-divs-without-leaf-divs">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates mode="temp-clio-insert-pix"/>
        </xsl:copy>
    </xsl:template>
    <xsl:variable name="clio-image-dir-relative">../../../../../Google%20Drive/CLIO%20commons/Final%20versions%20of%20homily%20transcriptions/Greek%20Excerpts/</xsl:variable>
    <xsl:variable name="clio-image-dir-resolved" select="resolve-uri($clio-image-dir-relative, static-base-uri())"/>
    
    <xsl:template match="tan:div[not(tan:div)]/text()" mode="temp-clio-insert-pix">
        <xsl:variable name="this-ref" select="../tan:ref"/>
        <xsl:variable name="this-homily-number" select="$this-ref/tan:n[1]"/>
        <xsl:variable name="this-section-number" select="$this-ref/tan:n[2]"/>
        <xsl:variable name="this-subsection-number" select="$this-ref/tan:n[3]"/>
        <xsl:variable name="this-url" select="concat($clio-image-dir-resolved, 'Homily ', $this-homily-number, ' Greek/', 
            $this-homily-number, '.', $this-section-number, '/', string-join($this-ref/tan:n, '.'), '.jpg')"/>
        <!--<xsl:value-of select="$this-url"/>-->
        <a href="{$this-url}" target="_blank"><img src="{$this-url}" width="240px"/></a>
    </xsl:template>
    

    <!-- PASS 2: Merge the sources -->

    <xsl:param name="input-pass-2" select="tan:merge-expanded-docs($input-pass-1b)"/>

    <!-- PASS 3 -->
    <!-- This pass is devoted to adjusting the merge before the migration to HTML elements. The most
        important part is getting aligned sources into the proper group and sort orders.
    -->


    <!-- Grouping and sorting sources: place aligned source-specific parts of a TAN-A-merge file into a particular grouping or sort order -->
    <!-- This set of templates assumes passage of an XML fragment consisting of <group>, <alias>, and <idref> -->
    <!-- <idref> contains the idref to a source -->

    <xsl:template match="tan:group" mode="regroup-and-re-sort-heads regroup-and-re-sort-divs">
        <xsl:param name="items-to-group-and-sort" tunnel="yes" as="element()*"/>
        <xsl:variable name="these-idrefs" select=".//tan:idref"/>
        <xsl:variable name="items-that-cannot-be-interpreted"
            select="$items-to-group-and-sort[not(exists(tan:src))]"/>
        <!--<xsl:variable name="is-topmost-group" select="not(parent::tan:group)"/>-->
        <xsl:variable name="those-items-that-cannot-be-placed"
            select="$items-to-group-and-sort[not(tan:src = $these-idrefs)]"/>
        <xsl:variable name="children-that-are-not-sortable" select="tan:alias"/>
        <xsl:copy>
            <xsl:if test="exists(tan:alias)">
                <xsl:variable name="this-alias-pos" select="index-of($alias-ids, tan:alias[1])"/>
                <xsl:attribute name="class" select="concat('alias--', string($this-alias-pos))"/>
            </xsl:if>
            <xsl:choose>
                <xsl:when test="exists($children-that-are-not-sortable)">
                    <!-- Because of the dragging function that is intended, children that shouldn't be sorted should be separated from those that can -->
                    <!-- The latter should be wrapped so they aren't siblings of unsortable children; that means only source-specific material will be draggable, not the labels (aliases) -->
                    <xsl:apply-templates select="$children-that-are-not-sortable" mode="#current"/>
                    <xsl:copy>
                        <xsl:apply-templates select="* except $children-that-are-not-sortable"
                            mode="#current"/>
                        <!--<xsl:if test="$is-topmost-group">
                            <xsl:copy-of select="$those-items-that-cannot-be-placed"/>
                        </xsl:if>-->
                    </xsl:copy>
                </xsl:when>
                <xsl:otherwise>
                    <!-- If all the children are sortable, they can just be reproduced as they are -->
                    <xsl:apply-templates mode="#current"/>
                    <!--<xsl:if test="$is-topmost-group">
                        <xsl:copy-of select="$those-items-that-cannot-be-placed"/>
                    </xsl:if>-->
                </xsl:otherwise>
            </xsl:choose>
        </xsl:copy>
        <!--<xsl:if test="$is-topmost-group">
            <!-\- There may be input that doesn't fit the hierarchy that has been built; it should be placed at the end, at the top of the hierarchy -\->
            <xsl:for-each select="$items-that-cannot-be-interpreted">
                <xsl:message select="'Every item should have a tan:src; cannot interpret ', ."/>
            </xsl:for-each>
        </xsl:if>-->
    </xsl:template>
    <xsl:template match="tan:idref" mode="regroup-and-re-sort-heads">
        <xsl:param name="items-to-group-and-sort" as="element()*" tunnel="yes"/>
        <xsl:variable name="this-idref" select="."/>
        <xsl:variable name="those-items" select="$items-to-group-and-sort[tan:src = $this-idref]"/>
        <xsl:variable name="filler-element" as="element()">
            <head type="#version" class="filler" xmlns="tag:textalign.net,2015:ns">
                <src>
                    <xsl:value-of select="$this-idref"/>
                </src>
                <xsl:text> </xsl:text>
            </head>
        </xsl:variable>
        <xsl:apply-templates select="$those-items" mode="input-pass-3"/>
        <xsl:if test="not(exists($those-items))">
            <xsl:copy-of select="$filler-element"/>
        </xsl:if>
    </xsl:template>
    <xsl:template match="tan:idref" mode="regroup-and-re-sort-divs">
        <xsl:param name="items-to-group-and-sort" as="element()*" tunnel="yes"/>
        <xsl:param name="n-pattern" as="element()*" tunnel="yes"/>
        <xsl:variable name="this-idref" select="."/>
        <xsl:variable name="those-divs" select="$items-to-group-and-sort[tan:src = $this-idref]"/>
        <xsl:variable name="filler-element" as="element()">
            <div type="#version" class="filler" xmlns="tag:textalign.net,2015:ns">
                <src><xsl:value-of select="$this-idref"/></src>
                <xsl:text> </xsl:text>
            </div>
        </xsl:variable>
        <xsl:variable name="items-to-group-and-sort"
            select="
                if (exists($those-divs)) then
                    $those-divs
                else
                    $filler-element"/>

        <!-- There could easily be many <div>s for a given source, so we wrap them up (even singletons) in a <group> -->
        <group xmlns="tag:textalign.net,2015:ns">
            <src>
                <xsl:value-of select="$this-idref"/>
            </src>
            <xsl:apply-templates select="$n-pattern" mode="#current">
                <xsl:with-param name="items-to-group-and-sort" as="element()*"
                    select="$items-to-group-and-sort"/>
                <xsl:with-param name="filler-element" as="element()?" select="$filler-element"/>
            </xsl:apply-templates>
        </group>

    </xsl:template>
    <xsl:template match="tan:primary-ns | tan:n" mode="regroup-and-re-sort-divs">
        <xsl:param name="items-to-group-and-sort" as="element()*"/>
        <xsl:param name="filler-element" as="element()?"/>
        <xsl:variable name="diagnostics" select="false()"/>
        <xsl:variable name="this-src" select="$filler-element/tan:src/text()"/>
        <xsl:variable name="these-ns" select="descendant-or-self::tan:n"/>
        <xsl:variable name="those-divs" select="$items-to-group-and-sort[tan:n = $these-ns]"/>
        <xsl:variable name="divs-of-interest" select="$those-divs[tan:n[1] = $these-ns]"/>
        <xsl:variable name="first-div-of-interest" select="$divs-of-interest[1]"/>
        <xsl:variable name="divs-not-of-interest" select="$those-divs except $divs-of-interest"/>
        <xsl:variable name="divs-of-interest-consolidated"/>
        <xsl:if test="$diagnostics">
            <xsl:message select="'This src: ', $this-src"/>
            <xsl:message select="'These ns: ', $these-ns"/>
            <xsl:message select="'Those divs: ', $those-divs"/>
            <xsl:message select="'Divs of interest: ', $divs-of-interest"/>
            <xsl:message
                select="'Extra divs of interest: ', ($divs-of-interest except $first-div-of-interest)"
            />
        </xsl:if>
        <xsl:apply-templates select="$divs-of-interest[1]" mode="input-pass-3">
            <xsl:with-param name="extra-divs-of-interest"
                select="$divs-of-interest except $first-div-of-interest"/>
        </xsl:apply-templates>
        <xsl:apply-templates select="$divs-not-of-interest" mode="#current">
            <xsl:with-param name="context-ns" select="$these-ns"/>
        </xsl:apply-templates>
        <xsl:if test="not(exists($those-divs))">
            <div xmlns="tag:textalign.net,2015:ns">
                <xsl:copy-of select="$filler-element/@*"/>
                <xsl:copy-of select="$filler-element/*"/>
                <xsl:copy-of select="$these-ns"/>
                <xsl:copy-of select="$filler-element/text()"/>
            </div>
        </xsl:if>
    </xsl:template>
    <xsl:template match="tan:div" mode="regroup-and-re-sort-divs">
        <xsl:param name="context-ns" as="element()*"/>
        <!-- These are divs not of interest, because they've been marked earlier. But we take this step to calculate rowspan -->
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:attribute name="class" select="'continuation'"/>
            <xsl:copy-of select="tan:src"/>
            <xsl:copy-of select="$context-ns"/>
        </xsl:copy>
    </xsl:template>

    <!-- now start re-grouping and re-sorting -->
    <xsl:template match="tan:TAN-T-merge" mode="input-pass-3">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <!-- control mechanism -->
            <div class="control">
                <xsl:apply-templates select="$source-group-and-sort-pattern"
                    mode="regroup-and-re-sort-heads">
                    <xsl:with-param name="items-to-group-and-sort" tunnel="yes" select="tan:head"/>
                </xsl:apply-templates>
            </div>
            <xsl:apply-templates select="tan:body" mode="#current"/>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="tan:div[tan:div[@type = '#version']]" mode="input-pass-3">
        <!-- This template finds a parent of a version, then groups and re-sorts the descendant versions -->
        <!-- Such a version wrapper will wind up being table-like or table-row-like, whether that is executed as 
            an html <table> or through CSS. That decision cannot be made at this point. -->
        <!-- This element wraps one or more versions, which are sorted and grouped in the predefined order. -->
        <xsl:variable name="diagnostics" select="false()"/>
        <xsl:variable name="children-divs" select="tan:div"/>
        <xsl:variable name="sources-to-process" select="distinct-values($children-divs/tan:src)"/>
        <xsl:variable name="skip-this-div"
            select="
                exists($leaf-div-must-have-at-least-how-many-versions)
                and (count($sources-to-process) lt $leaf-div-must-have-at-least-how-many-versions)"/>
        <xsl:if test="$diagnostics">
            <xsl:message select="'This div: ', tan:shallow-copy(.)"/>
            <xsl:message select="'Sources to process: ', $sources-to-process"/>
            <xsl:message select="'Div should be skipped: ', $skip-this-div"/>
        </xsl:if>
        <xsl:if test="not($skip-this-div)">
            <xsl:variable name="ns-that-are-integers" select="tan:n[. castable as xs:integer]"/>
            <xsl:variable name="ns-that-are-strings" select="tan:n except $ns-that-are-integers"/>
            <xsl:variable name="distinct-integer-ns" as="element()*">
                <xsl:for-each-group select="$ns-that-are-integers" group-by=".">
                    <xsl:copy-of select="current-group()[1]"/>
                </xsl:for-each-group>
            </xsl:variable>
            <xsl:variable name="distinct-string-ns" as="element()*">
                <xsl:for-each-group select="$ns-that-are-strings" group-by=".">
                    <xsl:copy-of select="current-group()[1]"/>
                </xsl:for-each-group>
            </xsl:variable>
            <!--<xsl:variable name="distinct-string-ns" select="tan:distinct-items($ns-that-are-strings)"/>-->
            <xsl:variable name="rebuilt-integer-sequence"
                select="tan:integers-to-sequence($distinct-integer-ns)"/>
            <xsl:variable name="n-pattern" as="element()+">
                <!-- The idea is that a <div> or a cluster of <div>s might attract many values of @n. They will be either
                calculable as integers or not. Those that are should be treated as distinct ns. Those that are not should be
                treated as synonyms for the same <div> or cluster of <div>s. Those string-based synonyms should be
                associated with the first integer value (if any) as the primary group of <n>s. -->
                <primary-ns xmlns="tag:textalign.net,2015:ns">
                    <xsl:copy-of select="$distinct-string-ns"/>
                    <xsl:copy-of select="$distinct-integer-ns[1]"/>
                </primary-ns>
                <xsl:copy-of select="$distinct-integer-ns[position() gt 1]"/>
            </xsl:variable>
            <xsl:variable name="pre-div-elements-except-n" select="* except (tan:n, tan:div)"/>
            <xsl:if test="$diagnostics">
                <xsl:message select="$n-pattern"/>
            </xsl:if>
            <xsl:copy>
                <xsl:copy-of select="@*"/>
                <xsl:attribute name="class" select="$version-wrapper-class-name"/>
                <!-- We eliminate duplication of elements -->
                <xsl:for-each-group select="$pre-div-elements-except-n" group-by="name(.)">
                    <xsl:for-each-group select="current-group()" group-by=".">
                        <xsl:copy-of select="current-group()[1]"/>
                    </xsl:for-each-group>
                </xsl:for-each-group>
                <xsl:copy-of select="$n-pattern"/>
                <xsl:if test="not($rebuilt-integer-sequence = tan:n)">
                    <n class="rebuilt" xmlns="tag:textalign.net,2015:ns">
                        <xsl:value-of select="$rebuilt-integer-sequence"/>
                    </n>
                </xsl:if>
                <xsl:apply-templates select="$source-group-and-sort-pattern"
                    mode="regroup-and-re-sort-divs">
                    <xsl:with-param name="items-to-group-and-sort" tunnel="yes"
                        select="$children-divs"/>
                    <xsl:with-param name="n-pattern" tunnel="yes" select="$n-pattern"/>
                </xsl:apply-templates>
            </xsl:copy>
        </xsl:if>
    </xsl:template>
    <xsl:template match="tan:div" mode="input-pass-3">
        <xsl:param name="extra-divs-of-interest" as="element()*"/>
        <!-- If there are other divs of interest, they should be consolidated into a single wrapper. -->
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:choose>
                <xsl:when test="exists($extra-divs-of-interest)">
                    <xsl:attribute name="class" select="'consolidated'"/>
                    <xsl:apply-templates select="tan:*" mode="#current"/>
                    <!--<xsl:copy>
                        <xsl:copy-of select="@*"/>
                        <xsl:apply-templates select="node()" mode="#current"/>
                    </xsl:copy>-->
                    <xsl:for-each select="self::*, $extra-divs-of-interest">
                        <!-- In this method, we make sure to drop <n> and other metadata that could be misleading in the next step -->
                        <xsl:copy>
                            <xsl:copy-of select="@*"/>
                            <xsl:apply-templates select="(tan:div, text(), tei:*)" mode="#current"/>
                        </xsl:copy>
                    </xsl:for-each>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates mode="#current"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="tan:ref | tan:orig-ref" mode="input-pass-3">
        <xsl:if test="not($suppress-refs)">
            <xsl:copy>
                <xsl:copy-of select="@*"/>
                <xsl:apply-templates mode="#current"/>
            </xsl:copy>
        </xsl:if>
    </xsl:template>
    <xsl:template match="tan:n" mode="input-pass-3">
        <xsl:if test="not(exists(preceding-sibling::tan:n)) and $add-display-n">
            <display-n xmlns="tag:textalign.net,2015:ns">
                <xsl:value-of select="../(@orig-n, @n)[1]"/>
            </display-n>
        </xsl:if>
        <xsl:copy-of select="."/>
    </xsl:template>

    <xsl:template match="tan:body/text() | tan:div/text()" mode="input-pass-3">
        <xsl:value-of select="normalize-space(.)"/>
    </xsl:template>

    <xsl:template match="tan:ref/text()" mode="input-pass-3">
        <xsl:variable name="constituent-ns" select="../tan:n"/>
        <xsl:variable name="new-ns" as="xs:string*">
            <xsl:for-each select="$constituent-ns">
                <xsl:variable name="this-pos" select="position()"/>
                <xsl:variable name="this-n" select="."/>
                <xsl:choose>
                    <xsl:when
                        test="$this-pos = $levels-to-convert-to-aaa and $this-n castable as xs:integer">
                        <xsl:value-of select="tan:int-to-aaa(xs:integer($this-n))"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="."/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:for-each>
        </xsl:variable>
        <xsl:value-of select="string-join($new-ns, ' ')"/>
    </xsl:template>

    <!-- PASS 4 -->
    <!-- make adjustments in the conversion from TAN to HTML -->

    <!-- It will be a common practice to tag an html <div> according to the class types of the source id; the following functions expedite that process -->
    <xsl:function name="tan:class-val-for-src-id" as="xs:string?">
        <!-- Input: a source id -->
        <!-- Output: all relevant class values -->
        <xsl:param name="src-id" as="xs:string?"/>
        <xsl:variable name="results" as="xs:string*">
            <!--<xsl:value-of select="tan:class-val-for-alias-group($src-id)"/>-->
            <xsl:value-of select="tan:class-val-for-source($src-id)"/>
            <xsl:value-of select="tan:class-val-for-group-item-number($src-id)"/>
        </xsl:variable>
        <xsl:value-of select="string-join($results, ' ')"/>
    </xsl:function>
    <xsl:function name="tan:class-val-for-alias-group" as="xs:string?">
        <!-- Input: a source id -->
        <!-- Output: the class marking the alias name and position number -->
        <!-- If no alias can be found, nothing is returned -->
        <xsl:param name="src-id" as="xs:string?"/>
        <xsl:variable name="this-pattern-match" select="tan:get-pattern-match($src-id)"/>
        <xsl:variable name="this-alias" select="$this-pattern-match/preceding-sibling::tan:alias"/>
        <xsl:variable name="this-alias-pos" select="index-of($alias-ids, $this-alias)"/>
        <xsl:if test="exists($this-alias)">
            <xsl:value-of
                select="concat('alias--', string($this-alias-pos), ' alias--', $this-alias)"/>
        </xsl:if>
    </xsl:function>
    <xsl:function name="tan:class-val-for-group-item-number" as="xs:string?">
        <!-- Input: a source id -->
        <!-- Output: the class marking the item's position in the group -->
        <!-- If no pattern idref can be found, nothing is returned -->
        <xsl:param name="src-id" as="xs:string?"/>
        <xsl:variable name="this-pattern-match" select="tan:get-pattern-match($src-id)"/>
        <xsl:variable name="preceding-items"
            select="$this-pattern-match/preceding-sibling::tan:idref"/>
        <xsl:if test="exists($this-pattern-match)">
            <xsl:value-of select="concat('groupitem--', string(count($preceding-items) + 1))"/>
        </xsl:if>
    </xsl:function>
    <xsl:function name="tan:class-val-for-source" as="xs:string?">
        <!-- Input: a source id -->
        <!-- Output: the class marking the alias name and position number -->
        <!-- If no idref can be found, nothing is returned -->
        <xsl:param name="src-id" as="xs:string?"/>
        <xsl:value-of select="concat('src--', $src-id)"/>
    </xsl:function>
    <xsl:function name="tan:get-pattern-match" as="item()*">
        <!-- Input: source ids -->
        <!-- Output: the corresponding <idref> nodes in the source group and sort pattern -->
        <xsl:param name="src-ids" as="xs:string*"/>
        <xsl:sequence select="$source-group-and-sort-pattern//tan:idref[. = $src-ids]"/>
    </xsl:function>


    <xsl:template match="tan:TAN-T-merge" mode="tan-to-html-pass-2">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates select="$self-resolved/*/tan:head/tan:name"
                mode="tan-to-html-pass-2-title"/>
            <xsl:apply-templates select="$self-resolved/*/tan:head/tan:desc"
                mode="tan-to-html-pass-2-title"/>
            <xsl:if test="$add-bibliography">
                <xsl:copy-of select="$source-bibliography"/>
            </xsl:if>
            <hr/>
            <xsl:apply-templates mode="#current"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="tan:head/tan:name" mode="tan-to-html-pass-2-title">
        <h1>
            <xsl:value-of select="."/>
        </h1>
    </xsl:template>
    <xsl:template match="tan:head/tan:desc" mode="tan-to-html-pass-2-title">
        <div class="desc title">
            <xsl:value-of select="."/>
        </div>
    </xsl:template>

    <xsl:variable name="source-bibliography" as="element()">
        <div class="bibl">
            <h2 class="label">Bibliography</h2>
            <!-- first, the key -->
            <div class="bibl-key">
                <xsl:for-each select="$valid-src-ids">
                    <xsl:variable name="this-src-id" select="."/>
                    <div class="bibl-key-item">
                        <div class="{tan:class-val-for-alias-group($this-src-id)}">
                            <div class="{tan:class-val-for-src-id($this-src-id)}">
                                <xsl:value-of select="$this-src-id"/>
                            </div>
                        </div>
                        <div class="name">
                            <xsl:value-of
                                select="$input-pass-1/tan:TAN-T[@src = $this-src-id]/tan:head/tan:source/tan:name[not(@common)][1]"
                            />
                        </div>
                    </div>
                </xsl:for-each>
            </div>
            <!-- second, the sorted bibliography -->
            <div class="bibl-body">
                <xsl:for-each-group select="$input-pass-1/tan:TAN-T/tan:head/tan:source"
                    group-by="tan:name[not(@common)][1]">
                    <xsl:sort select="current-grouping-key()"/>
                    <div class="bibl-item">
                        <div class="name">
                            <xsl:value-of select="current-grouping-key()"/>
                        </div>
                        <xsl:for-each-group select="current-group()/tan:desc" group-by=".">
                            <div class="desc">
                                <xsl:value-of select="."/>
                            </div>
                        </xsl:for-each-group>
                    </div>
                </xsl:for-each-group>
            </div>
        </div>
    </xsl:variable>

    <!-- The source controller -->
    <xsl:template match="html:div[tokenize(@class, ' ') = 'control']" mode="tan-to-html-pass-2">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <h2 class="label">Source controller</h2>
            <div>Drag to reorder sources; click the checkbox to turn sources on and off; click the
                label to learn more about the source.</div>
            <xsl:apply-templates mode="#current"/>
            <div class="options">
                <div class="label">Other options</div>
                <xsl:copy-of select="tan:add-class-switch('table', 'layout-fixed', 'Table layout fixed', true())"/>
                <div class="option-item">
                    <div>Table width <input id="tableWidth" type="number" min="50" max="10000"
                        value="100" />%</div>
                </div>
                <xsl:copy-of select="tan:add-class-switch('.add', 'hidden', 'Additions hidden', true())"/>
                <xsl:copy-of select="tan:add-class-switch('.note', 'hidden', 'Annotations hidden', true())"/>
                <xsl:copy-of select="tan:add-class-switch('.rdg', 'hidden', 'Variant readings hidden', true())"/>
            </div>
        </xsl:copy>
    </xsl:template>
    <xsl:function name="tan:add-class-switch" as="element()?">
        <!-- Input: three strings and a boolean -->
        <!-- Output: an html switch with a div.elementName for the first string, a div.className for the second,
            a plain div for the third, then an on/off switch set to the default value of the boolean. The effect is that
            an accompanying JavaScript algorithm targets elements that match the selector and toggles the class name. 
        -->
        <xsl:param name="elementSelector" as="xs:string"/>
        <xsl:param name="className" as="xs:string"/>
        <xsl:param name="label" as="xs:string"/>
        <xsl:param name="default-on" as="xs:boolean"/>
        <div class="option-item">
            <div class="classSwitch">
                <div class="elementName" style="display:none">
                    <xsl:value-of select="$elementSelector"/>
                </div>
                <div class="className" style="display:none">
                    <xsl:value-of select="$className"/>
                </div>
                <div>
                    <xsl:value-of select="$label"/>
                </div>
                <div class="on">
                    <xsl:if test="$default-on = false()">
                        <xsl:attribute name="style">display:none</xsl:attribute>
                    </xsl:if>
                    <xsl:text>☑</xsl:text>
                </div>
                <div class="off">
                    <xsl:if test="$default-on = true()">
                        <xsl:attribute name="style">display:none</xsl:attribute>
                    </xsl:if>
                    <xsl:text>☐</xsl:text>
                </div>
            </div>
        </div>
    </xsl:function>
    <xsl:template match="tan:head/tan:src | tan:group/tan:alias" mode="tan-to-html-pass-2">
        <!-- For filtering and reording the merged contents -->
        <div class="switch">
            <div class="on">☑</div>
            <div class="off" style="display:none">☐</div>
        </div>
        <div class="label">
            <xsl:value-of select="replace(., '_', ' ')"/>
        </div>
    </xsl:template>

    <!-- The <colgroup> that will be put inside every <table>, so that sources can be grouped by leaf <group> -->
    <xsl:variable name="standard-colgroup" as="element()">
        <colgroup>
            <col/>
            <xsl:for-each select="$valid-src-ids">
                <xsl:variable name="this-src-id" select="."/>
                <xsl:variable name="these-class-values"
                    select="tan:class-val-for-source(.), tan:class-val-for-alias-group(.)"
                    as="xs:string*"/>
                <col class="{string-join($these-class-values, ' ')}"/>
            </xsl:for-each>
            <!--<xsl:apply-templates select="$source-group-and-sort-pattern" mode="build-colgroup"/>-->
        </colgroup>
    </xsl:variable>
    <!--<xsl:template match="tan:group" mode="build-colgroup">
        <xsl:variable name="this-alias" select="tan:alias"/>
        <xsl:for-each select="tan:idref">
        </xsl:for-each>
        <!-\-<xsl:for-each-group select="* except tan:alias" group-adjacent="name()">
            <xsl:choose>
                <xsl:when test="current-grouping-key() = 'idref'">
                    <xsl:variable name="these-class-values" as="xs:string*">
                        <xsl:for-each select="current-group()">
                            <xsl:value-of select="concat('src-\\-', .)"/>
                        </xsl:for-each>
                        <xsl:if test="exists($this-alias)">
                            <xsl:variable name="idref-alias-pos"
                                select="index-of($alias-ids, $this-alias)"/>
                            <xsl:value-of
                                select="concat('alias-\\-', string($idref-alias-pos), ' alias-\\-', $this-alias)"
                            />
                        </xsl:if>
                    </xsl:variable>
                    <col span="{count(current-group())}">
                        <xsl:if test="exists($this-alias)">
                            <xsl:attribute name="class"
                                select="string-join($these-class-values, ' ')"/>
                        </xsl:if>
                    </col>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates select="current-group()" mode="#current"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each-group>-\->
    </xsl:template>-->

    <xsl:template match="tan:desc" mode="tan-to-html-pass-2">
        <div class="desc"><xsl:value-of select="."/></div>
    </xsl:template>
    <xsl:template match="tan:TAN-T-merge/*[@class = 'control']//tan:group[not(tan:alias)]"
        mode="tan-to-html-pass-2">
        <xsl:variable name="class-values-to-add" as="xs:string+">
            <xsl:text>sortable</xsl:text>
        </xsl:variable>
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:attribute name="class" select="string-join((@class, $class-values-to-add), ' ')"/>
            <xsl:if test="exists(parent::tan:group)">
                <xsl:attribute name="draggable"/>
            </xsl:if>
            <xsl:apply-templates mode="#current"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="tan:head" mode="tan-to-html-pass-2">
        <xsl:variable name="this-src" select="tan:src"/>
        <xsl:variable name="this-pattern-marker"
            select="$source-group-and-sort-pattern//tan:idref[. = $this-src]"/>
        <xsl:variable name="extra-class-values" as="xs:string*">
            <xsl:if test="exists($this-pattern-marker)">
                <xsl:value-of
                    select="concat('groupitem--', string(count($this-pattern-marker/preceding-sibling::tan:idref) + 1))"
                />
            </xsl:if>
        </xsl:variable>
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:attribute name="draggable"/>
            <xsl:attribute name="class" select="string-join((@class, $extra-class-values), ' ')"/>
            <xsl:apply-templates mode="#current"/>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="tan:body" mode="tan-to-html-pass-2">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:choose>
                <xsl:when test="$tables-via-css">
                    <xsl:apply-templates mode="tan-to-html-pass-2-css-tables"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates mode="tan-to-html-pass-2-html-tables"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="text()" mode="tan-to-html-pass-2-html-tables">
        <xsl:value-of select="replace(., '_', ' ')"/>
    </xsl:template>
    <xsl:template match="tan:n | tan:src | tan:ref" mode="tan-to-html-pass-2-html-tables">
        <xsl:variable name="this-name" select="name(.)"/>
        <xsl:variable name="preceding-siblings" select="preceding-sibling::*[name(.) = $this-name]"/>
        <xsl:if test="not(. = $preceding-siblings)">
            <xsl:copy>
                <xsl:copy-of select="@*"/>
                <xsl:apply-templates mode="#current"/>
            </xsl:copy>
        </xsl:if>
    </xsl:template>
    <xsl:template match="tan:div[tokenize(@class, ' ') = $version-wrapper-class-name]"
        mode="tan-to-html-pass-2-html-tables">
        <xsl:variable name="n-pattern" as="element()*"
            select="(tan:primary-ns, tan:n[not(contains(@class, 'rebuilt'))])"/>
        <xsl:variable name="these-div-versions"
            select=".//tan:div[tokenize(@class, ' ') = 'version']"/>
        <div>
            <xsl:copy-of select="@*"/>
            <div class="meta">
                <!-- doing this allows us to set paratextual material to the side, above, wherever -->
                <xsl:apply-templates select="* except tan:group" mode="#current"/>
            </div>
            <table>
                <xsl:if test="$table-layout-fixed">
                    <xsl:attribute name="class" select="'layout-fixed'"/>
                </xsl:if>
                <xsl:copy-of select="$standard-colgroup"/>
                <tbody>
                    <xsl:apply-templates select="$n-pattern"
                        mode="tan-to-html-pass-2-html-tables-tr">
                        <xsl:with-param name="div-versions" select="$these-div-versions"/>
                    </xsl:apply-templates>
                </tbody>
            </table>
        </div>
    </xsl:template>
    <xsl:template match="tan:primary-ns | tan:n" mode="tan-to-html-pass-2-html-tables-tr">
        <xsl:param name="div-versions" as="element()*"/>
        <xsl:variable name="these-ns" select="descendant-or-self::tan:n"/>
        <!-- It is important that only the first n matches, otherwise you get a primary <div> lumped in with a continuation. -->
        <xsl:variable name="these-div-versions" select="$div-versions[tan:n[1] = $these-ns]"/>
        <tr>
            <td class="n">
                <xsl:value-of select="."/>
            </td>
            <xsl:apply-templates select="$these-div-versions" mode="tan-to-html-pass-2-html-tables"/>
            <!--<xsl:for-each-group select="$these-div-versions" group-by="tan:src">
                <xsl:variable name="first-div" select="current-group()[1]"/>
                <xsl:variable name="following-siblings" select="$first-div/following-sibling::tan:div"/>
                <xsl:variable name="first-following-noncontinuation-sibling"
                    select="$following-siblings[not(tokenize(@class, ' ') = 'continuation')][1]"/>
                <xsl:variable name="following-continuations"
                    select="$following-siblings except $first-following-noncontinuation-sibling/(self::*, following-sibling::*)"/>
                <td>
                    <xsl:copy-of select="$first-div/@*"/>
                    <xsl:apply-templates select="." mode="tan-to-html-pass-2-html-tables"/>
                </td>
            </xsl:for-each-group>-->
        </tr>
    </xsl:template>
    <xsl:template
        match="tan:div[tokenize(@class, ' ') = ('version', 'filler', 'continuation', 'consolidated')]"
        mode="tan-to-html-pass-2-html-tables">
        <xsl:variable name="diagnostics" select="false()"/>
        <xsl:variable name="is-continuation" select="tokenize(@class, ' ') = 'continuation'"/>
        <xsl:variable name="this-src" select="tan:src"/>
        <xsl:variable name="this-pattern-marker"
            select="$source-group-and-sort-pattern//tan:idref[. = $this-src]"/>
        <xsl:variable name="following-siblings" select="following-sibling::tan:div"/>
        <xsl:variable name="first-following-noncontinuation-sibling"
            select="$following-siblings[not(tokenize(@class, ' ') = 'continuation')][1]"/>
        <xsl:variable name="following-continuations"
            select="$following-siblings except $first-following-noncontinuation-sibling/(self::*, following-sibling::*)"/>
        <xsl:variable name="these-alias-ids" select="ancestor::tan:group/tan:alias"/>
        <xsl:variable name="these-class-additions" as="xs:string*">
            <xsl:for-each select="$these-alias-ids">
                <xsl:value-of select="concat('alias--', .)"/>
                <xsl:value-of select="concat('alias--', string(index-of($alias-ids, .)))"/>
                <xsl:if test="exists($this-pattern-marker)">
                    <xsl:value-of
                        select="concat('groupitem--', string(count($this-pattern-marker/preceding-sibling::tan:idref) + 1))"
                    />
                </xsl:if>
            </xsl:for-each>
        </xsl:variable>
        <xsl:if test="$diagnostics">
            <xsl:message select="tan:shallow-copy(.)"/>
        </xsl:if>
        <xsl:if test="not($is-continuation)">
            <td>
                <xsl:copy-of select="@*"/>
                <xsl:attribute name="class"
                    select="string-join((@class, $these-class-additions), ' ')"/>
                <xsl:if test="exists($following-continuations)">
                    <xsl:attribute name="rowspan" select="count($following-continuations) + 1"/>
                </xsl:if>
                <xsl:copy-of select="node()"/>
            </td>
        </xsl:if>
    </xsl:template>

    <xsl:variable name="src-count-width-css" as="xs:string*">td.version { width: <xsl:value-of
            select="format-number((1 div count($input-pass-1)), '0.0%')"/>}</xsl:variable>
    <xsl:variable name="src-length-width-css" as="xs:string*">
        <xsl:variable name="total-length"
            select="string-length(tan:text-join($input-pass-1/tan:TAN-T/tan:body))"/>
        <xsl:for-each select="$input-pass-1">
            <xsl:variable name="this-src-id" select="*/@src"/>
            <xsl:variable name="this-length"
                select="string-length(tan:text-join(tan:TAN-T/tan:body))"/>
            <xsl:value-of
                select="concat('td.src--', $this-src-id, '{ width: ', format-number(($this-length div $total-length), '0.0%'), '}')"
            />
        </xsl:for-each>
    </xsl:variable>
    <xsl:template match="html:head" mode="revise-infused-template">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates mode="#current"/>
            <style>
                .layout-fixed {
                    table-layout: fixed
                }</style>
            <xsl:choose>
                <xsl:when test="$td-widths-proportionate-to-td-count">
                    <style><xsl:value-of select="$src-count-width-css"/></style>
                </xsl:when>
                <xsl:when test="$td-widths-proportionate-to-string-length">
                    <style><xsl:value-of select="$src-length-width-css"/></style>
                </xsl:when>
            </xsl:choose>
        </xsl:copy>
    </xsl:template>
    <!--<xsl:template match="tan:alias" mode="tan-to-html-pass-2-html-tables"/>-->
    <!--<xsl:template match="tan:group[tan:alias]" mode="tan-to-html-pass-2-html-tables">
        <table class="alias-\-{tan:alias/text()}">
            <tbody>
                <tr>
                    <xsl:apply-templates mode="#current"/>
                </tr>
            </tbody>
        </table>
    </xsl:template>-->
    <!--<xsl:template match="tan:group[tan:src]" mode="tan-to-html-pass-2-html-tables">
        <td class="src-\-{tan:src/text()}">
            <xsl:apply-templates mode="#current"/>
        </td>
    </xsl:template>-->

    <!--<xsl:template match="/" priority="1">
        <diagnostics>
            <xsl:copy-of select="$self-expanded[4]"/>
            <!-\-<xsl:value-of select="$template-url-relative-to-actual-input, $input-base-uri-resolved"/>-\->
            <!-\-<xsl:value-of select="$template-url-resolved"/>-\->
            <!-\-<xsl:value-of select="$output-url-resolved"/>-\->
            <!-\-<xsl:value-of select="$output-filename-resolved"/>-\->
            <!-\-<xsl:copy-of select="$validation-phase"/>-\->
            <!-\-<xsl:copy-of select="$self-expanded"/>-\->
            <!-\-<xsl:copy-of select="$standard-colgroup"/>-\->
            <!-\-<xsl:copy-of select="$alias-based-group-and-sort-pattern"/>-\->
            <!-\-<xsl:copy-of select="$valid-src-ids"/>-\->
            <!-\-<xsl:copy-of select="$source-group-and-sort-pattern"/>-\->
            <!-\-<xsl:copy-of select="$sources-resolved[2]"/>-\->
            <!-\-<xsl:copy-of select="$input-items[2]"/>-\->
            <!-\-<xsl:copy-of select="$input-pass-1"/>-\->
            <!-\-<xsl:copy-of select="$input-pass-1b"/>-\->
            <!-\-<xsl:copy-of select="$input-pass-2"/>-\->
            <!-\-<xsl:copy-of select="$input-pass-3"/>-\->
            <!-\-<xsl:copy-of select="$source-bibliography"/>-\->
            <!-\-<xsl:copy-of select="$input-pass-4"/>-\->
            <!-\-<xsl:copy-of select="$template-infused-with-revised-input"/>-\->
            <!-\-<xsl:copy-of select="$infused-template-revised"/>-\->
        </diagnostics>
    </xsl:template>-->

</xsl:stylesheet>
