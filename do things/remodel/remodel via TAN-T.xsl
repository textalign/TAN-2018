<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns="tag:textalign.net,2015:ns"
    xmlns:html="http://www.w3.org/1999/xhtml" xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:tan="tag:textalign.net,2015:ns"
    exclude-result-prefixes="#all" version="2.0">

    <!-- Input: a class 1 file or a non-TAN XML file -->
    <!-- Template: a TAN-T (not TAN-TEI) -->
    <!-- Output: the text content of the input file proportionally divided up as the new content of the template -->

    <!-- If the input is not TAN, then there is no way for the algorithm to figure out what the correct metadata is for the output file. Errors are likely. -->


    <xsl:import href="../get%20inclusions/convert.xsl"/>
    <xsl:output indent="no"/>


    <xsl:param name="stylesheet-iri" select="'tag:textalign.net,2015:stylesheet:remodel-via-tan-t'"/>
    <xsl:param name="change-message">
        <xsl:text>Input from </xsl:text>
        <xsl:value-of select="base-uri(/)"/>
        <xsl:text> proporitionally inserted into template at </xsl:text>
        <xsl:value-of select="$template-url-resolved"/>
    </xsl:param>

    <xsl:param name="exclude-what-input-div-types" select="('ti', 'summ')" as="xs:string*"/>
    <xsl:variable name="some-text-has-been-cut" select="exists($input-precheck//tan:div[@type = $exclude-what-input-div-types])" as="xs:boolean"/>

    <xsl:variable name="input-namespace-prefix" select="tan:namespace($input-namespace)"/>
    <xsl:variable name="input-namespace" select="tan:namespace(/*)"/>
    <xsl:variable name="input-precheck" as="document-node()?">
        <xsl:choose>
            <xsl:when test="$doc-class = 1">
                <xsl:sequence select="/"/>
            </xsl:when>
            <xsl:when test="not(tan:namespace($input-namespace) = ('tan', 'tei'))">
                <xsl:message
                    select="concat('Processing input in namespace ', $input-namespace-prefix)"/>
                <xsl:document>
                    <TAN-T>
                        <head>
                            <xsl:comment>metadata needs to be filled in by hand</xsl:comment>
                            <definitions/>
                        </head>
                        <body>
                            <xsl:value-of select="normalize-space(string-join(//text(), ''))"/>
                        </body>
                    </TAN-T>
                </xsl:document>
            </xsl:when>
            <xsl:otherwise>
                <xsl:message select="concat('Input at ', base-uri(/), ' is unexpected')"
                    terminate="yes"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>
    <xsl:param name="input-items" select="$input-precheck"/>
    <xsl:param name="input-base-uri" select="base-uri(/)"/>
    <xsl:variable name="this-see-also" as="element()?">
        <xsl:if test="$some-text-has-been-cut = false()">
            <see-also relationship="ade">
                <IRI>
                    <xsl:value-of select="root()/*/@id"/>
                </IRI>
                <xsl:copy-of select="root()/*/tan:head/tan:name"/>
                <location href="{$input-base-uri}" when-accessed="{current-date()}"/>
            </see-also>
        </xsl:if>
    </xsl:variable>
    <xsl:variable name="this-relationship" as="element()?">
        <xsl:if test="$some-text-has-been-cut = false()">
            <relationship xml:id="ade" which="resegmented copy"/>
        </xsl:if>
    </xsl:variable>

    <xsl:template match="tan:see-also[1]" mode="input-pass-1">
        <xsl:copy-of select="$this-see-also"/>
        <xsl:copy-of select="."/>
    </xsl:template>
    <xsl:template match="tan:definitions" mode="input-pass-1">
        <xsl:if test="not(exists(../tan:see-also))">
            <xsl:copy-of select="$this-see-also"/>
        </xsl:if>
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:copy-of select="$template-doc/tan:TAN-T/tan:head/tan:definitions/tan:div-type"/>
            <xsl:apply-templates select="node() except tan:div-type" mode="#current"/>
            <xsl:if test="not(exists(tan:relationship))">
                <xsl:copy-of select="$this-relationship"/>
            </xsl:if>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="tan:relationship[1]" mode="input-pass-1">
        <xsl:copy-of select="$this-relationship"/>
        <xsl:copy-of select="."/>
    </xsl:template>
    <xsl:template match="tan:div" mode="input-pass-1">
        <xsl:if test="not(@type = $exclude-what-input-div-types)">
            <xsl:copy>
                <xsl:copy-of select="@*"/>
                <xsl:apply-templates mode="#current"/>
            </xsl:copy>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="*:body" mode="input-pass-2">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:copy-of select="tan:div-to-div-transfer(., $template-doc/tan:TAN-T/tan:body, $break-at-regex)/*"/>
        </xsl:copy>
    </xsl:template>


    <!--<xsl:param name="template-url-relative-to-input" as="xs:string?"
        select="($head/tan:see-also/tan:location/@href)[1]"/>-->
    <xsl:param name="template-url-relative-to-input" as="xs:string?" select="'ar.cat.grc.1949.minio-paluello.sem-native.xml'"/>
    <xsl:variable name="template-body-analyzed" as="element()?">
        <xsl:choose>
            <xsl:when test="$template-doc/tan:TAN-T">
                <xsl:copy-of select="tan:analyze-string-length($template-doc/tan:TAN-T/tan:body)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:message terminate="yes"
                    select="concat('Template at URL ', $template-url-relative-to-input, ' is not a TAN-T file')"
                />
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>

    <xsl:variable name="template-resolved" select="tan:resolve-doc($template-doc)"/>
    <xsl:variable name="template-leaf-div-types" select="$template-resolved//tan:div[not(tan:div)]/@type"/>
    <xsl:variable name="majority-leaf-div-type" select="tan:most-common-item($template-leaf-div-types)"/>
    <xsl:variable name="majority-leaf-div-type-definition"
        select="$template-resolved/tan:TAN-T/tan:head/tan:definitions/tan:div-type[@xml:id = $majority-leaf-div-type]"
    />
    <xsl:param name="template-reference-system-is-based-on-physical-features" as="xs:boolean"
        select="tokenize($majority-leaf-div-type-definition/@orig-group, ' ') = 'physical'"/>
    <xsl:param name="break-at-regex"
        select="
            if ($template-reference-system-is-based-on-physical-features) then
            '\s+'
            else
            '[\.,;\?!]+\p{P}*'"
    />

    <xsl:param name="template-infused-with-revised-input" select="$input-pass-2"/>


    <xsl:param name="output-url-relative-to-input" as="xs:string?"
        select="replace($input-base-uri, '(\.[^\.]+$)', concat('-', format-date(current-date(), '[Y0001]-[M01]-[D01]'), '$1'))"/>

    <xsl:template match="/" priority="5">
        <!-- diagnostics -->
        <diagnostics>
            <!--<xsl:copy-of select="$input-precheck"/>-->
            <!--<xsl:copy-of select="$template-doc"/>-->
            <!--<xsl:copy-of select="$template-body-analyzed"/>-->
            <!--<xsl:copy-of select="$output-url-resolved"/>-->
            <!--<xsl:copy-of select="tan:resolve-doc($template-doc)"/>-->
            <!--<xsl:copy-of select="tan:expand-doc($template-doc, 'terse')"/>-->
            <!--<xsl:copy-of select="$input-pass-1"/>-->
            <xsl:copy-of select="$input-pass-2"/>
            <!--<test06a><xsl:copy-of select="$majority-leaf-div-type"/></test06a>-->
            <!--<test06a><xsl:copy-of select="$template-resolved/tan:TAN-T/tan:head/tan:definitions/tan:div-type"/></test06a>-->
            <!--<test06b><xsl:copy-of select="$majority-leaf-div-type-definition"/></test06b>-->
            <!--<test06c><xsl:copy-of select="$template-reference-system-is-based-on-physical-features"/></test06c>-->
        </diagnostics>
    </xsl:template>

</xsl:stylesheet>
