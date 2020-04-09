<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:saxon="http://saxon.sf.net/"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tan="tag:textalign.net,2015:ns"
    exclude-result-prefixes="#all" version="3.0">
    
    <!-- Create App for XSL -->
    <!-- author: Joel Kalvesmaki -->
    <!-- updated: 2020-04-08 -->
    <!-- To do: 
        refine, test batch process
        develop parallel process for shell (.sh)
    -->
    
    <!-- This stylesheet creates a batch file for each of one or more input XSLT stylesheets, to make
        it easier for someone to use an XSLT stylesheet like a traditional application. A user needs 
        merely to use the File Explorer to drag files onto the batch file, and run the stylesheet. 
        
        This process will not serve every type of XSLT application. It targets a significant subset of XSLT
        that we will call here MIRU stylesheets: Main Input via Resolved URIs.
        In a MIRU stylesheet:
          - the initial, catalyzing input is irrelevant; any XML file, including stylesheet itself, can be the catalyzing input.
          - the main input is determined by a single parameter that takes a sequence of strings for resolved 
            uris; those files are either input files or plain-text lists of input files.
        In a MIRU stylesheet, the catalyzing XML input is of no consequence, and so the MIRU stylesheet can be its own
        catalyzing input. The main input is drawn from files fetched from the resolved uris. 
        
        The advantage of a MIRU stylesheet is that anything can be input, including non-XML, binary files. In many 
        MIRU stylesheets the primary output (the output determined by the default or initial template) is of no or 
        little consequence, perhaps providing a diagnostic report or a log. The more important output files are generated 
        by xsl:result-document, either iterating over the input and saving each output file somewhere relative to the input,
        the stylesheet, or some other location. 
        
        The file you are reading is an example of a MIRU stylesheet. To test it, copy this file, and drag the copy atop the 
        original. A new batch file will appear alongside the copy. 
        
        The process should work as will for NIR (no input required) XSLT stylesheets.
    -->
    
    <!-- Catalyzing input: any XML file (including this one) -->
    <!-- Main input: one or more resolved uris pointing to XSLT stylesheets -->
    <!-- Primary output: nothing, unless diagnostics are on -->
    <!-- Secondary output: a batch file with the same name as the main input -->
    <!-- Adjust parameters below, as needed -->
    
    
    <xsl:import href="../../functions/TAN-A-functions.xsl"/>
    
    <!-- Static parameter to see if advanced Saxon functions are available -->
    <xsl:param name="function-saxon-evaluate-available" static="yes" select="function-available('saxon:evaluate')"/>
    
    <!-- + + + + + + + + + + + + + + -->
    <!-- START OF NON-STATIC PARAMETERS -->


    <!-- Parameters part 1: where are the input XSLT files -->

    <!-- What are the resolved uris for the XSLT files that should have an app created? -->
    <xsl:param name="main-input-resolved-uris" as="xs:string*"/>
    
    <!-- Alternatively, you might provide resolved URIs pointing to a plain-text list of resolved URIs, each on a separate line -->
    <xsl:param name="main-input-resolved-uri-lists" as="xs:string*"/>
    


    <!-- Parameters part 2: values that will populate the batch file. The values below are the default. But if you want to overwrite
    them, you may do so in the input XSLT file with identically named parameters. Note, however, that those parameters
    should be simple strings and not set as XPath expressions, unless you can run this through Saxon PE or EE. -->
    
    <!-- Where is the Saxon XSLT processor relative to the stylesheet that declares this parameter? If left blank, the target will point to the Saxon processor used by Create App for XSL -->
    <xsl:param name="processor-path-relative-to-this-stylesheet" as="xs:string"
        >../../processors/saxon9he.jar</xsl:param>

    <!-- What are the standard Saxon options you want to include? See https://saxonica.com/documentation/index.html#!using-xsl/commandline -->
    <xsl:param name="default-saxon-options" as="xs:string?"/>
    
    <!-- Where should the app be saved relative to the input XSLT? If the value is empty, the batch file will have the same name as the input XSLT, but with a .bat extension -->
    <xsl:param name="target-batch-uri-relative-to-input-xslt" as="xs:string?"/>
    
    <!-- What should be the filename of the target app's primary output (if any)? Note, this value populates the -o parameter, and does not dictate whether there will be any primary output, or the handling of secondary output via xsl:result-document -->
    <xsl:param name="primary-output-target-uri" as="xs:string">%_xslPath%.output.xml</xsl:param>
    
    <!-- What is the name of the key parameter in the stylesheet? It must be anticipating a sequence of strings representing resolved uris -->
    <xsl:param name="key-parameter-name" as="xs:string">main-input-resolved-uri-lists</xsl:param>
    
    <!-- What other parameters should be set in the stylesheet? It must follow the syntax laid out in [params] here: https://saxonica.com/documentation/index.html#!using-xsl/commandline  -->
    <xsl:param name="other-parameters" as="xs:string?"/>
    
    <!-- Do you want to turn diagnostics on? This parameter does not affect the content of the output file(s). -->
    <xsl:param name="diagnostics-on" as="xs:string?">1</xsl:param>
    
    <!-- What additional documentation if any do you want to add to the app? If you can run this through Saxon PE or EE, try select="root()/*/*[1]/preceding-sibling::comment()" to insert all initial comments -->
    <xsl:param name="additional-documentation" as="xs:string?"/>
    
    <!-- There are numerous other adjustments you can make to the batch file itself. When you are finished,
    you will want to pay careful attention to the relative paths of various files. -->

    <!-- END OF PARAMETERS -->
    <!-- + + + + + + + + + + + + + + -->
    
    <!-- If resolved uris point to a list of uris, get them -->
    <xsl:variable name="miru-lists-parsed" as="xs:string*">
        <xsl:for-each select="distinct-values($main-input-resolved-uri-lists)">
            <xsl:choose>
                <xsl:when test="unparsed-text-available(.)">
                    <!-- get text lines that have text -->
                    <xsl:message select="'unparsed text lines: ' || unparsed-text-lines(.)"/>
                    <xsl:sequence select="unparsed-text-lines(.)[matches(., '\S')]"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:message select="'No text file found at ' || ."/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:variable>
    
    <xsl:variable name="processor-path-resolved" as="xs:string"
        select="resolve-uri($processor-path-relative-to-this-stylesheet, static-base-uri())"/>
    
    <!-- The template is the same name as this stylesheet, but with a .bat extension -->
    <xsl:variable name="batch-file-template" as="xs:string"
        select="unparsed-text(replace(string(static-base-uri()), '\.xsl$', '.bat'))"/>
    
    
    <xsl:function name="tan:get-xslt" as="document-node()*">
        <!-- Input: a sequence of resolved URIs pointing to XSLT files, a sequence of resolved URIs already visited, a loop counter -->
        <!-- Output: the XSLT files, along with incuded / imported XSLT files, processed recursively -->
        <xsl:param name="resolved-uris-to-check" as="xs:string*"/>
        <xsl:param name="resolved-uris-already-checked" as="xs:string*"/>
        <xsl:param name="loop-counter" as="xs:integer"/>
        <xsl:choose>
            <xsl:when test="$loop-counter gt $loop-tolerance">
                <xsl:message select="'tan:get-xslt() has exceeded loop tolerance'"/>
            </xsl:when>
            <xsl:when test="count($resolved-uris-to-check) lt 1"/>
            <xsl:otherwise>
                <xsl:variable name="next-uri" select="$resolved-uris-to-check[1]"/>
                <xsl:variable name="this-doc" as="document-node()?">
                    <xsl:try select="doc($next-uri)">
                        <xsl:catch>
                            <xsl:message select="'No file found at ' || $next-uri"/>
                        </xsl:catch>
                    </xsl:try>
                </xsl:variable>
                <xsl:choose>
                    <xsl:when test="$next-uri = $resolved-uris-already-checked">
                        <!-- In this case the uri has already been checked, so we move on. There are cases
                            where tracing a stylesheet might lead to repetition of a resolved uri to an
                            included or imported stylesheet. -->
                        <xsl:sequence
                            select="tan:get-xslt($resolved-uris-to-check[position() gt 1], ($resolved-uris-to-check, $next-uri), $loop-counter + 1)"
                        />
                    </xsl:when>
                    <xsl:when test="not(exists($this-doc/(xsl:stylesheet, xsl:transform)))">
                        <xsl:if test="exists($this-doc/*)">
                            <xsl:message select="'Target of ' || $next-uri || ' is not XSLT'"/>
                        </xsl:if>
                        <xsl:sequence
                            select="tan:get-xslt($resolved-uris-to-check[position() gt 1], ($resolved-uris-to-check, $next-uri), $loop-counter + 1)"
                        />
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:variable name="these-imports" select="$this-doc/*/xsl:import"/>
                        <xsl:variable name="these-includes" select="$this-doc/*/xsl:include"/>
                        <xsl:variable name="new-uris-to-check"
                            select="
                                for $i in ($these-imports, $these-includes)
                                return
                                    resolve-uri($i/@href, $next-uri)"
                        />
                        <xsl:sequence select="$this-doc"/>
                        <xsl:sequence
                            select="tan:get-xslt(($resolved-uris-to-check[position() gt 1], $new-uris-to-check), ($resolved-uris-to-check, $next-uri), $loop-counter + 1)"
                        />
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    <xsl:function name="tan:evaluate-param" as="xs:string?">
        <!-- Input: elements (xsl:params) -->
        <!-- Output: the value of the first param that can be evaluated -->
        <xsl:param name="param-to-evaluate" as="element()?"/>
        <xsl:variable name="open-and-close-quote-regex" as="xs:string">^['"]|['"]$</xsl:variable>
        <xsl:if test="$diagnostics-on">
            <xsl:message
                select="'Evaluating param ' || $param-to-evaluate/@name || ' (parent ' || name($param-to-evaluate/parent::*) || ')'"
            />
        </xsl:if>
        <xsl:choose>
            <xsl:when test="exists($param-to-evaluate/@select)"
                use-when="$function-saxon-evaluate-available">
                <!-- We work only with saxon:evaluate and not xsl:evaluate because the latter (for security reasons) must
                be pegged to parameters in this stylesheet. -->
                <xsl:try>
                    <xsl:for-each select="$param-to-evaluate">
                        <xsl:variable name="this-evaluation" select="saxon:evaluate(@select)"/>
                        <xsl:value-of select="string-join($this-evaluation, '&#xd;&#xa;')"/>
                    </xsl:for-each>
                    <xsl:catch>
                        <xsl:message
                            select="'Could not use saxon:evaluate on @select in parameter ' || $param-to-evaluate/@name"
                        />
                    </xsl:catch>
                </xsl:try>
            </xsl:when>
            <xsl:when test="matches($param-to-evaluate/@select, $open-and-close-quote-regex)">
                <xsl:value-of select="replace($param-to-evaluate/@select, $open-and-close-quote-regex, '')"/>
            </xsl:when>
            <xsl:when test="not(exists($param-to-evaluate/*))">
                <xsl:value-of select="$param-to-evaluate"/>
            </xsl:when>
            <xsl:otherwise>
                <!-- This is a case where @select either doesn't have a string value or it has children elements, and
                cannot be evaluated -->
                <xsl:message select="'Could not evaluate complex parameter ' || $param-to-evaluate/@name"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    

    <xsl:function name="tan:adjust-batch-content" as="xs:string">
        <!-- Input: a template batch file, assorted parameters -->
        <!-- Output: a copy of the batch file revised according to the parameters specified by the input XSLT file -->
        <xsl:param name="target-uri-resolved" as="xs:string"/>
        <xsl:param name="override-params" as="element()*"/>
        <xsl:param name="relative-path-from-batch-to-xslt" as="xs:string?"/>
        
        <xsl:variable name="saxon-path-override" as="xs:string?"
            select="
                (for $i in $override-params[@name = 'processor-path-relative-to-this-stylesheet'],
                    $j in tan:evaluate-param($i)
                return
                    $j)[1]"
        />
        <xsl:variable name="new-saxon-path"
            select="tan:uri-relative-to(($saxon-path-override, $processor-path-resolved)[1], $target-uri-resolved)"
        />

        <xsl:variable name="default-saxon-options-override" as="xs:string?"
            select="
                (for $i in $override-params[@name = 'default-saxon-options'],
                    $j in tan:evaluate-param($i)
                return
                    $j)[1]"
        />
        <xsl:variable name="new-default-saxon-options"
            select="($default-saxon-options-override, $default-saxon-options)[1]"/>
        
        <!-- We process the output in multiple passes, to ease legibility of this stylesheet's code (indentations) -->
        <xsl:variable name="output-pass-1" as="xs:string+">
            <!-- set up the path to the Saxon engine and its options (other than -xsl:, -o:, and -s:) -->
            <xsl:analyze-string select="$batch-file-template" regex="(set _saxonPath=)\S*">
                <xsl:matching-substring>
                    <xsl:value-of select="regex-group(1) || $new-saxon-path"/>
                </xsl:matching-substring>
                <xsl:non-matching-substring>
                    <xsl:analyze-string select="." regex="(set _saxonOptions=)\S*">
                        <xsl:matching-substring>
                            <xsl:value-of select="regex-group(1) || $new-default-saxon-options"/>
                        </xsl:matching-substring>
                        <xsl:non-matching-substring>
                            <xsl:value-of select="."/>
                        </xsl:non-matching-substring>
                    </xsl:analyze-string>
                </xsl:non-matching-substring>
            </xsl:analyze-string>
        </xsl:variable>
        
        
        <xsl:variable name="key-parameter-name-override" as="xs:string?"
            select="
                (for $i in $override-params[@name = 'key-parameter-name'],
                    $j in tan:evaluate-param($i)
                return
                    $j)[1]"
        />
        <xsl:variable name="new-key-parameter-name"
            select="($key-parameter-name-override, $key-parameter-name)[1]"/>
        
        <xsl:variable name="primary-output-target-uri-override" as="xs:string?"
            select="
                (for $i in $override-params[@name = 'primary-output-target-uri'],
                    $j in tan:evaluate-param($i)
                return
                    $j)[1]"
        />
        <xsl:variable name="new-primary-output-target-uri"
            select="($primary-output-target-uri-override, $primary-output-target-uri)[1]"/>
        
        <xsl:variable name="output-pass-2" as="xs:string+">
            <!-- set up option -o: and the key parameter -->
            <xsl:analyze-string select="string-join($output-pass-1)" regex="(set _keyParameter=)\S+">
                <xsl:matching-substring>
                    <xsl:value-of select="regex-group(1) || $new-key-parameter-name"/>
                </xsl:matching-substring>
                <xsl:non-matching-substring>
                    <!-- set up the primary output target uri -->
                    <xsl:analyze-string select="." regex="(set _xslOutput=)\S+">
                        <xsl:matching-substring>
                            <xsl:value-of select="regex-group(1) || $new-primary-output-target-uri"/>
                        </xsl:matching-substring>
                        <xsl:non-matching-substring>
                            <xsl:value-of select="."/>
                        </xsl:non-matching-substring>
                    </xsl:analyze-string>
                </xsl:non-matching-substring>
            </xsl:analyze-string>
        </xsl:variable>
        
        
        
        <xsl:variable name="diagnostics-on-override" as="xs:string?"
            select="
                (for $i in $override-params[@name = 'diagnostics-on'],
                    $j in tan:evaluate-param($i)
                return
                    $j)[1]"
        />
        <xsl:variable name="new-diagnostics-on"
            select="($diagnostics-on-override, $diagnostics-on)[1]"/>

        <xsl:variable name="additional-documentation-override" as="xs:string?"
            select="
                (for $i in $override-params[@name = 'additional-documentation'],
                    $j in tan:evaluate-param($i)
                return
                    $j)[1]"
        />
        <xsl:variable name="new-additional-documentation"
            select="($additional-documentation-override, $additional-documentation)[1]"/>
        
        <xsl:variable name="output-pass-3" as="xs:string+">
            <!-- set up diagnostics option -->
            <xsl:analyze-string select="string-join($output-pass-2)" regex="(set _diagnostics=)\S+">
                <xsl:matching-substring>
                    <xsl:value-of select="regex-group(1) || $new-diagnostics-on"/>
                </xsl:matching-substring>
                <xsl:non-matching-substring>
                    <!-- add additional documentation -->
                    <xsl:analyze-string select="." regex="REM additional documentation">
                        <xsl:matching-substring>
                            <xsl:message select="'Escaping new documentation for batch syntax. Check results for errors.'"/>
                            <xsl:for-each select="tokenize($new-additional-documentation, '\r?\n')">
                                <xsl:choose>
                                    <xsl:when test="matches(., '\S')">
                                        <!-- Escape parentheses. -->
                                        <xsl:variable name="this-batch-escaped-text-pass-1" select="replace(., '([\)\(])', '^$1')"/>
                                        <!-- A line that terminates in a parentheses should have its escape escaped. Batch syntax. Ugh. -->
                                        <xsl:variable name="this-batch-escaped-text-pass-2" select="replace($this-batch-escaped-text-pass-1, '(\^\))\s*$', '^^$1')"/>
                                        <xsl:value-of select="'echo ' || $this-batch-escaped-text-pass-2 || '&#xd;&#xa;'"/>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <!-- A blank line is simply: echo. (no space between 'echo' and the period) -->
                                        <xsl:value-of select="'echo.&#xd;&#xa;'"/>
                                    </xsl:otherwise>
                                </xsl:choose>
                            </xsl:for-each>
                        </xsl:matching-substring>
                        <xsl:non-matching-substring>
                            <xsl:value-of select="."/>
                        </xsl:non-matching-substring>
                    </xsl:analyze-string>
                </xsl:non-matching-substring>
            </xsl:analyze-string>
        </xsl:variable>


        
        <xsl:variable name="other-parameters-override" as="xs:string?"
            select="
                (for $i in $override-params[@name = 'other-parameters'],
                    $j in tan:evaluate-param($i)
                return
                    $j)[1]"
        />
        <xsl:variable name="new-other-parameters"
            select="($other-parameters-override, $other-parameters)[1]"/>
        
        <xsl:variable name="output-pass-4" as="xs:string+">
            <!-- add other parameters -->
            <xsl:analyze-string select="string-join($output-pass-3)" regex="(set _otherParameters=)\S+">
                <xsl:matching-substring>
                    <xsl:value-of select="regex-group(1) || $new-other-parameters"/>
                </xsl:matching-substring>
                <xsl:non-matching-substring>
                    <!-- adjust the path to the XSLT file -->
                    <xsl:analyze-string select="." regex="(set _xslPath=)\S+">
                        <xsl:matching-substring>
                            <xsl:value-of select="regex-group(1) || $relative-path-from-batch-to-xslt"/>
                        </xsl:matching-substring>
                        <xsl:non-matching-substring>
                            <xsl:value-of select="."/>
                        </xsl:non-matching-substring>
                    </xsl:analyze-string>
                </xsl:non-matching-substring>
            </xsl:analyze-string>
        </xsl:variable>
        
        <xsl:value-of select="string-join($output-pass-4)"/>
    </xsl:function>
    
    <!-- The only primary output is perhaps a diagnostic log -->
    <xsl:output indent="yes"/>
    
    <xsl:template match="/">
        <xsl:if test="$diagnostics-on">
            <diagnostics>
                <main-input-uris-resolved count="{count($main-input-resolved-uris) + count($miru-lists-parsed)}">
                    <xsl:for-each select="$main-input-resolved-uris, $miru-lists-parsed">
                        <uri doc-available="{doc-available(.)}"><xsl:value-of select="."/></uri>
                    </xsl:for-each>
                </main-input-uris-resolved>
            </diagnostics>
        </xsl:if>
        <xsl:if test="count($miru-lists-parsed) gt 0 and count($main-input-resolved-uris) gt 1">
            <xsl:message select="'Input is both a sequence of resolved uris and a list of them. Attempting to synthesize both.'"/>
        </xsl:if>
        <xsl:for-each select="$miru-lists-parsed, $main-input-resolved-uris">
            <xsl:variable name="this-uri" select="normalize-space(.)"/>
            <xsl:variable name="these-xslt-files" select="tan:get-xslt($this-uri, (), 1)" as="document-node()*"/>
            <xsl:variable name="these-params" select="$these-xslt-files/*/xsl:param"/>
            <xsl:variable name="target-batch-uri-relative-to-input-xslt-override" as="xs:string?"
                select="
                    (for $i in $these-params[@name = 'target-batch-uri-relative-to-input-xslt'],
                        $j in tan:evaluate-param($i)
                    return
                        $j)[1]"
            />
            <!-- If there is no override provided, the batch file is placed alongside the input XSLT -->
            <xsl:variable name="target-batch-href" as="xs:string"
                select="
                    if (matches($target-batch-uri-relative-to-input-xslt-override, '\S')) then
                        resolve-uri($target-batch-uri-relative-to-input-xslt-override, $this-uri)
                    else
                        replace($this-uri, '.[^\.]+$', '.bat')"
            />
            <!-- If the batch file is going to a directory other than where the XSLT file is, build a relative path -->
            <xsl:variable name="relative-path-from-batch-to-xslt"
                select="
                    if (matches($target-batch-uri-relative-to-input-xslt-override, '\S')) then
                        tan:uri-relative-to($this-uri, $target-batch-href)
                    else
                        '%_thisBatchName:.bat=.xsl%'"
            />
            
            <xsl:variable name="these-params-for-strings" select="$these-params[not(@as) or (@as = ('xs:string+', 'xs:string*'))]"/>
            <xsl:variable name="these-params-correctly-named" select="$these-params[@name = $key-parameter-name]"/>
            <xsl:variable name="this-valid-key-param"
                select="$these-params-for-strings[@name = $key-parameter-name][1]"/>
            
            <xsl:choose>
                <xsl:when test="exists($this-valid-key-param)">
                    <xsl:variable name="new-batch-file"
                        select="tan:adjust-batch-content($target-batch-href, $these-params, $relative-path-from-batch-to-xslt)"
                    />
                    <xsl:message select="'Saving batch file at ' || $target-batch-href"/>
                    <xsl:result-document method="text" href="{$target-batch-href}">
                        <xsl:value-of select="$new-batch-file"/>
                    </xsl:result-document>
                </xsl:when>
                <xsl:when test="exists($these-params-correctly-named)">
                    <xsl:message select="$this-uri || ' is an XSLT document, and there is a key param named ' || $key-parameter-name || 
                        ' but it is not defined as taking a sequence of strings.'"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:message
                        select="
                            $this-uri || ' is an XSLT document, but there is no key param named ' ||
                            $key-parameter-name || '. This operation expects a single parameter that accepts a sequence of strings. ' ||
                            string(count($these-params-for-strings)) || ' such parameters exist: ' || string-join($these-params-for-strings/@name, ', ') || '.'"
                    />
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:template>
</xsl:stylesheet>
