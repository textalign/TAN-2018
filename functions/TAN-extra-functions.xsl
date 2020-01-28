<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="tag:textalign.net,2015:ns" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:fn="http://www.w3.org/2005/xpath-functions" xmlns:saxon="http://saxon.sf.net/"
   xmlns:math="http://www.w3.org/2005/xpath-functions/math" exclude-result-prefixes="#all"
   version="3.0">

   <xsl:include href="extra/TAN-function-functions.xsl"/>
   <xsl:include href="extra/TAN-schema-functions.xsl"/>

   <!-- Functions that are not central to validating TAN files, but could be helpful in creating, editing, or reusing them -->

   <!-- Global variables and parameters -->
   <!-- An xpath pattern looks like this: {PATTERN} -->
   <xsl:variable name="xpath-pattern" select="'\{[^\}]+?\}'"/>
   <xsl:variable name="namespaces-and-prefixes" as="element()">
      <namespaces>
         <ns prefix="" uri=""/>
         <ns prefix="cp" uri="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"/>
         <ns prefix="dc" uri="http://purl.org/dc/elements/1.1/"/>
         <ns prefix="dcmitype" uri="http://purl.org/dc/dcmitype/"/>
         <ns prefix="dcterms" uri="http://purl.org/dc/terms/"/>
         <ns prefix="html" uri="http://www.w3.org/1999/xhtml"/>
         <ns prefix="m" uri="http://schemas.openxmlformats.org/officeDocument/2006/math"/>
         <ns prefix="mc" uri="http://schemas.openxmlformats.org/markup-compatibility/2006"/>
         <ns prefix="mo" uri="http://schemas.microsoft.com/office/mac/office/2008/main"/>
         <ns prefix="mv" uri="urn:schemas-microsoft-com:mac:vml"/>
         <ns prefix="o" uri="urn:schemas-microsoft-com:office:office"/>
         <ns prefix="r" uri="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/>
         <ns prefix="rel" uri="http://schemas.openxmlformats.org/package/2006/relationships"/>
         <ns prefix="tei" uri="http://www.tei-c.org/ns/1.0"/>
         <ns prefix="tan" uri="tag:textalign.net,2015:ns"/>
         <ns prefix="v" uri="urn:schemas-microsoft-com:vml"/>
         <ns prefix="w" uri="http://schemas.openxmlformats.org/wordprocessingml/2006/main"/>
         <ns prefix="w10" uri="urn:schemas-microsoft-com:office:word"/>
         <ns prefix="w14" uri="http://schemas.microsoft.com/office/word/2010/wordml"/>
         <ns prefix="w15" uri="http://schemas.microsoft.com/office/word/2012/wordml"/>
         <ns prefix="wne" uri="http://schemas.microsoft.com/office/word/2006/wordml"/>
         <ns prefix="wp" uri="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"/>
         <ns prefix="wp14" uri="http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing"/>
         <ns prefix="wpc" uri="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas"/>
         <ns prefix="wpg" uri="http://schemas.microsoft.com/office/word/2010/wordprocessingGroup"/>
         <ns prefix="wpi" uri="http://schemas.microsoft.com/office/word/2010/wordprocessingInk"/>
         <ns prefix="wps" uri="http://schemas.microsoft.com/office/word/2010/wordprocessingShape"/>
         <ns prefix="xs" uri="http://www.w3.org/2001/XMLSchema"/>
         <ns prefix="xsi" uri="http://www.w3.org/2001/XMLSchema-instance"/>
         <ns prefix="xsl" uri="http://www.w3.org/1999/XSL/Transform"/>
      </namespaces>
   </xsl:variable>
   
   
   <!-- Parameters can be easily changed upstream by users who wish to depart from the defaults -->
   <xsl:param name="searches-ignore-accents" select="true()" as="xs:boolean"/>
   <xsl:param name="searches-are-case-sensitive" select="false()" as="xs:boolean"/>
   <xsl:param name="match-flags"
      select="
         if ($searches-are-case-sensitive = true()) then
            ()
         else
            'i'"
      as="xs:string?"/>
   <xsl:param name="searches-suppress-what-text" as="xs:string?" select="'[\p{M}]'"/>


   <!-- Functions: numerics -->

   <xsl:function name="tan:grc-to-int" as="xs:integer*">
      <!-- Input: Greek letters that represent numerals -->
      <!-- Output: the numerical value of the letters -->
      <!-- NB, this does not take into account the use of letters representing numbers 1000 and greater -->
      <xsl:param name="greek-numerals" as="xs:string*"/>
      <xsl:value-of select="tan:letter-to-number($greek-numerals)"/>
   </xsl:function>

   <xsl:function name="tan:syr-to-int" as="xs:integer*">
      <!-- Input: Syriac letters that represent numerals -->
      <!-- Output: the numerical value of the letters -->
      <!-- NB, this does not take into account the use of letters representing numbers 1000 and greater -->
      <xsl:param name="syriac-numerals" as="xs:string*"/>
      <xsl:for-each select="$syriac-numerals">
         <xsl:variable name="orig-numeral-seq" as="xs:string*">
            <xsl:analyze-string select="." regex=".">
               <xsl:matching-substring>
                  <xsl:value-of select="."/>
               </xsl:matching-substring>
            </xsl:analyze-string>
         </xsl:variable>
         <!-- The following removes redoubled numerals as often happens in Syriac, to indicate clearly that a character is a numeral not a letter. -->
         <xsl:variable name="duplicates-stripped"
            select="
               for $i in (1 to count($orig-numeral-seq))
               return
                  if ($orig-numeral-seq[$i] = $orig-numeral-seq[$i + 1]) then
                     ()
                  else
                     $orig-numeral-seq[$i]"/>
         <xsl:value-of select="tan:letter-to-number(string-join($duplicates-stripped, ''))"/>
      </xsl:for-each>
   </xsl:function>

   <xsl:function name="tan:ordinal" xml:id="f-ordinal" as="xs:string*">
      <!-- Input: one or more numerals
        Output: one or more strings with the English form of the ordinal form of the input number
        E.g., (1, 4, 17)  ->  ('first','fourth','17th'). 
        -->
      <xsl:param name="in" as="xs:integer*"/>
      <xsl:variable name="ordinals"
         select="
            ('first',
            'second',
            'third',
            'fourth',
            'fifth',
            'sixth',
            'seventh',
            'eighth',
            'ninth',
            'tenth')"/>
      <xsl:variable name="ordinal-suffixes"
         select="
            ('th',
            'st',
            'nd',
            'rd',
            'th',
            'th',
            'th',
            'th',
            'th',
            'th')"/>
      <xsl:copy-of
         select="
            for $i in $in
            return
               if (exists($ordinals[$i]))
               then
                  $ordinals[$i]
               else
                  if ($i lt 1) then
                     'none'
                  else
                     concat(xs:string($i), $ordinal-suffixes[($i mod 10) + 1])"
      />
   </xsl:function>

   <xsl:function name="tan:counts-to-lasts" xml:id="f-counts-to-lasts" as="xs:integer*">
      <!-- Input: sequence of numbers representing counts of items. 
         Output: sequence of numbers representing the last position of each item within the total count.
      E.g., (4, 12, 0, 7) - > (4, 16, 16, 23)-->
      <xsl:param name="seq" as="xs:integer*"/>
      <xsl:copy-of
         select="
            for $i in (1 to count($seq))
            return
               sum(for $j in (1 to $i)
               return
                  $seq[$j])"
      />
   </xsl:function>

   <xsl:function name="tan:counts-to-firsts" xml:id="f-counts-to-firsts" as="xs:integer*">
      <!-- Input: sequence of numbers representing counts of items.  -->
      <!-- Output: sequence of numbers representing the first position of each item within the total count.
      E.g., (4, 12, 0, 7) - > (1, 5, 17, 17)-->
      <xsl:param name="seq" as="xs:integer*"/>
      <xsl:copy-of
         select="
            for $i in (1 to count($seq))
            return
               sum(for $j in (1 to $i)
               return
                  $seq[$j]) - $seq[$i] + 1"
      />
   </xsl:function>

   <xsl:function name="tan:product" as="xs:double?">
      <!-- Input: a sequence of numbers -->
      <!-- Output: the product of those numbers -->
      <xsl:param name="numbers" as="item()*"/>
      <xsl:copy-of select="tan:product-loop($numbers[1], subsequence($numbers, 2))"/>
   </xsl:function>
   <xsl:function name="tan:product-loop" as="xs:double?">
      <xsl:param name="product-so-far" as="xs:double?"/>
      <xsl:param name="numbers-to-multiply" as="item()*"/>
      <xsl:choose>
         <xsl:when test="count($numbers-to-multiply) lt 1">
            <xsl:copy-of select="$product-so-far"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:copy-of
               select="tan:product-loop(($product-so-far * xs:double($numbers-to-multiply[1])), subsequence($numbers-to-multiply, 2))"
            />
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>

   <xsl:function name="tan:number-sort" as="xs:double*">
      <!-- Input: any sequence of items -->
      <!-- Output: the same sequence, sorted with string numerals converted to numbers -->
      <xsl:param name="numbers" as="xs:anyAtomicType*"/>
      <xsl:variable name="numbers-norm" as="item()*"
         select="
            for $i in $numbers
            return
               if ($i instance of xs:string) then
                  number($i)
               else
                  $i"/>
      <xsl:for-each select="$numbers-norm">
         <xsl:sort/>
         <xsl:copy-of select="."/>
      </xsl:for-each>
   </xsl:function>

   <xsl:function name="tan:median" as="xs:double?">
      <!-- Input: any sequence of numbers -->
      <!-- Output: the median value -->
      <!-- It is assumed that the input has already been sorted by tan:numbers-sorted() vel sim -->
      <xsl:param name="numbers" as="xs:double*"/>
      <xsl:variable name="number-count" select="count($numbers)"/>
      <xsl:variable name="mid-point" select="$number-count div 2"/>
      <xsl:variable name="mid-point-ceiling" select="ceiling($mid-point)"/>
      <xsl:choose>
         <xsl:when test="$mid-point = $mid-point-ceiling">
            <xsl:copy-of
               select="avg(($numbers[$mid-point-ceiling], $numbers[$mid-point-ceiling - 1]))"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:copy-of select="xs:double($numbers[$mid-point-ceiling])"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>

   <xsl:function name="tan:outliers" as="xs:anyAtomicType*">
      <!-- Input: any sequence of numbers -->
      <!-- Output: outliers in the sequence, -->
      <xsl:param name="numbers" as="xs:anyAtomicType*"/>
      <xsl:variable name="numbers-sorted" select="tan:number-sort($numbers)" as="xs:anyAtomicType*"/>
      <xsl:variable name="half-point" select="count($numbers) idiv 2"/>
      <xsl:variable name="top-half" select="$numbers-sorted[position() le $half-point]"/>
      <xsl:variable name="bottom-half" select="$numbers-sorted[position() gt $half-point]"/>
      <xsl:variable name="q1" select="tan:median($top-half)"/>
      <xsl:variable name="q2" select="tan:median($numbers)"/>
      <xsl:variable name="q3" select="tan:median($bottom-half)"/>
      <xsl:variable name="interquartile-range" select="$q3 - $q1"/>
      <xsl:variable name="outer-fences" select="$interquartile-range * 3"/>
      <xsl:variable name="top-fence" select="$q1 - $outer-fences"/>
      <xsl:variable name="bottom-fence" select="$q3 + $outer-fences"/>
      <xsl:variable name="top-outliers" select="$top-half[. lt $top-fence]"/>
      <xsl:variable name="bottom-outliers" select="$bottom-half[. gt $bottom-fence]"/>
      <xsl:for-each select="$numbers">
         <xsl:variable name="this-number"
            select="
               if (. instance of xs:string) then
                  number(.)
               else
                  xs:double(.)"/>
         <xsl:if test="$this-number = ($top-outliers, $bottom-outliers)">
            <xsl:copy-of select="."/>
         </xsl:if>
      </xsl:for-each>
   </xsl:function>

   <xsl:function name="tan:no-outliers" as="xs:anyAtomicType*">
      <!-- Input: any sequence of numbers -->
      <!-- Output: the same sequence, without outliers -->
      <xsl:param name="numbers" as="xs:anyAtomicType*"/>
      <xsl:variable name="outliers" select="tan:outliers($numbers)"/>
      <xsl:copy-of select="$numbers[not(. = $outliers)]"/>
   </xsl:function>


   <xsl:function name="tan:analyze-stats" as="element()?">
      <!-- Input: a sequence of numbers -->
      <!-- Output: a single <stats> with attributes calculating the count, sum, average, max, min, variance, standard deviation, and then one child <d> per datum with the value of the datum -->
      <xsl:param name="arg" as="xs:anyAtomicType*"/>
      <xsl:variable name="this-avg" select="avg($arg)"/>
      <xsl:variable name="these-deviations"
         select="
            for $i in $arg
            return
               math:pow(($i - $this-avg), 2)"/>
      <xsl:variable name="this-variance" select="avg($these-deviations)"/>
      <xsl:variable name="this-standard-deviation" select="math:sqrt($this-variance)"/>
      <stats>
         <xsl:attribute name="count" select="count($arg)"/>
         <xsl:attribute name="sum" select="sum($arg)"/>
         <xsl:attribute name="avg" select="$this-avg"/>
         <xsl:attribute name="max" select="max($arg)"/>
         <xsl:attribute name="min" select="min($arg)"/>
         <xsl:attribute name="var" select="$this-variance"/>
         <xsl:attribute name="std" select="$this-standard-deviation"/>
         <xsl:for-each select="$arg">
            <xsl:variable name="pos" select="position()"/>
            <xsl:element name="d" namespace="tag:textalign.net,2015:ns">
               <xsl:attribute name="dev" select="$these-deviations[$pos]"/>
               <xsl:value-of select="."/>
            </xsl:element>
         </xsl:for-each>
      </stats>
   </xsl:function>

   <xsl:function name="tan:merge-analyzed-stats" as="element()">
      <!-- Takes a group of elements that follow the pattern that results from tan:analyze-stats and synthesizes them into a single element. If $add-stats is true, then they are added; if false, the sum of the 2nd - last elements is subtracted from the first; if neither true nor false, nothing happens. Will work on elements of any name, so long as they have tan:d children, with the data points to be merged. -->
      <xsl:param name="analyzed-stats" as="element()*"/>
      <xsl:param name="add-stats" as="xs:boolean?"/>
      <xsl:variable name="datum-counts" as="xs:integer*"
         select="
            for $i in $analyzed-stats
            return
               count($i/tan:d)"/>
      <xsl:variable name="data-summed" as="xs:anyAtomicType*"
         select="
            for $i in (1 to $datum-counts[1])
            return
               sum($analyzed-stats/tan:d[$i])"/>
      <xsl:variable name="data-diff" as="element()">
         <stats>
            <xsl:attribute name="count"
               select="(avg($analyzed-stats[position() gt 1]/@count)) - $analyzed-stats[1]/@count"/>
            <xsl:attribute name="sum"
               select="(avg($analyzed-stats[position() gt 1]/@sum)) - $analyzed-stats[1]/@sum"/>
            <xsl:attribute name="avg"
               select="(avg($analyzed-stats[position() gt 1]/@avg)) - $analyzed-stats[1]/@avg"/>
            <xsl:attribute name="max"
               select="(avg($analyzed-stats[position() gt 1]/@max)) - $analyzed-stats[1]/@max"/>
            <xsl:attribute name="min"
               select="(avg($analyzed-stats[position() gt 1]/@min)) - $analyzed-stats[1]/@min"/>
            <xsl:attribute name="var"
               select="(avg($analyzed-stats[position() gt 1]/@var)) - $analyzed-stats[1]/@var"/>
            <xsl:attribute name="std"
               select="(avg($analyzed-stats[position() gt 1]/@std)) - $analyzed-stats[1]/@std"/>
            <xsl:for-each select="$analyzed-stats[1]/tan:d">
               <xsl:variable name="pos" select="position()"/>
               <d>
                  <xsl:copy-of
                     select="avg($analyzed-stats[position() gt 1]/tan:d[$pos]) - $analyzed-stats[1]/tan:d[$pos]"
                  />
               </d>
            </xsl:for-each>
         </stats>
      </xsl:variable>
      <stats>
         <xsl:choose>
            <xsl:when test="$analyzed-stats/tan:d and count(distinct-values($datum-counts)) gt 1">
               <xsl:copy-of select="tan:error('adv03', $datum-counts)"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:choose>
                  <xsl:when test="$add-stats = true() and $analyzed-stats/tan:d">
                     <xsl:copy-of select="tan:analyze-stats($data-summed)/(@*, node())"/>
                  </xsl:when>
                  <xsl:when test="$add-stats = false() and $analyzed-stats/tan:d">
                     <xsl:copy-of select="$data-diff/(@*, node())"/>
                     <!--<xsl:copy-of select="tan:analyze-stats($data-diff)/(@*, node())"/>-->
                  </xsl:when>
               </xsl:choose>
            </xsl:otherwise>
         </xsl:choose>
      </stats>
   </xsl:function>


   <!-- Functions: strings -->

   <xsl:function name="tan:namespace" as="xs:string*">
      <!-- Input: any strings representing a namespace prefix or uri -->
      <!-- Output: the corresponding prefix or uri whenever a match is found in the global variable -->
      <xsl:param name="prefix-or-uri" as="xs:string*"/>
      <xsl:for-each select="$prefix-or-uri">
         <xsl:variable name="this-string" select="."/>
         <xsl:value-of select="$namespaces-and-prefixes/*[@* = $this-string]/(@*[not(. = $this-string)])[1]"/>
      </xsl:for-each>
   </xsl:function>

   <xsl:function name="tan:blob-to-regex" as="xs:string*">
      <!-- Input: any strings that follow a blob-like syntax -->
      <!-- Output: the strings converted to regular expressions -->
      <xsl:param name="globs" as="xs:string*"/>
      <xsl:for-each select="$globs">
         <xsl:variable name="pass1" select="replace(., '\*', '.*')"/>
         <xsl:variable name="pass2" select="replace($pass1, '\?', '.')"/>
         <xsl:value-of select="concat('^', $pass2, '$')"/>
      </xsl:for-each>
   </xsl:function>


   <!-- Functions: booleans -->

   <xsl:function name="tan:true" as="xs:boolean*">
      <!-- Input: a sequence of strings representing truth values -->
      <!-- Output: the same number of booleans; if the string is some approximation of y, yes, 1, or true, then it is true, and false otherwise -->
      <xsl:param name="string" as="xs:string*"/>
      <xsl:for-each select="$string">
         <xsl:choose>
            <xsl:when test="matches(., '^y(es)?|1|t(rue)?$', 'i')">
               <xsl:value-of select="true()"/>
            </xsl:when>
            <xsl:when test="matches(., '^n(o)?|0|f(alse)?$', 'i')">
               <xsl:value-of select="false()"/>
            </xsl:when>
         </xsl:choose>
      </xsl:for-each>
   </xsl:function>


   <!-- Functions: nodes -->

   <xsl:function name="tan:node-type" as="xs:string*">
      <!-- Input: any XML items -->
      <!-- Output: the node types of each item -->
      <xsl:param name="xml-items" as="item()*"/>
      <xsl:for-each select="$xml-items">
         <xsl:choose>
            <xsl:when test=". instance of document-node()">document-node</xsl:when>
            <xsl:when test=". instance of comment()">comment</xsl:when>
            <xsl:when test=". instance of processing-instruction()">processing-instruction</xsl:when>
            <xsl:when test=". instance of element()">element</xsl:when>
            <xsl:when test=". instance of attribute()">attribute</xsl:when>
            <xsl:when test=". instance of text()">text</xsl:when>
            <xsl:when test=". instance of xs:boolean">boolean</xsl:when>
            <xsl:when test=". instance of map(*)">map</xsl:when>
            <xsl:when test=". instance of array(*)">array</xsl:when>
            <xsl:otherwise>undefined</xsl:otherwise>
         </xsl:choose>
      </xsl:for-each>
   </xsl:function>

   <xsl:function name="tan:group-elements" as="element()*">
      <!-- Input: any elements that should be grouped; parameters specifying minimum size of grouping and the name of a label to prepend -->
      <!-- Output: those elements grouped -->
      <!-- This function was written primarily for the major alter function -->
      <xsl:param name="elements-to-group" as="element()*"/>
      <xsl:param name="group-min" as="xs:double?"/>
      <xsl:param name="label-to-prepend"/>
      <xsl:variable name="group-namespace" select="namespace-uri($elements-to-group[1])"/>
      <xsl:variable name="expected-group-size" select="max(($group-min, 1))"/>
      <xsl:choose>
         <xsl:when test="count($elements-to-group) ge $expected-group-size">
            <xsl:element name="group" namespace="{$group-namespace}">
               <xsl:if test="string-length($label-to-prepend) gt 0">
                  <xsl:element name="label" namespace="{$group-namespace}">
                     <xsl:value-of select="tan:evaluate($label-to-prepend, $elements-to-group[1], $elements-to-group)"/>
                  </xsl:element>
               </xsl:if>
               <xsl:copy-of select="$elements-to-group"/>
            </xsl:element>
         </xsl:when>
         <xsl:otherwise>
            <xsl:copy-of select="$elements-to-group"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>
   
   <xsl:template match="text()" mode="strip-text"/>
   
   <xsl:template match="* | comment() | processing-instruction()" mode="text-only">
      <xsl:apply-templates mode="#current"/>
   </xsl:template>
   
   <xsl:template match="* | processing-instruction() | comment()" mode="prepend-line-break">
      <!-- Useful for breaking up XML content that is not indented -->
      <xsl:text>&#xa;</xsl:text>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   
   <xsl:function name="tan:element-fingerprint" as="xs:string?">
      <!-- Input: any element -->
      <!-- Output: a string representing a value of the element based on the element's name, its namespace, its attributes, and all descendant nodes -->
      <!-- This function is useful for determining whether two elements are deeply equal, particularly to be used as a key for grouping -->
      <xsl:param name="element" as="element()?"/>
      <xsl:variable name="results" as="xs:string*">
         <xsl:apply-templates select="$element" mode="element-fingerprint"/>
      </xsl:variable>
      <xsl:value-of select="string-join($results,'')"/>
   </xsl:function>
   <xsl:template match="*" mode="element-fingerprint">
      <xsl:text>e#</xsl:text>
      <xsl:value-of select="name()"/>
      <xsl:text>ns#</xsl:text>
      <xsl:value-of select="namespace-uri()"/>
      <xsl:text>aa#</xsl:text>
      <xsl:for-each select="@*">
         <xsl:sort select="name()"/>
         <xsl:text>a#</xsl:text>
         <xsl:value-of select="name()"/>
         <xsl:text>#</xsl:text>
         <xsl:value-of select="normalize-space(.)"/>
         <xsl:text>#</xsl:text>
      </xsl:for-each>
      <xsl:apply-templates select="node()" mode="#current"/>
   </xsl:template>
   <!-- We presume (perhaps wrongly) that comments and pi's in an element don't matter -->
   <xsl:template match="comment() | processing-instruction()" mode="element-fingerprint"/>
   <xsl:template match="text()" mode="element-fingerprint">
         <xsl:if test="matches(., '\S')">
            <xsl:text>t#</xsl:text>
            <xsl:value-of select="normalize-space(.)"/>
            <xsl:text>#</xsl:text>
         </xsl:if>
   </xsl:template>
   
   <xsl:function name="tan:add-attribute" as="element()*">
      <!-- Input: elements; a string and a value -->
      <!-- Output: Each element with an attribute given the name of the string and a value of the value -->
      <xsl:param name="elements-to-change" as="element()*"/>
      <xsl:param name="attribute-name" as="xs:string?"/>
      <xsl:param name="attribute-value" as="item()?"/>
      <xsl:for-each select="$elements-to-change">
         <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:attribute name="{$attribute-name}">
               <xsl:value-of select="$attribute-value"/>
            </xsl:attribute>
            <xsl:copy-of select="node()"/>
         </xsl:copy>
      </xsl:for-each>
   </xsl:function>
   

   <!-- Functions: sequences-->

   <xsl:function name="tan:most-common-item" as="item()?">
      <!-- Input: any sequence of items -->
      <!-- Output: the one item that appears most frequently -->
      <!-- If two or more items appear equally frequently, only the first is returned -->
      <xsl:param name="sequence" as="item()*"/>
      <xsl:for-each-group select="$sequence" group-by=".">
         <xsl:sort select="count(current-group())" order="descending"/>
         <xsl:if test="position() = 1">
            <xsl:copy-of select="current-group()[1]"/>
         </xsl:if>
      </xsl:for-each-group>
   </xsl:function>


   <!-- Functions: accessors and manipulation of uris -->

   <xsl:function name="tan:zip-uris" as="xs:anyURI*">
      <!-- Input: any string representing a uri -->
      <!-- Output: the same string with 'zip:' prepended if it represents a uri to a file in an archive (docx, jar, zip, etc.) -->
      <xsl:param name="uris" as="xs:string*"/>
      <xsl:for-each select="$uris">
         <xsl:value-of
            select="
               if (matches(., '!/')) then
                  concat('zip:', .)
               else
                  ."
         />
      </xsl:for-each>
   </xsl:function>


   <!-- Functions: XPath Functions and Operators -->

   <xsl:function name="tan:evaluate" as="item()*">
      <!-- 2-param version of the fuller one below -->
      <xsl:param name="string-with-xpath-to-evaluate" as="xs:string"/>
      <xsl:param name="context-1" as="item()*"/>
      <xsl:copy-of select="tan:evaluate($string-with-xpath-to-evaluate, $context-1, ())"/>
   </xsl:function>
   <xsl:function name="tan:evaluate" as="item()*">
      <!-- Input: a string to be evaluated in light of XPath expressions; a context node -->
      <!-- Output: the result of the string evaluated as an XPath statement against the context node -->
      <xsl:param name="string-with-xpath-to-evaluate" as="xs:string"/>
      <xsl:param name="context-1" as="item()*"/>
      <xsl:param name="context-2" as="item()*"/>
      <xsl:if test="string-length($string-with-xpath-to-evaluate) gt 0">
         <xsl:variable name="results" as="item()*">
            <xsl:analyze-string select="$string-with-xpath-to-evaluate" regex="{$xpath-pattern}">
               <xsl:matching-substring>
                  <xsl:variable name="this-xpath" select="replace(., '[\{\}]', '')"/>
                  <xsl:choose>
                     <xsl:when test="function-available('saxon:evaluate')">
                        <!-- If saxon:evaluate is available, use it -->
                        <xsl:copy-of select="saxon:evaluate($this-xpath, $context-1, $context-2)"
                           copy-namespaces="no"/>
                     </xsl:when>
                     <xsl:otherwise>
                        <!-- otherwise, only some very common substitutions will be supported, e.g., an attribute value or the first <name> child -->
                        <xsl:choose>
                           <xsl:when test="$this-xpath = 'name($p1)'">
                              <xsl:value-of select="name($context-1)"/>
                           </xsl:when>
                           <xsl:when test="matches($this-xpath, '^$p1/@')">
                              <xsl:value-of
                                 select="$context-1/@*[name() = replace(., '^\$@', '')]"/>
                           </xsl:when>
                           <xsl:when test="matches($this-xpath, '^$p1/\w+$')">
                              <xsl:value-of select="$context-1/*[name() = $this-xpath]"/>
                           </xsl:when>
                           <xsl:when test="matches($this-xpath, '^$p1/\w+\[\d+\]$')">
                              <xsl:variable name="simple-xpath-analyzed" as="xs:string*">
                                 <xsl:analyze-string select="$this-xpath" regex="\[\d+\]$">
                                    <xsl:matching-substring>
                                       <xsl:value-of select="replace(., '\$p|\D', '')"/>
                                    </xsl:matching-substring>
                                    <xsl:non-matching-substring>
                                       <xsl:value-of select="."/>
                                    </xsl:non-matching-substring>
                                 </xsl:analyze-string>
                              </xsl:variable>
                              <xsl:value-of
                                 select="$context-1/*[name() = $simple-xpath-analyzed[1]][$simple-xpath-analyzed[2]]"
                              />
                           </xsl:when>
                           <xsl:otherwise>
                              <xsl:message>
                                 <xsl:value-of
                                    select="concat('saxon:evaluate unavailable, and no actions predefined for string: ', .)"
                                 />
                              </xsl:message>
                              <xsl:value-of select="."/>
                           </xsl:otherwise>
                        </xsl:choose>
                     </xsl:otherwise>
                  </xsl:choose>
               </xsl:matching-substring>
               <xsl:non-matching-substring>
                  <xsl:value-of select="."/>
               </xsl:non-matching-substring>
            </xsl:analyze-string>
         </xsl:variable>
         <xsl:for-each-group select="$results" group-adjacent=". instance of xs:string">
            <xsl:choose>
               <xsl:when test="current-grouping-key() = true()">
                  <xsl:value-of select="string-join(current-group(),'')"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:copy-of select="current-group()"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:for-each-group> 
      </xsl:if>
   </xsl:function>


   <!-- Functions: TAN files -->

   <xsl:function name="tan:reset-hierarchy" as="document-node()*">
      <!-- Input: any expanded class-1 documents whose <div>s may be in the wrong place, because <rename> or <reassign> have altered the <ref> values; a boolean indicating whether misplaced leaf divs should be flagged -->
      <!-- Output: the same documents, with <div>s restored to their proper place in the hierarchy -->
      <xsl:param name="expanded-class-1-docs" as="document-node()*"/>
      <xsl:param name="flag-misplaced-leaf-divs" as="xs:boolean?"/>
      <xsl:apply-templates select="$expanded-class-1-docs" mode="reset-hierarchy">
         <xsl:with-param name="flag-misplaced-leaf-divs" select="$flag-misplaced-leaf-divs"
            tunnel="yes"/>
      </xsl:apply-templates>
   </xsl:function>

   <xsl:function name="tan:resolve-keyword" as="item()*">
      <!-- Input: any items; any extra keys -->
      <!-- Output: the same items, but with elements with @which expanded into their full form, using the predefined TAN vocabulary and the extra keys supplied -->
      <xsl:param name="items" as="item()*"/>
      <xsl:param name="extra-keys" as="document-node()*"/>
      <xsl:apply-templates select="$items" mode="resolve-keyword">
         <xsl:with-param name="extra-keys" select="$extra-keys" tunnel="yes"/>
      </xsl:apply-templates>
   </xsl:function>
   
   <xsl:function name="tan:normalize-xml-element-space" as="element()?">
      <!-- Input: an element -->
      <!-- Output: the same element, but with text node descendants with space normalized -->
      <!-- If a text node begins with a space, and its first preceding sibling text node ends with a space, then the preceding space is dropped, otherwise it is normalized to a single space -->
      <xsl:param name="element-to-normalize" as="element()?"/>
      <xsl:apply-templates select="$element-to-normalize" mode="normalize-xml-fragment-space"/>
   </xsl:function>   
   <xsl:template match="text()" mode="normalize-xml-fragment-space">
      <xsl:variable name="prev-sibling-text" select="preceding-sibling::text()[1]"/>
      <xsl:variable name="last-text-node"
         select="
         if (exists($prev-sibling-text)) then
         $prev-sibling-text
         else
         (preceding::text())[last()]"
      />
      <xsl:analyze-string select="." regex="^(\s+)">
         <xsl:matching-substring>
            <xsl:choose>
               <xsl:when test="matches($last-text-node, '\S$')">
                  <xsl:text> </xsl:text>
               </xsl:when>
            </xsl:choose>
         </xsl:matching-substring>
         <xsl:non-matching-substring>
            <xsl:analyze-string select="." regex="\s+$">
               <xsl:matching-substring>
                  <xsl:text> </xsl:text>
               </xsl:matching-substring>
               <xsl:non-matching-substring>
                  <xsl:value-of select="normalize-space(.)"/>
               </xsl:non-matching-substring>
            </xsl:analyze-string>
         </xsl:non-matching-substring>
      </xsl:analyze-string>
   </xsl:template>


   <!-- BIBLIOGRAPHIES -->
   <xsl:param name="bibliography-words-to-ignore" as="xs:string*"
      select="('university', 'press', 'publication')"/>
   <xsl:function name="tan:possible-bibliography-id" as="xs:string">
      <!-- Input: a string with a bibliographic entry -->
      <!-- Output: unique values of the two longest words and the first numeral that looks like a date -->
      <!-- When working with bibliographical data, it is next to impossible to rely upon an exact match to tell whether two citations are for the same item -->
      <!-- Many times, however, the longest word or two, plus the four-digit date, are good ways to try to find matches. -->
      <xsl:param name="bibl-cit" as="xs:string"/>
      <xsl:variable name="this-citation-dates" as="xs:string*">
         <xsl:analyze-string select="$bibl-cit" regex="^\d\d\d\d\D|\D\d\d\d\d\D|\D\d\d\d\d$">
            <xsl:matching-substring>
               <xsl:value-of select="replace(., '\D', '')"/>
            </xsl:matching-substring>
         </xsl:analyze-string>
      </xsl:variable>
      <xsl:variable name="this-citation-longest-words" as="xs:string*">
         <xsl:for-each select="tokenize($bibl-cit, '\W+')">
            <xsl:sort select="string-length(.)" order="descending"/>
            <xsl:if test="not(lower-case(.) = $bibliography-words-to-ignore)">
               <xsl:value-of select="."/>
            </xsl:if>
         </xsl:for-each>
      </xsl:variable>
      <xsl:value-of
         select="string-join(distinct-values(($this-citation-longest-words[position() lt 3], $this-citation-dates[1])), ' ')"
      />
   </xsl:function>

</xsl:stylesheet>
