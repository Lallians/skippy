# allows skippy to parse CLI arguments
# returns an array of $arg => $value
function parseArguments {
    param(
        [string[]]$RemainingArgs
    )

    $parsed = @{}
    for ($i = 0; $i -lt $RemainingArgs.Count; $i++) {

        # If the tested string starts with '-', we know we want to assign a value with a key named after the stirng.
        if ($RemainingArgs[$i] -like "-*") {
            $key = $RemainingArgs[$i].TrimStart("-")

            # We check if the following string does not start with '-', which mean the user provided a value
            # if no value is provided, we assume the parameter is a flag, ie a boolean set to true
            if ($i + 1 -lt $RemainingArgs.Count) {
                # there is indeed a following string

                # we check whether it is a value for our parameter or a flag
                if($RemainingArgs[$i + 1] -notlike "-*") {
                    $i++; # increment so that we check the next parameter
                    $value = $RemainingArgs[$i]
                } else {
                    $value = $true
                }

            }
            
            $parsed[$key] = $value
        } else {

            # the argument was not named, so we just fill with whatever value was passed
            $parsed[$i] = $RemainingArgs[$i]

        }

    }

    return $parsed
}




# Function that returns a string of argument to use in a dynamically generated function call
# Takes an array or argument names and a set of value. the set of values must be a map with the same keys as the argument name list.
function getArgsFormatted {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$fnArgs,

        [Parameter(Mandatory = $true)]
        [hashtable]$parsedArgs
    )

    # Use what the user provided
    $paramsFormatted = @{}
    foreach($theKey in $fnArgs.Keys) {
        if($parsedArgs.ContainsKey($theKey)) {
            $paramsFormatted[$theKey] = $parsedArgs[$theKey]
        }
    }
    
    # Join the parameters into a string: -param1 'value1' -param2 'value2'
    $argString = ($paramsFormatted.GetEnumerator() | ForEach-Object {
        # no quotes for bool values
        if( ($_.Value -eq 0) -or ($_.Value -eq $false) ) {
            "-$($_.Key) `$false"
        } elseif( ($_.Value -eq 1) -or ($_.Value -eq $true) ) {
            "-$($_.Key) `$true"
        } else {
            "-$($_.Key) '$($_.Value)'"
        }
    }) -join ' '

    return $argString

}