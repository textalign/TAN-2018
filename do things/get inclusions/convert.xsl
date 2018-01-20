<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns="http://www.w3.org/1999/xhtml" xmlns:html="http://www.w3.org/1999/xhtml"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tei="http://www.tei-c.org/ns/1.0"
   xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
   exclude-result-prefixes="#all" version="2.0">

   <xsl:include href="core-for-TAN-output.xsl"/>
   <xsl:include href="../../functions/TAN-A-div-functions.xsl"/>
   <xsl:include href="../../functions/TAN-extra-functions.xsl"/>
   <xsl:include href="xslt-for-docx/open-and-save-docx.xsl"/>

   <!--<xsl:output indent="no"/>-->
   <xsl:output indent="yes" use-character-maps="tan"/>

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


   <!-- Set up default values if the output is TAN -->
   <xsl:param name="stylesheet-iri" select="'tag:textalign.net,2015:stylesheet:convert'"/>
   <xsl:param name="change-message" as="xs:string*"
      select="
         concat('Conversion of input at ', $input-base-uri, ' to ', $template-root-element-name, ' at ', $output-url-resolved)"/>



   <!-- Main parameter: Input -->
   <xsl:param name="input-items" as="item()*" select="$self-expanded"/>
   <xsl:param name="input-base-uri" select="(tan:base-uri($input-items[1]), static-base-uri())[1]"/>
   



   <!-- Main parameter: Template -->
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
            <xsl:sequence select="doc($template-url-resolved)"/>
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
   <xsl:variable name="template-is-openxml" select="$template-namespace-prefix = 'rel'"
      as="xs:boolean"/>




   <!-- Main parameter: What part of the template should be replaced by the revised input? -->
   <!-- By default, any element whose text matches this string exactly will be replaced by the revised input -->
   <xsl:param name="replace-template-element-with-text-content" as="xs:string"
      select="'new-content'"/>




   <!-- Main parameter: Output -->
   <xsl:param name="output-url-relative-to-this-stylesheet" as="xs:string?" select="''"/>
   <xsl:param name="output-url-relative-to-input" as="xs:string?" select="''"/>
   <xsl:param name="output-url-relative-to-template" as="xs:string?" select="''"/>

   <xsl:param name="suffixes-for-multiple-output" as="xs:string*"/>
   <xsl:variable name="output-url-resolved"
      select="
         if (string-length($output-url-relative-to-template) gt 0) then
            resolve-uri($output-url-relative-to-template, $template-url-resolved)
         else
            
            if (string-length($output-url-relative-to-input) gt 0) then
               resolve-uri($output-url-relative-to-input, $input-base-uri)
            else
               resolve-uri($output-url-relative-to-this-stylesheet, static-base-uri())"/>
   <xsl:variable name="output-suffix-count" select="count($suffixes-for-multiple-output)"/>




   <!-- Now the process begins -->
   <!-- Change the input -->
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


   <!-- Infuse the template with the input -->
   <xsl:param name="template-infused-with-revised-input" as="document-node()*">
      <xsl:apply-templates select="$template-doc" mode="infuse-template">
         <xsl:with-param name="new-content" select="$input-pass-4" tunnel="yes"/>
      </xsl:apply-templates>
   </xsl:param>

   <xsl:template match="tan:head" mode="infuse-template">
      <xsl:apply-templates select="." mode="credit-stylesheet"/>
   </xsl:template>
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


   <!-- Revise the newly infused template -->
   <xsl:param name="infused-template-revised" as="document-node()*">
      <xsl:apply-templates select="$template-infused-with-revised-input"
         mode="revise-infused-template"/>
   </xsl:param>

   <xsl:template match="* | comment() | @*" mode="revise-infused-template">
      <xsl:copy>
         <xsl:apply-templates select="node() | @*" mode="#current"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="processing-instruction()" mode="revise-infused-template">
      <xsl:variable name="href-regex" as="xs:string">(href=['"])([^'"]+)(['"])</xsl:variable>
      <xsl:processing-instruction name="{name(.)}">
            <xsl:analyze-string select="." regex="{$href-regex}">
                <xsl:matching-substring>
                    <xsl:value-of select="concat(regex-group(1), tan:uri-relative-to(resolve-uri(regex-group(2), $template-url-resolved), $output-url-resolved), regex-group(3))"/>
                </xsl:matching-substring>
                <xsl:non-matching-substring>
                    <xsl:value-of select="."/>
                </xsl:non-matching-substring>
            </xsl:analyze-string>
        </xsl:processing-instruction>
   </xsl:template>
   <xsl:template match="@href" mode="revise-infused-template">
      <xsl:attribute name="{name(.)}"
         select="tan:uri-relative-to(resolve-uri(., $template-url-resolved), $output-url-resolved)"
      />
   </xsl:template>




   <!-- Generate results -->
   <xsl:template match="/">
      <!-- feedback, diagnostics, results -->
      <!--<xsl:copy-of select="$input-pass-1"/>-->
      <!--<xsl:copy-of select="$input-pass-2"/>-->
      <!--<xsl:copy-of select="$input-pass-3"/>-->
      <!--<xsl:copy-of select="$input-pass-4"/>-->
      <!--<xsl:copy-of select="$template-infused-with-revised-input"/>-->
      <!--<xsl:copy-of select="$infused-template-revised"/>-->
      <xsl:if test="string-length($output-url-resolved) gt 0">
         <xsl:variable name="output" select="$infused-template-revised"/>
         <xsl:variable name="distinct-output-base-uris"
            select="distinct-values($infused-template-revised/*/@base-uri)"/>
         <xsl:variable name="output-count" as="xs:integer"
            select="
               count(if ($template-is-openxml)
               then
                  $distinct-output-base-uris
               else
                  $output)"/>
         <xsl:if test="($output-suffix-count gt 1) and not($output-suffix-count = $output-count)">
            <xsl:message>
               <xsl:value-of
                  select="'The number of suffixes (', $output-suffix-count, ') and output documents (', $output-count, ') do not match. Only the first output will be generated.'"
               />
            </xsl:message>
         </xsl:if>
         <xsl:for-each
            select="
               if (($output-suffix-count gt 0) and ($output-suffix-count = $output-count)) then
                  $suffixes-for-multiple-output
               else
                  ''">
            <xsl:variable name="this-suffix" select="."/>
            <xsl:variable name="this-suffix-encoded-for-uri" select="encode-for-uri(.)"/>
            <xsl:variable name="this-pos" select="position()"/>
            <xsl:variable name="this-target-uri"
               select="replace($output-url-resolved, '(.+)(\.[^\.]+)$', concat('$1', $this-suffix-encoded-for-uri, '$2'))"/>
            <xsl:choose>
               <xsl:when test="$template-is-openxml">
                  <xsl:variable name="this-output"
                     select="$output[*/@base-uri = $distinct-output-base-uris[$this-pos]]"/>
                  <xsl:call-template name="tan:save-docx">
                     <xsl:with-param name="docx-parts" select="$this-output"/>
                     <xsl:with-param name="resolved-uri" select="$this-target-uri"/>
                  </xsl:call-template>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:variable name="this-output" select="$output[$this-pos]"/>
                  <xsl:result-document href="{$this-target-uri}">
                     <xsl:copy-of select="$this-output"/>
                  </xsl:result-document>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:for-each>
      </xsl:if>
   </xsl:template>

</xsl:stylesheet>
