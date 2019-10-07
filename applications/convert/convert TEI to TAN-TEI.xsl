<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="http://www.tei-c.org/ns/1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:fn="http://www.w3.org/2005/xpath-functions"
    xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:ti="http://chs.harvard.edu/xmlns/cts"
    xmlns:tan="tag:textalign.net,2015:ns" exclude-result-prefixes="#all" version="2.0">

    <!-- Input: A TEI file that should be converted to TAN-TEI -->
    <!-- Output: a TAN-TEI file, constructed according to the supplied parameters -->
    <!-- This stylesheet is a work in progress. TEI files come in so many flavors, with so many surprises, that it is difficult or impossible to anticipate
        every way in which they need to be modified in order to be ready for the Text Alignment Network. Therefore, expect this stylesheet to 
        change often. -->

    <!-- See the bottom of this page for the default template (which is where output and diagnostics are controlled) -->


    <!-- The following is the core set of TAN functions, some of which may be used in the transformation -->
    <xsl:import href="../../functions/incl/TAN-core-functions.xsl"/>
    <!-- Extra functions used for extra feedback -->
    <xsl:import href="../../functions/TAN-extra-functions.xsl"/>
    <!-- The next item lets us tap into tan:evaluate -->
    <xsl:import href="../get%20inclusions/TAN-alter-functions.xsl"/>
    <!-- The following stylesheet ensures that this transformation gets credited/blamed in the resultant TAN-TEI file -->
    <xsl:import href="../get%20inclusions/core-for-TAN-output.xsl"/>

    <xsl:output indent="yes"/>

    <xsl:variable name="input-root-element" select="/*"/>
    
    <!-- Dec. 2017: placeholder, to make sure stylesheets validate -->
    <xsl:variable name="alter-doc" select="$empty-doc"/>

    <!-- The following points to an empty sample TAN-TEI file that serves as the mold into which the input TEI document will be poured -->

    <xsl:param name="TAN-TEI-template-url-relative-to-this-stylesheet" as="xs:string?"
        select="'../../templates/template-TAN-TEI.xml'"/>
    <xsl:param name="TAN-TEI-template-url-relative-to-actual-input" as="xs:string?"/>
    <xsl:variable name="TAN-TEI-template-url-resolved"
        select="
            if (string-length($TAN-TEI-template-url-relative-to-actual-input) gt 0) then
                resolve-uri($TAN-TEI-template-url-relative-to-actual-input, $doc-uri)
            else
                resolve-uri($TAN-TEI-template-url-relative-to-this-stylesheet, static-base-uri())"/>
    <xsl:variable name="TAN-TEI-template" as="document-node()"
        select="doc($TAN-TEI-template-url-resolved)"/>
    <!-- Normally, $self-resolved is a global variable that responds to an input TAN document. But because the input document is not a TAN file,
    but a TEI one, $self-resolved (upon which the core output file depends) is defined as the TAN-TEI template -->
    <xsl:variable name="self-resolved" as="document-node()">
        <xsl:document>
            <xsl:apply-templates select="$TAN-TEI-template" mode="adjust-template"/>
        </xsl:document>
    </xsl:variable>

    <xsl:variable name="extra-vocabularies" select="tan:get-1st-doc($TAN-TEI-template/*/tan:head/tan:vocabulary)"/>
    <xsl:variable name="extra-vocabularies-resolved" select="tan:resolve-doc($extra-vocabularies)"/>
    <xsl:variable name="extra-vocabularies-cleaned">
        <xsl:for-each select="$extra-vocabularies-resolved">
            <xsl:document>
                <xsl:apply-templates mode="adjust-vocabularies"/>
            </xsl:document>
        </xsl:for-each>
    </xsl:variable>
    <!--<xsl:variable name="agent-glossary" select="tan:glossary('person', (), $extra-vocabularies-cleaned, ()), tan:glossary('organization', (), $extra-vocabularies-cleaned, ())"/>-->
    <xsl:variable name="agent-glossary" select="tan:vocabulary(('person', 'organization'), ())"/>

    <!-- These parameters modify the core TAN output stylesheet -->
    <xsl:variable name="stylesheet-iri"
        select="'tag:textalign.net,2015:stylesheet:convert-tei-to-tan-tei'"/>
    <xsl:variable name="this-stylesheet-uri" select="static-base-uri()"/>
    <xsl:variable name="change-message" as="xs:string">Converted from TAN-TEI to TAN-T.</xsl:variable>

    <xsl:variable name="href-regex"
        select="concat('(href=[', $quot, $apos, '])([^', $quot, $apos, ']+)([', $quot, $apos, '])')"/>
    <xsl:template match="node() | @*">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*"/>
        </xsl:copy>
    </xsl:template>
    <xsl:function name="tan:adjust-href" as="xs:string?">
        <!-- Input: any string -->
        <!-- Output: the same string, but with content of the form href="[URL]" revised such that the URL is adjusted to match the location of the input document -->
        <xsl:param name="input-string" as="xs:string?"/>
        <xsl:if test="string-length($input-string) gt 0">
            <xsl:variable name="results" as="xs:string*">
                <xsl:analyze-string select="$input-string" regex="{$href-regex}">
                    <xsl:matching-substring>
                        <xsl:value-of
                            select="concat(regex-group(1), tan:uri-relative-to(regex-group(2), $doc-uri), regex-group(3))"
                        />
                    </xsl:matching-substring>
                    <xsl:non-matching-substring>
                        <xsl:value-of select="."/>
                    </xsl:non-matching-substring>
                </xsl:analyze-string>
            </xsl:variable>
            <xsl:value-of select="$results"/>
        </xsl:if>
    </xsl:function>
    <xsl:template match="processing-instruction()" mode="adjust-template">
        <xsl:processing-instruction name="xml-model">
            <xsl:value-of select="tan:adjust-href(.)"/>
        </xsl:processing-instruction>
    </xsl:template>
    <xsl:template match="comment()" mode="adjust-template">
        <!-- Delete all comments except those toggle items with @href (i.e., commented out processing-instructions) -->
        <xsl:if test="matches(., 'href=')">
            <xsl:comment>
            <xsl:value-of select="tan:adjust-href(.)"/>
        </xsl:comment>
        </xsl:if>
    </xsl:template>
    <xsl:template match="@href" mode="adjust-template">
        <xsl:attribute name="{name()}" select="tan:uri-relative-to(., $doc-uri)"/>
    </xsl:template>
    <xsl:template match="*" mode="adjust-template">
        <xsl:copy>
            <xsl:apply-templates select="@* | node()" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="@*" mode="adjust-template">
        <xsl:attribute name="{name(.)}"
            select="string-join(tan:evaluate(., $input-root-element), '')"/>
    </xsl:template>
    <xsl:template match="text()" mode="adjust-template">
        <!-- Ignore whitespace text nodes preceding comments -->
        <xsl:if test="not(following-sibling::node()[1]/self::comment()) or (matches(., '\S'))">
            <xsl:value-of select="string-join(tan:evaluate(., $input-root-element), '')"/>
        </xsl:if>
    </xsl:template>

    <xsl:variable name="license-nodes" select="/tei:TEI/tei:teiHeader//tei:availability/tei:license"/>
    <xsl:variable name="TAN-voc-license-items"
        select="
            for $i in $TAN-vocabularies
            return
                key('item-via-node-name', 'license', $i)"/>
    <xsl:variable name="TAN-voc-license-matches"
        select="$TAN-voc-license-items[(tan:name, tan:IRI) = $license-nodes//(@*, *)]"/>
    <xsl:template match="tan:license" mode="adjust-template">
        <xsl:copy>
            <xsl:choose>
                <xsl:when test="exists($TAN-voc-license-matches)">
                    <xsl:attribute name="which" select="$TAN-voc-license-matches[1]/tan:name[1]"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:copy-of select="@*"/>
                    <xsl:apply-templates mode="#current"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:copy>
    </xsl:template>

    <xsl:variable name="person-role-nodes"
        select="/tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/(tei:funder, tei:editor, tei:sponsor, tei:principal)[node()]"/>
    <xsl:variable name="person-role-nodes-checked" as="element()*">
        <xsl:for-each select="$person-role-nodes">
            <!-- We use replace, because some TEI file encoders have decided to include more than just the names of the agent (i.e., sometimes the institutional affiliation gets added) -->
            <xsl:variable name="this-name" select="replace(normalize-space(.), ',.+$', '')"/>
            <xsl:variable name="possible-iris" select="@ref"/>
            <xsl:variable name="possible-agents"
                select="
                    $agent-glossary[tan:name[matches($this-name, tan:escape(.))]
                    or tan:IRI = $possible-iris]"/>
            <xsl:copy>
                <xsl:copy-of select="@*"/>
                <IRI>
                    <xsl:value-of select="($possible-agents/tan:IRI, $possible-iris, $this-name)[1]"
                    />
                </IRI>
                <xsl:copy-of select="node()"/>
            </xsl:copy>
        </xsl:for-each>
    </xsl:variable>
    <xsl:template match="tan:person | tan:organization | tan:algorithm" mode="adjust-template">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates mode="#current"/>
        </xsl:copy>
        <xsl:if
            test="not(exists((following-sibling::tan:person, following-sibling::tan:organization, following-sibling::tan:algorithm)))">
            <xsl:for-each-group select="$person-role-nodes-checked" group-by="tei:IRI">
                <xsl:variable name="this-agent"
                    select="$agent-glossary[tan:IRI = current-grouping-key()]"/>
                <xsl:variable name="this-agent-type" select="($this-agent/ancestor-or-self::*/@affects-element)[last()]"/>
                <xsl:element name="{($this-agent-type, 'person')[1]}" namespace="tag:textalign.net,2015:ns">
                    <xsl:choose>
                        <xsl:when test="exists($this-agent)">
                            <xsl:attribute name="which" select="$this-agent/tan:name[1]"/>
                            <xsl:attribute name="xml:id"
                                select="lower-case(replace($this-agent/tan:name[1], '\W', ''))"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:attribute name="xml:id" select="concat('agent', position())"/>
                            <xsl:element name="IRI" namespace="tag:textalign.net,2015:ns">
                                <xsl:value-of select="current-grouping-key()"/>
                            </xsl:element>
                            <xsl:for-each select="current-group()/text()">
                                <xsl:element name="name" namespace="tag:textalign.net,2015:ns">
                                    <xsl:value-of select="normalize-space(.)"/>
                                </xsl:element>
                            </xsl:for-each>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:element>
            </xsl:for-each-group>
        </xsl:if>
    </xsl:template>
    <xsl:template match="tan:role[not(following-sibling::tan:role)]" mode="adjust-template">
        <xsl:copy>
            <xsl:apply-templates select="@* | node()" mode="#current"/>
        </xsl:copy>
        <xsl:for-each-group select="$person-role-nodes" group-by="local-name()">
            <xsl:element name="role" namespace="tag:textalign.net,2015:ns">
                <xsl:attribute name="xml:id" select="current-grouping-key()"/>
                <xsl:attribute name="which" select="current-grouping-key()"/>
            </xsl:element>
        </xsl:for-each-group>
    </xsl:template>
    <xsl:template match="tan:resp" mode="adjust-template">
        <xsl:copy-of select="."/>
        <xsl:if test="not(exists(following-sibling::tan:resp))">
            <xsl:for-each-group select="$person-role-nodes-checked" group-by="name()">
                <xsl:element name="resp" namespace="tag:textalign.net,2015:ns">
                    <xsl:attribute name="roles" select="current-grouping-key()"/>
                    <xsl:attribute name="who">
                        <xsl:for-each select="current-group()">
                            <xsl:if test="position() gt 1">
                                <xsl:text> </xsl:text>
                            </xsl:if>
                            <xsl:variable name="this-agent-iri" select="*:IRI"/>
                            <xsl:variable name="this-agent"
                                select="$agent-glossary[tan:IRI = $this-agent-iri]"/>
                            <xsl:choose>
                                <xsl:when test="exists($this-agent)">
                                    <xsl:value-of 
                                        select="lower-case(replace($this-agent/tan:name[1], '\W', ''))"/>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:value-of select="'agent???'"/>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:for-each>
                    </xsl:attribute>
                </xsl:element>
            </xsl:for-each-group> 
        </xsl:if>
    </xsl:template>


    <xsl:template match="* | comment() | processing-instruction() | @*" mode="adjust-vocabularies">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="text()" mode="adjust-vocabularies">
        <xsl:value-of select="tan:normalize-text(.)"/>
    </xsl:template>


    <xsl:template match="tei:TEI">
        <!-- Here we copy things such as the root @id and @TAN-ver -->
        <xsl:copy>
            <xsl:copy-of select="$self-resolved/*/@*"/>
            <xsl:apply-templates/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="tei:teiHeader">
        <xsl:copy-of select="." copy-namespaces="no"/>
        <xsl:copy-of select="$self-resolved/*/tan:head" copy-namespaces="no"/>
    </xsl:template>
    <xsl:template match="tei:body">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:copy-of select="$self-resolved//tei:body/@*"/>
            <xsl:apply-templates/>
        </xsl:copy>
    </xsl:template>
    <xsl:template
        match="tei:div | tei:div1 | tei:div2 | tei:div3 | tei:div4 | tei:div5 | tei:div6 | tei:div7 | tei:div8 | tei:div9">
        <xsl:variable name="is-div-to-be-skipped" as="xs:boolean"
            select="parent::tei:body and count(../(tei:div, tei:div1)) = 1"/>
        <xsl:variable name="children-are-divs-and-other-elements"
            select="
                exists((tei:div | tei:div1 | tei:div2 | tei:div3 | tei:div4 | tei:div5 | tei:div6 | tei:div7 | tei:div8 | tei:div9))
                and exists(*[not(matches(local-name(), '^div'))])"/>
        <xsl:choose>
            <xsl:when test="$is-div-to-be-skipped">
                <xsl:apply-templates>
                    <xsl:with-param name="has-mixed-siblings"
                        select="$children-are-divs-and-other-elements"/>
                </xsl:apply-templates>
            </xsl:when>
            <xsl:otherwise>
                <div type="" n="">
                    <xsl:copy-of select="@*"/>
                    <xsl:apply-templates>
                        <xsl:with-param name="parent-is-div" select="true()"/>
                        <xsl:with-param name="has-mixed-siblings"
                            select="$children-are-divs-and-other-elements"/>
                    </xsl:apply-templates>
                </div>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="tei:*">
        <!-- We assume, from another template, that this has not caught any tei elements in the div family -->
        <xsl:param name="parent-is-div" as="xs:boolean" select="false()"/>
        <xsl:param name="has-mixed-siblings" as="xs:boolean" select="false()"/>
        <xsl:variable name="is-in-body" select="exists(ancestor::tei:body)"/>
        <xsl:variable name="children-names"
            select="
                for $i in *
                return
                    local-name($i)"
            as="xs:string*"/>
        <xsl:variable name="this-name" select="local-name()"/>
        <xsl:variable name="preceding-sibling-namesakes"
            select="preceding-sibling::*[local-name() = $this-name]"/>
        <xsl:choose>
            <xsl:when test="not(exists(preceding-sibling::*)) and text() = ../@n">
                <xsl:comment>
                    <xsl:text>Duplicate of @n? In TAN, the best practice for reference numbers in the text is to treat them as metadata and delete.</xsl:text>
                </xsl:comment>
                <xsl:comment><xsl:value-of select="tan:xml-to-string(.)"/></xsl:comment>
            </xsl:when>
            <xsl:when test="$has-mixed-siblings">
                <xsl:choose>
                    <xsl:when
                        test="local-name() = 'head' and count(distinct-values($children-names)) = 1 and $children-names = ('title')">
                        <xsl:for-each select="*">
                            <div type="{local-name()}"
                                n="{local-name()}{if (exists($preceding-sibling-namesakes)) then count($preceding-sibling-namesakes) + 1 else ()}">
                                <ab><xsl:value-of select="."/></ab>
                            </div>
                        </xsl:for-each>
                    </xsl:when>
                    <xsl:otherwise>
                        <div type="{local-name()}"
                            n="{local-name()}{if (exists($preceding-sibling-namesakes)) then count($preceding-sibling-namesakes) + 1 else ()}">
                            <xsl:apply-templates select="node()"/>
                        </div>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy>
                    <xsl:apply-templates select="@* | node()"/>
                </xsl:copy>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>


    <xsl:template match="node() | @*" mode="build-div-types-and-clean-ns">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    <!--<xsl:variable name="div-type-glossary"
        select="tan:glossary('div-type', (), $extra-vocabularies-cleaned, ())"/>-->
    <xsl:variable name="div-type-glossary" select="tan:vocabulary('div-type', ())"/>
    <xsl:template match="tan:div-type[not(exists(following-sibling::tan:div-type))]"
        mode="build-div-types-and-clean-ns">
        <xsl:copy-of select="."/>
        <xsl:variable name="div-type-ids" select="../tan:div-type/@xml:id"/>
        <xsl:variable name="div-types-used" select="root()//tei:body//tei:div/@type"/>
        <xsl:for-each-group select="$div-types-used[not(. = $div-type-ids)]" group-by=".">
            <xsl:variable name="this-div-type" select="current-grouping-key()"/>
            <xsl:variable name="div-type-matches" as="element()*">
                <xsl:copy-of select="$div-type-glossary[tan:name = $this-div-type]"/>
                <xsl:copy-of
                    select="
                        $div-type-glossary[some $i in tan:name
                            satisfies matches($i, $this-div-type)]"
                />
            </xsl:variable>
            <xsl:element name="div-type" namespace="tag:textalign.net,2015:ns">
                <xsl:attribute name="xml:id" select="."/>
                <xsl:choose>
                    <xsl:when test="exists($div-type-matches)">
                        <xsl:attribute name="which" select="$div-type-matches[1]/tan:name[1]"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:element name="IRI" namespace="tag:textalign.net,2015:ns">
                            <xsl:text>urn:fill-me-out</xsl:text>
                        </xsl:element>
                        <xsl:element name="name" namespace="tag:textalign.net,2015:ns">
                            <xsl:text>give me a name</xsl:text>
                        </xsl:element>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:element>
        </xsl:for-each-group>
    </xsl:template>
    <xsl:template match="tei:div[string-length(@n) lt 1]" mode="build-div-types-and-clean-ns">
        <xsl:variable name="this-type" select="@type"/>
        <xsl:variable name="previous-sibling-namesakes"
            select="preceding-sibling::tei:div[@type = $this-type]"/>
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:attribute name="n"
                select="
                    concat(@type, if (exists($previous-sibling-namesakes)) then
                        string(count($previous-sibling-namesakes) + 1)
                    else
                        ())"/>
            <xsl:copy-of select="node()"/>
        </xsl:copy>
    </xsl:template>




    <xsl:variable name="pass1" as="document-node()">
        <xsl:document>
            <!-- Iteration ensures we can put a new line  before each top-level node, for legibility. -->
            <xsl:for-each
                select="$self-resolved/processing-instruction()[1]/(self::processing-instruction(), following-sibling::processing-instruction(), following-sibling::comment()[matches(., '\?xml-model')])">
                <xsl:text>&#xa;</xsl:text>
                <xsl:copy-of select="."/>
            </xsl:for-each>
            <xsl:text>&#xa;</xsl:text>
            <xsl:variable name="pass1a">
                <xsl:apply-templates select="/*"/>
            </xsl:variable>
            <xsl:apply-templates select="$pass1a" mode="build-div-types-and-clean-ns"/>
        </xsl:document>
    </xsl:variable>

    <xsl:template match="/">
        <!-- diagnostics, results -->
        <!--<xsl:copy-of select="$pass1"/>-->
        <!--<xsl:copy-of select="$extra-vocabularies-resolved"/>-->
        <!--<xsl:copy-of select="$agent-glossary"/>-->
        <!--<temp><xsl:copy-of select="$agent-role-nodes-checked"/></temp>-->
        <xsl:apply-templates select="$pass1" mode="credit-stylesheet"/>

    </xsl:template>

</xsl:stylesheet>
