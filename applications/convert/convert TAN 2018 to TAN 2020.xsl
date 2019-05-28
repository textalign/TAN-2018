<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="tag:textalign.net,2015:ns" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" 
    xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:ti="http://chs.harvard.edu/xmlns/cts"
    xmlns:tan="tag:textalign.net,2015:ns" exclude-result-prefixes="#all" version="2.0"
    xpath-default-namespace="http://www.w3.org/2005/xpath-functions">

    <!-- Input: A TAN file written to conform to the TAN schema that was written for the TAN-2018 schema -->
    <!-- Output: The same TAN file, updated to suit the 2020 schemas. -->
    <!-- It is important that this stylesheet avoid any variables or functions that try to resolve the file -->

    <!-- The following is a stylesheet that ensures that this transformation gets credited/blamed in the resultant TAN-TEI file -->
    <xsl:import href="../get%20inclusions/convert.xsl"/>

    <xsl:output indent="no" use-character-maps="tan"/>

    <!-- STYLESHEET -->
    <xsl:param name="stylesheet-iri"
        select="'tag:textalign.net,2015:stylesheet:convert-tan2018-to-tan2020"/>
    <xsl:param name="stylesheet-url" select="static-base-uri()"/>
    <xsl:param name="stylesheet-name" select="'Converter from TAN 2018 to TAN 2020'"/>
    <xsl:param name="change-message" select="'Converted from 2018 to 2020 schemas.'"/>

    <xsl:variable name="other-stylesheets" select="$applications-collection[xsl:stylesheet]"/>

    <!-- INPUT -->

    <xsl:param name="input-items" as="item()*" select="/"/>

    <xsl:variable name="test-input" as="document-node()">
        <xsl:apply-templates select="/" mode="test-input"/>
    </xsl:variable>

    <xsl:template match="node() | @*" mode="input-pass-1 test-input">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*" mode="#current"/>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="processing-instruction()" priority="1" mode="input-pass-1 test-input">
        <xsl:processing-instruction name="{name(.)}" select="replace(., 'TAN-2018', 'TAN-2020')"/>
    </xsl:template>
    <xsl:template match="/comment()" mode="input-pass-1 test-input">
        <xsl:comment select="replace(., 'TAN-2018', 'TAN-2020')"/>
    </xsl:template>

    <xsl:template match="text()[not(matches(., '\S'))]" mode="input-pass-1 test-input">
        <xsl:param name="indent-offset" tunnel="yes" as="xs:integer?"/>
        <xsl:choose>
            <xsl:when test="exists($indent-offset)">
                <xsl:variable name="this-anc-count" select="count(ancestor::*)"/>
                <xsl:variable name="last-text-node-offset"
                    select="
                        if (exists(following-sibling::*)) then
                            0
                        else
                            -1"/>
                <xsl:value-of
                    select="$most-common-indentations[$this-anc-count + $indent-offset + $last-text-node-offset]"
                />
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="."/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template match="/*" mode="input-pass-1 test-input">
        <xsl:if test="not(@TAN-version = '2018')">
            <xsl:message terminate="yes">Input must have @TAN-version = 2018</xsl:message>
        </xsl:if>
        <xsl:choose>
            <xsl:when test="name(.) = 'TAN-key'">
                <TAN-voc>
                    <xsl:attribute name="xml:base" select="$doc-uri"/>
                    <xsl:apply-templates select="node() | @*" mode="#current"/>
                </TAN-voc>
            </xsl:when>
            <xsl:when test="name(.) = 'TAN-A-div'">
                <TAN-A>
                    <xsl:attribute name="xml:base" select="$doc-uri"/>
                    <xsl:apply-templates select="node() | @*" mode="#current"/>
                </TAN-A>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy>
                    <xsl:attribute name="xml:base" select="$doc-uri"/>
                    <xsl:apply-templates select="node() | @*" mode="#current"/>
                </xsl:copy>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template match="@TAN-version" mode="input-pass-1 test-input">
        <xsl:attribute name="TAN-version">2020</xsl:attribute>
    </xsl:template>

    <xsl:template match="@when-accessed" mode="input-pass-1 test-input">
        <xsl:attribute name="accessed-when">
            <xsl:value-of select="."/>
        </xsl:attribute>
    </xsl:template>

    <xsl:variable name="head-map" as="element()">
        <head-map>
            <file-name>
                <element>name</element>
                <element>desc</element>
                <element>master-location</element>
            </file-name>
            <declaration-list>
                <element>license</element>
                <element>licensor</element>
                <!-- licensor is dropped -->
                <!-- core definitions to move here: ambiguous-letter-numerals-are-roman-->
                <!-- class 1 definitions to move here: <work>, <version>, <token-definition> -->
                <!-- class 2 definitions to move here: <token-definition>, <for-lang>, <tok-starts-with>, <tok-is> -->
                <!-- class 3 definitions to move here: <for-lang> -->
            </declaration-list>
            <other-files>
                <element>key</element>
                <element>inclusion</element>
                <element>source</element>
                <element>see-also</element>
            </other-files>
            <key-list>
                <element>definitions</element>
            </key-list>
            <adjustment-list>
                <element>alter</element>
            </adjustment-list>
            <resp-list>
                <element>resp</element>
            </resp-list>
            <change-list>
                <element>change</element>
            </change-list>
            <to-do-list/>
        </head-map>
    </xsl:variable>



    <xsl:template match="tan:head" mode="input-pass-1 test-input">
        <xsl:variable name="part-1-terminus" select="*[name() = $head-map/*[1]/*][last()]"/>
        <xsl:variable name="part-2-terminus"
            select="*[name() = $head-map/*[position() le 2]/*][last()]"/>
        <xsl:variable name="part-3-terminus"
            select="*[name() = $head-map/*[position() le 3]/*][last()]"/>
        <xsl:variable name="part-4-terminus"
            select="*[name() = $head-map/*[position() le 4]/*][last()]"/>
        <xsl:variable name="part-5-terminus"
            select="*[name() = $head-map/*[position() le 5]/*][last()]"/>
        <xsl:variable name="part-6-terminus" select="tan:resp[last()]"/>
        <xsl:variable name="part-7-terminus" select="tan:change[last()]"/>
        <xsl:copy>
            <xsl:apply-templates select="@*" mode="#current"/>
            <!-- part 1: name, desc, master-location -->
            <xsl:apply-templates mode="#current"
                select="$part-1-terminus/(preceding-sibling::node(), self::node())"/>
            <!-- part 2: license -->
            <xsl:apply-templates mode="#current"
                select="$part-2-terminus/(preceding-sibling::node(), self::node()) except $part-1-terminus/(preceding-sibling::node(), self::node())"/>
            <xsl:for-each
                select="
                    /(tei:TEI, tan:TAN-T)/tan:head/tan:definitions/(tan:work, tan:version),
                    tan:definitions/(tan:token-definition, tan:ambiguous-letter-numerals-are-roman)">
                <xsl:value-of select="$most-common-indentations[2]"/>
                <xsl:apply-templates select="." mode="#current">
                    <xsl:with-param name="indent-offset" select="-1" tunnel="yes"/>
                </xsl:apply-templates>
            </xsl:for-each>
            <xsl:for-each
                select="following-sibling::tan:body/(tan:for-lang, tan:tok-starts-with, tan:tok-is)">
                <xsl:value-of select="$most-common-indentations[2]"/>
                <xsl:copy-of select="."/>
            </xsl:for-each>
            <!-- part 3: networked files -->
            <xsl:apply-templates mode="#current"
                select="$part-3-terminus/(preceding-sibling::node(), self::node()) except $part-2-terminus/(preceding-sibling::node(), self::node())"/>
            <!-- new part 4: adjustments -->
            <xsl:apply-templates mode="#current"
                select="$part-5-terminus/(preceding-sibling::node(), self::node()) except $part-4-terminus/(preceding-sibling::node(), self::node())"/>
            <!-- new part 5: vocabulary-key -->
            <xsl:apply-templates mode="#current"
                select="$part-4-terminus/(preceding-sibling::node(), self::node()) except $part-3-terminus/(preceding-sibling::node(), self::node())"/>
            <!-- part 6: responsibilities -->
            <xsl:apply-templates mode="#current"
                select="$part-6-terminus/(preceding-sibling::node(), self::node()) except $part-5-terminus/(preceding-sibling::node(), self::node())"/>
            <!-- part 7: change log -->
            <xsl:apply-templates mode="#current"
                select="$part-7-terminus/(preceding-sibling::node(), self::node()) except $part-6-terminus/(preceding-sibling::node(), self::node())"/>
            <xsl:value-of select="$most-common-indentations[2]"/>
            <!-- part 8: to-do -->
            <to-do>
                <xsl:if test="not(exists(/*/(tan:body, */*:body)/@in-progress))">
                    <xsl:value-of select="$most-common-indentations[3]"/>
                    <comment>
                        <xsl:copy-of select="$doc-history/*[1]/(@when, @who)"/>
                        <xsl:text>File is still in progress.</xsl:text>
                    </comment>
                    <xsl:value-of select="$most-common-indentations[2]"/>
                </xsl:if>
            </to-do>
            <xsl:apply-templates mode="#current" select="$part-7-terminus/following-sibling::node()"
            />
        </xsl:copy>
    </xsl:template>

    <xsl:template match="tan:license" mode="input-pass-1 test-input">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:if test="not(exists(@licensor))">
                <xsl:attribute name="licensor" select="../tan:licensor/@who"/>
            </xsl:if>
            <xsl:apply-templates mode="#current"/>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="tan:licensor | text()[following-sibling::node()[1]/self::tan:licensor]"
        mode="input-pass-1 test-input" priority="1"/>

    <xsl:template match="tan:ambiguous-letter-numerals-are-roman" mode="input-pass-1 test-input">
        <xsl:variable name="is-true" select="xs:boolean(.)"/>
        <numerals priority="{if ($is-true) then 'roman' else 'letters'}"/>
    </xsl:template>

    <xsl:template match="tan:TAN-mor/tan:head/tan:source/@xml:id" mode="input-pass-1"/>

    <xsl:template match="tan:key" mode="input-pass-1 test-input">
        <vocabulary>
            <xsl:apply-templates select="@* | node()" mode="#current"/>
        </vocabulary>
    </xsl:template>

    <xsl:template match="tan:see-also" mode="input-pass-1 test-input">
        <xsl:variable name="this-relationship" select="tan:attribute-vocabulary(@relationship)"/>
        <xsl:variable name="this-relationship-glossary-entry"
            select="tan:attribute-vocabulary(@relationship)"/>
        <xsl:choose>
            <xsl:when test="$this-relationship-glossary-entry//tan:name = 'model'">
                <model>
                    <xsl:apply-templates select="@* except @relationship" mode="#current"/>
                    <xsl:apply-templates select="node()" mode="#current"/>
                </model>
            </xsl:when>
            <xsl:when test="$this-relationship-glossary-entry//tan:name = 'redivision'">
                <redivision>
                    <xsl:apply-templates select="@* except @relationship" mode="#current"/>
                    <xsl:apply-templates select="node()" mode="#current"/>
                </redivision>
            </xsl:when>
            <xsl:when test="$this-relationship-glossary-entry//tan:name = 'class 2'">
                <annotation>
                    <xsl:apply-templates select="@* except @relationship" mode="#current"/>
                    <xsl:apply-templates select="node()" mode="#current"/>
                </annotation>
            </xsl:when>
            <xsl:when test="$this-relationship-glossary-entry//tan:name = 'old version'">
                <predecessor>
                    <xsl:apply-templates select="@* except @relationship" mode="#current"/>
                    <xsl:apply-templates select="node()" mode="#current"/>
                </predecessor>
            </xsl:when>
            <xsl:when test="$this-relationship-glossary-entry//tan:name = 'new version'">
                <successor>
                    <xsl:apply-templates select="@* except @relationship" mode="#current"/>
                    <xsl:apply-templates select="node()" mode="#current"/>
                </successor>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy>
                    <xsl:apply-templates select="@* | node()" mode="#current"/>
                </xsl:copy>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template match="tan:alter" mode="input-pass-1 test-input">
        <adjustments>
            <xsl:apply-templates mode="#current" select="@* | node()"/>
        </adjustments>
    </xsl:template>

    <xsl:template match="tan:reassign/tan:tok" mode="input-pass-1">
        <passage>
            <xsl:copy-of select="@ref"/>
            <xsl:if test="not(exists(*)) and exists(@pos)">
                <xsl:variable name="these-poses" select="tan:analyze-sequence(@pos, 'pos')"/>
                <xsl:for-each select="$these-poses/*">
                    <xsl:variable name="is-odd" select="position() mod 2 = 1"/>
                    <xsl:choose>
                        <xsl:when test="$is-odd">
                            <from-tok pos="{.}"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <through-tok pos="{.}"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:for-each>
                <xsl:apply-templates mode="#current"/>
            </xsl:if>
        </passage>
    </xsl:template>
    <xsl:template match="tan:reassign/tan:tok/tan:from" mode="input-pass-1">
        <from-tok>
            <xsl:copy-of select="@*"/>
        </from-tok>
    </xsl:template>
    <xsl:template match="tan:reassign/tan:tok/tan:to" mode="input-pass-1">
        <through-tok>
            <xsl:copy-of select="@*"/>
        </through-tok>
    </xsl:template>

    <xsl:template match="tan:definitions" mode="input-pass-1 test-input">
        <vocabulary-key>
            <xsl:apply-templates select="@*" mode="#current"/>
            <!-- Note, we can discard any vocabulary items whose @xml:id and @which values are identical -->
            <xsl:apply-templates
                select="
                    node() except
                    (tan:relationship[(tan:name, @which, tan:attribute-vocabulary(@relationship)//tan:name) = ('model', 'redivision', 'class 2', 'old version', 'new version')],
                    (tan:work, tan:version)[ancestor::tei:TEI or ancestor::tan:TAN-T],
                    *[@xml:id = @which],
                    tan:token-definition, tan:ambiguous-letter-numerals-are-roman)/(self::node(), preceding-sibling::node()[1]/self::text())"
                mode="#current"/>
        </vocabulary-key>
    </xsl:template>
    <xsl:template match="tan:morphology/tan:for-lang" mode="input-pass-1 test-input"/>
    <xsl:template match="tan:algorithm" mode="input-pass-1 test-input">
        <xsl:variable name="last-text-node" select="node()[last()]/self::text()"/>
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates select="node() except $last-text-node" mode="#current"/>
            <xsl:if test="not(exists(tan:location))">
                <xsl:variable name="these-iris" select="tan:IRI"/>
                <xsl:variable name="these-matching-stylesheets"
                    select="$other-stylesheets[xsl:stylesheet/*[(replace(@select, '^.|.$', ''), text()) = $these-iris]]"/>
                <xsl:variable name="matching-stylesheet-urls"
                    select="
                        for $i in $these-matching-stylesheets
                        return
                            tan:base-uri($i)"
                />
                <xsl:for-each select="$matching-stylesheet-urls">
                    <xsl:value-of select="$most-common-indentations[4]"/>
                    <location href="{tan:uri-relative-to(., $doc-uri)}" accessed-when="{$today-iso}"/>
                </xsl:for-each>
                <xsl:if test="not(exists($matching-stylesheet-urls))">
                    <xsl:value-of select="$most-common-indentations[4]"/>
                    <location href="" accessed-when="{$today-iso}"/>
                </xsl:if>
            </xsl:if>
            <xsl:copy-of select="$last-text-node"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="tan:algorithm/tan:desc" mode="input-pass-1 test-input">
        <xsl:variable name="url-check" select="tan:parse-urls(text())"/>
        <xsl:variable name="urls-valid" as="xs:string*">
            <xsl:for-each select="$url-check/tan:url">
                <xsl:variable name="this-url-with-ad-hoc-fixes"
                    select="replace(., 'do( |%20)things', 'applications')"/>
                <xsl:variable name="this-url-resolved"
                    select="resolve-uri($this-url-with-ad-hoc-fixes, $doc-uri)"/>
                <xsl:if test="doc-available($this-url-resolved)">
                    <xsl:value-of select="$this-url-with-ad-hoc-fixes"/>
                </xsl:if>
            </xsl:for-each>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="$urls-valid">
                <xsl:for-each select="$urls-valid">
                    <location accessed-when="{current-dateTime()}" href="{.}"/>
                </xsl:for-each>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy-of select="."/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template match="tan:resp[1]" mode="input-pass-1">
        <file-resp who=""/>
        <xsl:value-of select="$most-common-indentations[2]"/>
        <xsl:copy-of select="."/>
    </xsl:template>

    <xsl:template match="*:body" mode="input-pass-1">
        <xsl:copy>
            <xsl:apply-templates select="@*" mode="#current"/>
            <xsl:apply-templates
                select="
                    node() except
                    (tan:for-lang, tan:tok-is, tan:tok-starts-with)/(self::node(), preceding-sibling::node()[1]/self::text())"
                mode="#current"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="tan:locus" mode="input-pass-1">
        <at>
            <xsl:apply-templates select="@* | node()" mode="#current"/>
        </at>
    </xsl:template>

    <xsl:template match="@in-progress" mode="input-pass-1"/>

    <xsl:template match="@val" mode="input-pass-1">
        <xsl:variable name="is-rgx"
            select="matches(., $characters-to-escape-when-converting-string-to-regex)"/>
        <xsl:choose>
            <xsl:when test="$is-rgx">
                <xsl:attribute name="rgx" select="."/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy-of select="."/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:variable name="pass-1-resolved" select="tan:resolve-doc($input-pass-1)"/>
    <xsl:variable name="pass-1-agent-vocabulary"
        select="tan:vocabulary(('person', 'organization'), false(), (), $pass-1-resolved/*/tan:head)"/>
    <xsl:variable name="pass-1-likely-primary-agents"
        select="$pass-1-agent-vocabulary/*[tan:IRI[starts-with(., $doc-id-namespace)]]"/>
    <xsl:variable name="pass-1-primary-agent-ids"
        select="
            for $i in $pass-1-likely-primary-agents
            return
                if (exists($i/tan:id)) then
                    $i/tan:id[1]
                else
                    replace($i/tan:name[1], '\s', '_')"/>
    <xsl:template match="tan:file-resp" mode="input-pass-2">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:if test="exists($pass-1-primary-agent-ids)">
                <xsl:attribute name="who" select="string-join($pass-1-primary-agent-ids, ' ')"/>
            </xsl:if>
        </xsl:copy>
    </xsl:template>

    <!-- TEMPLATE -->

    <xsl:param name="template-infused-with-revised-input" select="$input-pass-2"/>

    <xsl:template match="/" mode="revise-infused-template">
        <xsl:document>
            <xsl:for-each select="node()">
                <xsl:text>&#xa;</xsl:text>
                <xsl:copy-of select="."/>
            </xsl:for-each>
        </xsl:document>
    </xsl:template>

    <xsl:template match="@xml:base" mode="credit-stylesheet"/>

    <!-- OUTPUT -->
    <xsl:param name="output-directory-relative-to-actual-input" select="tan:uri-directory($doc-uri)"/>
    <xsl:param name="output-filename" select="concat(tan:cfn(/), '-', $today-iso, '.xml')"/>
    <!--<xsl:param name="output-url-relative-to-actual-input" as="xs:string?"
        select="replace($doc-uri, '(\.\w+)$', concat('-', $today-iso, '$1'))"/>-->

    <xsl:template match="/" priority="1">
        <!-- diagnostics -->
        <!--<diagnostics>
            <xsl:value-of select="base-uri(/)"/>
            <!-\-<xsl:value-of select="$output-url-resolved"/>-\->
        </diagnostics>-->
        <!--<xsl:copy-of select="$applications-collection"/>-->
        <!--<xsl:copy-of select="$template-doc"/>-->
        <!--<xsl:copy-of select="$template-infused-with-revised-input"/>-->
        <!--<xsl:copy-of select="$test-input"/>-->
        <!--<xsl:copy-of select="tan:get-doc-history($orig-self)"/>-->
        <!--<xsl:copy-of select="$doc-history"/>-->
        <!--<xsl:copy-of select="$input-pass-1"/>-->
        <!--<xsl:copy-of select="$input-pass-2"/>-->
        <!--<xsl:copy-of select="$infused-template-credited"/>-->
        <xsl:copy-of select="$final-output"/>
    </xsl:template>

</xsl:stylesheet>
