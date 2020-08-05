<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="tag:textalign.net,2015:ns" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:fn="http://www.w3.org/2005/xpath-functions" xmlns:saxon="http://saxon.sf.net/"
   xmlns:html="http://www.w3.org/1999/xhtml" xmlns:tei="http://www.tei-c.org/ns/1.0"
   xmlns:file="http://expath.org/ns/file" xmlns:bin="http://expath.org/ns/binary"
   xmlns:math="http://www.w3.org/2005/xpath-functions/math" exclude-result-prefixes="#all"
   version="3.0">

   <!-- Are advanced Saxon features available? -->
   <xsl:param name="advanced-saxon-features-available" static="yes"
      select="system-property('xsl:supports-higher-order-functions') eq 'yes'"/>

   <xsl:include href="extra/TAN-function-functions.xsl"/>
   <xsl:include href="extra/TAN-schema-functions.xsl"/>
   <xsl:include href="extra/TAN-search-functions.xsl"/>
   <xsl:include href="extra/TAN-language-functions.xsl"/>
   <xsl:include href="extra/TAN-A-lm-extra-functions.xsl"/>
   <xsl:include href="../parameters/extra-parameters.xsl"/>

   <!-- Functions that are not central to validating TAN files, but could be helpful in creating, editing, or reusing them -->

   <xsl:key name="get-ana" match="tan:ana" use="tan:tok/@val"/>

   <!-- GLOBAL VARIABLES AND PARAMETERS -->

   <xsl:variable name="doc-history" select="tan:get-doc-history($orig-self)"/>
   <!--<xsl:variable name="doc-filename" select="replace($doc-uri, '.*/([^/]+)$', '$1')"/>-->
   <xsl:variable name="doc-filename" select="tan:cfne(/)"/>
   <xsl:param name="saxon-extension-functions-available" static="yes" as="xs:boolean" select="fn:function-available('saxon:evaluate', 3)"/>
   
   <!-- sources -->
   <!--<xsl:variable name="sources-1st-da" select="tan:get-1st-doc($head/tan:source)"/>
   <xsl:variable name="sources-must-be-adjusted"
      select="exists($head/tan:adjustments/(tan:equate, tan:rename, tan:reassign, tan:skip))"/>
   <xsl:variable name="sources-resolved" as="document-node()*"
      select="tan:resolve-doc($sources-1st-da, $sources-must-be-adjusted, 'src', $source-ids, ($validation-phase = 'verbose'))"/>-->
   
   <!-- see-also, context -->
   <xsl:variable name="see-alsos-1st-da" select="tan:get-1st-doc($head/tan:see-also)"/>
   <!--<xsl:variable name="see-alsos-resolved" select="tan:resolve-doc($see-alsos-1st-da, false(), 'see-also', (), ($validation-phase = 'verbose'))"/>-->
   <xsl:variable name="see-alsos-resolved"
      select="tan:resolve-doc($see-alsos-1st-da, false(), tan:attr('relationship', 'see-also'))"/>
   
   <!-- predecessors -->
   <xsl:variable name="predecessors-1st-da" select="tan:get-1st-doc($head/tan:predecessor)"/>
   <!--<xsl:variable name="predecessors-resolved" select="tan:resolve-doc($predecessors-1st-da, false(), 'predecessor', (), ($validation-phase = 'verbose'))"/>-->
   <xsl:variable name="predecessors-resolved" select="tan:resolve-doc($predecessors-1st-da, false(), tan:attr('relationship', 'predecessor'))"/>
   
   <!-- successors -->
   <xsl:variable name="successors-1st-da" select="tan:get-1st-doc($head/tan:successor)"/>
   <!--<xsl:variable name="successors-resolved" select="tan:resolve-doc($successors-1st-da, false(), 'successor', (), ($validation-phase = 'verbose'))"/>-->
   <xsl:variable name="successors-resolved" select="tan:resolve-doc($successors-1st-da, false(), tan:attr('relationship', 'successor'))"/>
   
   <xsl:variable name="most-common-indentations" as="xs:string*">
      <xsl:for-each-group select="//text()[not(matches(., '\S'))][following-sibling::*]"
         group-by="count(ancestor::*)">
         <xsl:sort select="current-grouping-key()"/>
         <xsl:value-of select="tan:most-common-item(current-group())"/>
      </xsl:for-each-group>
   </xsl:variable>

   <!-- An xpath pattern built into a text node or an attribute value looks like this: {PATTERN} -->
   <xsl:variable name="xpath-pattern" select="'\{[^\}]+?\}'"/>

   <xsl:variable name="namespaces-and-prefixes" as="element()">
      <namespaces>
         <ns prefix="" uri=""/>
         <ns prefix="cp"
            uri="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"/>
         <ns prefix="dc" uri="http://purl.org/dc/elements/1.1/"/>
         <ns prefix="dcmitype" uri="http://purl.org/dc/dcmitype/"/>
         <ns prefix="dcterms" uri="http://purl.org/dc/terms/"/>
         <ns prefix="html" uri="http://www.w3.org/1999/xhtml"/>
         <ns prefix="m" uri="http://schemas.openxmlformats.org/officeDocument/2006/math"/>
         <ns prefix="map" uri="http://www.w3.org/2005/xpath-functions/map"/>
         <ns prefix="mc" uri="http://schemas.openxmlformats.org/markup-compatibility/2006"/>
         <ns prefix="mo" uri="http://schemas.microsoft.com/office/mac/office/2008/main"/>
         <ns prefix="mods" uri="http://www.loc.gov/mods/v3"/>
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
         <ns prefix="wp"
            uri="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"/>
         <ns prefix="wp14" uri="http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing"/>
         <ns prefix="wpc" uri="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas"/>
         <ns prefix="wpg" uri="http://schemas.microsoft.com/office/word/2010/wordprocessingGroup"/>
         <ns prefix="wpi" uri="http://schemas.microsoft.com/office/word/2010/wordprocessingInk"/>
         <ns prefix="wps" uri="http://schemas.microsoft.com/office/word/2010/wordprocessingShape"/>
         <ns prefix="xs" uri="http://www.w3.org/2001/XMLSchema"/>
         <ns prefix="xsi" uri="http://www.w3.org/2001/XMLSchema-instance"/>
         <ns prefix="xsl" uri="http://www.w3.org/1999/XSL/Transform"/>
         <ns prefix="zs" uri="http://www.loc.gov/zing/srw/"/>
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

   <!-- regular expressions to detect the end of sentences, clauses, and words -->
   <xsl:param name="sentence-end-regex" select="'[\.\?!]+\p{P}*\s*'"/>
   <xsl:param name="clause-end-regex" select="'\w\p{P}+\s*'"/>
   <xsl:param name="word-end-regex" select="'\s+'"/>

   <!--<xsl:variable name="local-TAN-collection" as="document-node()*"
      select="tan:collection($local-catalog, (), (), ())"/>-->
   <xsl:variable name="local-TAN-collection" as="document-node()*"
      select="collection(concat(resolve-uri('catalog.tan.xml', $doc-uri), '?on-error=warning'))"/>
   <xsl:variable name="local-TAN-voc-collection" select="$local-TAN-collection[name(*) = 'TAN-voc']"/>
   
   <!--<xsl:variable name="applications-collection" as="document-node()*"
      select="collection(concat('../applications/catalog.xml', '?on-error=ignore'))"/>-->
   <xsl:variable name="applications-uri-collection"
      select="uri-collection('../applications/catalog.xml?on-error=ignore')"/>
   <xsl:variable name="applications-collection" as="document-node()*">
      <xsl:for-each select="$applications-uri-collection">
         <xsl:choose>
            <xsl:when test="doc-available(.)">
               <xsl:sequence select="doc(.)"/>
            </xsl:when>
            <xsl:when test="$is-validation"/>
            <xsl:otherwise>
               <xsl:message select="'applications collection has bad entry for ', ."/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:for-each>
   </xsl:variable>

   <xsl:variable name="today-iso" select="format-date(current-date(), '[Y0001]-[M01]-[D01]')"/>

   <!-- FUNCTIONS -->

   <!-- Functions: numerics -->

   <xsl:function name="tan:grc-to-int" as="xs:integer*">
      <!-- Input: Greek letters that represent numerals -->
      <!-- Output: the numerical value of the letters -->
      <!-- NB, this does not take into account the use of letters representing numbers 1000 and greater -->
      <xsl:param name="greek-numerals" as="xs:string*"/>
      <xsl:sequence select="tan:letter-to-number($greek-numerals)"/>
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
         <xsl:sequence select="tan:letter-to-number(string-join($duplicates-stripped, ''))"/>
      </xsl:for-each>
   </xsl:function>

   <xsl:function name="tan:int-to-aaa" as="xs:string*">
      <!-- Input: any integers -->
      <!-- Output: the alphabetic representation of those numerals -->
      <xsl:param name="integers" as="xs:integer*"/>
      <xsl:for-each select="$integers">
         <xsl:variable name="this-integer" select="."/>
         <xsl:variable name="this-letter-codepoint" select="(. mod 26) + 96"/>
         <xsl:variable name="this-number-of-letters" select="(. idiv 26) + 1"/>
         <xsl:variable name="these-codepoints"
            select="
               for $i in (1 to $this-number-of-letters)
               return
                  $this-letter-codepoint"/>
         <xsl:value-of select="codepoints-to-string($these-codepoints)"/>
      </xsl:for-each>
   </xsl:function>

   <xsl:function name="tan:int-to-grc" as="xs:string*">
      <!-- Input: any integers -->
      <!-- Output: the integers expressed as lowercase Greek alphabetic numerals, with numeral marker(s) -->
      <xsl:param name="integers" as="xs:integer*"/>
      <xsl:variable name="arabic-numerals" select="'123456789'"/>
      <xsl:variable name="greek-units" select="'αβγδεϛζηθ'"/>
      <xsl:variable name="greek-tens" select="'ικλμνξοπϙ'"/>
      <xsl:variable name="greek-hundreds" select="'ρστυφχψωϡ'"/>
      <xsl:for-each select="$integers">
         <xsl:variable name="this-numeral" select="format-number(., '0')"/>
         <xsl:variable name="these-digits" select="tan:chop-string($this-numeral)"/>
         <xsl:variable name="new-digits-reversed" as="xs:string*">
            <xsl:for-each select="reverse($these-digits)">
               <xsl:variable name="pos" select="position()"/>
               <xsl:choose>
                  <xsl:when test=". = '0'"/>
                  <xsl:when test="$pos mod 3 = 1">
                     <xsl:value-of select="translate(., $arabic-numerals, $greek-units)"/>
                  </xsl:when>
                  <xsl:when test="$pos mod 3 = 2">
                     <xsl:value-of select="translate(., $arabic-numerals, $greek-tens)"/>
                  </xsl:when>
                  <xsl:when test="$pos mod 3 = 0">
                     <xsl:value-of select="translate(., $arabic-numerals, $greek-hundreds)"/>
                  </xsl:when>
               </xsl:choose>
            </xsl:for-each>
         </xsl:variable>
         <xsl:variable name="prepended-numeral-sign"
            select="
               if (count($these-digits) gt 3) then
                  '͵'
               else
                  ()"/>
         <xsl:if test="count($new-digits-reversed) gt 0">
            <xsl:value-of
               select="concat($prepended-numeral-sign, string-join(reverse($new-digits-reversed), ''), 'ʹ')"
            />
         </xsl:if>
      </xsl:for-each>
   </xsl:function>
   
   <xsl:function name="tan:dec-to-bin" as="xs:string?">
      <!-- Input: a decimal -->
      <!-- Output: the number in binary, represented as a string -->
      <xsl:param name="in" as="xs:integer?"/>
      <xsl:sequence select="tan:dec-to-n($in, 2)"/>
   </xsl:function>
   
   
   <xsl:function name="tan:base64-to-dec" as="xs:integer?">
      <!-- Input: a base64 datum -->
      <!-- Output: an integer representing the base-10 value of the input -->
      <xsl:param name="base64" as="xs:base64Binary?"/>
      <xsl:variable name="base64-string" select="xs:string($base64)"/>
      <xsl:copy-of select="tan:n-to-dec($base64-string, 64)"/>
   </xsl:function>
   
   <xsl:function name="tan:base64-to-bin" as="xs:string?">
      <!-- Input: a base64 datum -->
      <!-- Output: a string representing the datum in binary code -->
      <xsl:param name="base64" as="xs:base64Binary?"/>
      <xsl:copy-of select="tan:dec-to-bin(tan:base64-to-dec($base64))"/>
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

   <xsl:function name="tan:lengths-to-positions" as="xs:integer*">
      <!-- Input: sequence of numbers representing legnths of items.  -->
      <!-- Output: sequence of numbers representing the first position of each input item, if the sequence concatenated.
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
               if ($i castable as xs:double) then
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

      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on for tan:outliers()'"/>
         <xsl:message select="'numbers sorted: ', $numbers-sorted"/>
      </xsl:if>
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
      <xsl:variable name="max-deviation" select="max($these-deviations)"/>
      <xsl:variable name="this-variance" select="avg($these-deviations)"/>
      <xsl:variable name="this-standard-deviation" select="math:sqrt($this-variance)"/>
      <stats>
         <count>
            <xsl:copy-of select="count($arg)"/>
         </count>
         <sum>
            <xsl:copy-of select="sum($arg)"/>
         </sum>
         <avg>
            <xsl:copy-of select="$this-avg"/>
         </avg>
         <max>
            <xsl:copy-of select="max($arg)"/>
         </max>
         <min>
            <xsl:copy-of select="min($arg)"/>
         </min>
         <var>
            <xsl:copy-of select="$this-variance"/>
         </var>
         <std>
            <xsl:copy-of select="$this-standard-deviation"/>
         </std>
         <xsl:for-each select="$arg">
            <xsl:variable name="pos" select="position()"/>
            <xsl:variable name="this-dev" select="$these-deviations[$pos]"/>
            <d dev="{$these-deviations[$pos]}">
               <xsl:if test="$this-dev = $max-deviation">
                  <xsl:attribute name="max"/>
               </xsl:if>
               <xsl:value-of select="."/>
            </d>
         </xsl:for-each>
      </stats>
   </xsl:function>

   <xsl:function name="tan:merge-analyzed-stats" as="element()">
      <!-- Input: Results from tan:analyze-stats(); a boolean -->
      <!-- Output: A synthesis of the results. If the second parameter is true, the stats are added; if false, the first statistic will be compared to the sum of all subsequent ones. -->
      <xsl:param name="analyzed-stats" as="element()*"/>
      <xsl:param name="add-stats" as="xs:boolean?"/>
      <xsl:variable name="datum-counts" as="xs:integer*"
         select="
            for $i in $analyzed-stats
            return
               count($i/tan:d)"/>
      <xsl:variable name="this-count" select="avg($analyzed-stats[position() gt 1]/tan:count)"/>
      <xsl:variable name="this-sum" select="avg($analyzed-stats[position() gt 1]/tan:sum)"/>
      <xsl:variable name="this-avg" select="avg($analyzed-stats[position() gt 1]/tan:avg)"/>
      <xsl:variable name="this-max" select="avg($analyzed-stats[position() gt 1]/tan:max)"/>
      <xsl:variable name="this-min" select="avg($analyzed-stats[position() gt 1]/tan:min)"/>
      <xsl:variable name="this-var" select="avg($analyzed-stats[position() gt 1]/tan:var)"/>
      <xsl:variable name="this-std" select="avg($analyzed-stats[position() gt 1]/tan:std)"/>
      <xsl:variable name="this-count-diff" select="$this-count - $analyzed-stats[1]/tan:count"/>
      <xsl:variable name="this-sum-diff" select="$this-sum - $analyzed-stats[1]/tan:sum"/>
      <xsl:variable name="this-avg-diff" select="$this-avg - $analyzed-stats[1]/tan:avg"/>
      <xsl:variable name="this-max-diff" select="$this-max - $analyzed-stats[1]/tan:max"/>
      <xsl:variable name="this-min-diff" select="$this-min - $analyzed-stats[1]/tan:min"/>
      <xsl:variable name="this-var-diff" select="$this-var - $analyzed-stats[1]/tan:var"/>
      <xsl:variable name="this-std-diff" select="$this-std - $analyzed-stats[1]/tan:std"/>
      <xsl:variable name="data-diff" as="element()">
         <stats>
            <count diff="{$this-count-diff div $analyzed-stats[1]/tan:count}">
               <xsl:copy-of select="$this-count-diff"/>
            </count>
            <sum diff="{$this-sum-diff div $analyzed-stats[1]/tan:sum}">
               <xsl:copy-of select="$this-sum-diff"/>
            </sum>
            <avg diff="{$this-avg-diff div $analyzed-stats[1]/tan:avg}">
               <xsl:copy-of select="$this-avg-diff"/>
            </avg>
            <max diff="{$this-max-diff div $analyzed-stats[1]/tan:max}">
               <xsl:copy-of select="$this-max-diff"/>
            </max>
            <min diff="{$this-min-diff div $analyzed-stats[1]/tan:min}">
               <xsl:copy-of select="$this-min-diff"/>
            </min>
            <var diff="{$this-var-diff div $analyzed-stats[1]/tan:var}">
               <xsl:copy-of select="$this-var-diff"/>
            </var>
            <std diff="{$this-std-diff div $analyzed-stats[1]/tan:std}">
               <xsl:copy-of select="$this-std-diff"/>
            </std>
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
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on for tan:merge-analyzed-stats()'"/>
         <xsl:message select="'add stats?', $add-stats"/>
         <xsl:message select="'datum counts:', $datum-counts"/>
         <xsl:message select="'data diff: ', $data-diff"/>
      </xsl:if>
      <xsl:choose>
         <xsl:when test="$add-stats = true()">
            <xsl:copy-of select="tan:analyze-stats($analyzed-stats/tan:d)"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:copy-of select="$data-diff"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>
   
   <xsl:function name="tan:blend-color-channel-value" as="xs:double?">
      <!-- Input: two integers and a double between zero and 1 -->
      <!-- Output: a double representing a blend between the first two numbers, interpreted as RGB values -->
      <xsl:param name="color-a" as="xs:double"/>
      <xsl:param name="color-b" as="xs:double"/>
      <xsl:param name="blend-mid-point" as="xs:double"/>
      <xsl:variable name="color-a-norm" select="$color-a mod 256"/>
      <xsl:variable name="color-b-norm" select="$color-b mod 256"/>
      <xsl:variable name="blend-mid-point-norm" select="abs($blend-mid-point) - floor($blend-mid-point)"/>
      <xsl:variable name="pass-1" as="xs:double"
         select="((1 - $blend-mid-point-norm) * math:pow($color-a-norm, 2)) + ($blend-mid-point-norm * math:pow($color-b-norm, 2))"
      />
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on for tan:blend-color-channel-value()'"/>
         <xsl:message select="'color a norm: ', $color-a-norm"/>
         <xsl:message select="'color b norm: ', $color-b-norm"/>
         <xsl:message select="'blend-mid-point-norm: ', $blend-mid-point-norm"/>
         <xsl:message select="'pass 1: ', $pass-1"/>
      </xsl:if>
      <xsl:value-of select="math:sqrt($pass-1)"/>
   </xsl:function>
   
   <xsl:function name="tan:blend-alpha-value" as="xs:double?">
      <!-- Input: three doubles between zero and 1 -->
      <!-- Output: the blend of the first two doubles, interpreted as alpha values and the third interpreted as a midpoint -->
      <xsl:param name="alpha-a" as="xs:double"/>
      <xsl:param name="alpha-b" as="xs:double"/>
      <xsl:param name="blend-mid-point" as="xs:double"/>
      <xsl:variable name="alpha-a-norm" select="abs($alpha-a) - floor($alpha-a)"/>
      <xsl:variable name="alpha-b-norm" select="abs($alpha-b) - floor($alpha-b)"/>
      <xsl:variable name="blend-mid-point-norm" select="abs($blend-mid-point) - floor($blend-mid-point)"/>
      <xsl:value-of select="((1 - $blend-mid-point-norm) * $alpha-a-norm) + ($blend-mid-point-norm * $alpha-b-norm)"/>
   </xsl:function>
   
   <xsl:function name="tan:blend-colors" as="xs:double*">
      <!-- Input: two sequences of doubles (the first three items being from 0 through 255 and the fourth and last between 0 and 1); a double between zero and 1 -->
      <!-- Output: a sequence of doubles representing a blend of the first two sequences, interpreted as RGB colors, and the last double as a desired midpoint -->
      <xsl:param name="rgb-color-1" as="item()+"/>
      <xsl:param name="rgb-color-2" as="item()+"/>
      <xsl:param name="blend-mid-point" as="xs:double"/>
      <xsl:variable name="blend-mid-point-norm" select="abs($blend-mid-point) - floor($blend-mid-point)"/>
      <xsl:choose>
         <xsl:when
            test="
               not(every $i in $rgb-color-1
                  satisfies $i castable as xs:double)">
            <xsl:message
               select="'Every item in $rgb-color-1 must be a double or castable as a double'"/>
         </xsl:when>
         <xsl:when
            test="
               not(every $i in $rgb-color-2
                  satisfies $i castable as xs:double)">
            <xsl:message
               select="'Every item in $rgb-color-2 must be a double or castable as a double'"/>
         </xsl:when>
         <xsl:when test="(count($rgb-color-1) lt 3) or (count($rgb-color-1) gt 4) or (count($rgb-color-2) lt 3) or (count($rgb-color-2) gt 4)">
            <xsl:message select="'tan:blend-colors() expects as the first two parameters a sequence of three or four doubles'"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:variable name="diagnostics-on" select="false()"/>
            <xsl:if test="$diagnostics-on">
               <xsl:message select="'diagnostics on for tan:blend-colors()'"/>
            </xsl:if>
            <xsl:for-each select="1 to 3">
               <xsl:variable name="this-pos" select="."/>
               <xsl:variable name="channel-1" select="xs:double($rgb-color-1[$this-pos])"/>
               <xsl:variable name="channel-2" select="xs:double($rgb-color-2[$this-pos])"/>
               <xsl:if test="$diagnostics-on">
                  <xsl:message select="'this channel number: ', $this-pos"/>
                  <xsl:message select="'channel 1 item: ', $rgb-color-1[$this-pos]"/>
                  <xsl:message select="'channel 1 as double: ', $channel-1"/>
                  <xsl:message select="'channel 2 item: ', $rgb-color-2[$this-pos]"/>
                  <xsl:message select="'channel 2 as double: ', $channel-2"/>
               </xsl:if>
               <xsl:value-of select="tan:blend-color-channel-value($channel-1, $channel-2, $blend-mid-point-norm)"/>
            </xsl:for-each>
            <xsl:choose>
               <xsl:when test="not(exists($rgb-color-1[4])) and not(exists($rgb-color-2[4]))"/>
               <xsl:when test="not(exists($rgb-color-1[4]))">
                  <xsl:value-of select="xs:double($rgb-color-2[4])"/>
               </xsl:when>
               <xsl:when test="not(exists($rgb-color-2[4]))">
                  <xsl:value-of select="xs:double($rgb-color-1[4])"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:value-of select="tan:blend-alpha-value(xs:double($rgb-color-1[4]), xs:double($rgb-color-2[4]), $blend-mid-point-norm)"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>


   <!-- Functions: strings -->

   <xsl:function name="tan:namespace" as="xs:string*">
      <!-- Input: any strings representing a namespace prefix or uri -->
      <!-- Output: the corresponding prefix or uri whenever a match is found in the global variable -->
      <xsl:param name="prefix-or-uri" as="xs:string*"/>
      <xsl:for-each select="$prefix-or-uri">
         <xsl:variable name="this-string" select="."/>
         <xsl:value-of
            select="$namespaces-and-prefixes/*[@* = $this-string]/(@*[not(. = $this-string)])[1]"/>
      </xsl:for-each>
   </xsl:function>

   <xsl:function name="tan:glob-to-regex" as="xs:string*">
      <!-- Input: any strings that follow a glob-like syntax -->
      <!-- Output: the strings converted to regular expressions -->
      <xsl:param name="globs" as="xs:string*"/>
      <xsl:for-each select="$globs">
         <!-- escape special regex characters that aren't special glob characters -->
         <xsl:variable name="pass-1" select="replace(., '([\.\\\|\^\$\+\{\}\(\)])', '\$1')"/>
         <!-- convert glob * -->
         <xsl:variable name="pass-2" select="replace($pass-1, '\*', '.*')"/>
         <!-- convert glob ? -->
         <xsl:variable name="pass-3" select="replace($pass-2, '\?', '.')"/>
         <!-- make sure the results match either an entire filename or an entire path -->
         <xsl:value-of select="concat('^', $pass-3, '$|/', $pass-3, '$')"/>
      </xsl:for-each>
   </xsl:function>

   <xsl:function name="tan:acronym" as="xs:string?">
      <!-- Input: any strings -->
      <!-- Output: the acronym of those strings (initial letters joined without spaces) -->
      <xsl:param name="string-input" as="xs:string*"/>
      <xsl:variable name="initials"
         select="
            for $i in $string-input,
               $j in tokenize($i, '\s+')
            return
               substring($j, 1, 1)"/>
      <xsl:value-of select="string-join($initials, '')"/>
   </xsl:function>

   <xsl:variable name="url-regex" as="xs:string">\S+\.\w+</xsl:variable>
   <xsl:function name="tan:parse-urls" as="element()*">
      <!-- Input: any sequence of strings -->
      <!-- Output: one element per string, parsed into children <non-url> and <url> -->
      <xsl:param name="input-strings" as="xs:string*"/>
      <xsl:for-each select="$input-strings">
         <string>
            <xsl:analyze-string select="." regex="{$url-regex}">
               <xsl:matching-substring>
                  <url>
                     <xsl:value-of select="."/>
                  </url>
               </xsl:matching-substring>
               <xsl:non-matching-substring>
                  <non-url>
                     <xsl:value-of select="."/>
                  </non-url>
               </xsl:non-matching-substring>
            </xsl:analyze-string>
         </string>
      </xsl:for-each>
   </xsl:function>
   
   <xsl:function name="tan:batch-replace-advanced" as="item()*">
      <!-- Input: a string; a sequence of elements <[ANY NAME] pattern="" [flags=""]>[ANY CONTENT]</[ANY NAME]> -->
      <!-- Output: a sequence of items, with instances of @pattern replaced by the content of the elements -->
      <!-- This is a more advanced form of tan:batch-replace(), in that it allows text to be replaced by elements. -->
      <!-- The function was devised to convert raw text into TAN-T. Textual references can be turned into <div n=""/> anchors, and the result can then be changed into a traditional hierarchy. -->
      <xsl:param name="string" as="xs:string?"/>
      <xsl:param name="replace-elements" as="element()*"/>
      <xsl:choose>
         <xsl:when test="not(exists($replace-elements))">
            <xsl:value-of select="$string"/>
         </xsl:when>
         <xsl:when test="string-length($replace-elements[1]/@pattern) lt 1">
            <xsl:copy-of
               select="tan:batch-replace-advanced($string, $replace-elements[position() gt 1])"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:analyze-string select="$string" regex="{$replace-elements[1]/@pattern}" flags="{$replace-elements[1]/@flags}">
               <xsl:matching-substring>
                  <xsl:apply-templates select="$replace-elements[1]/node()" mode="batch-replace-advanced">
                     <xsl:with-param name="regex-zero" tunnel="yes" select="."/>
                     <xsl:with-param name="regex-groups" tunnel="yes"
                        select="
                           for $i in (1 to 20)
                           return
                              regex-group($i)"
                     />
                  </xsl:apply-templates>
               </xsl:matching-substring>
               <xsl:non-matching-substring>
                  <!-- Anything that doesn't match should be processed with the next replace element -->
                  <xsl:copy-of
                     select="tan:batch-replace-advanced(., $replace-elements[position() gt 1])"/>
               </xsl:non-matching-substring>
            </xsl:analyze-string>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>
   <xsl:template match="*" mode="batch-replace-advanced">
      <xsl:copy>
         <xsl:apply-templates select="@* | node()" mode="#current"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="@*" mode="batch-replace-advanced">
      <xsl:param name="regex-zero" as="xs:string" tunnel="yes"/>
      <xsl:param name="regex-groups" as="xs:string*" tunnel="yes"/>
      <xsl:variable name="new-value" as="xs:string*">
         <xsl:analyze-string select="." regex="\$(\d+)">
            <xsl:matching-substring>
               <xsl:variable name="this-regex-no" select="number(regex-group(1))"/>
               <xsl:value-of select="$regex-groups[$this-regex-no]"/>
            </xsl:matching-substring>
            <xsl:non-matching-substring>
               <xsl:value-of select="."/>
            </xsl:non-matching-substring>
         </xsl:analyze-string>
      </xsl:variable>
      <xsl:attribute name="{name(.)}" select="string-join($new-value, '')"/>
   </xsl:template>
   <xsl:template match="text()" mode="batch-replace-advanced">
      <xsl:param name="regex-zero" as="xs:string" tunnel="yes"/>
      <xsl:param name="regex-groups" as="xs:string*" tunnel="yes"/>
      <xsl:choose>
         <!-- omit whitespace text -->
         <xsl:when test="not(matches(., '\S'))"/>
         <xsl:otherwise>
            <xsl:analyze-string select="." regex="\$(\d+)">
               <xsl:matching-substring>
                  <xsl:variable name="this-regex-no" select="number(regex-group(1))"/>
                  <xsl:value-of select="$regex-groups[$this-regex-no]"/>
               </xsl:matching-substring>
               <xsl:non-matching-substring>
                  <xsl:value-of select="."/>
               </xsl:non-matching-substring>
            </xsl:analyze-string>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>
   
   <xsl:variable name="english-prepositions" as="xs:string+"
      select="('aboard', 'about', 'above', 'across', 'after', 'against', 'along', 'amid', 'among', 'anti', 'around', 'as', 'at', 'before', 'behind', 'below', 'beneath', 'beside', 'besides', 'between', 'beyond', 'but', 'by', 'concerning', 'considering', 'despite', 'down', 'during', 'except', 'excepting', 'excluding', 'following', 'for', 'from', 'in', 'inside', 'into', 'like', 'minus', 'near', 'of', 'off', 'on', 'onto', 'opposite', 'outside', 'over', 'past', 'per', 'plus', 'regarding', 'round', 'save', 'since', 'than', 'through', 'to', 'toward', 'towards', 'under', 'underneath', 'unlike', 'until', 'up', 'upon', 'versus', 'via', 'with', 'within', 'without')"
   />
   <xsl:variable name="english-articles" as="xs:string+" select="('a', 'the')"/>
   <xsl:function name="tan:title-case" as="xs:string*">
      <!-- Input: a sequence of strings -->
      <!-- Output: each string set in title case, following the conventions of English (one of the only languages that bother with title-case) -->
      <!-- According to Chicago rules of title casing, the first and last words are always capitalized, and interior words are capitalzied unless they are a preposition or article -->
      <xsl:param name="string-to-convert" as="xs:string*"/>
      <xsl:for-each select="$string-to-convert">
         <xsl:variable name="pass-1" as="element()">
            <phrase>
               <xsl:analyze-string select="." regex="\w+">
                  <xsl:matching-substring>
                     <word>
                        <xsl:choose>
                           <xsl:when test=". = ($english-prepositions, $english-articles)">
                              <xsl:value-of select="lower-case(.)"/>
                           </xsl:when>
                           <xsl:otherwise>
                              <xsl:value-of select="tan:initial-upper-case(.)"/>
                           </xsl:otherwise>
                        </xsl:choose>
                     </word>
                  </xsl:matching-substring>
                  <xsl:non-matching-substring>
                     <non-word>
                        <xsl:value-of select="."/>
                     </non-word>
                  </xsl:non-matching-substring>
               </xsl:analyze-string>
            </phrase>
         </xsl:variable>
         <xsl:variable name="pass-2" as="element()">
            <xsl:apply-templates select="$pass-1" mode="title-case"/>
         </xsl:variable>
         <xsl:value-of select="string-join($pass-2/*, '')"/>
      </xsl:for-each>
   </xsl:function>
   <xsl:template match="tan:word[1] | tan:word[last()]" mode="title-case">
      <xsl:copy>
         <xsl:value-of select="tan:initial-upper-case(.)"/>
      </xsl:copy>
   </xsl:template>
   
   <xsl:function name="tan:initial-upper-case" as="xs:string*">
      <!-- Input: any strings -->
      <!-- Output: each string with the initial letters capitalized and the rest set lower-case -->
      <xsl:param name="strings" as="xs:string*"/>
      <xsl:variable name="non-letter-regex">\P{L}</xsl:variable>
      <xsl:for-each select="$strings">
         <xsl:variable name="pass-1" as="xs:string*">
            <xsl:analyze-string select="." regex="^{$non-letter-regex}+">
               <xsl:matching-substring>
                  <xsl:value-of select="."/>
               </xsl:matching-substring>
               <xsl:non-matching-substring>
                  <xsl:value-of select="upper-case(substring(., 1, 1)) || lower-case(substring(., 2))"/>
               </xsl:non-matching-substring>
            </xsl:analyze-string>
         </xsl:variable>
         <xsl:value-of select="string-join($pass-1)"/>
      </xsl:for-each>
   </xsl:function>
   
   <xsl:function name="tan:commas-and-ands" as="xs:string?">
      <!-- One-parameter version of the full one below -->
      <xsl:param name="input-strings" as="xs:string*"/>
      <xsl:value-of select="tan:commas-and-ands($input-strings, true())"/>
   </xsl:function>
   <xsl:function name="tan:commas-and-ands" as="xs:string?">
      <!-- Input: sequences of strings -->
      <!-- Output: the strings joined together with , and 'and' -->
      <xsl:param name="input-strings" as="xs:string*"/>
      <xsl:param name="oxford-comma" as="xs:boolean"/>
      <xsl:variable name="input-string-count" select="count($input-strings)"/>
      <xsl:variable name="results" as="xs:string*">
         <xsl:for-each select="$input-strings">
            <xsl:variable name="this-pos" select="position()"/>
            <xsl:value-of select="."/>
            <xsl:if test="$input-string-count gt 2">
               <xsl:choose>
                  <xsl:when test="$this-pos lt ($input-string-count - 1)">,</xsl:when>
                  <xsl:when test="$this-pos = ($input-string-count - 1) and $oxford-comma">,</xsl:when>
               </xsl:choose>
            </xsl:if>
            <xsl:if test="$this-pos lt $input-string-count">
               <xsl:text> </xsl:text>
            </xsl:if>
            <xsl:if test="$input-string-count gt 1 and $this-pos = ($input-string-count - 1)"
               >and </xsl:if>
         </xsl:for-each>
      </xsl:variable>
      <xsl:value-of select="string-join($results)"/>
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
            <xsl:when test=". instance of processing-instruction()"
               >processing-instruction</xsl:when>
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
                     <xsl:value-of
                        select="tan:evaluate($label-to-prepend, $elements-to-group[1], $elements-to-group)"
                     />
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

   <xsl:function name="tan:tree-to-sequence" as="item()*">
      <!-- Input: any XML fragment -->
      <!-- Output: a sequence of XML nodes representing the original fragment. Each element is given a new @level specifying the level of hierarchy the element had in the original. -->
      <xsl:param name="xml-fragment" as="item()*"/>
      <xsl:apply-templates select="$xml-fragment" mode="tree-to-sequence">
         <xsl:with-param name="current-level" select="1"/>
      </xsl:apply-templates>
   </xsl:function>
   <xsl:template match="*" mode="tree-to-sequence">
      <xsl:param name="current-level"/>
      <xsl:variable name="next-text-sibling" select="following-sibling::node()[1]/self::text()"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:attribute name="level" select="$current-level"/>
         <xsl:attribute name="next-sibling-text-length" select="string-length($next-text-sibling)"/>
      </xsl:copy>
      <xsl:apply-templates mode="#current">
         <xsl:with-param name="current-level" select="$current-level + 1"/>
      </xsl:apply-templates>
   </xsl:template>

   <xsl:function name="tan:sequence-to-tree" as="item()*">
      <!-- One-parameter version of the more complete one below -->
      <xsl:param name="sequence-to-reconstruct" as="item()*"/>
      <xsl:sequence select="tan:sequence-to-tree($sequence-to-reconstruct, true())"/>
   </xsl:function>
   <xsl:function name="tan:sequence-to-tree" as="item()*">
      <!-- Input: a result of tan:tree-to-sequence(); a boolean -->
      <!-- Output: the original tree; if the boolean is true, then any first children that are text nodes will be wrapped in a shallow copy of the first child element -->
      <xsl:param name="sequence-to-reconstruct" as="item()*"/>
      <xsl:param name="fix-orphan-text" as="xs:boolean"/>
      <xsl:variable name="sequence-prepped" as="element()">
         <tree>
            <xsl:copy-of select="$sequence-to-reconstruct"/>
         </tree>
      </xsl:variable>
      <xsl:variable name="results" as="element()">
         <xsl:apply-templates select="$sequence-prepped" mode="sequence-to-tree">
            <xsl:with-param name="level-so-far" select="0"/>
            <xsl:with-param name="fix-orphan-text" select="$fix-orphan-text" tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:variable>
      <xsl:copy-of select="$results/node()"/>
   </xsl:function>
   <xsl:template match="*" mode="sequence-to-tree">
      <xsl:param name="level-so-far" as="xs:integer"/>
      <xsl:param name="fix-orphan-text" as="xs:boolean" tunnel="yes"/>
      <xsl:variable name="this-element" select="."/>
      <xsl:variable name="first-child-element" select="*[1]"/>
      <xsl:variable name="level-to-process" select="$level-so-far + 1"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:for-each-group select="node()" group-starting-with="*[@level = $level-to-process]">
            <xsl:variable name="this-head" select="current-group()[1]"/>
            <xsl:variable name="this-tail-text"
               select="
                  if (count(current-group()) gt 1) then
                     current-group()[last()]/self::text()
                  else
                     ()"/>
            <xsl:variable name="this-next-sibling-text-memo"
               select="$this-head/@next-sibling-text-length"/>
            <xsl:variable name="this-sibling-length"
               select="(xs:integer($this-head/@next-sibling-text-length), 0)[1]"/>
            <xsl:variable name="this-tail-length"
               select="
                  if ($this-tail-text instance of text()) then
                     string-length($this-tail-text)
                  else
                     ()"/>
            <xsl:variable name="this-tail-section-to-be-child"
               select="
                  if ($this-tail-text instance of text()) then
                     substring($this-tail-text, 1, ($this-tail-length - $this-sibling-length))
                  else
                     ()"/>
            <xsl:variable name="this-tail-section-to-be-sibling"
               select="
                  if ($this-tail-text instance of text()) then
                     substring($this-tail-text, ($this-tail-length - $this-sibling-length) + 1)
                  else
                     ()"/>
            <xsl:variable name="the-rest"
               select="current-group() except ($this-head, $this-tail-text)"/>
            <xsl:variable name="new-group" as="item()*">
               <xsl:if test="$this-head/@level = $level-to-process">
                  <xsl:element name="{name($this-head)}" namespace="{namespace-uri($this-head)}">
                     <xsl:copy-of
                        select="$this-head/(@* except (@level, @next-sibling-text-length))"/>
                     <xsl:copy-of select="$the-rest"/>
                     <xsl:copy-of select="$this-tail-section-to-be-child"/>
                  </xsl:element>
                  <xsl:value-of select="$this-tail-section-to-be-sibling"/>
               </xsl:if>
            </xsl:variable>
            <xsl:choose>
               <xsl:when
                  test="
                     $this-head instance of text() and $fix-orphan-text
                     and exists($first-child-element) and matches($this-head, '\S')">
                  <xsl:element name="{name($first-child-element)}"
                     namespace="{namespace-uri($first-child-element)}">
                     <xsl:copy-of select="$first-child-element/(@* except @level)"/>
                     <xsl:value-of select="current-group()"/>
                  </xsl:element>
               </xsl:when>
               <xsl:when test="not(exists($new-group))">
                  <xsl:copy-of select="current-group()"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:apply-templates select="$new-group" mode="#current">
                     <xsl:with-param name="level-so-far" select="$level-to-process"/>
                  </xsl:apply-templates>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:for-each-group>
      </xsl:copy>
   </xsl:template>
   
   <xsl:function name="tan:remove-duplicate-siblings" as="item()*">
      <xsl:param name="items-to-process" as="item()*"/>
      <xsl:apply-templates select="$items-to-process" mode="remove-duplicate-siblings"/>
   </xsl:function>
   <xsl:function name="tan:remove-duplicate-siblings" as="item()*">
      <!-- Input: any items -->
      <!-- Output: the same documents after removing duplicate elements whose names match the second parameter. -->
      <!-- This function is applied during document resolution, to prune duplicate elements that might have been included -->
      <xsl:param name="items-to-process" as="document-node()*"/>
      <xsl:param name="element-names-to-check" as="xs:string*"/>
      <xsl:apply-templates select="$items-to-process" mode="remove-duplicate-siblings">
         <xsl:with-param name="element-names-to-check" select="$element-names-to-check"
            tunnel="yes"/>
      </xsl:apply-templates>
   </xsl:function>
   <xsl:template match="*" mode="remove-duplicate-siblings">
      <xsl:param name="element-names-to-check" as="xs:string*" tunnel="yes"/>
      <xsl:variable name="check-this-element" select="not(exists($element-names-to-check))
         or ($element-names-to-check = '*')
         or ($element-names-to-check = name(.))"/>
      <xsl:choose>
         <xsl:when
            test="
               ($check-this-element = true()) and (some $i in preceding-sibling::*
                  satisfies deep-equal(., $i))"
         />
         <xsl:otherwise>
            <xsl:copy>
               <xsl:copy-of select="@*"/>
               <xsl:apply-templates mode="#current"/>
            </xsl:copy>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>


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
   
   <xsl:function name="tan:integers-to-sequence" as="xs:string?">
      <!-- Input: any integers -->
      <!-- Output: a string that compactly expresses those integers -->
      <!-- Example: (1, 3, 6, 1, 2) - > "1-3, 6" -->
      <xsl:param name="input-integers" as="xs:integer*"/>
      <xsl:variable name="input-sorted" as="element()">
         <sorted>
            <xsl:for-each select="distinct-values($input-integers)">
               <xsl:sort/>
               <n>
                  <xsl:value-of select="."/>
               </n>
            </xsl:for-each>
         </sorted>
      </xsl:variable>
      <xsl:variable name="input-analyzed" as="element()">
         <xsl:apply-templates select="$input-sorted" mode="integers-to-sequence"/>
      </xsl:variable>
      <xsl:variable name="output-atoms" as="xs:string*">
         <xsl:for-each-group select="$input-analyzed/*" group-starting-with="*[@start]">
            <xsl:variable name="last-item" select="current-group()[not(@start)][last()]"/>
            <xsl:choose>
               <xsl:when test="exists($last-item)">
                  <xsl:value-of select="concat(current-group()[1], '-', $last-item)"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:value-of select="current-group()[1]"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:for-each-group> 
      </xsl:variable>
      <!--<xsl:message select="$input-analyzed"/>-->
      <!--<xsl:value-of select="$input-sorted"/>-->
      <!--<xsl:value-of select="$input-analyzed"/>-->
      <!--<xsl:value-of select="$output-atoms"/>-->
      <xsl:value-of select="string-join($output-atoms, ', ')"/>
   </xsl:function>
   <xsl:template match="tan:n" mode="integers-to-sequence">
      <xsl:variable name="preceding-n" select="preceding-sibling::tan:n[1]"/>
      <xsl:variable name="this-n-val" select="xs:integer(.)"/>
      <xsl:variable name="preceding-n-val" select="xs:integer($preceding-n)"/>
      <xsl:copy>
         <xsl:choose>
            <xsl:when test="not(exists($preceding-n-val))">
               <xsl:attribute name="start"/>
            </xsl:when>
            <xsl:when test="$this-n-val - $preceding-n-val gt 1">
               <xsl:attribute name="start"/>
            </xsl:when>
         </xsl:choose>
         <xsl:value-of select="."/>
      </xsl:copy>
   </xsl:template>


   <!-- Functions: accessors and manipulation of uris -->
   
   <xsl:function name="tan:open-file">
      <!-- 1-parameter function of the main one below -->
      <xsl:param name="resolved-urls"/>
      <xsl:copy-of select="tan:open-file($resolved-urls, $fallback-encoding)"/>
   </xsl:function>
   
   <xsl:function name="tan:open-file" as="document-node()*">
      <!-- Input: items that can be resolved as strings; a string -->
      <!-- Output: for each resolvable string in the first parameter, if a document is available, the document; 
            if it is not, but unparsed text is available, a document with the unparsed text wrapped in a root 
            element; otherwise an empty document node. If unparsed text is not available, another attempt 
            will be made on a fallback encoding specified by the 2nd parameter.
        -->
      <!-- If the file is not an XML document, the content will be wrapped by a root element of an
        XML document. That root node will have @xml:base pointing to the source url. -->
      <xsl:param name="resolved-urls"/>
      <xsl:param name="target-fallback-encoding" as="xs:string*"/>

      <xsl:for-each select="$resolved-urls[. castable as xs:string]">
         <xsl:variable name="this-path-normalized" select="replace(xs:string(.), '\s', '%20')"/>
         <xsl:variable name="this-path-normalized-for-extension-functions"
            select="replace($this-path-normalized, 'file:', '')"/>
         <xsl:choose>
            <xsl:when test="doc-available($this-path-normalized)">
               <xsl:sequence select="doc($this-path-normalized)"/>
            </xsl:when>
            <xsl:when test="unparsed-text-available($this-path-normalized)">
               <xsl:document>
                  <unparsed-text>
                     <xsl:attribute name="xml:base" select="$this-path-normalized"/>
                     <xsl:value-of select="unparsed-text($this-path-normalized)"/>
                  </unparsed-text>
               </xsl:document>
            </xsl:when>
            <xsl:when
               test="unparsed-text-available($this-path-normalized, $target-fallback-encoding)">
               <xsl:document>
                  <unparsed-text>
                     <xsl:attribute name="xml:base" select="$this-path-normalized"/>
                     <xsl:value-of
                        select="unparsed-text($this-path-normalized, $target-fallback-encoding)"/>
                  </unparsed-text>
               </xsl:document>
            </xsl:when>
            <xsl:when test="true()" use-when="$advanced-saxon-features-available">
               <xsl:variable name="file-exists" use-when="$advanced-saxon-features-available"
                  as="xs:boolean?">
                  <xsl:try select="file:exists($this-path-normalized-for-extension-functions)">
                     <xsl:catch>
                        <xsl:message
                           select="$this-path-normalized-for-extension-functions || ' breaks the syntax allowed for the function file:exists()'"/>
                        <xsl:value-of select="false()"/>
                     </xsl:catch>
                  </xsl:try>
               </xsl:variable>
               <xsl:if test="$file-exists">
                  <xsl:variable name="binary-file"
                     select="file:read-binary($this-path-normalized-for-extension-functions)"/>
                  <xsl:message
                     select="$this-path-normalized-for-extension-functions || ' points to a file that exists, but is neither XML nor unparsed text (UTF-8 or fallback encoding ' || $target-fallback-encoding || '). Returning an XML document whose root element contains a single text node encoded as xs:base64Binary.'"/>
                  <xsl:document>
                     <base64Binary>
                        <xsl:attribute name="xml:base"
                           select="$this-path-normalized-for-extension-functions"/>
                        <xsl:value-of select="$binary-file"/>
                     </base64Binary>
                  </xsl:document>
               </xsl:if>
            </xsl:when>
            <xsl:otherwise>
               <xsl:message
                  select="$this-path-normalized || ' points to a file that does not exist. Returning an empty document node.'"/>
               <xsl:document/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:for-each>
   </xsl:function>

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

   <xsl:function name="tan:revise-hrefs" as="item()*">
      <!-- Input: an item that should have urls resolved; the original url of the item; the target url (the item's destination) -->
      <!-- Output: the item with each @href (including those in processing instructions) and html:*/@src resolved -->
      <xsl:param name="item-to-resolve" as="item()?"/>
      <xsl:param name="items-original-url" as="xs:string"/>
      <xsl:param name="items-destination-url" as="xs:string"/>
      <xsl:variable name="original-url-resolved" select="resolve-uri($items-original-url)"/>
      <xsl:variable name="destination-url-resolved" select="resolve-uri($items-destination-url)"/>
      <xsl:if test="not($items-original-url = $original-url-resolved)">
         <xsl:message select="'tan:revise-hrefs() warning: param 2 url, ', $items-original-url, ', does not match resolved state: ', $original-url-resolved"/>
      </xsl:if>
      <xsl:if test="not($items-destination-url = $destination-url-resolved) and not(not($items-original-url = $original-url-resolved))">
         <xsl:message select="'tan:revise-hrefs() warning: param 3 url, ', $items-destination-url, ', does not match resolved state: ', $destination-url-resolved"/>
      </xsl:if>
      <xsl:apply-templates select="$item-to-resolve" mode="revise-hrefs">
         <xsl:with-param name="original-url" select="$items-original-url" tunnel="yes"/>
         <xsl:with-param name="target-url" select="$items-destination-url" tunnel="yes"/>
      </xsl:apply-templates>
   </xsl:function>
   <xsl:template match="node() | @*" mode="revise-hrefs">
      <xsl:copy>
         <xsl:apply-templates select="node() | @*" mode="#current"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="processing-instruction()" priority="1" mode="revise-hrefs">
      <xsl:param name="original-url" tunnel="yes" required="yes"/>
      <xsl:param name="target-url" tunnel="yes" required="yes"/>
      <xsl:variable name="href-regex" as="xs:string">(href=['"])([^'"]+)(['"])</xsl:variable>
      <xsl:processing-instruction name="{name(.)}">
            <xsl:analyze-string select="." regex="{$href-regex}">
                <xsl:matching-substring>
                    <xsl:value-of select="concat(regex-group(1), tan:uri-relative-to(resolve-uri(regex-group(2), $original-url), $target-url), regex-group(3))"/>
                </xsl:matching-substring>
                <xsl:non-matching-substring>
                    <xsl:value-of select="."/>
                </xsl:non-matching-substring>
            </xsl:analyze-string>
        </xsl:processing-instruction>
   </xsl:template>
   <xsl:template match="@href" mode="revise-hrefs">
      <xsl:param name="original-url" tunnel="yes" required="yes"/>
      <xsl:param name="target-url" tunnel="yes" required="yes"/>
      <xsl:variable name="this-href-resolved" select="resolve-uri(., $original-url)"/>
      <xsl:variable name="this-href-relative"
         select="tan:uri-relative-to($this-href-resolved, $target-url)"/>
      <xsl:choose>
         <xsl:when test="matches(., '^#')">
            <xsl:copy/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:attribute name="href" select="$this-href-relative"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>
   <xsl:template match="html:script/@src" mode="revise-hrefs">
      <xsl:param name="original-url" tunnel="yes" required="yes"/>
      <xsl:param name="target-url" tunnel="yes" required="yes"/>
      <xsl:attribute name="src"
         select="tan:uri-relative-to(resolve-uri(., $original-url), $target-url)"/>
   </xsl:template>


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
                     <xsl:when test="true()" use-when="$saxon-extension-functions-available">
                        <!-- If saxon:evaluate is available, use it -->
                        <xsl:copy-of select="saxon:evaluate($this-xpath, $context-1, $context-2)"
                           copy-namespaces="no"/>
                        
                     </xsl:when>
                     
                     <xsl:when test="$this-xpath = 'name($p1)'">
                        <xsl:value-of select="name($context-1)"/>
                     </xsl:when>
                     <xsl:when test="matches($this-xpath, '^$p1/@')">
                        <xsl:value-of select="$context-1/@*[name() = replace(., '^\$@', '')]"
                        />
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
               </xsl:matching-substring>
               <xsl:non-matching-substring>
                  <xsl:value-of select="."/>
               </xsl:non-matching-substring>
            </xsl:analyze-string>
         </xsl:variable>
         <xsl:for-each-group select="$results" group-adjacent=". instance of xs:string">
            <xsl:choose>
               <xsl:when test="current-grouping-key() = true()">
                  <xsl:value-of select="string-join(current-group(), '')"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:copy-of select="current-group()"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:for-each-group>
      </xsl:if>
   </xsl:function>


   <!-- FUNCTIONS: TAN FILES -->
   <!-- General TAN files -->

   <xsl:variable name="orig-self-validated" as="document-node()">
      <xsl:apply-templates select="$orig-self" mode="imitate-validation"/>
   </xsl:variable>
   <xsl:template match="*" mode="imitate-validation">
      <!-- new stuff -->
      <xsl:variable name="these-q-refs"
         select="
            for $i in ancestor-or-self::*
            return
               (generate-id($i))"
      />
      
      <!-- This template imitates the process of validation, for testing on efficiency, etc. -->
      <xsl:variable name="this-q-ref" select="generate-id(.)"/>
      <xsl:variable name="this-name" select="name(.)"/>
      <xsl:variable name="this-checked-for-errors"
         select="tan:get-via-q-ref($this-q-ref, $self-expanded[1])"/>
      <xsl:variable name="has-include-or-which-attr" select="exists(@include) or exists(@which)"/>
      <xsl:variable name="relevant-fatalities"
         select="
            if ($has-include-or-which-attr = true()) then
               $this-checked-for-errors//tan:fatal[not(@xml:id = $errors-to-squelch)]
            else
               $this-checked-for-errors/(self::*, *[@attr])/tan:fatal[not(@xml:id = $errors-to-squelch)]"/>
      <xsl:variable name="relevant-errors"
         select="
            if ($has-include-or-which-attr = true()) then
               $this-checked-for-errors//tan:error[not(@xml:id = $errors-to-squelch)]
            else
               $this-checked-for-errors/(self::*, *[@attr])/tan:error[not(@xml:id = $errors-to-squelch)]"/>
      <xsl:variable name="relevant-warnings"
         select="
            if ($has-include-or-which-attr = true()) then
               $this-checked-for-errors//tan:warning[not(@xml:id = $errors-to-squelch)]
            else
               $this-checked-for-errors/(self::*, *[@attr])/tan:warning[not(@xml:id = $errors-to-squelch)]"
      />
      <xsl:variable name="relevant-info"
         select="
            if ($has-include-or-which-attr = true()) then
               $this-checked-for-errors//tan:info
            else
               $this-checked-for-errors/(self::*, *[@attr])/tan:info"/>
      <xsl:variable name="help-offered"
         select="
            if ($has-include-or-which-attr = true()) then
               $this-checked-for-errors//tan:help
            else
               $this-checked-for-errors/(self::*, *[@attr])/tan:help"/>

      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="exists($relevant-fatalities)">
            <sch>
               <value-of select="tan:error-report($relevant-fatalities)"/>
            </sch>
         </xsl:if>
         <xsl:if test="exists($relevant-errors)">
            <sch>
               <value-of select="tan:error-report($relevant-errors)"/>
            </sch>
         </xsl:if>
         <xsl:if test="exists($relevant-warnings)">
            <sch>
               <value-of select="tan:error-report($relevant-warnings)"/>
            </sch>
         </xsl:if>
         <xsl:if test="exists($relevant-info)">
            <sch>
               <value-of select="$relevant-info/tan:message"/>
            </sch>
         </xsl:if>
         <xsl:if test="exists($help-offered)">
            <sch>
               <value-of select="$help-offered/tan:message"/>
            </sch>
         </xsl:if>
         <xsl:if test="not(exists($this-checked-for-errors))">
            <sch><value-of select="$this-q-ref"/> doesn't match; other @q values of <value-of
                  select="$this-name"/>: <value-of
                  select="string-join($self-expanded//*[name() = $this-name]/@q, ', ')"/></sch>
         </xsl:if>

         <xsl:apply-templates mode="#current"/>
      </xsl:copy>

   </xsl:template>
   
   <!--<xsl:variable name="error-tests" as="document-node()*"
      select="doc('errors/error-test-1.tan-t.xml'), doc('errors/error-test-2.tan-voc.xml')"/>-->
   <xsl:variable name="error-tests" as="document-node()*"
      select="collection('errors/?select=error-test-*.xml')"/>
   <xsl:variable name="error-markers" select="$error-tests//comment()[matches(., '\w\w\w\d\d')]"/>

   <!-- Functions: TAN-T(EI) -->

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
               (preceding::text())[last()]"/>
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

   <!-- Functions: TAN-A-lm -->

   <xsl:function name="tan:lm-data" as="element()*">
      <!-- Input: token value; a language code -->
      <!-- Output: <lm> data for that token value from any available resources -->
      <xsl:param name="token-value" as="xs:string?"/>
      <xsl:param name="lang-codes" as="xs:string*"/>

      <!-- First, look in the local language catalog and get relevant TAN-A-lm files -->
      <xsl:variable name="lang-catalogs" select="tan:lang-catalog($lang-codes)"
         as="document-node()*"/>
      <xsl:variable name="these-tan-a-lm-files" as="document-node()*">
         <xsl:for-each select="$lang-catalogs">
            <xsl:variable name="this-base-uri" select="tan:base-uri(.)"/>
            <xsl:for-each
               select="
                  collection/doc[(not(exists(tan:tok-is)) and not(exists(tan:tok-starts-with)))
                  or
                  (tan:tok-is = $token-value)
                  or (some $i in tan:tok-starts-with
                     satisfies starts-with($token-value, $i))]">
               <xsl:variable name="this-uri" select="resolve-uri(@href, string($this-base-uri))"/>
               <xsl:if test="doc-available($this-uri)">
                  <xsl:sequence select="doc($this-uri)"/>
               </xsl:if>
            </xsl:for-each>
         </xsl:for-each>
      </xsl:variable>

      <!-- Look for easy, exact matches -->
      <xsl:variable name="lex-val-matches"
         select="
            for $i in $these-tan-a-lm-files
            return
               key('get-ana', $token-value, $i)"/>

      <!-- If there's no exact match, look for a near match -->
      <xsl:variable name="this-string-approx" select="tan:string-base($token-value)"/>
      <xsl:variable name="lex-rgx-and-approx-matches"
         select="
            $these-tan-a-lm-files/tan:TAN-A-lm/tan:body/tan:ana[tan:tok[@val = $this-string-approx or (if (string-length(@rgx) gt 0)
            then
               matches($token-value, @rgx)
            else
               false())]]"/>

      <!-- If there's not even a near match, see if there's a search service -->
      <xsl:variable name="lex-matches-via-search" as="element()*">
         <xsl:if test="matches($lang-codes, '^(lat|grc)')">
            <xsl:variable name="this-raw-search" select="tan:search-morpheus($token-value)"/>
            <xsl:copy-of select="tan:search-results-to-claims($this-raw-search, 'morpheus')/*"/>
         </xsl:if>
      </xsl:variable>

      <xsl:choose>
         <xsl:when test="exists($lex-val-matches)">
            <xsl:sequence select="$lex-val-matches"/>
         </xsl:when>
         <xsl:when test="exists($lex-rgx-and-approx-matches)">
            <xsl:sequence select="$lex-rgx-and-approx-matches"/>
         </xsl:when>
         <xsl:when test="exists($lex-matches-via-search)">
            <xsl:sequence select="$lex-matches-via-search"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:if test="not(exists($these-tan-a-lm-files))">
               <xsl:message select="'No local TAN-A-lm files found for', $lang-codes"/>
            </xsl:if>
            <xsl:message select="'No data found for', $token-value, 'in language', $lang-codes"/>
         </xsl:otherwise>
      </xsl:choose>

   </xsl:function>

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
