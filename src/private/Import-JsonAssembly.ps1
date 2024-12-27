<#
.SYNOPSIS
Imports the required JSON .NET assemblies.
.DESCRIPTION
This function imports the Newtonsoft.Json and Newtonsoft.Json.Schema .NET assemblies required for JSON validation. It also defines and adds a custom Validator class for schema validation.
.NOTES
Ensure the Newtonsoft.Json.dll and Newtonsoft.Json.Schema.dll files are located in the same directory as this script.
#>
function Import-JsonAssembly {
    [CmdletBinding()]
    param ()
    $libraries = (
        "$PSScriptRoot/Newtonsoft.Json.dll",
        "$PSScriptRoot/Newtonsoft.Json.Schema.dll"
    )
    foreach ($library in $libraries) {
        Unblock-File -Path $library
        Add-Type -Path $library
    }
    $referenceLibraries = @(
        $libraries +
        @(
            [System.AppDomain]::CurrentDomain.GetAssemblies() |
                Where-Object -FilterScript { $_.FullName -match 'mscorlib' -or $_.FullName -match 'netstandard' } |
                Select-Object -ExpandProperty Location
        )
    )
    $validateSrc = @'
using System;
using System.Collections.Generic;
using Newtonsoft.Json.Linq;
using Newtonsoft.Json.Schema;
public class Validator
{
public static IList<string> Validate(JToken token, JSchema schema)
{
IList<string> messages;
SchemaExtensions.IsValid(token, schema, out messages);
return messages;
}
}
'@
    Add-Type -TypeDefinition $validateSrc -ReferencedAssemblies $referenceLibraries
}
