<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns="http://www.w3.org/1999/xhtml" xmlns:html="http://www.w3.org/1999/xhtml"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tei="http://www.tei-c.org/ns/1.0"
   xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
   exclude-result-prefixes="#all" version="3.0">

   <xsl:include href="core-for-TAN-output.xsl"/>
   <xsl:include href="../../functions/TAN-A-functions.xsl"/>
   <xsl:include href="../../functions/TAN-extra-functions.xsl"/>
   <xsl:include href="xslt-for-docx/open-and-save-docx.xsl"/>
   <xsl:include href="save-files.xsl"/>

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
   <!-- Main parameter: a target url where the results should be saved -->
   <!-- Output: the input in parameter 1, tranformed by the templates in parameter 2, and inserted into parameter 3 at element with content in parameter 4, saved at location parameter 5 -->
   <!-- See other parameters below -->

   <xsl:param name="is-validation" select="false()"/>

   <!-- Set up default values if the output is TAN -->
   <xsl:param name="stylesheet-iri" select="'tag:textalign.net,2015:stylesheet:convert'"/>
   <xsl:param name="stylesheet-name">An unnamed stylesheet</xsl:param>
   <xsl:param name="stylesheet-url" select="static-base-uri()"/>
   <xsl:param name="change-message" as="xs:string*"
      select="
         concat('Conversion of input at ', $input-base-uri-resolved, ' to ', $template-root-element-name, ' at ', $output-url-resolved)"/>



   <!-- Main parameter: Input -->
   <xsl:param name="input-items" as="item()*" select="$self-expanded"/>
   <xsl:param name="input-base-uri" select="tan:base-uri($input-items[1])"/>
   <xsl:param name="input-base-uri-resolved" select="($input-base-uri, static-base-uri())[1]"/>



   <!-- Main parameter: Language data -->
   <xsl:param name="languages-used" select="'grc'"/>
   <xsl:param name="lang-catalogs" select="tan:lang-catalog($languages-used)"
      as="document-node()*"/>




   <!-- Main parameter: Template -->
   <xsl:param name="template-url-relative-to-catalyzing-input" as="xs:string?"/>
   <xsl:param name="template-url-relative-to-actual-input" as="xs:string?"/>
   <xsl:param name="template-url-relative-to-this-stylesheet" as="xs:string?"/>
   <xsl:param name="template-url-resolved" as="xs:string?">
      <xsl:choose>
         <xsl:when test="string-length($template-url-relative-to-catalyzing-input) gt 0">
            <xsl:value-of select="resolve-uri($template-url-relative-to-catalyzing-input, $doc-uri)"/>
         </xsl:when>
         <xsl:when test="string-length($template-url-relative-to-actual-input) gt 0">
            <xsl:value-of select="resolve-uri($template-url-relative-to-actual-input, $input-base-uri-resolved)"/>
         </xsl:when>
         <xsl:when test="string-length($template-url-relative-to-this-stylesheet) gt 0">
            <xsl:value-of select="resolve-uri($template-url-relative-to-this-stylesheet, static-base-uri())"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:message select="'no template url has been supplied'"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:param>

   <xsl:variable name="template-extension"
      select="replace($template-url-resolved, '.+/([^/]+)$', '$1')"/>

   <xsl:param name="template-doc" as="document-node()*">
      <xsl:choose>
         <xsl:when
            test="not(exists($template-url-resolved)) or string-length($template-url-resolved) lt 1">
            <xsl:message>No template doc because no template url has been provided.</xsl:message>
         </xsl:when>
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



   <!-- Main parameter: Extra TAN files -->
   <xsl:param name="extra-tan-catalog-url-relative-to-catalyzing-input" as="xs:string?"/>
   <xsl:param name="extra-tan-catalog-url-relative-to-actual-input" as="xs:string?"/>
   <xsl:param name="extra-tan-catalog-url-relative-to-this-stylesheet" as="xs:string?"/>
   <xsl:param name="extra-tan-catalog-url-relative-to-template" as="xs:string?"/>
   <xsl:param name="extra-tan-catalog-url-resolved" as="xs:string?">
      <xsl:choose>
         <xsl:when test="string-length($extra-tan-catalog-url-relative-to-catalyzing-input) gt 0">
            <xsl:value-of select="resolve-uri($extra-tan-catalog-url-relative-to-catalyzing-input, $doc-uri)"/>
         </xsl:when>
         <xsl:when test="string-length($extra-tan-catalog-url-relative-to-actual-input) gt 0">
            <xsl:value-of select="resolve-uri($extra-tan-catalog-url-relative-to-actual-input, $input-base-uri-resolved)"/>
         </xsl:when>
         <xsl:when test="string-length($extra-tan-catalog-url-relative-to-this-stylesheet) gt 0">
            <xsl:value-of select="resolve-uri($extra-tan-catalog-url-relative-to-this-stylesheet, static-base-uri())"/>
         </xsl:when>
         <xsl:when test="string-length($extra-tan-catalog-url-relative-to-template) gt 0">
            <xsl:value-of select="resolve-uri($extra-tan-catalog-url-relative-to-template, $template-url-resolved)"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:message select="'no template url has been supplied'"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:param>
   <xsl:variable name="extra-tan-catalog"
      select="
         if (doc-available($extra-tan-catalog-url-resolved)) then
            doc($extra-tan-catalog-url-resolved)
         else
            ()"
   />
   <xsl:param name="extra-tan-collection" select="tan:collection($extra-tan-catalog)"/>
   
   
   
   <!-- Main parameter: intermediate steps that should be saved -->
   <xsl:param name="items-to-be-saved" as="document-node()*">
      <xsl:sequence select="$input-pass-1, $input-pass-2, $input-pass-3, $input-pass-4"/>
   </xsl:param>



   <!-- Main parameter: Output -->
   
   <!-- Where will output be saved? -->
   <xsl:param name="output-directory-relative-to-catalyzing-input" as="xs:string?"/>
   <xsl:param name="output-directory-relative-to-actual-input" as="xs:string?"/>
   <xsl:param name="output-directory-relative-to-template" as="xs:string?"/>
   <xsl:variable name="output-directory-resolved" as="xs:string">
      <xsl:choose>
         <xsl:when test="string-length($output-directory-relative-to-catalyzing-input) gt 0">
            <xsl:value-of
               select="replace(resolve-uri($output-directory-relative-to-catalyzing-input, $doc-uri), '([^/])$', '$1/')"/>
         </xsl:when>
         <xsl:when test="string-length($output-directory-relative-to-actual-input) gt 0">
            <xsl:value-of
               select="replace(resolve-uri($output-directory-relative-to-actual-input, $input-base-uri-resolved), '([^/])$', '$1/')"/>
         </xsl:when>
         <xsl:when test="string-length($output-directory-relative-to-template) gt 0">
            <xsl:value-of
               select="replace(resolve-uri($output-directory-relative-to-template, $template-url-resolved), '([^/])$', '$1/')"/>
         </xsl:when>
         <xsl:when test="string-length($default-output-directory-resolved) gt 0">
            <xsl:value-of select="replace($default-output-directory-resolved, '([^/])$', '$1/')"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:value-of select="replace($input-base-uri-resolved, '/[^/]+$', '/')"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:variable>
   
   <!-- What will output files be named? -->
   <xsl:param name="output-filename" as="xs:string?" select="()"/>
   <xsl:variable name="output-filename-resolved" as="xs:string">
      <xsl:choose>
         <xsl:when test="string-length($output-filename) gt 0">
            <xsl:value-of select="encode-for-uri($output-filename)"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:value-of select="replace(tan:cfne(/), '(\.\w+)$', concat('-', $today-iso, '$1'))"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:variable>

   <xsl:param name="suffixes-for-multiple-output" as="xs:string*"/>
   <xsl:param name="output-url-resolved" as="xs:string"
      select="concat($output-directory-resolved, $output-filename-resolved)"/>
   
   <xsl:variable name="output-suffix-count" select="count($suffixes-for-multiple-output)"/>




   <!-- Now the process begins -->
   <!-- Change the input, responsive to opening and saving intermediate steps -->

   <xsl:function name="tan:build-intermediate-step" as="item()*">
      <!-- Input: input items that are to be used to build a variable; a sequence of strings; a string -->
      <!-- Output: the input items prepared, and if not retrieved from a previously saved copy, sent to a template mode corresponding to the name of the pass -->
      <xsl:param name="preceding-items" as="item()*"/>
      <xsl:param name="target-uris" as="xs:string*"/>
      <xsl:param name="name-of-pass" as="xs:string"/>
      <!-- We save any preceding steps that have been marked with @save-as -->
      <xsl:variable name="variable-prepped" as="item()*">
         <xsl:choose>
            <xsl:when test="$save-intermediate-steps or $use-saved-intermediate-steps">
               <xsl:for-each select="$preceding-items">
                  <xsl:variable name="this-pos" select="position()"/>
                  <xsl:variable name="this-uri" select="$target-uris[$this-pos]"/>
                  <xsl:choose>
                     <xsl:when test="string-length($this-uri) lt 1">
                        <xsl:message
                           select="'No uri selected for', tan:ordinal($this-pos), 'input to', $name-of-pass, 'item, so cannot open or save.'"/>
                        <xsl:sequence select="."/>
                     </xsl:when>
                     <xsl:when test="$use-saved-intermediate-steps and doc-available($this-uri)">
                        <xsl:message
                           select="'Fetching previously saved', $name-of-pass, 'from', $this-uri"/>
                        <xsl:apply-templates select="doc($this-uri)" mode="opened-from"/>
                     </xsl:when>
                     <xsl:when test="$save-intermediate-steps">
                        <xsl:message select="'Marking', $name-of-pass, 'to be saved at', $this-uri"/>
                        <xsl:copy-of select="tan:mark-save-as(., $this-uri)"/>
                     </xsl:when>
                     <xsl:otherwise>
                        <xsl:sequence select="."/>
                     </xsl:otherwise>
                  </xsl:choose>
               </xsl:for-each>
            </xsl:when>
            <xsl:otherwise>
               <xsl:sequence select="$preceding-items"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>
      <xsl:if test="matches($name-of-pass,'input[ -]pass[ -][1234]')">
         <xsl:message select="'Starting', $name-of-pass"/>
      </xsl:if>
      <xsl:for-each select="$variable-prepped">
         <xsl:variable name="pos" select="position()"/>
         <xsl:choose>
            <xsl:when test="exists(root(.)/*/@opened-from) and not(exists(root(.)/*/@save-as))">
               <xsl:sequence select="."/>
            </xsl:when>
            <xsl:when test="matches($name-of-pass,'input[ -]pass[ -]1')">
               <xsl:apply-templates select="." mode="input-pass-1"/>
            </xsl:when>
            <xsl:when test="matches($name-of-pass,'input[ -]pass[ -]2')">
               <xsl:apply-templates select="." mode="input-pass-2"/>
            </xsl:when>
            <xsl:when test="matches($name-of-pass,'input[ -]pass[ -]3')">
               <xsl:apply-templates select="." mode="input-pass-3"/>
            </xsl:when>
            <xsl:when test="matches($name-of-pass,'input[ -]pass[ -]4')">
               <xsl:apply-templates select="." mode="input-pass-4"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:if test="string-length($name-of-pass) gt 0 and position() = 1">
                  <xsl:message select="'No template mode has been defined for', $name-of-pass"/>
               </xsl:if>
               <xsl:sequence select="."/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:for-each>
   </xsl:function>
   
   <xsl:template match="/*" mode="opened-from">
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:attribute name="opened-from" select="base-uri(.)"/>
         <xsl:copy-of select="node()"/>
      </xsl:copy>
   </xsl:template>

   <xsl:param name="uris-input-pass-1"
      select="tan:generate-save-uris($input-items, 'input-pass-1', (), $temp-directory)"/>
   <xsl:param name="input-pass-1" as="item()*"
      select="tan:build-intermediate-step($input-items, $uris-input-pass-1, 'input pass 1')"/>
   

   <xsl:param name="uris-input-pass-2"
      select="tan:generate-save-uris($input-pass-1, 'input-pass-2', (), $temp-directory)"/>
   <xsl:param name="input-pass-2" as="item()*"
      select="tan:build-intermediate-step($input-pass-1, $uris-input-pass-2, 'input pass 2')"/>
   

   <xsl:param name="uris-input-pass-3"
      select="tan:generate-save-uris($input-pass-2, 'input-pass-3', (), $temp-directory)"/>
   <xsl:param name="input-pass-3" as="item()*"
      select="tan:build-intermediate-step($input-pass-2, $uris-input-pass-3, 'input pass 3')"/>
   


   <xsl:param name="uris-input-pass-4"
      select="tan:generate-save-uris($input-pass-3, 'input-pass-4', (), $temp-directory)"/>
   <xsl:param name="input-pass-4" as="item()*"
      select="tan:build-intermediate-step($input-pass-3, $uris-input-pass-4, 'input pass 4')"/>



   <!-- Infuse the template with the input -->
   <xsl:param name="template-infused-with-revised-input" as="document-node()*">
      <xsl:for-each select="$input-pass-4">
         <xsl:apply-templates select="$template-doc" mode="infuse-template">
            <xsl:with-param name="new-content" select="." tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:for-each>
   </xsl:param>

   <xsl:template match="*:body" mode="infuse-template">
      <!-- It's unclear how you will want to put the new data in the template, but here is one obvious way -->
      <xsl:param name="new-content" tunnel="yes"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:copy-of select="$new-content"/>
      </xsl:copy>
   </xsl:template>


   <!-- Revise the newly infused template -->
   <!-- Caution: all @hrefs in the input should be resolved before being inserted into the template -->
   <xsl:param name="infused-template-revised"  as="document-node()*">
      <xsl:for-each select="$template-infused-with-revised-input">
         <xsl:variable name="pos" select="position()"/>
         <xsl:variable name="this-target-url" select="($output-url-resolved[$pos], $output-url-resolved[1])[1]"/>
         <!-- We revise hrefs before revising the infusion -->
         <xsl:variable name="item-to-revise" as="item()?">
            <xsl:choose>
               <xsl:when test="string-length($template-url-resolved) gt 0">
                  <xsl:copy-of select="tan:revise-hrefs(., $template-url-resolved, $this-target-url)"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:sequence select="."/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:variable>
         <xsl:apply-templates select="$item-to-revise" mode="revise-infused-template"/>
      </xsl:for-each>
   </xsl:param>
   <!--<xsl:param name="infused-template-revised" as="document-node()*">
      <xsl:apply-templates select="$template-infused-with-revised-input"
         mode="revise-infused-template"/>
   </xsl:param>-->

   <xsl:template match="* | comment() | @*" mode="revise-infused-template">
      <xsl:copy>
         <xsl:apply-templates select="node() | @*" mode="#current"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="processing-instruction()" mode="revise-infused-template">
      <xsl:variable name="href-regex" as="xs:string">(href=['"])([^'"]+)(['"])</xsl:variable>
      <xsl:variable name="this-base-uri" select="tan:base-uri(.)"/>
      <xsl:processing-instruction name="{name(.)}">
            <xsl:analyze-string select="." regex="{$href-regex}">
                <xsl:matching-substring>
                    <xsl:value-of select="concat(regex-group(1), tan:uri-relative-to(resolve-uri(regex-group(2), 
                       ($template-url-resolved, $this-base-uri)[1]), $output-url-resolved), regex-group(3))"/>
                </xsl:matching-substring>
                <xsl:non-matching-substring>
                    <xsl:value-of select="."/>
                </xsl:non-matching-substring>
            </xsl:analyze-string>
        </xsl:processing-instruction>
   </xsl:template>

   <!--<xsl:template match="@href" mode="revise-infused-template credit-stylesheet">
      <xsl:attribute name="href"
         select="tan:uri-relative-to(resolve-uri(., $template-url-resolved), $output-url-resolved)"
      />
   </xsl:template>-->
   <!--<xsl:template match="html:script/@src" mode="revise-infused-template">
      <xsl:attribute name="src"
         select="tan:uri-relative-to(resolve-uri(., $template-url-resolved), $output-url-resolved)"
      />
   </xsl:template>-->

   <xsl:param name="infused-template-credited" as="document-node()*">
      <xsl:apply-templates select="$infused-template-revised" mode="credit-stylesheet"/>
   </xsl:param>

   <!-- For intermediate steps -->
   <!-- note, we add the / in case it is missing -->
   <xsl:variable name="temp-directory"
      select="replace(resolve-uri($save-intermediate-steps-location-relative-to-initial-input, $doc-uri), '([^/])$', '$1/')"/>

   <xsl:param name="final-output" select="$infused-template-credited"/>

   <!-- Generate results -->

   <xsl:template match="/">
      <!-- This template returns only secondary results; that is, it uses xsl:result-document -->
      <!-- For feedback, diagnostics, results, create a default template in the importing stylesheet -->
      <xsl:if test="$save-intermediate-steps">
         <xsl:message>Attempting to save results.</xsl:message>
         <xsl:apply-templates select="$items-to-be-saved" mode="save-file"/>
      </xsl:if>
      <xsl:message>Attempting to save results.</xsl:message>
      <xsl:choose>
         <xsl:when test="string-length($output-url-resolved) gt 0">
            <xsl:variable name="distinct-output-base-uris"
               select="distinct-values($infused-template-credited/*/@xml:base)"/>
            <xsl:variable name="output-count" as="xs:integer"
               select="
                  count(if ($template-is-openxml)
                  then
                     $distinct-output-base-uris
                  else
                     $final-output)"/>
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
               <xsl:variable name="this-suffix-encoded-for-uri" select="encode-for-uri(.)"/>
               <xsl:variable name="this-pos" select="position()"/>

               <xsl:variable name="this-target-uri"
                  select="replace($output-url-resolved, '(\.[^\.]+)$', concat($this-suffix-encoded-for-uri, '$1'))"/>
               <xsl:message select="concat('Saving output to ', $this-target-uri)"/>
               <xsl:choose>
                  <xsl:when
                     test="($this-target-uri = static-base-uri()) or matches($this-target-uri, '\.xsl$')">
                     <xsl:message>Attempt has been made to write to a stylesheet URI.</xsl:message>
                  </xsl:when>
                  <xsl:when test="$template-is-openxml">
                     <xsl:variable name="this-output"
                        select="$final-output[*/@xml:base = $distinct-output-base-uris[$this-pos]]"/>
                     <xsl:call-template name="tan:save-docx">
                        <xsl:with-param name="docx-components" select="$this-output"/>
                        <xsl:with-param name="resolved-uri" select="$this-target-uri"/>
                     </xsl:call-template>
                  </xsl:when>
                  <xsl:otherwise>
                     <xsl:variable name="this-output" select="$final-output[$this-pos]"/>
                     <xsl:result-document href="{$this-target-uri}">
                        <xsl:copy-of select="$this-output"/>
                     </xsl:result-document>
                  </xsl:otherwise>
               </xsl:choose>
            </xsl:for-each>
         </xsl:when>
         <xsl:otherwise>
            <xsl:copy-of select="$final-output"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>

</xsl:stylesheet>
