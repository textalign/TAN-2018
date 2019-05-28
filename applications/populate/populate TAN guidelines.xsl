<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="http://docbook.org/ns/docbook" xmlns:docbook="http://docbook.org/ns/docbook"
   xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xs="http://www.w3.org/2001/XMLSchema"
   xmlns:math="http://www.w3.org/2005/xpath-functions/math"
   xmlns:saxon="http://icl.com/saxon"
   xmlns:lxslt="http://xml.apache.org/xslt" xmlns:redirect="http://xml.apache.org/xalan/redirect"
   xmlns:exsl="http://exslt.org/common" xmlns:doc="http://nwalsh.com/xsl/documentation/1.0"
   xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:tei="http://www.tei-c.org/ns/1.0"
   xmlns:rng="http://relaxng.org/ns/structure/1.0" xmlns:sch="http://purl.oclc.org/dsdl/schematron"
   xmlns:fn="http://www.w3.org/2005/xpath-functions" xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:a="http://relaxng.org/ns/compatibility/annotations/1.0"
   xmlns:sqf="http://www.schematron-quickfix.com/validator/process"
   xpath-default-namespace="http://docbook.org/ns/docbook"
   extension-element-prefixes="saxon redirect lxslt exsl" exclude-result-prefixes="#all"
   version="3.0">

   <!-- Stylesheet to generate the official TAN guidelines -->

   <xsl:output method="xml" indent="no"/>

   <xsl:include href="../../functions/incl/TAN-core-functions.xsl"/>
   <xsl:include href="../../functions/TAN-extra-functions.xsl"/>
   <xsl:include href="../get%20inclusions/rng-to-text.xsl"/>
   <xsl:include href="../get%20inclusions/tan-snippet-to-docbook.xsl"/>
   <xsl:include href="../get%20inclusions/tan-vocabularies-to-docbook.xsl"/>
   <xsl:include href="../get%20inclusions/XSLT%20analysis.xsl"/>

   <xsl:param name="max-examples" select="4"/>
   <xsl:param name="qty-contextual-siblings" select="1"/>
   <xsl:param name="qty-contextual-children" select="3"/>
   <xsl:param name="max-example-size" select="2000"/>

   <xsl:variable name="chapter-caveat" as="element()">
      <para>The contents of this chapter have been generated automatically. Although much effort has
         been spent to ensure accurate representation of the schemas and function library, you may
         find errors or inconsistencies. In such cases, the functions and schemas (particularly the
         RELAX-NG, compact syntax) are to be given priority.</para>
   </xsl:variable>

   <xsl:variable name="target-uri-1" select="resolve-uri('../../guidelines/inclusions/elements-attributes-and-patterns.xml',static-base-uri())"/>

   <xsl:variable name="ex-collection"
      select="collection('../../examples/?select=*.xml;recurse=yes'), collection('../../vocabularies/?select=*.xml;recurse=yes')"/>
   <xsl:variable name="fn-collection"
      select="collection('../../functions/?select=*.xsl;recurse=yes')"/>
   <xsl:variable name="vocabulary-collection"
      select="collection('../../vocabularies/?select=*voc.xml;recurse=yes')"/>
   <xsl:variable name="elements-excl-TEI" select="$rng-collection-without-TEI//rng:element[@name]"/>
   <xsl:variable name="attributes-excl-TEI"
      select="$rng-collection-without-TEI//rng:attribute[@name]"/>

   <xsl:variable name="sequence-of-sections" as="element()">
      <!-- Filters and arranges the function files into sequence sequence and hierarchy the documentation should follow. -->
      <sec n="TAN-core">
         <sec n="TAN-parameters"/>
         <sec n="TAN-core-errors"/>
         <sec n="TAN-core-resolve"/>
         <sec n="TAN-core-expand"/>
         <sec n="TAN-core-string"/>
         <sec n="TAN-class-1">
            <sec n="TAN-T"/>
         </sec>
         <sec n="TAN-class-2">
            <sec n="TAN-A"/>
            <sec n="TAN-A-tok"/>
            <sec n="TAN-A-lm"/>
         </sec>
         <sec n="TAN-class-3">
            <sec n="TAN-voc"/>
            <sec n="TAN-mor"/>
            <sec n="catalog.tan"/>
         </sec>
         <sec n="TAN-extra">
            <sec n="TAN-function"/>
            <sec n="TAN-schema"/>
         </sec>
         <sec n="diff-for-xslt2"/>
         <sec n="regex-ext-tan"/>
         <sec n="TAN-schema"/>
      </sec>
   </xsl:variable>

   <xsl:variable name="function-docs-picked"
      select="$all-functions[replace(tan:cfn(.), '-functions', '') = $sequence-of-sections/descendant-or-self::*/@n]"/>
   <xsl:variable name="function-library-keys" select="$function-docs-picked/xsl:stylesheet/xsl:key"/>
   <xsl:variable name="function-library-functions"
      select="$function-docs-picked/xsl:stylesheet/xsl:function"/>
   <xsl:variable name="names-of-functions-to-append" as="xs:string*">
      <xsl:for-each-group select="$function-library-functions" group-by="@name">
         <xsl:variable name="these-file-names" select="distinct-values(tan:cfn(current-group()))"/>
         <xsl:if test="count($these-file-names) gt 1">
            <xsl:value-of select="current-grouping-key()"/>
         </xsl:if>
      </xsl:for-each-group>
   </xsl:variable>
   
   <xsl:variable name="function-library-templates"
      select="$function-docs-picked/xsl:stylesheet/xsl:template"/>
   
   <xsl:variable name="function-library-variables"
      select="$function-docs-picked/xsl:stylesheet/xsl:variable"/>
   <xsl:variable name="function-library-duplicate-variable-names"
      select="tan:duplicate-items($function-library-variables/@name)"/>
   <xsl:variable name="function-library-variables-duplicate"
      select="$function-library-variables[@name = $function-library-duplicate-variable-names]"/>
   <xsl:variable name="function-library-variables-unique"
      select="$function-library-variables[not(@name = $function-library-duplicate-variable-names)]"/>

   <xsl:variable name="lf" select="'&#xA;'"/>
   <xsl:variable name="lt" select="'&lt;'"/>
   <xsl:variable name="ellipses" select="'.........&#xA;'"/>

   <xsl:template match="*" mode="errors-to-docbook context-errors-to-docbook"/>
   <xsl:template match="docbook:squelch"/>
   
   <xsl:variable name="indent"
      select="
         string-join(for $i in (1 to $indent-value)
         return
            ' ')"/>
   <xsl:variable name="distinct-element-names" select="distinct-values($elements-excl-TEI/@name)"/>
   <xsl:variable name="distinct-attribute-names"
      select="distinct-values($attributes-excl-TEI/@name)"/>
   <xsl:variable name="function-library-template-names-and-modes"
      select="
         for $i in $function-library-templates/(@name, @mode)
         return
            tokenize($i, '\s+')"/>

   <xsl:function name="tan:prep-string-for-docbook" as="item()*">
      <xsl:param name="text" as="xs:string*"/>
      <!-- we assume that all components defined in component syntax.xml are to be marked -->
      <xsl:variable name="capture-group-replacement"
         select="'(' || $component-syntax/*/@name-replacement || ')'"/>
      <xsl:variable name="string-regexes" select="$component-syntax/*/*/@string-matching-pattern"/>
      <xsl:variable name="master-regex"
         select="
            string-join(for $i in $string-regexes
            return
               replace($i, 'name', $capture-group-replacement), '|')"/>
      <!-- The next variables specify the second and third parameters for fn:replace() applied to a result from a function -->
      <xsl:variable name="replacement-for-function-result-to-put-inside-link" select="('\(', '')"
         as="xs:string+"/>
      <xsl:variable name="replacement-for-function-result-to-put-outside-code" select="('.+', '(')"
         as="xs:string+"/>
      <xsl:variable name="pass-1" as="item()*">
         <!-- This <analyze-string> regular expression looks for <ELEMENT> ~PATTERN @ATTRIBUTE key('KEY') tan:FUNCTION() $VARIABLE as endpoints -->
         <!-- It also looks for, but does not treat as an endpoint, {template (mode|named) TEMPLATE}, to at least put it inside of <code> -->
         <!-- We coin initial ~ as representing a pattern, similar to the @ prefix to signal an attribute -->
         <!-- former regex: {$lt || '([-:\w]+)&gt;|[~@]([-:\w]+)|key\('||$apos||'([-\w]+)'||$apos||'\)|tan:([-\w]+)\(\)|\$([-\w]+)|[Ŧŧ] ([-#\w]+)'} -->
         <xsl:for-each select="$text">
            <xsl:analyze-string select="." regex="{$master-regex}">
               <xsl:matching-substring>
                  <xsl:variable name="first-match"
                     select="((1 to 11)[string-length(regex-group(.)) gt 0])[1]"/>
                  <xsl:variable name="match-type"
                     select="tokenize($component-syntax/*/*[$first-match]/@type, ' ')[1]"/>
                  <xsl:variable name="match-name" select="regex-group($first-match)"/>
                  <xsl:variable name="is-valid-link" as="xs:boolean">
                     <xsl:choose>
                        <xsl:when
                           test="
                              ($match-type = 'attribute' and not(exists($attributes-excl-TEI[@name = $match-name]))) or
                              ($match-type = 'element' and not(exists($elements-excl-TEI[@name = $match-name]))) or
                              ($match-type = 'key' and not(exists($function-library-keys[@name = $match-name]))) or
                              ($match-type = 'function' and not(exists($function-library-functions[@name = $match-name]))) or
                              ($match-type = 'variable' and not(exists($function-library-variables[@name = $match-name])))">
                           <xsl:value-of select="false()"/>
                        </xsl:when>
                        <xsl:otherwise>
                           <xsl:value-of select="true()"/>
                        </xsl:otherwise>
                     </xsl:choose>
                  </xsl:variable>
                  <xsl:variable name="linkend"
                     select="$match-type || '-' || replace($match-name, '[:#]|tan:', '')"/>
                  <code>
                     <xsl:choose>
                        <xsl:when test="$is-valid-link">
                           <xsl:variable name="linktext"
                              select="
                                 if ($match-type = 'function') then
                                    replace(., $replacement-for-function-result-to-put-inside-link[1], $replacement-for-function-result-to-put-inside-link[2])
                                 else
                                    ."/>
                           <link linkend="{$linkend}">
                              <xsl:value-of select="$linktext"/>
                           </link>
                        </xsl:when>
                        <xsl:otherwise>
                           <xsl:value-of select="."/>
                        </xsl:otherwise>
                     </xsl:choose>
                  </code>
                  <xsl:if test="$match-type = 'function' and $is-valid-link">
                     <xsl:value-of
                        select="replace(., $replacement-for-function-result-to-put-outside-code[1], $replacement-for-function-result-to-put-outside-code[2])"
                     />
                  </xsl:if>
               </xsl:matching-substring>
               <xsl:non-matching-substring>
                  <xsl:analyze-string select="." regex="main\.xml#[-_\w]+|iris\.xml|https?://\S+">
                     <xsl:matching-substring>
                        <xsl:choose>
                           <xsl:when test="starts-with(., 'main')">
                              <xref linkend="{replace(.,'main\.xml#','')}"/>
                           </xsl:when>
                           <xsl:otherwise>
                              <link xlink:href="{.}">
                                 <xsl:value-of select="."/>
                              </link>
                           </xsl:otherwise>
                        </xsl:choose>
                     </xsl:matching-substring>
                     <xsl:non-matching-substring>
                        <xsl:value-of select="."/>
                     </xsl:non-matching-substring>
                  </xsl:analyze-string>
               </xsl:non-matching-substring>
            </xsl:analyze-string>
         </xsl:for-each>
      </xsl:variable>
      <xsl:copy-of select="$pass-1"/>
   </xsl:function>

   <xsl:function name="tan:component-comments-to-docbook" as="element()*">
      <!-- Input: one or more XSLT elements -->
      <!-- Output: one docbook <para> per comment -->
      <xsl:param name="xslt-elements" as="element()*"/>
      <xsl:for-each select="$xslt-elements/comment()[not(preceding-sibling::*)]">
         <xsl:for-each select="tokenize(., '\n')">
            <para>
               <xsl:copy-of select="tan:prep-string-for-docbook(.)"/>
            </para>
         </xsl:for-each>
      </xsl:for-each>
   </xsl:function>
   <xsl:function name="tan:component-dependees-to-docbook" as="element()*">
      <!-- Input: one or more XSLT elements -->
      <!-- Output: one docbook <para> per type listing other components that depend upon the input component -->
      <xsl:param name="xslt-element" as="element()?"/>
      <xsl:variable name="this-type-of-component" select="name($xslt-element)"/>
      <xsl:variable name="what-depends-on-this"
         select="tan:xslt-dependencies($xslt-element/(@name, @mode, @xml:id)[1], $this-type-of-component, exists($xslt-element/@mode), $all-functions)[name() = ('xsl:function', 'xsl:variable', 'xsl:template', 'xsl:key')]"/>
      <xsl:for-each-group select="$what-depends-on-this" group-by="name()">
         <xsl:sort select="name()" order="descending"/>
         <xsl:variable name="component-type" select="current-grouping-key()"/>
         <para>Used by <xsl:value-of select="replace(current-grouping-key(), 'xsl:', '')"/>
            <xsl:for-each select="tan:distinct-items(current-group())">
               <xsl:text> </xsl:text>
               <xsl:copy-of
                  select="tan:prep-string-for-docbook(tan:string-representation-of-component((@name, @mode)[1], $component-type, exists(@mode)))"
               />
            </xsl:for-each>
         </para>
      </xsl:for-each-group>
      <xsl:if test="not(exists($what-depends-on-this))">
         <para>No variables, keys, functions, or named templates depend upon this <xsl:value-of
               select="$this-type-of-component"/>.</para>
      </xsl:if>
   </xsl:function>
   <xsl:function name="tan:component-dependencies-to-docbook" as="element()*">
      <!-- Input: one or more XSLT elements -->
      <!-- Output: one docbook <para> per type listing other components upon which the input component depends -->
      <xsl:param name="xslt-elements" as="element()*"/>
      <xsl:variable name="what-this-depends-on-pass-1" as="item()*">
         <xsl:copy-of
            select="
               for $i in $xslt-elements/descendant-or-self::*/@*
               return
                  tan:prep-string-for-docbook($i)"/>
         <xsl:copy-of
            select="
               for $j in $xslt-elements//xsl:call-template
               return
                  tan:prep-string-for-docbook(tan:string-representation-of-component($j/@name, 'template'))"/>
         <xsl:copy-of
            select="
               for $k in $xslt-elements//xsl:apply-templates
               return
                  tan:prep-string-for-docbook(tan:string-representation-of-component($k/@mode, 'template', true()))"
         />
      </xsl:variable>
      <xsl:variable name="what-this-depends-on-pass-2"
         select="$what-this-depends-on-pass-1/descendant-or-self::docbook:code[docbook:link[not(matches(@linkend, '^attribute-'))]]"/>
      <xsl:variable name="what-this-depends-on"
         select="tan:distinct-items($what-this-depends-on-pass-2)"/>
      <xsl:choose>
         <xsl:when test="exists($what-this-depends-on)">
            <para>Relies upon <xsl:for-each select="$what-this-depends-on">
                  <xsl:copy-of select="."/>
                  <xsl:text> </xsl:text>
               </xsl:for-each>.</para>
         </xsl:when>
         <xsl:otherwise>
            <para>Does not rely upon global variables, keys, functions, or templates.</para>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>

   <xsl:template match="tan:rule | tan:message" mode="errors-to-docbook">
      <para>
         <xsl:copy-of select="tan:prep-string-for-docbook(.)"/>
      </para>
   </xsl:template>
   <xsl:template match="tan:error | tan:warning | tan:fatal" priority="1" mode="errors-to-docbook">
      <xsl:variable name="affected-attributes"
         select="
            for $i in ancestor-or-self::*/@affects-attribute
            return
               tokenize($i, '\s+')"/>
      <xsl:variable name="affected-elements"
         select="
            for $i in ancestor-or-self::*/@affects-element
            return
               tokenize($i, '\s+')"/>
      <section>
         <title>
            <xsl:value-of select="name(.)"/>
            <code>[<xsl:value-of select="@xml:id"/>]</code>
         </title>
         <xsl:apply-templates mode="#current"/>
         <xsl:choose>
            <xsl:when test="exists($affected-attributes) or exists($affected-elements)">
               <para>Affects: <xsl:copy-of
                     select="tan:prep-string-for-docbook(tan:string-representation-of-component($affected-attributes, 'attribute'))"/>
                  <xsl:copy-of
                     select="tan:prep-string-for-docbook(tan:string-representation-of-component($affected-elements, 'element'))"
                  />
               </para>
            </xsl:when>
            <xsl:otherwise>
               <para>General rule not affecting specific attibutes or elements.</para>
            </xsl:otherwise>
         </xsl:choose>
         <xsl:copy-of select="tan:component-dependees-to-docbook(.)"/>
      </section>
   </xsl:template>
   <xsl:template match="a:documentation[parent::rng:element or parent::rng:attribute]"
      mode="rng-to-docbook">
      <xsl:variable name="parent-type" select="lower-case(name(..))"/>
      <para>
         <xsl:if test="not(preceding-sibling::a:documentation)">
            <xsl:value-of select="'The ' || $parent-type || ' '"/>
            <code>
               <xsl:value-of select="../@name"/>
            </code>
            <xsl:text> </xsl:text>
         </xsl:if>
         <xsl:copy-of select="tan:prep-string-for-docbook(.)"/>
      </para>
   </xsl:template>
   <xsl:template match="a:documentation[parent::rng:define]" mode="rng-to-docbook">
      <xsl:variable name="this-name" select="replace(base-uri(.), '.+/(.+)\.rng$', '$1')"/>
      <para>
         <xsl:value-of select="$this-name || ': '"/>
         <xsl:copy-of select="tan:prep-string-for-docbook(.)"/>
      </para>
   </xsl:template>
   <xsl:template match="tan:error | tan:fatal" priority="1" mode="context-errors-to-docbook">
      <caution>
         <para>
            <xsl:copy-of select="tan:prep-string-for-docbook(tan:rule)"/>
         </para>
      </caution>
   </xsl:template>
   <xsl:template match="tan:warning" priority="1" mode="context-errors-to-docbook">
      <important>
         <para>
            <xsl:copy-of select="tan:prep-string-for-docbook(tan:rule)"/>
            <xsl:if test="exists(tan:message)">
               <xsl:text> </xsl:text>
               <quote>
                  <xsl:copy-of select="tan:prep-string-for-docbook(tan:message)"/>
               </quote>
            </xsl:if>
         </para>
      </important>
   </xsl:template>
   <xsl:template match="tan:info" mode="context-errors-to-docbook">
      <info>
         <para>
            <xsl:copy-of select="tan:prep-string-for-docbook(tan:rule)"/>
         </para>
      </info>
   </xsl:template>

   <xsl:template name="rng-node-to-docbook-section">
      <!-- This is the main mechanism for populating sections that document the definition of an element, attribute, pattern, or global variable -->
      <xsl:param name="rng-element-or-attribute-group" as="element()*"/>
      <xsl:variable name="this-group" select="$rng-element-or-attribute-group"/>
      <!-- We prefer the term 'pattern' to 'define' to describe general patterns. -->
      <xsl:variable name="this-node-type"
         select="replace(name($this-group[1]), 'define', 'pattern')"/>
      <xsl:variable name="this-node-name" select="$this-group[1]/@name"/>
      <xsl:variable name="containing-definitions" select="$this-group/parent::rng:define"/>
      <xsl:variable name="possible-parents-of-this-node"
         select="$this-group/(ancestor::rng:element, rng:define)[last()], $rng-collection-without-TEI//rng:ref[@name = ($this-node-name, $containing-definitions/@name)]/(ancestor::rng:element, ancestor::rng:define)[last()]"/>
      <xsl:variable name="possible-parents-norm">
         <xsl:for-each select="$possible-parents-of-this-node">
            <xsl:variable name="this-name" select="@name"/>
            <xsl:choose>
               <xsl:when test="count(rng:*) gt 1 or not(rng:element or rng:attribute)">
                  <xsl:sequence select="."/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:sequence
                     select="$rng-collection-without-TEI//rng:ref[@name = ($this-name)]/(ancestor::rng:element, ancestor::rng:define)[last()]"
                  />
               </xsl:otherwise>
            </xsl:choose>
         </xsl:for-each>
      </xsl:variable>
      <section xml:id="{$this-node-type || '-' || replace($this-node-name,':','')}">
         <title>
            <code>
               <xsl:copy-of
                  select="tan:string-representation-of-component($this-node-name, $this-node-type)"
               />
            </code>
         </title>
         <!-- part 1, documentation -->
         <xsl:apply-templates select="$this-group/a:documentation" mode="rng-to-docbook"/>
         <!-- part 2a, formal definiton -->
         <para>Formal Definition</para>
         <synopsis>
            <xsl:apply-templates select="$this-group/rng:*" mode="formaldef">
               <xsl:with-param name="current-indent" select="$indent" tunnel="yes"/>
            </xsl:apply-templates>
         </synopsis>
         <!-- part 2, defined where? -->
         <para>Defined at: 
            <xsl:for-each
               select="
                  distinct-values(for $i in $this-group
                  return
                     base-uri($i))">
               <xsl:if test="position() gt 1">
                  <xsl:text>, </xsl:text>
               </xsl:if>
               <code>
                  <link xlink:href="{tan:uri-relative-to(., $target-uri-1)}">
                     <xsl:value-of select="replace(.,'.+/','')"/>
                  </link>
               </code>
            </xsl:for-each></para>
         <!-- part 3, parents -->
         <xsl:if test="exists($possible-parents-of-this-node)">
            <para>
               <xsl:text>Used by: </xsl:text>
               <xsl:for-each-group select="$possible-parents-of-this-node"
                  group-by="name() || '_' || @name">
                  <xsl:variable name="this-key" select="tokenize(current-grouping-key(), '_')"/>
                  <xsl:if test="position() gt 1">
                     <xsl:text>, </xsl:text>
                  </xsl:if>
                  <xsl:copy-of
                     select="tan:prep-string-for-docbook(tan:string-representation-of-component($this-key[2], $this-key[1]))"
                  />
               </xsl:for-each-group>
            </para>
         </xsl:if>
         <!-- part 4 and 5, errors and warnings and examples -->
         <xsl:choose>
            <xsl:when test="$this-node-type = 'element'">
               <xsl:apply-templates mode="context-errors-to-docbook"
                  select="$errors//tan:group[tokenize(@affects-element, '\s+') = $this-node-name]/tan:*"/>
               <xsl:copy-of select="tan:examples($this-node-name, false())"/>
            </xsl:when>
            <xsl:when test="$this-node-type = 'attribute'">
               <xsl:apply-templates mode="context-errors-to-docbook"
                  select="$errors//tan:group[tokenize(@affects-attribute, '\s+') = $this-node-name]/tan:*"/>
               <xsl:copy-of select="tan:examples($this-node-name, true())"/>
            </xsl:when>
         </xsl:choose>
      </section>
   </xsl:template>

   <xsl:template match="/*">

      <!-- Docbook inclusion for elements, attributes, and patterns -->

      <xsl:result-document href="{$target-uri-1}">
         <chapter version="5.0" xml:id="elements-attributes-and-patterns">
            <title>TAN patterns, elements, and attributes defined</title>
            <xsl:copy-of select="$chapter-caveat"/>
            <para>
               <xsl:value-of
                  select="'The ' || count($distinct-element-names) || ' elements and ' || count($distinct-attribute-names) || ' attributes defined in TAN, excluding TEI, are the following:'"
               />
            </para>
            <xsl:for-each
               select="$rng-collection-without-TEI[tan:cfn(.) = $sequence-of-sections/descendant-or-self::*/@n]">
               <xsl:sort>
                  <xsl:variable name="this-cfn" select="tan:cfn(.)"/>
                  <xsl:copy-of
                     select="count($sequence-of-sections//*[@n = $this-cfn]/(preceding::*, ancestor-or-self::*))"
                  />
               </xsl:sort>
               <xsl:variable name="this-name" select="tan:cfn(.)"/>
               <para>
                  <emphasis>
                     <xsl:value-of select="$this-name"/>
                  </emphasis>
                  <xsl:for-each select=".//(rng:element, rng:attribute)[@name]">
                     <xsl:sort select="lower-case(@name)"/>
                     <xsl:variable name="node-type" select="name()"/>
                     <xsl:variable name="node-name" select="@name"/>
                     <xsl:copy-of
                        select="tan:prep-string-for-docbook(tan:string-representation-of-component($node-name, $node-type))"/>
                     <xsl:text> </xsl:text>
                  </xsl:for-each>
               </para>
            </xsl:for-each>


            <xsl:for-each-group select="($attributes-excl-TEI, $elements-excl-TEI)"
               group-by="name() || ' ' || @name">
               <xsl:sort select="lower-case(current-grouping-key())"/>
               <xsl:variable name="node-type-and-name"
                  select="tokenize(current-grouping-key(), '\s+')"/>
               <xsl:variable name="this-node-type" select="$node-type-and-name[1]"/>
               <xsl:variable name="this-node-name" select="$node-type-and-name[2]"/>
               <xsl:call-template name="rng-node-to-docbook-section">
                  <xsl:with-param name="rng-element-or-attribute-group" select="current-group()"/>
               </xsl:call-template>
            </xsl:for-each-group>

            <section>
               <title>TAN patterns</title>
               <xsl:for-each-group select="$rng-collection-without-TEI//rng:define" group-by="@name">
                  <xsl:sort select="lower-case(@name)"/>
                  <xsl:call-template name="rng-node-to-docbook-section">
                     <xsl:with-param name="rng-element-or-attribute-group" select="current-group()"
                     />
                  </xsl:call-template>
               </xsl:for-each-group>
            </section>
         </chapter>
      </xsl:result-document>

      <!-- Docbook inclusion for vocabularies -->

      <xsl:result-document
         href="{resolve-uri('../../guidelines/inclusions/vocabularies.xml',static-base-uri())}">
         <chapter version="5.0" xml:id="vocabularies-master-list">
            <xsl:variable name="intro-text" as="xs:string">In this section are collected all
               official TAN vocabularies, i.e., values of @which predefined by TAN for certain elements.
               Remember, these vocabularies are not @xml:id values, and do not fall under the same
               restrictions. They may contain punctuation, spaces, and so forth. For more on the use
               of these vocabularies, see @which, specific elements, or various examples.
            </xsl:variable>
            <title>Official TAN vocabularies</title>
            <para>
               <xsl:copy-of select="tan:prep-string-for-docbook(normalize-space($intro-text))"/>
            </para>
            <xsl:copy-of select="$chapter-caveat"/>
            <xsl:apply-templates select="$vocabulary-collection" mode="vocabularies-to-docbook"/>
         </chapter>
      </xsl:result-document>

      <!-- Docbook inclusion for variables, keys, functions, and templates -->

      <xsl:result-document
         href="{resolve-uri('../../guidelines/inclusions/variables-keys-functions-and-templates.xml',static-base-uri())}">
         <chapter version="5.0" xml:id="variables-keys-functions-and-templates">
            <title>TAN variables, keys, functions, and templates</title>
            <para>
               <xsl:value-of
                  select="
                     'The ' || count(distinct-values($function-library-variables/@name)) || ' global variables, ' || count(distinct-values($function-library-keys/@name)) || ' keys, ' || count(distinct-values($function-library-functions/@name)) || ' functions, and ' || count(distinct-values(for $i in $function-library-templates/(@name, @mode)
                     return
                     tokenize($i, '\s+'))) || ' templates (Ŧ = named template; ŧ = template mode) defined in the TAN function library, are the following (ʞ = key):'"
               />
            </para>
            <xsl:for-each-group
               select="($function-library-keys, $function-library-functions, $function-library-variables, $function-library-templates)"
               group-by="
                  if (exists(@name)) then
                     substring(replace(@name, '^\w+:', ''), 1, 1)
                  else
                     for $i in tokenize(@mode, '\s+')
                     return
                        substring(replace($i, '^\w+:', ''), 1, 1)">
               <xsl:sort select="lower-case(current-grouping-key())"/>
               <xsl:variable name="this-letter" select="lower-case(current-grouping-key())"/>
               <para>
                  <xsl:for-each-group select="current-group()"
                     group-by="
                        if (exists(@name)) then
                           (name() || ' ' || @name)
                        else
                           for $i in tokenize(@mode, '\s+')[matches(lower-case(.), ('^' || $this-letter))]
                           return
                              (name() || ' ' || $i)">
                     <xsl:sort
                        select="lower-case(replace(tokenize(current-grouping-key(), '\s+')[2], '^\w+:', ''))"/>
                     <xsl:variable name="node-type-and-name"
                        select="tokenize(current-grouping-key(), '\s+')"/>
                     <xsl:copy-of
                        select="tan:prep-string-for-docbook(tan:string-representation-of-component($node-type-and-name[2], $node-type-and-name[1], exists(current-group()/@mode)))"/>
                     <xsl:text> </xsl:text>
                  </xsl:for-each-group>
               </para>
               <xsl:text>
</xsl:text>
            </xsl:for-each-group>
            <xsl:copy-of select="$chapter-caveat"/>
            <!-- First, group according to place in the TAN hierarchy the variables, keys, functions, and named templates, which are all unique and so can take an id; because template modes spread out across components, they need to be handled outside the TAN hierarchical structure -->
            <xsl:for-each-group group-by="replace(tan:cfn(.), '-functions', '')"
               select="($function-library-keys, $function-library-functions[not(@name = $names-of-functions-to-append)], $function-library-variables-unique, $function-library-templates[@name])">
               <xsl:sort
                  select="count($sequence-of-sections//*[@n = current-grouping-key()]/(preceding::*, ancestor-or-self::*))"
               />
               <xsl:variable name="this-file-name" select="current-grouping-key()"/>
               <xsl:variable name="these-components-to-traverse" select="current-group()"/>
               <section>
                  <title>
                     <xsl:value-of
                        select="$this-file-name || ' global variables, keys, and functions summarized'"
                     />
                  </title>
                  <xsl:for-each-group select="$these-components-to-traverse" group-by="name()">
                     <!-- This is a group of variables, keys, functions, and named templates, but not template modes, which are handled later -->
                     <xsl:sort
                        select="index-of(('xsl:variable', 'xsl:key', 'xsl:function', 'xsl:template'), current-grouping-key())"/>
                     <xsl:variable name="this-type-of-component"
                        select="replace(current-grouping-key(), 'xsl:(.+)', '$1')"/>
                     <section>
                        <title>
                           <xsl:value-of select="$this-type-of-component || 's'"/>
                        </title>
                        <xsl:for-each-group select="current-group()" group-by="@name">
                           <!-- This is a group of variables, keys, functions, or named templates that share the same name (grouping is mainly for functions) -->
                           <xsl:sort select="lower-case(@name)"/>
                           <xsl:variable name="what-depends-on-this"
                              select="tan:xslt-dependencies(current-grouping-key(), $this-type-of-component, false(), $all-functions)[name() = ('xsl:function', 'xsl:variable', 'xsl:template', 'xsl:key')]"/>
                           <xsl:variable name="this-group-count" select="count(current-group())"/>
                           <section
                              xml:id="{$this-type-of-component || '-' || replace(current-grouping-key(),'^\w+:','')}">
                              <title>
                                 <code>
                                    <xsl:value-of
                                       select="tan:string-representation-of-component(current-grouping-key(), $this-type-of-component)"
                                    />
                                 </code>
                              </title>
                              <xsl:for-each select="current-group()">
                                 <!-- This fetches an individual variable, key, function, or named template -->
                                 <xsl:if test="$this-group-count gt 1">
                                    <para>
                                       <emphasis>Option <xsl:value-of select="position()"/>
                                          <xsl:value-of select="' (' || tan:cfn(.) || ')'"/>
                                       </emphasis>
                                    </para>
                                 </xsl:if>
                                 <!-- Insert remarks specific to the type of component, e.g., the input and output expectations of a function -->
                                 <xsl:choose>
                                    <xsl:when test="$this-type-of-component = 'key'">
                                       <para>Looks for elements matching <code>
                                             <xsl:value-of select="@match"/>
                                          </code>
                                       </para>
                                    </xsl:when>
                                    <xsl:when test="$this-type-of-component = 'function'">
                                       <xsl:variable name="these-params" select="xsl:param"/>
                                       <xsl:variable name="param-text" as="xs:string*"
                                          select="
                                             for $i in $these-params
                                             return
                                                '$' || $i/@name || (if (exists($i/@as)) then
                                                   (' as ' || $i/@as)
                                                else
                                                   ())"/>
                                       <para>
                                          <code>
                                             <xsl:value-of select="@name"/>(<xsl:value-of
                                                select="string-join($param-text, ', ')"/>) <xsl:if
                                                test="exists(@as)">as <xsl:value-of select="@as"/>
                                             </xsl:if>
                                          </code>
                                       </para>
                                    </xsl:when>
                                    <xsl:when test="$this-type-of-component = 'variable'">
                                       <xsl:choose>
                                          <xsl:when test="exists(@select)">
                                             <para>Definition: <code>
                                                  <xsl:copy-of
                                                  select="tan:copy-of-except(tan:prep-string-for-docbook(@select), (), (), (), (), 'code')"
                                                  />
                                                </code>
                                             </para>
                                          </xsl:when>
                                          <xsl:otherwise>
                                             <para>This variable has a complex definition. See
                                                stylesheet for definiton.</para>
                                          </xsl:otherwise>
                                       </xsl:choose>
                                    </xsl:when>
                                 </xsl:choose>
                                 <!-- Insert prefatory comments placed inside the component -->
                                 <xsl:copy-of select="tan:component-comments-to-docbook(.)"/>
                                 <!-- State what depends on this -->
                                 <xsl:copy-of select="tan:component-dependees-to-docbook(.)"/>
                                 <!-- State what it depends upon -->
                                 <xsl:copy-of select="tan:component-dependencies-to-docbook(.)"/>
                              </xsl:for-each>
                           </section>
                           <xsl:text>
</xsl:text>
                        </xsl:for-each-group>
                     </section>
                     <xsl:text>
</xsl:text>
                  </xsl:for-each-group>
                  <xsl:if test="not(exists($these-components-to-traverse))">
                     <para>
                        <xsl:value-of
                           select="'No variables, keys, functions, or named templates are defined for ' || $this-file-name || '.'"
                        />
                     </para>
                  </xsl:if>
               </section>
               <xsl:text>
</xsl:text>
            </xsl:for-each-group>
            <xsl:for-each-group
               select="($function-library-templates[@mode], $function-library-variables-duplicate, $function-library-functions[@name = $names-of-functions-to-append])"
               group-by="name()">
               <xsl:variable name="this-type-of-component"
                  select="replace(current-grouping-key(), '^.+:', '')"/>
               <section>
                  <xsl:choose>
                     <xsl:when test="$this-type-of-component = 'variable'">
                        <title>Cross-format global variables</title>
                        <para>Global variables that straddle different files in the TAN function
                           library.</para>
                     </xsl:when>
                     <xsl:when test="$this-type-of-component = 'function'">
                        <title>Cross-format functions</title>
                        <para>Some functions are defined differently according to different TAN formats.</para>
                     </xsl:when>
                     <xsl:otherwise>
                        <title>Mode templates</title>
                        <para>Templates based on modes are frequently found across constituent
                           files, so they are collated here separately, one entry per mode.</para>
                     </xsl:otherwise>
                  </xsl:choose>
                  <xsl:for-each-group select="current-group()" group-by="tokenize((@mode, @name)[1], '\s+')">
                     <xsl:sort select="lower-case(current-grouping-key())"/>
                     <xsl:variable name="this-template-id"
                        select="$this-type-of-component || '-' || replace(current-grouping-key(), '#|^.+:', '')"
                     />
                     <section xml:id="{$this-template-id}">
                        <title>
                           <code>
                              <xsl:value-of
                                 select="tan:string-representation-of-component(current-grouping-key(), $this-type-of-component, exists(current-group()/@mode))"
                              />
                           </code>
                        </title>
                        <para>
                           <xsl:value-of select="count(current-group())"/> element<xsl:if
                              test="count(current-group()) gt 1">s</xsl:if>: <xsl:for-each-group
                              select="current-group()" group-by="tan:cfn(.)">
                              <code>
                                 <xsl:value-of select="current-grouping-key() || '.xsl '"/>
                              </code>
                           </xsl:for-each-group>
                        </para>
                        <xsl:copy-of select="tan:component-comments-to-docbook(current-group())"/>
                        <xsl:copy-of select="tan:component-dependees-to-docbook(current-group()[1])"/>
                        <xsl:copy-of select="tan:component-dependencies-to-docbook(current-group())"
                        />
                     </section>
                  </xsl:for-each-group>
               </section>
            </xsl:for-each-group>
         </chapter>
      </xsl:result-document>

      <!-- Docbook inclusion for errors -->

      <xsl:result-document
         href="{resolve-uri('../../guidelines/inclusions/errors.xml',static-base-uri())}">
         <chapter version="5.0" xml:id="errors">
            <title>Errors</title>
            <para>Below is a list of <xsl:value-of select="count($errors//*[@xml:id])"/>
               specifically defined TAN errors.</para>
            <xsl:copy-of select="$chapter-caveat"/>
            <xsl:for-each select="$errors//*[@xml:id]">
               <xsl:sort select="@xml:id"/>
               <xsl:apply-templates select="." mode="errors-to-docbook"/>
            </xsl:for-each>
         </chapter>
      </xsl:result-document>
   </xsl:template>

</xsl:stylesheet>
