<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns="tag:textalign.net,2015:ns"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:math="http://www.w3.org/2005/xpath-functions/math"
    xmlns:docbook="http://docbook.org/ns/docbook"
    xmlns:saxon="http://icl.com/saxon" xmlns:lxslt="http://xml.apache.org/xslt"
    xmlns:redirect="http://xml.apache.org/xalan/redirect" xmlns:exsl="http://exslt.org/common"
    xmlns:doc="http://nwalsh.com/xsl/documentation/1.0" xmlns:xlink="http://www.w3.org/1999/xlink"
    xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:rng="http://relaxng.org/ns/structure/1.0"
    xmlns:sch="http://purl.oclc.org/dsdl/schematron"
    xmlns:fn="http://www.w3.org/2005/xpath-functions" xmlns:tan="tag:textalign.net,2015:ns"
    xmlns:a="http://relaxng.org/ns/compatibility/annotations/1.0"
    xmlns:sqf="http://www.schematron-quickfix.com/validator/process"
    extension-element-prefixes="saxon redirect lxslt exsl"
    exclude-result-prefixes="#all" version="3.0">
    
    <!--Functions for analyzing the TAN schemas, using ../schemas/*.rng for analysis. This
                stylesheet is used primarily to generate the documentation, not for core validation,
                but it may be useful in other contexts.-->
    <xsl:variable name="schema-collection" select="collection('../../schemas/collection.xml')"/>
    <xsl:variable name="rng-collection" select="$schema-collection[rng:*]"/>
    <xsl:variable name="rng-collection-without-TEI"
        select="$rng-collection[not(matches(base-uri(.), 'TAN-TEI'))]"/>
    
    <xsl:variable name="TAN-elements-that-take-the-attribute-which"
        select="
            tan:get-parent-elements($rng-collection-without-TEI/rng:grammar/rng:define[rng:attribute/@name = 'which'])"
    />

    <xsl:function name="tan:get-parent-elements" as="element()*">
        <!-- requires as input some rng: element from $rng-collection, oftentimes an rng:element or rng:attribute -->
        <xsl:param name="current-elements" as="element()*"/>
        <xsl:variable name="elements-to-define" select="$current-elements[self::rng:define]"/>
        <xsl:choose>
            <xsl:when test="exists($elements-to-define)">
                <xsl:variable name="new-elements"
                    select="
                        for $i in $elements-to-define/@name
                        return
                            $rng-collection-without-TEI//rng:ref[@name = $i]//(ancestor::rng:define,
                            ancestor::rng:element)[last()]"/>
                <xsl:copy-of
                    select="
                        tan:get-parent-elements((($current-elements except $current-elements[name(.) = 'define']),
                        $new-elements))"
                />
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy-of select="$current-elements"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
</xsl:stylesheet>
