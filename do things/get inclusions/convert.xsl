<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns="http://www.w3.org/1999/xhtml" xmlns:html="http://www.w3.org/1999/xhtml"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:tan="tag:textalign.net,2015:ns"
    xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
    exclude-result-prefixes="#all" version="2.0">
    <xsl:import href="core-for-TAN-output.xsl"/>
    
    <xsl:include href="../../functions/TAN-A-div-functions.xsl"/>
    <xsl:include href="../../functions/TAN-extra-functions.xsl"/>
    <xsl:include href="xslt-for-docx/open-and-save-docx.xsl"/>

    <!--<xsl:output indent="no"/>-->
    <xsl:output indent="yes"/>

    <!-- This stylesheet is written primarily to help files of one type be converted to another. -->
    <!-- In normal use, a master stylesheet would import this one, re-defining (if need be) any parameters below, and detailing the stages that should take place at each level of transformation -->

    <!-- At the heart of this stylesheet is a particular approach to conversion that follows these steps:
    1. Strip away what you don't want from the input
    2. Add and change what you want to the input (including a wholesale change of namespace, if going to a different format)  
    3. Get a template that looks like what you want the final output to be
    4. Pour the altered input into the template -->

    <!-- Input: Any XML file; the actual input file is determined by the parameters below -->
    <!-- Main parameter: any XML file intended to be converted -->
    <!-- Main parameter: a series of passes where the input is converted -->
    <!-- Main parameter: a template in the target format (see 'do things/get templates' for examples) -->
    <!-- Main parameter: a string indicating what element in the template should be replaced by the revised input -->
    <!-- Main parameter: a target url where the results should be saved -->
    <!-- Output: the input in parameter 1, tranformed by the templates in parameter 2, and inserted into parameter 3 at element with content in parameter 4, saved at location parameter 5 -->
    <!-- See other parameters below -->


    <!-- Set up this stylesheet to imprint its changes -->
    <xsl:param name="stylesheet-iri" select="'tag:textalign.net,2015:stylesheet:convert'"/>
    <xsl:param name="change-message" as="xs:string*">
        <xsl:text>Conversion from </xsl:text>
        <xsl:value-of
            select="
                for $i in $input-items/*
                return
                    name($i)"
        />
        <xsl:text> to </xsl:text>
        <xsl:value-of select="$target-format"/>
    </xsl:param>



    <!-- Main parameter -->
    <xsl:param name="input-items" as="item()*" select="$self-expanded"/>
    <xsl:variable name="input-base-uri" select="tan:base-uri($input-items[1])"/>



    <!-- Main parameter -->
    <xsl:param name="template-url-relative-to-this-stylesheet" as="xs:string?"
        select="'../configure%20templates/template.html'"/>
    <xsl:param name="template-url-relative-to-input" as="xs:string?"/>
    <xsl:variable name="template-url-resolved"
        select="
                if (string-length($template-url-relative-to-input) gt 0) then
                    resolve-uri($template-url-relative-to-input, $input-base-uri)
                else
                    resolve-uri($template-url-relative-to-this-stylesheet, static-base-uri())"/>
    <xsl:variable name="template-extension"
        select="replace($template-url-resolved, '.+/([^/]+)$', '$1')"/>
    
    <xsl:param name="template-doc" as="document-node()*">
        <xsl:choose>
            <xsl:when test="$template-extension = 'docx'">
                <xsl:copy-of select="tan:open-docx($template-url-resolved)"/>
            </xsl:when>
            <xsl:when test="doc-available($template-url-resolved)">
                <xsl:copy-of select="doc($template-url-resolved)"/>
            </xsl:when>
            <xsl:when test="unparsed-text-available($template-url-resolved)">
                <xsl:document>
                    <xsl:element name="unparsed-text" namespace="''">
                        <xsl:copy-of select="unparsed-text($template-url-resolved)"/>
                    </xsl:element>
                </xsl:document>
            </xsl:when>
        </xsl:choose>
    </xsl:param>
    
    <xsl:variable name="template-root-element-name" select="name($template-doc[1]/*)"/>
    <xsl:variable name="template-namespace" select="namespace-uri($template-doc[1]/*)"/>
    <xsl:variable name="template-namespace-prefix" select="tan:namespace($template-namespace)"/>
    
    <xsl:variable name="target-format" as="xs:string?">
        <xsl:choose>
            <xsl:when test="$template-namespace = 'http://schemas.openxmlformats.org/package/2006/relationships'">
                <xsl:text>docx</xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <!-- for the time being, we are worried only about target formats that require special treatment, i.e., docx -->
                <xsl:text>xml</xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>
    
    


    <!-- Main parameter -->
    <!-- By default, any element whose text matches this string exactly will be replaced by the revised input -->
    <xsl:param name="replace-template-element-with-text-content" as="xs:string" select="'new-content'"/>




    <!-- Main parameter -->
    <xsl:param name="output-url-relative-to-this-stylesheet" as="xs:string?" select="''"/>
    <xsl:param name="output-url-relative-to-input" as="xs:string?" select="'test.html'"/>
    <xsl:variable name="output-url-resolved"
        select="
                if (string-length($output-url-relative-to-input) gt 0) then
                    resolve-uri($output-url-relative-to-input, $input-base-uri)
                else
                    resolve-uri($output-url-relative-to-this-stylesheet, static-base-uri())"/>


    

    <!-- Now the process begins -->
    <xsl:param name="input-pass-1" as="item()*">
        <xsl:apply-templates select="$input-items" mode="input-pass-1"/>
    </xsl:param>
    <xsl:param name="input-pass-2" as="item()*">
        <xsl:apply-templates select="$input-pass-1" mode="input-pass-2"/>
    </xsl:param>
    <xsl:param name="input-pass-3" as="item()*">
        <xsl:apply-templates select="$input-pass-2" mode="input-pass-3"/>
    </xsl:param>
    <xsl:param name="input-pass-4" as="item()*">
        <xsl:apply-templates select="$input-pass-3" mode="input-pass-4"/>
    </xsl:param>

    <xsl:param name="template-infused-with-revised-input" as="document-node()*">
        <xsl:apply-templates select="$template-doc" mode="infuse-template">
            <xsl:with-param name="new-content" select="$input-pass-4" tunnel="yes"/>
        </xsl:apply-templates>
    </xsl:param>
    <xsl:param name="infused-template-revised" as="document-node()*">
        <xsl:apply-templates select="$template-infused-with-revised-input"
            mode="infused-template-revised"/>
    </xsl:param>

    <xsl:template match="*" mode="infuse-template">
        <xsl:param name="new-content" tunnel="yes"/>
        <!-- we arrange the text value this way because some docx files will have text content that's split between <w:r>s -->
        <xsl:variable name="this-text" select="string-join(.//text(), '')"/>
        <xsl:choose>
            <xsl:when test="$this-text = $replace-template-element-with-text-content">
                <xsl:copy-of select="$new-content"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy>
                    <xsl:copy-of select="@*"/>
                    <xsl:apply-templates mode="#current"/>
                </xsl:copy>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template match="/">
        <!-- diagnostics, results -->
        <!--<test56>
            <test56a><xsl:copy-of select="$input-uri-resolved"/></test56a>
            <test56b><xsl:copy-of select="$input-base-uri"/></test56b>
            <test56c><xsl:copy-of select="tan:shallow-copy($input-items[1]/*)"/></test56c>
        </test56>-->
        <!--<xsl:copy-of select="$input-pass-1"/>-->
        <xsl:copy-of select="$input-pass-2"/>
        <!--<xsl:copy-of select="$input-pass-3"/>-->
        <!--<xsl:copy-of select="$input-pass-4"/>-->
        <!--<xsl:copy-of select="$template-infused-with-revised-input"/>-->
        <!--<xsl:copy-of select="$infused-template-revised"/>-->
        <!--<xsl:if test="string-length($output-url-resolved) gt 0">
            <xsl:choose>
                <xsl:when test="$target-format = 'docx'">
                    <xsl:call-template name="tan:save-docx">
                        <xsl:with-param name="docx-parts"
                            select="$infused-template-revised"/>
                        <xsl:with-param name="resolved-uri" select="$output-url-resolved"/>
                    </xsl:call-template>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:result-document href="{$output-url-resolved}">
                        <!-\- diagnostics, results -\->
                        <!-\-<xsl:copy-of select="$input-items"/>-\->
                        <!-\-<xsl:copy-of select="$input-pass-3"/>-\->
                        <!-\-<xsl:copy-of select="$template-infused-with-revised-input"/>-\->
                        <xsl:copy-of select="$infused-template-revised"/>
                    </xsl:result-document>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:if>-->
    </xsl:template>

</xsl:stylesheet>
