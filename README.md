# Text Alignment Network 
http://textalign.net

Version 2019

This project has submodules, which must be invoked using the --recursive option:
`git clone --recursive [SOURCE PATH]`

New to TAN? Start with directories marked with an asterisk.

* `/applications`: XSLT and XProc stylesheets intended for creating, editing, and working with TAN files. 
* \*`/examples`: A small library of example TAN files. Snippets of these examples appear in the guidelines.
* `functions/`: The TAN function library. This is the core of both the validation process and subsequent activities.
* \* `/guidelines`: the main documentation for TAN. See also http://textalign.net/release/TAN-2018/guidelines/xhtml/index.xhtml. 
* `parameters`: Parameters that can be altered, to adjust both validation and activities.
* `schemas/`: The principle schemas for validating TAN files.
* `TAN-key/`: core definitions of various concepts (things that take IRI + name, or `<token-definition>`)
* `templates`: Templates in various formats, both TAN and non-TAN. Useful for activities.

Participation in development of TAN is welcome. If you create or maintain a library of TAN files, share it.