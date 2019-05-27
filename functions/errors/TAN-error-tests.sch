<?xml version="1.0" encoding="UTF-8"?>
<sch:schema xmlns:sch="http://purl.oclc.org/dsdl/schematron" xmlns:tan="tag:textalign.net,2015:ns"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform" queryBinding="xslt2"
    xmlns:sqf="http://www.schematron-quickfix.com/validator/process">
    <xsl:include href="../../functions/incl/TAN-core-functions.xsl"/>
    <xsl:include href="../../functions/TAN-extra-functions.xsl"/>
    <!--<xsl:param name="validation-phase" select="'terse'"/>-->
    <sch:title>Tests on TAN error tests</sch:title>
    <sch:ns prefix="tan" uri="tag:textalign.net,2015:ns"/>
    <sch:ns uri="http://www.w3.org/1999/XSL/Transform" prefix="xsl"/>
    <sch:pattern>
        <sch:rule context="*">
            <sch:let name="this-q-ref" value="generate-id(.)"/>
            <sch:let name="this-checked-for-errors"
                value="tan:get-via-q-ref($this-q-ref, $self-expanded[1])"/>
            <sch:let name="has-include-or-which-attr" value="exists(@include) or exists(@which)"/>
            <sch:let name="relevant-fatalities"
                value="
                    if ($has-include-or-which-attr = true()) then
                        $this-checked-for-errors//tan:fatal[not(@xml:id = $errors-to-squelch)]
                    else
                        $this-checked-for-errors/(self::*, tan:range)/(self::*, *[@attr])/tan:fatal[not(@xml:id = $errors-to-squelch)]"/>
            <sch:let name="relevant-errors"
                value="
                    if ($has-include-or-which-attr = true()) then
                        $this-checked-for-errors//tan:error[not(@xml:id = $errors-to-squelch)]
                    else
                        $this-checked-for-errors/(self::*, tan:range)/(self::*, *[@attr])/tan:error[not(@xml:id = $errors-to-squelch)]"/>
            <sch:let name="relevant-warnings"
                value="
                    if ($has-include-or-which-attr = true()) then
                        $this-checked-for-errors//tan:warning[not(@xml:id = $errors-to-squelch)]
                    else
                        $this-checked-for-errors/(self::*, tan:range)/(self::*, *[@attr])/tan:warning[not(@xml:id = $errors-to-squelch)]"/>

            <sch:let name="preceding-node" value="preceding-sibling::node()[1]"></sch:let>
            <sch:let name="preceding-comment"
                value="($preceding-node/self::comment(), $preceding-node/preceding-sibling::node()[1]/self::comment())[1]"
            />
            <sch:let name="these-intended-error-codes" value="tan:error-codes($preceding-comment)"/>
            
            <sch:report test="exists($these-intended-error-codes)">Errors <sch:value-of select="$these-intended-error-codes"/></sch:report>
        </sch:rule>
    </sch:pattern>
</sch:schema>
