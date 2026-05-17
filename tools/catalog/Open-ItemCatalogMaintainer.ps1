param(
    [Parameter()]
    [ValidateSet("Retail", "PTR", "Beta")]
    [string]$Target = "Retail",

    [Parameter()]
    [string]$WoWRoot,

    [Parameter()]
    [string]$ClientDirectory,

    [Parameter()]
    [string]$Locale = "en_US",

    [Parameter()]
    [string]$ProgressPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$statusScript = Join-Path $PSScriptRoot "Get-ItemCatalogMaintainerStatus.ps1"
$refreshScript = Join-Path $PSScriptRoot "Refresh-ItemCatalog.ps1"
$deployScript = Join-Path $PSScriptRoot "Deploy-AddonsToTarget.ps1"

function Invoke-StatusSnapshot {
    param(
        [string]$SelectedTarget,
        [string]$SelectedRoot
    )

    $arguments = @{
        Target = $SelectedTarget
        Locale = $Locale
    }
    if (-not [string]::IsNullOrWhiteSpace($SelectedRoot)) {
        $arguments.WoWRoot = $SelectedRoot
    }
    if (-not [string]::IsNullOrWhiteSpace($ClientDirectory)) {
        $arguments.ClientDirectory = $ClientDirectory
    }
    if (-not [string]::IsNullOrWhiteSpace($ProgressPath)) {
        $arguments.ProgressPath = $ProgressPath
    }

    return & $statusScript @arguments
}

function Invoke-RefreshRun {
    param(
        [string]$SelectedTarget,
        [string]$SelectedRoot,
        [ValidateSet("Fresh", "Resume")]
        [string]$Mode
    )

    $arguments = @{
        Target = $SelectedTarget
        Locale = $Locale
    }
    if ($Mode -eq "Fresh") {
        $arguments.Fresh = $true
    } else {
        $arguments.Resume = $true
    }
    if (-not [string]::IsNullOrWhiteSpace($SelectedRoot)) {
        $arguments.WoWRoot = $SelectedRoot
    }
    if (-not [string]::IsNullOrWhiteSpace($ClientDirectory)) {
        $arguments.ClientDirectory = $ClientDirectory
    }
    if (-not [string]::IsNullOrWhiteSpace($ProgressPath)) {
        $arguments.ProgressPath = $ProgressPath
    }

    return & $refreshScript @arguments
}

function Invoke-DeployRun {
    param(
        [string]$SelectedTarget,
        [string]$SelectedRoot
    )

    $arguments = @{
        Target = $SelectedTarget
        Locale = $Locale
    }
    if (-not [string]::IsNullOrWhiteSpace($SelectedRoot)) {
        $arguments.WoWRoot = $SelectedRoot
    }
    if (-not [string]::IsNullOrWhiteSpace($ClientDirectory)) {
        $arguments.ClientDirectory = $ClientDirectory
    }

    return & $deployScript @arguments
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "GBankManager Maintainer"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(760, 430)
$form.MinimumSize = New-Object System.Drawing.Size(760, 430)

$targetLabel = New-Object System.Windows.Forms.Label
$targetLabel.Text = "Target"
$targetLabel.Location = New-Object System.Drawing.Point(16, 18)
$targetLabel.AutoSize = $true
$form.Controls.Add($targetLabel)

$targetDropdown = New-Object System.Windows.Forms.ComboBox
$targetDropdown.Location = New-Object System.Drawing.Point(16, 40)
$targetDropdown.Size = New-Object System.Drawing.Size(140, 28)
$targetDropdown.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
[void]$targetDropdown.Items.AddRange(@("Retail", "PTR", "Beta"))
$targetDropdown.SelectedItem = $Target
$form.Controls.Add($targetDropdown)

$rootLabel = New-Object System.Windows.Forms.Label
$rootLabel.Text = "WoW Root"
$rootLabel.Location = New-Object System.Drawing.Point(176, 18)
$rootLabel.AutoSize = $true
$form.Controls.Add($rootLabel)

$rootText = New-Object System.Windows.Forms.TextBox
$rootText.Location = New-Object System.Drawing.Point(176, 40)
$rootText.Size = New-Object System.Drawing.Size(430, 28)
$rootText.Text = $WoWRoot
$form.Controls.Add($rootText)

$browseButton = New-Object System.Windows.Forms.Button
$browseButton.Text = "Browse"
$browseButton.Location = New-Object System.Drawing.Point(620, 38)
$browseButton.Size = New-Object System.Drawing.Size(104, 30)
$form.Controls.Add($browseButton)

$statusValue = New-Object System.Windows.Forms.Label
$statusValue.Location = New-Object System.Drawing.Point(16, 92)
$statusValue.Size = New-Object System.Drawing.Size(700, 22)
$statusValue.Text = "Status: -"
$form.Controls.Add($statusValue)

$buildValue = New-Object System.Windows.Forms.Label
$buildValue.Location = New-Object System.Drawing.Point(16, 118)
$buildValue.Size = New-Object System.Drawing.Size(700, 22)
$buildValue.Text = "Build: -"
$form.Controls.Add($buildValue)

$lastSyncValue = New-Object System.Windows.Forms.Label
$lastSyncValue.Location = New-Object System.Drawing.Point(16, 144)
$lastSyncValue.Size = New-Object System.Drawing.Size(700, 22)
$lastSyncValue.Text = "Last Sync: -"
$form.Controls.Add($lastSyncValue)

$addOnsValue = New-Object System.Windows.Forms.Label
$addOnsValue.Location = New-Object System.Drawing.Point(16, 170)
$addOnsValue.Size = New-Object System.Drawing.Size(700, 22)
$addOnsValue.Text = "AddOns: -"
$form.Controls.Add($addOnsValue)

$refreshStatusButton = New-Object System.Windows.Forms.Button
$refreshStatusButton.Text = "Refresh Status"
$refreshStatusButton.Location = New-Object System.Drawing.Point(16, 208)
$refreshStatusButton.Size = New-Object System.Drawing.Size(140, 32)
$form.Controls.Add($refreshStatusButton)

$freshSyncButton = New-Object System.Windows.Forms.Button
$freshSyncButton.Text = "Run Fresh Sync"
$freshSyncButton.Location = New-Object System.Drawing.Point(168, 208)
$freshSyncButton.Size = New-Object System.Drawing.Size(140, 32)
$form.Controls.Add($freshSyncButton)

$resumeSyncButton = New-Object System.Windows.Forms.Button
$resumeSyncButton.Text = "Resume Sync"
$resumeSyncButton.Location = New-Object System.Drawing.Point(320, 208)
$resumeSyncButton.Size = New-Object System.Drawing.Size(140, 32)
$form.Controls.Add($resumeSyncButton)

$deployButton = New-Object System.Windows.Forms.Button
$deployButton.Text = "Deploy Addons"
$deployButton.Location = New-Object System.Drawing.Point(472, 208)
$deployButton.Size = New-Object System.Drawing.Size(140, 32)
$form.Controls.Add($deployButton)

$outputBox = New-Object System.Windows.Forms.TextBox
$outputBox.Location = New-Object System.Drawing.Point(16, 256)
$outputBox.Size = New-Object System.Drawing.Size(708, 128)
$outputBox.Multiline = $true
$outputBox.ScrollBars = "Vertical"
$outputBox.ReadOnly = $true
$form.Controls.Add($outputBox)

function Set-UiBusy {
    param([bool]$Busy)

    $form.UseWaitCursor = $Busy
    foreach ($button in @($browseButton, $refreshStatusButton, $freshSyncButton, $resumeSyncButton, $deployButton, $targetDropdown)) {
        $button.Enabled = -not $Busy
    }
    [System.Windows.Forms.Application]::DoEvents()
}

function Refresh-StatusUi {
    Set-UiBusy -Busy $true
    try {
        $snapshot = Invoke-StatusSnapshot -SelectedTarget ([string]$targetDropdown.SelectedItem) -SelectedRoot $rootText.Text
        $statusValue.Text = "Status: " + ([string]$snapshot.syncStatus)
        $buildValue.Text = "Build: " + ($(if ([string]::IsNullOrWhiteSpace([string]$snapshot.build)) { "-" } else { [string]$snapshot.build }))
        $lastSyncValue.Text = "Last Sync: " + ($(if ([string]::IsNullOrWhiteSpace([string]$snapshot.lastSyncAt)) { "-" } else { [string]$snapshot.lastSyncAt }))
        $addOnsValue.Text = "AddOns: " + [string]$snapshot.addOnsDirectory
        $outputBox.Text = @(
            "Target: " + [string]$snapshot.target
            "WoW Root: " + [string]$snapshot.wowRoot
            "Client: " + [string]$snapshot.clientDirectory
            "Progress: " + [string]$snapshot.progressPath
            "Phase: " + [string]$snapshot.phase
            "Phase Status: " + [string]$snapshot.phaseStatus
        ) -join [Environment]::NewLine
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "GBankManager Maintainer")
    } finally {
        Set-UiBusy -Busy $false
    }
}

$browseButton.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    if (-not [string]::IsNullOrWhiteSpace($rootText.Text) -and (Test-Path -LiteralPath $rootText.Text)) {
        $dialog.SelectedPath = $rootText.Text
    }
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $rootText.Text = $dialog.SelectedPath
        Refresh-StatusUi
    }
})

$refreshStatusButton.Add_Click({ Refresh-StatusUi })
$targetDropdown.Add_SelectedIndexChanged({ Refresh-StatusUi })

$freshSyncButton.Add_Click({
    Set-UiBusy -Busy $true
    try {
        $result = Invoke-RefreshRun -SelectedTarget ([string]$targetDropdown.SelectedItem) -SelectedRoot $rootText.Text -Mode "Fresh"
        $outputBox.Text = (($result | ConvertTo-Json -Depth 8) -replace "\\n", [Environment]::NewLine)
        Refresh-StatusUi
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "GBankManager Maintainer")
    } finally {
        Set-UiBusy -Busy $false
    }
})

$resumeSyncButton.Add_Click({
    Set-UiBusy -Busy $true
    try {
        $result = Invoke-RefreshRun -SelectedTarget ([string]$targetDropdown.SelectedItem) -SelectedRoot $rootText.Text -Mode "Resume"
        $outputBox.Text = (($result | ConvertTo-Json -Depth 8) -replace "\\n", [Environment]::NewLine)
        Refresh-StatusUi
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "GBankManager Maintainer")
    } finally {
        Set-UiBusy -Busy $false
    }
})

$deployButton.Add_Click({
    Set-UiBusy -Busy $true
    try {
        $result = Invoke-DeployRun -SelectedTarget ([string]$targetDropdown.SelectedItem) -SelectedRoot $rootText.Text
        $outputBox.Text = (($result | ConvertTo-Json -Depth 8) -replace "\\n", [Environment]::NewLine)
        Refresh-StatusUi
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "GBankManager Maintainer")
    } finally {
        Set-UiBusy -Busy $false
    }
})

Refresh-StatusUi
[void]$form.ShowDialog()
