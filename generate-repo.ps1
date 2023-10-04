$pluginsOut = @()

$pluginList = Get-Content '.\repos.json' | ConvertFrom-Json

foreach ($plugin in $pluginList) {
    # Get values from the object
    $username = $plugin.username
    $repo = $plugin.repo
    $branch = $plugin.branch
    $pluginName = $plugin.pluginName
    $configFolder = $plugin.configFolder

    # Fetch release data from the GitHub API
    $data = Invoke-WebRequest -Uri "https://api.github.com/repos/$($username)/$($repo)/releases"
    $releases = ConvertFrom-Json $data.content

    # Initialize download count variable
    $totalCount = 0

    # Loop through releases and accumulate download counts
    foreach ($release in $releases) {
        $totalCount += $release.assets[0].download_count
    }

    # Get the latest release for other information
    $latestRelease = $releases[0]
    $assembly = $latestRelease.tag_name
    $download = $latestRelease.assets[0].browser_download_url
    $time = [Int](New-TimeSpan -Start (Get-Date "01/01/1970") -End ([DateTime]$latestRelease.published_at)).TotalSeconds

    # Get the config data from the repo
    $configData = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/$($username)/$($repo)/$($branch)/$($configFolder)/$($pluginName).json"
    $config = ConvertFrom-Json $configData.content

    # Ensure that config is converted properly
    if ($null -eq $config) {
        Write-Error "Config for plugin $($plugin) is null!"
        ExitWithCode(1)
    }

    # Add additional properties to the config
    $config | Add-Member -Name "IsHide" -MemberType NoteProperty -Value "False"
    $config | Add-Member -Name "IsTestingExclusive" -MemberType NoteProperty -Value "False"
    $config | Add-Member -Name "AssemblyVersion" -MemberType NoteProperty -Value $assembly
    $config | Add-Member -Name "LastUpdated" -MemberType NoteProperty -Value $time
    $config | Add-Member -Name "DownloadCount" -MemberType NoteProperty -Value $totalCount
    $config | Add-Member -Name "DownloadLinkInstall" -MemberType NoteProperty -Value $download
    $config | Add-Member -Name "DownloadLinkTesting" -MemberType NoteProperty -Value $download
    $config | Add-Member -Name "DownloadLinkUpdate" -MemberType NoteProperty -Value $download

    # Add to the plugin array
    $pluginsOut += $config
}

# Convert plugins to JSON
$pluginJson = ConvertTo-Json $pluginsOut

# Save repo to file
Set-Content -Path "pluginmaster.json" -Value $pluginJson

# Function to exit with a specific code
function ExitWithCode($code) {
    $host.SetShouldExit($code)
    exit $code
}
