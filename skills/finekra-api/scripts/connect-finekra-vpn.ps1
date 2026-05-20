param(
    [string]$Profile = "Finekra",
    [Parameter(Mandatory = $true)][string]$Username,
    [Parameter(Mandatory = $true)][string]$Password,
    [int]$TimeoutSeconds = 240,
    [string]$FortiClientPath = "C:\Program Files\Fortinet\FortiClient\FortiClient.exe",
    [switch]$ValidateProfileOnly
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
if (-not ("FortiClientInput" -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public class FortiClientInput {
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
}
"@
}

function Test-FinekraNetwork {
    $server58 = Test-TcpPort -ComputerName "172.16.220.58" -Port 22 -TimeoutMilliseconds 2500
    $elastic = Test-TcpPort -ComputerName "172.16.220.59" -Port 5601 -TimeoutMilliseconds 2500
    return ($server58 -and $elastic)
}

function Test-TcpPort {
    param(
        [Parameter(Mandatory = $true)][string]$ComputerName,
        [Parameter(Mandatory = $true)][int]$Port,
        [int]$TimeoutMilliseconds = 2500
    )

    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $async = $client.BeginConnect($ComputerName, $Port, $null, $null)
        if (-not $async.AsyncWaitHandle.WaitOne($TimeoutMilliseconds, $false)) {
            return $false
        }
        $client.EndConnect($async)
        return $true
    } catch {
        return $false
    } finally {
        $client.Close()
    }
}

function Get-FortiClientWindow {
    param([datetime]$Deadline)

    $root = [System.Windows.Automation.AutomationElement]::RootElement
    $condition = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
        [System.Windows.Automation.ControlType]::Window
    )

    while ((Get-Date) -lt $Deadline) {
        $processWindow = Get-Process -Name "FortiClient" -ErrorAction SilentlyContinue |
            Where-Object { $_.MainWindowHandle -and $_.MainWindowHandle -ne 0 } |
            Sort-Object StartTime -Descending |
            Select-Object -First 1
        if ($processWindow) {
            $element = [System.Windows.Automation.AutomationElement]::FromHandle($processWindow.MainWindowHandle)
            if ($element) {
                return $element
            }
        }

        $windows = $root.FindAll([System.Windows.Automation.TreeScope]::Children, $condition)
        foreach ($window in $windows) {
            $name = $window.Current.Name
            if ($name -match "FortiClient|Zero Trust Fabric") {
                return $window
            }
        }
        Start-Sleep -Milliseconds 300
    }

    throw "Could not find the FortiClient window."
}

function Find-DescendantByName {
    param(
        [Parameter(Mandatory = $true)][System.Windows.Automation.AutomationElement]$Root,
        [Parameter(Mandatory = $true)][string]$NamePattern
    )

    $all = $Root.FindAll(
        [System.Windows.Automation.TreeScope]::Descendants,
        [System.Windows.Automation.Condition]::TrueCondition
    )
    foreach ($element in $all) {
        if ($element.Current.Name -match $NamePattern) {
            return $element
        }
    }
    return $null
}

function Invoke-Control {
    param([Parameter(Mandatory = $true)][System.Windows.Automation.AutomationElement]$Element)

    $pattern = $null
    if ($Element.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$pattern)) {
        $pattern.Invoke()
        return
    }

    $rect = $Element.Current.BoundingRectangle
    if (-not $rect.IsEmpty) {
        [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point(
            [int]($rect.Left + ($rect.Width / 2)),
            [int]($rect.Top + ($rect.Height / 2))
        )
        [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
    }
}

function Click-WindowPoint {
    param(
        [Parameter(Mandatory = $true)][System.Windows.Automation.AutomationElement]$Window,
        [Parameter(Mandatory = $true)][double]$XRatio,
        [Parameter(Mandatory = $true)][double]$YRatio
    )

    $rect = $Window.Current.BoundingRectangle
    $x = [int]($rect.Left + ($rect.Width * $XRatio))
    $y = [int]($rect.Top + ($rect.Height * $YRatio))
    [FortiClientInput]::SetCursorPos($x, $y) | Out-Null
    Start-Sleep -Milliseconds 80
    [FortiClientInput]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 80
    [FortiClientInput]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
}

function Set-ControlText {
    param(
        [Parameter(Mandatory = $true)][System.Windows.Automation.AutomationElement]$Element,
        [Parameter(Mandatory = $true)][string]$Text
    )

    $pattern = $null
    if ($Element.TryGetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern, [ref]$pattern) -and -not $pattern.Current.IsReadOnly) {
        $pattern.SetValue($Text)
        return
    }

    $Element.SetFocus()
    Start-Sleep -Milliseconds 150
    [System.Windows.Forms.SendKeys]::SendWait("^a")
    Start-Sleep -Milliseconds 100
    [System.Windows.Forms.SendKeys]::SendWait($Text)
}

function Select-FortiVpnProfile {
    param(
        [Parameter(Mandatory = $true)][System.Windows.Automation.AutomationElement]$Window,
        [Parameter(Mandatory = $true)][string]$ProfileName
    )

    $remoteAccess = Find-DescendantByName -Root $Window -NamePattern "Remote Access|VPN"
    if ($remoteAccess) {
        Invoke-Control -Element $remoteAccess
        Start-Sleep -Milliseconds 700
    }

    $comboCondition = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
        [System.Windows.Automation.ControlType]::ComboBox
    )
    $combos = $Window.FindAll([System.Windows.Automation.TreeScope]::Descendants, $comboCondition)

    foreach ($combo in $combos) {
        $combo.SetFocus()
        Start-Sleep -Milliseconds 150

        $expand = $null
        if ($combo.TryGetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern, [ref]$expand)) {
            $expand.Expand()
            Start-Sleep -Milliseconds 500
        } else {
            [System.Windows.Forms.SendKeys]::SendWait("%{DOWN}")
            Start-Sleep -Milliseconds 500
        }

        $profileItem = Find-DescendantByName -Root $Window -NamePattern "^$([regex]::Escape($ProfileName))$"
        if ($profileItem) {
            $selection = $null
            if ($profileItem.TryGetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern, [ref]$selection)) {
                $selection.Select()
            } else {
                Invoke-Control -Element $profileItem
            }
            Start-Sleep -Milliseconds 500
            return $true
        }

        [System.Windows.Forms.SendKeys]::SendWait("{ESC}")
        Start-Sleep -Milliseconds 200
    }

    # FortiClient 7.x renders the Remote Access form inside a Chrome widget on
    # some machines, so UIAutomation cannot always see the inner controls.
    Click-WindowPoint -Window $Window -XRatio 0.67 -YRatio 0.62
    Start-Sleep -Milliseconds 200
    [System.Windows.Forms.SendKeys]::SendWait("^a")
    Start-Sleep -Milliseconds 100
    [System.Windows.Forms.SendKeys]::SendWait($ProfileName)
    Start-Sleep -Milliseconds 200
    [System.Windows.Forms.SendKeys]::SendWait("{TAB}")
    Start-Sleep -Milliseconds 200
    return $true
}

function Get-EditableControls {
    param([Parameter(Mandatory = $true)][System.Windows.Automation.AutomationElement]$Window)

    $editCondition = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
        [System.Windows.Automation.ControlType]::Edit
    )
    $edits = $Window.FindAll([System.Windows.Automation.TreeScope]::Descendants, $editCondition)
    $result = New-Object System.Collections.Generic.List[System.Windows.Automation.AutomationElement]
    foreach ($edit in $edits) {
        if ($edit.Current.IsEnabled -and -not $edit.Current.IsOffscreen) {
            $result.Add($edit)
        }
    }
    return @($result)
}

function Start-FortiClientFineKraLogin {
    param(
        [Parameter(Mandatory = $true)][string]$ProfileName,
        [Parameter(Mandatory = $true)][string]$VpnUsername,
        [Parameter(Mandatory = $true)][string]$VpnPassword,
        [switch]$ProfileValidationOnly
    )

    Start-Process -FilePath $FortiClientPath -WindowStyle Normal | Out-Null
    Start-Sleep -Seconds 3

    $wshell = New-Object -ComObject WScript.Shell
    $activated = $wshell.AppActivate("FortiClient - Zero Trust Fabric Agent")
    if (-not $activated) {
        $activated = $wshell.AppActivate("FortiClient")
    }
    if (-not $activated) {
        throw "Could not activate FortiClient window."
    }

    $window = Get-FortiClientWindow -Deadline (Get-Date).AddSeconds(15)
    if (-not (Select-FortiVpnProfile -Window $window -ProfileName $ProfileName)) {
        throw "FortiClient VPN profile '$ProfileName' could not be selected. Aborting before entering credentials."
    }

    if ($ProfileValidationOnly) {
        [pscustomobject]@{
            status = "profile-selected"
            profile = $ProfileName
            message = "FortiClient VPN profile was explicitly selected. Credentials were not entered."
        } | ConvertTo-Json -Compress
        exit 0
    }

    $edits = Get-EditableControls -Window $window
    if ($edits.Count -ge 2) {
        Set-ControlText -Element $edits[0] -Text $VpnUsername
        Start-Sleep -Milliseconds 200
        Set-ControlText -Element $edits[1] -Text $VpnPassword
        Start-Sleep -Milliseconds 200
    } else {
        Click-WindowPoint -Window $window -XRatio 0.67 -YRatio 0.66
        Start-Sleep -Milliseconds 150
        [System.Windows.Forms.SendKeys]::SendWait("^a")
        [System.Windows.Forms.SendKeys]::SendWait($VpnUsername)
        Start-Sleep -Milliseconds 150
        Click-WindowPoint -Window $window -XRatio 0.67 -YRatio 0.70
        Start-Sleep -Milliseconds 150
        [System.Windows.Forms.SendKeys]::SendWait("^a")
        [System.Windows.Forms.SendKeys]::SendWait($VpnPassword)
        Start-Sleep -Milliseconds 200
    }

    $connectButton = Find-DescendantByName -Root $window -NamePattern "^Connect$|Connect VPN|Bağlan|Baglan"
    if ($connectButton) {
        Invoke-Control -Element $connectButton
    } else {
        Click-WindowPoint -Window $window -XRatio 0.62 -YRatio 0.80
    }
}

if (-not $ValidateProfileOnly -and (Test-FinekraNetwork)) {
    [pscustomobject]@{
        status = "connected"
        message = "Finekra VPN network is already reachable."
        server58Ssh = $true
        elasticKibana = $true
    } | ConvertTo-Json -Compress
    exit 0
}

if (-not (Test-Path -LiteralPath $FortiClientPath)) {
    throw "FortiClient executable not found at $FortiClientPath"
}

Start-FortiClientFineKraLogin -ProfileName $Profile -VpnUsername $Username -VpnPassword $Password -ProfileValidationOnly:$ValidateProfileOnly

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$approvalNoticeShown = $false
while ((Get-Date) -lt $deadline) {
    if (Test-FinekraNetwork) {
        [pscustomobject]@{
            status = "connected"
            message = "Finekra VPN network is reachable."
            server58Ssh = $true
            elasticKibana = $true
        } | ConvertTo-Json -Compress
        exit 0
    }

    $elapsed = $TimeoutSeconds - [int]($deadline - (Get-Date)).TotalSeconds
    if (-not $approvalNoticeShown -and $elapsed -ge 25) {
        Write-Output "WAITING_FOR_PHONE_APPROVAL"
        $approvalNoticeShown = $true
    }
    Start-Sleep -Seconds 5
}

[pscustomobject]@{
    status = "timeout"
    message = "VPN did not become reachable before timeout. It may be waiting for phone approval or manual FortiClient input."
    server58Ssh = (Test-TcpPort -ComputerName "172.16.220.58" -Port 22 -TimeoutMilliseconds 2500)
    elasticKibana = (Test-TcpPort -ComputerName "172.16.220.59" -Port 5601 -TimeoutMilliseconds 2500)
} | ConvertTo-Json -Compress
exit 2
