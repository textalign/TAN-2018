<?xml version="1.0" encoding="UTF-8"?>
<pattern xmlns="http://purl.oclc.org/dsdl/schematron" xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:sqf="http://www.schematron-quickfix.com/validator/process"
   xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:fn="http://www.w3.org/2005/xpath-functions"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   id="core-tests">
   <title>Core Schematron tests for all TAN files.</title>
   <!-- This empty rule prevents checking TEI's <text>, which is always shallowly skipped in validation. -->
   <rule context="*:text"/>
   <!--<rule context="/*">
      <!-\- for testing -\->
      <report test="true()" role="warning"><value-of select="$validation-phase"/></report>
   </rule>-->
   <rule context="*">
      <let name="this-q-ref" value="generate-id(.)"/>
      <let name="this-name" value="name(.)"/>
      <let name="this-checked-for-errors" value="tan:get-via-q-ref($this-q-ref, $self-expanded[1])"/>
      <let name="has-include-or-which-attr" value="exists(@include) or exists(@which)"/>
      <let name="relevant-fatalities"
         value="
            if ($has-include-or-which-attr = true()) then
               $this-checked-for-errors//tan:fatal[not(@xml:id = $errors-to-squelch)]
            else
               $this-checked-for-errors/(self::*, tan:range)/(self::*, *[@attr])/tan:fatal[not(@xml:id = $errors-to-squelch)]"/>
      <let name="relevant-errors"
         value="
            if ($has-include-or-which-attr = true()) then
               $this-checked-for-errors//tan:error[not(@xml:id = $errors-to-squelch)]
            else
               $this-checked-for-errors/(self::*, tan:range)/(self::*, *[@attr])/tan:error[not(@xml:id = $errors-to-squelch)]"/>
      <let name="relevant-warnings"
         value="
            if ($has-include-or-which-attr = true()) then
               $this-checked-for-errors//tan:warning[not(@xml:id = $errors-to-squelch)]
            else
               $this-checked-for-errors/(self::*, tan:range)/(self::*, *[@attr])/tan:warning[not(@xml:id = $errors-to-squelch)]"/>
      <let name="relevant-info"
         value="
            if ($has-include-or-which-attr = true()) then
               $this-checked-for-errors//tan:info
            else
               $this-checked-for-errors/(self::*, tan:range)/(self::*, *[@attr])/tan:info"/>
      <let name="help-offered"
         value="
            if ($has-include-or-which-attr = true()) then
               $this-checked-for-errors//tan:help
            else
               $this-checked-for-errors/(self::*, tan:range)/(self::*, *[@attr])/tan:help"/>
      <let name="relevant-items"
         value="($relevant-fatalities, $relevant-errors, $relevant-warnings, $relevant-info, $help-offered)"/>
      <let name="these-fixes"
         value="($this-checked-for-errors/(self::*, *[@attr])/tan:fix, $relevant-items/tan:fix)"/>
      <let name="self-replacements" value="$these-fixes[@type = 'replace-self']"/>
      <let name="self-and-next-sibling-replacements"
         value="$these-fixes[@type = 'replace-self-and-next-sibling']"/>
      <let name="self-and-next-leaf-div-replacements"
         value="$these-fixes[@type = 'replace-self-and-next-leaf-divs']"/>
      <let name="text-replacements" value="$these-fixes[@type = 'replace-text']"/>
      <let name="content-to-prepend" value="$these-fixes[@type = 'prepend-content']"/>
      <let name="content-to-append" value="$these-fixes[@type = 'append-content']"/>
      <let name="content-to-copy-after" value="$these-fixes[@type = 'copy-after']"/>
      <let name="attributes-to-copy" value="$these-fixes[@type = 'copy-attributes']"/>
      <let name="elements-to-copy-elsewhere"
         value="$these-fixes[@type = 'copy-element-after-last-of-type']"/>
      <let name="replacement-children" value="$these-fixes[@type = 'replace-children']"/>
      <let name="replacement-attributes" value="$these-fixes[@type = 'replace-attributes']"/>
      <let name="self-deletions" value="$these-fixes[@type = 'delete-self']"/>
      <let name="vocabulary-key-item" value="$these-fixes[@type = 'add-vocabulary-key-item']"/>
      

      <report test="exists($relevant-fatalities)" role="fatal"><value-of
            select="tan:error-report($relevant-fatalities)"/></report>
      <report test="exists($relevant-errors)" sqf:fix="tan-sqf"><value-of
            select="tan:error-report($relevant-errors)"/></report>
      <report test="exists($relevant-warnings)" role="warning" sqf:fix="tan-sqf"><value-of
            select="tan:error-report($relevant-warnings)"/></report>
      <report test="exists($relevant-info)" role="info"><value-of
            select="$relevant-info/tan:message"/></report>
      <report test="exists($help-offered)" role="warning" sqf:fix="tan-sqf">
         <value-of select="$help-offered/tan:message"/>
      </report>
      <assert test="exists($this-checked-for-errors)"><value-of select="$this-q-ref"/> doesn't
         match; other @q values of <value-of select="$this-name"/>: <value-of select="string-join($self-expanded//*[name() = $this-name]/@q, ', ')"/></assert>
      <sqf:group id="tan-sqf" use-when="$has-include-or-which-attr = false()">
         <sqf:fix id="replace-self" use-when="exists($self-replacements)">
            <sqf:description>
               <sqf:title>Replace self with: <value-of
                     select="tan:xml-to-string($self-replacements[1]/node())"/></sqf:title>
            </sqf:description>
            <sqf:replace select="$self-replacements[1]/node()"/>
         </sqf:fix>
         <sqf:fix id="replace-self-and-next-sibling"
            use-when="exists($self-and-next-sibling-replacements)">
            <sqf:description>
               <sqf:title>Replace self and next sibling with: <value-of
                     select="tan:xml-to-string($self-replacements[1]/node()[position() lt 3])"
                  /></sqf:title>
            </sqf:description>
            <sqf:replace select="$self-and-next-sibling-replacements/node()[1]"/>
            <sqf:replace match="following-sibling::node()[1]"
               select="$self-and-next-sibling-replacements/node()[2]"/>
         </sqf:fix>
         <sqf:fix id="replace-self-leaf-div"
            use-when="exists($self-and-next-leaf-div-replacements/*)">
            <sqf:description>
               <sqf:title>Replace self leaf div</sqf:title>
            </sqf:description>

         </sqf:fix>
         <sqf:fix id="replace-self-and-next-leaf-div"
            use-when="count($self-and-next-leaf-div-replacements/*) gt 1">
            <sqf:description>
               <sqf:title>Replace self and next leaf div</sqf:title>
            </sqf:description>
            <let name="leaf-divs" value="following::tan:div[not(tan:div)]"/>
            <sqf:replace select="$self-and-next-leaf-div-replacements/*[1]" match="self::*"/>
            <sqf:replace select="$self-and-next-leaf-div-replacements/*[2]" match="$leaf-divs[1]"/>
         </sqf:fix>
         <sqf:fix id="replace-self-and-next-2-leaf-divs"
            use-when="count($self-and-next-leaf-div-replacements/*) gt 2">
            <sqf:description>
               <sqf:title>Replace self and next two leaf divs</sqf:title>
            </sqf:description>
            <let name="leaf-divs" value="following::tan:div[not(tan:div)]"/>
            <sqf:replace select="$self-and-next-leaf-div-replacements/*[1]" match="self::*"/>
            <sqf:replace select="$self-and-next-leaf-div-replacements/*[2]" match="$leaf-divs[1]"/>
            <sqf:replace select="$self-and-next-leaf-div-replacements/*[3]" match="$leaf-divs[2]"/>
         </sqf:fix>
         <sqf:fix id="replace-self-and-next-3-leaf-divs"
            use-when="count($self-and-next-leaf-div-replacements/*) gt 3">
            <sqf:description>
               <sqf:title>Replace self and next three leaf divs</sqf:title>
            </sqf:description>
            <let name="leaf-divs" value="following::tan:div[not(tan:div)]"/>
            <sqf:replace select="$self-and-next-leaf-div-replacements/*[1]" match="self::*"/>
            <sqf:replace select="$self-and-next-leaf-div-replacements/*[2]" match="$leaf-divs[1]"/>
            <sqf:replace select="$self-and-next-leaf-div-replacements/*[3]" match="$leaf-divs[2]"/>
            <sqf:replace select="$self-and-next-leaf-div-replacements/*[4]" match="$leaf-divs[3]"/>
         </sqf:fix>
         <sqf:fix id="replace-text" use-when="exists($text-replacements)">
            <sqf:description>
               <sqf:title>Replace text with: <value-of select="$text-replacements[1]"/></sqf:title>
            </sqf:description>
            <let name="text-node-number"
               value="count($text-replacements[1]/../preceding-sibling::text()) + 1"/>
            <sqf:replace match="text()[$text-node-number]" select="$text-replacements[1]/text()"/>
         </sqf:fix>
         <sqf:fix id="replace-text-2" use-when="exists($text-replacements[2])">
            <sqf:description>
               <sqf:title>Replace text with: <value-of select="$text-replacements[2]"/></sqf:title>
            </sqf:description>
            <let name="text-node-number"
               value="count($text-replacements[2]/../preceding-sibling::text()) + 1"/>
            <sqf:replace match="text()[$text-node-number]" select="$text-replacements[2]/text()"/>
         </sqf:fix>
         <sqf:fix id="prepend-content" use-when="exists($content-to-prepend)">
            <sqf:description>
               <sqf:title>Prepend content with: <value-of
                     select="tan:xml-to-string($content-to-prepend/node())"/></sqf:title>
            </sqf:description>
            <sqf:add position="first-child" select="$content-to-prepend/node()"/>
         </sqf:fix>
         <sqf:fix id="append-content" use-when="exists($content-to-append)">
            <sqf:description>
               <sqf:title>Append content with: <value-of
                     select="tan:xml-to-string($content-to-append/node())"/></sqf:title>
            </sqf:description>
            <sqf:add position="last-child" select="$content-to-append/node()"/>
         </sqf:fix>
         <sqf:fix id="copy-after" use-when="exists($content-to-copy-after)">
            <sqf:description>
               <sqf:title>Copy content after this element: <value-of
                     select="tan:xml-to-string($content-to-copy-after/node())"/></sqf:title>
            </sqf:description>
            <sqf:add position="after" select="$content-to-copy-after/node()"/>
         </sqf:fix>
         <sqf:fix id="copy-attributes-1" use-when="exists($attributes-to-copy[1]/*)">
            <sqf:description>
               <sqf:title>Insert <value-of
                     select="tan:xml-to-string($attributes-to-copy[1]/*[1]/@*)"/></sqf:title>
            </sqf:description>
            <sqf:replace>
               <xsl:copy>
                  <xsl:copy-of select="@*"/>
                  <xsl:copy-of select="$attributes-to-copy[1]/*[1]/@*"/>
                  <xsl:copy-of select="node()"/>
               </xsl:copy>
            </sqf:replace>
         </sqf:fix>
         <sqf:fix id="copy-attributes-2" use-when="exists($attributes-to-copy[1]/*[2])">
            <sqf:description>
               <sqf:title>Insert <value-of
                     select="tan:xml-to-string($attributes-to-copy[1]/*[2]/@*)"/>
               </sqf:title>
            </sqf:description>
            <sqf:replace>
               <xsl:copy>
                  <xsl:copy-of select="@*"/>
                  <xsl:copy-of select="$attributes-to-copy[1]/*[2]/@*"/>
                  <xsl:copy-of select="node()"/>
               </xsl:copy>
            </sqf:replace>
         </sqf:fix>
         <sqf:fix id="copy-attributes-3" use-when="exists($attributes-to-copy[1]/*[3])">
            <sqf:description>
               <sqf:title>Insert <value-of
                     select="tan:xml-to-string($attributes-to-copy[1]/*[3]/@*)"/>
               </sqf:title>
            </sqf:description>
            <sqf:replace>
               <xsl:copy>
                  <xsl:copy-of select="@*"/>
                  <xsl:copy-of select="$attributes-to-copy[1]/*[3]/@*"/>
                  <xsl:copy-of select="node()"/>
               </xsl:copy>
            </sqf:replace>
         </sqf:fix>
         <sqf:fix id="copy-attributes-4" use-when="exists($attributes-to-copy[1]/*[4])">
            <sqf:description>
               <sqf:title>Insert <value-of
                     select="tan:xml-to-string($attributes-to-copy[1]/*[4]/@*)"/>
               </sqf:title>
            </sqf:description>
            <sqf:replace>
               <xsl:copy>
                  <xsl:copy-of select="@*"/>
                  <xsl:copy-of select="$attributes-to-copy[1]/*[4]/@*"/>
                  <xsl:copy-of select="node()"/>
               </xsl:copy>
            </sqf:replace>
         </sqf:fix>

         <sqf:fix id="copy-element-after-last-of-type"
            use-when="exists($elements-to-copy-elsewhere)">
            <sqf:description>
               <sqf:title>Copy as last of its type the following element: <value-of
                     select="tan:xml-to-string($elements-to-copy-elsewhere/*)"/>
               </sqf:title>
               <sqf:p>Element will be added after the last occurrence of <value-of
                     select="name($elements-to-copy-elsewhere[1]/*[1])"/></sqf:p>
            </sqf:description>
            <sqf:add match="(//*[name(.) = name($elements-to-copy-elsewhere[1]/*[1])])[last()]"
               position="after">
               <xsl:text>&#xA;</xsl:text>
               <xsl:copy-of select="$elements-to-copy-elsewhere[1]/*"/>
            </sqf:add>
         </sqf:fix>

         <sqf:fix id="replace-first-child" use-when="exists($replacement-children)">
            <sqf:description>
               <sqf:title>Replace <value-of select="name($replacement-children/*[1])"/> with
                     <value-of select="tan:xml-to-string($replacement-children/*[1])"/></sqf:title>
            </sqf:description>
            <sqf:replace match="*[name(.) = name($replacement-children/*[1])][1]"
               select="$replacement-children/*[1]"/>
         </sqf:fix>
         <sqf:fix id="replace-second-child" use-when="exists($replacement-children/*[2])">
            <sqf:description>
               <sqf:title>Replace <value-of select="name($replacement-children/*[2])"/> with
                     <value-of select="tan:xml-to-string($replacement-children/*[2])"/></sqf:title>
            </sqf:description>
            <sqf:replace match="*[name(.) = name($replacement-children/*[2])][1]"
               select="$replacement-children/*[2]"/>
         </sqf:fix>

         <sqf:fix id="add-master-location"
            use-when="exists($these-fixes[@type = 'add-master-location'])">
            <sqf:description>
               <sqf:title>Add master-location element after &lt;name&gt;</sqf:title>
               <sqf:p>Insert a &lt;master-location> immediately after &lt;name>, with the current
                  file's URL.</sqf:p>
            </sqf:description>
            <sqf:add position="after" select="$these-fixes[@type = 'add-master-location']/*"
               match="/*/tan:head/tan:name[last()]"/>
         </sqf:fix>
         
         <sqf:fix id="replace-attributes-1" use-when="exists($replacement-attributes)">
            <let name="first-attribute" value="$replacement-attributes/@*[1]"></let>
            <sqf:description>
               <sqf:title>Replace attribute <value-of
                  select="tan:xml-to-string($first-attribute)"/> (first instance)</sqf:title>
            </sqf:description>
            <sqf:replace match="(.//@*[name() = name($first-attribute)])[1]"
               select="$first-attribute"/>
            <!--<sqf:replace match=""></sqf:replace>-->
         </sqf:fix>
         
         <sqf:fix id="self-deletion" use-when="exists($self-deletions)">
            <sqf:description>
               <sqf:title>Delete this element</sqf:title>
            </sqf:description>
            <sqf:delete/>
         </sqf:fix>
         
         <sqf:fix id="current-date">
            <sqf:description>
               <sqf:title>Change date to today's date, <value-of select="current-date()"
                  /></sqf:title>
            </sqf:description>
            <sqf:replace match="@when" target="when" node-type="attribute" use-when="@when"
               select="current-date()"/>
            <sqf:replace match="@ed-when" target="ed-when" node-type="attribute" use-when="@ed-when"
               select="current-date()"/>
            <sqf:replace match="@when-accessed" target="when-accessed" node-type="attribute"
               use-when="@when-accessed" select="current-date()"/>
         </sqf:fix>
         <sqf:fix id="current-date-time">
            <sqf:description>
               <sqf:title>Change date to today's date + time, <value-of select="current-dateTime()"
                  /></sqf:title>
            </sqf:description>
            <sqf:replace match="@when" target="when" node-type="attribute" use-when="@when"
               select="current-dateTime()"/>
            <sqf:replace match="@ed-when" target="ed-when" node-type="attribute" use-when="@ed-when"
               select="current-dateTime()"/>
            <sqf:replace match="." target="when-accessed" node-type="attribute"
               use-when="@when-accessed" select="current-dateTime()"/>
         </sqf:fix>
         
         <sqf:fix id="vocabulary-key-item" use-when="exists($vocabulary-key-item)">
            <sqf:description>
               <sqf:title>Add new item to the end of vocabulary-key</sqf:title>
            </sqf:description>
            <sqf:add position="last-child" match="root()/*/tan:head/tan:vocabulary-key">
               <xsl:copy-of select="$vocabulary-key-item/node()"/>
            </sqf:add>
         </sqf:fix>
      </sqf:group>

   </rule>
</pattern>
