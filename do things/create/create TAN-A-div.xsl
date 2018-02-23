<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns="tag:textalign.net,2015:ns"
    xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:tan="tag:textalign.net,2015:ns" exclude-result-prefixes="#all" version="2.0">
    <!-- Input: any class 1 file -->
    <!-- Template: a TAN-A-div file -->
    <!-- Output: a TAN-A-div file populated with local files that use the file as a model, or use the file's model as a model -->
    <xsl:import href="../get%20inclusions/convert.xsl"/>
    <xsl:output indent="yes"/>

    <xsl:param name="validation-phase" select="'terse'"/>
    <xsl:variable name="input-root" select="/"/>
    
    <xsl:variable name="stylesheet-iri"
        select="'tag:textalign.net,2015:stylesheet:create-tan-a-div'"/>
    <xsl:variable name="change-message" select="concat('Created TAN-A-div from ', $doc-id, ' and nearby class 1 files that share the same model')"/>
    
    <xsl:variable name="this-model"
        select="($head/tan:see-also[tan:definition(tan:relationship)/tan:name = 'model'])[1]"/>
    <xsl:variable name="other-versions-of-this-work" as="document-node()*">
        <xsl:for-each select="$local-TAN-collection">
            <xsl:variable name="this-doc-resolved" select="tan:resolve-doc(.)"/>
            <xsl:variable name="model-id-ref"
                select="$this-doc-resolved/*/tan:head/tan:definitions/tan:relationship[tan:name = 'model']/@xml:id"/>
            <xsl:variable name="this-doc-model"
                select="$this-doc-resolved/*/tan:head/(tan:see-also[@relationship = $model-id-ref])[1]"/>
            <xsl:if
                test="($this-doc-resolved/*/@id, $this-doc-model/tan:IRI) = ($this-model/tan:IRI, $doc-id)">
                <xsl:sequence select="$this-doc-resolved"/>
            </xsl:if>
        </xsl:for-each>
    </xsl:variable>
    <xsl:param name="input-pass-1" as="element()*">
        <xsl:for-each select="$other-versions-of-this-work">
            <source xml:id="s{position()}-{*//*:body/@xml:lang}">
                <IRI>
                    <xsl:value-of select="*/@id"/>
                </IRI>
                <name>
                    <xsl:value-of select="*/tan:head/tan:name[1]"/>
                </name>
                <location href="{*/@base-uri}" when-accessed="{current-date()}"/>
            </source>
        </xsl:for-each>
    </xsl:param>
    
    
    <!-- TEMPLATE -->
    <xsl:param name="template-url-relative-to-this-stylesheet" as="xs:string?"
        select="'../configure%20templates/template-TAN-A-div.xml'"/>
    
    <xsl:template match="tan:TAN-A-div" mode="infuse-template">
        <xsl:copy>
            <xsl:copy-of select="@* except @id"/>
            <!-- @id is intentionally invalid, because it needs to be created by hand -->
            <xsl:attribute name="id" select="concat('tag;',$doc-namespace, ':tan-a-div ', $today-iso)"/>
            <xsl:apply-templates mode="#current"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="tan:license" mode="infuse-template">
        <xsl:copy-of select="$input-root/*/tan:head/tan:license"/>
    </xsl:template>
    <xsl:template match="tan:licensor" mode="infuse-template">
        <xsl:copy-of select="$input-root/*/tan:head/tan:licensor"/>
    </xsl:template>
    <xsl:template match="tan:source" mode="infuse-template">
        <!--<xsl:copy-of select=""/>-->
        <xsl:apply-templates select="$input-root/*/tan:head/tan:key" mode="resolve-href"/>
        <xsl:copy-of select="$input-pass-1"/>
    </xsl:template>
    <xsl:template match="tan:person" mode="infuse-template">
        <xsl:copy-of select="$input-root/*/tan:head/tan:definitions/tan:person"/>
    </xsl:template>
    <xsl:template match="tan:change" mode="infuse-template">
        <xsl:copy>
            <xsl:attribute name="when" select="current-date()"/>
            <xsl:copy-of select="$input-root/*/tan:head/tan:licensor/@who"/>
            <xsl:text>Created file</xsl:text>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="tan:resp" mode="infuse-template">
        <xsl:copy>
            <xsl:copy-of select="@roles"/>
            <xsl:copy-of select="$input-root/*/tan:head/tan:licensor/@who"/>
        </xsl:copy>
    </xsl:template>
    


    <!--<xsl:template match="/" priority="5">
        <!-\-<test15a>
            <!-\\-<xsl:copy-of select="count($local-TAN-collection)"/>-\\->
            <!-\\-<xsl:copy-of select="count($other-versions-of-this-work)"/>-\\->
            <!-\\-<xsl:copy-of select="tan:shallow-copy($other-versions-of-this-work/*)"/>-\\->
            <!-\\-<xsl:copy-of select="$local-catalog"/>-\\->
            <!-\\-<xsl:copy-of select="$input-pass-1"/>-\\->
            <!-\\-<xsl:copy-of select="$template-doc"/>-\\->
            <xsl:copy-of select="$template-infused-with-revised-input"/>
        </test15a>-\->
    </xsl:template>-->
</xsl:stylesheet>
