<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:tan="tag:textalign.net,2015:ns" xmlns="tag:textalign.net,2015:ns"
   xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:map="http://www.w3.org/2005/xpath-functions/map"
   xmlns:fn="http://www.w3.org/2005/xpath-functions" xmlns:xs="http://www.w3.org/2001/XMLSchema"
   xmlns:tei="http://www.tei-c.org/ns/1.0" exclude-result-prefixes="#all" version="3.0">
   <!-- Core global parameters, primarily for ../get inclusions/core-for-TAN-output.xsl -->
   <!-- This stylesheet is meant to be imported (not included) by other stylesheets. -->

   <!-- If the output is a TAN file, the stylesheet should be credited/blamed. That is done primarily through an IRI assigned to the stylesheet -->
   <xsl:param name="stylesheet-iri" as="xs:string" required="yes"/>
   
   <!-- This parameter needs to be redefined at the master stylesheet level, otherwise this parameters file uri will be returned -->
   <xsl:param name="stylesheet-url" as="xs:string" required="yes"/>
   
   <!-- What message should be recorded when saving? -->
   <xsl:param name="change-message" as="xs:string*" required="yes"/>
   
   <!-- Saving and retrieving intermediate steps -->
   
   <!-- Should select intermediate results be saved along the way? -->
   <xsl:param name="save-intermediate-steps" select="false()" as="xs:boolean"/>

   <!-- Where should intermediate results be saved? -->
   <xsl:param name="save-intermediate-steps-location-relative-to-initial-input" select="'tmp'"/>

   <!-- Should previously saved intermediate results be fetched, if available? -->
   <xsl:param name="use-saved-intermediate-steps" select="false()" as="xs:boolean"/>
   
</xsl:stylesheet>
