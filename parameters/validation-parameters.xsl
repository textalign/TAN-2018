<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="tag:textalign.net,2015:ns" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:fn="http://www.w3.org/2005/xpath-functions" xmlns:tei="http://www.tei-c.org/ns/1.0"
   xmlns:math="http://www.w3.org/2005/xpath-functions/math" xmlns:functx="http://www.functx.com"
   xmlns:sch="http://purl.oclc.org/dsdl/schematron" exclude-result-prefixes="#all" version="2.0">

   <!-- The parameters in this file are to be used in the core validation function files. -->

   <!-- This is a special set of parameters with low import precedence, to optimize time spent in Schematron validation -->
   <xsl:param name="validation-is-terse" as="xs:boolean" select="false()"/>
   <xsl:param name="validation-is-normal" as="xs:boolean" select="false()"/>
   <xsl:param name="validation-is-verbose" as="xs:boolean" select="false()"/>
   <xsl:param name="validation-phase" as="xs:string">
      <xsl:choose>
         <xsl:when test="$validation-is-verbose">
            <xsl:value-of select="'verbose'"/>
         </xsl:when>
         <xsl:when test="$validation-is-normal">
            <xsl:value-of select="'normal'"/>
         </xsl:when>
         <xsl:when test="$validation-is-terse">
            <xsl:value-of select="'terse'"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:value-of select="$validation-phase-names[3]"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:param>
   
   <!-- Shall error messages part of the validation process also be passed on as an xslt message (primarily affects transformations)? -->
   <xsl:param name="error-messages-on" as="xs:boolean" select="false()"/>
   
   <!-- What string in an attribute value should be interpreted as a request for help? -->
   <xsl:param name="help-trigger" select="'???'"/>
   
   <!-- Schematron validation will override this value; setting it to false() ensures that non-validation algorithms using the function library get richer results -->
   <xsl:param name="is-validation" as="xs:boolean" select="false()"/>
   
   <!-- How many loops should be tolerated in a recursive function before exiting? -->
   <xsl:param name="loop-tolerance" as="xs:integer" select="550"/>
   
   <!-- Should validation routines avoid checking non-local files (those available only on the Internet)? -->
   <xsl:param name="do-not-access-internet" as="xs:boolean" select="false()"/>
   
   <!-- What should the default whitespace indentation value be? -->
   <xsl:param name="indent-value" select="3"/>
   
   <!-- During expansion, should every value for every attribute that points to a vocabulary item have the vocabulary imprinted with the value? This is used primarily in non-validation applications where immediate, quick access to the vocabulary is required. Caution: setting this value to true may result in very large files. -->
   <xsl:param name="distribute-vocabulary" select="false()"/>
   
</xsl:stylesheet>
