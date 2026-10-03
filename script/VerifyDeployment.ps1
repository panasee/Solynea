# Verify a deployment record. No private key or gas is needed.
param(
    [Parameter(Mandatory = $true)]
    [string]$RecordPath
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Forge = Join-Path $env:USERPROFILE '.foundry\bin\forge.exe'
$Cast = Join-Path $env:USERPROFILE '.foundry\bin\cast.exe'
$RecordPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($RecordPath)
$EnteredApiKey = $false

Push-Location $ProjectRoot
try {
    $Record = Get-Content -LiteralPath $RecordPath -Raw | ConvertFrom-Json
    & $Forge build --root $ProjectRoot --profile default
    if ($LASTEXITCODE -ne 0) { throw 'Build failed; verification was not submitted.' }

    $ArtifactPath = Join-Path $ProjectRoot 'out/Solynea.sol/Solynea.json'
    $Artifact = Get-Content -LiteralPath $ArtifactPath -Raw | ConvertFrom-Json
    if ($Artifact.metadata.compiler.version -ne $Record.compiler -or
        $Artifact.metadata.settings.evmVersion -ne $Record.evmVersion -or
        $Artifact.metadata.settings.optimizer.runs -ne $Record.optimizerRuns -or
        -not $Artifact.metadata.settings.optimizer.enabled) {
        throw 'Compiler settings differ from the recorded deployment.'
    }
    $CurrentSources = $Artifact.metadata.sources.PSObject.Properties
    $RecordedSources = $Record.sourceHashesKeccak256.PSObject.Properties
    if (@($CurrentSources).Count -ne @($RecordedSources).Count) {
        throw 'Source file list differs from the recorded deployment.'
    }
    foreach ($Source in $RecordedSources) {
        $CurrentSource = $Artifact.metadata.sources.PSObject.Properties[$Source.Name]
        if (-not $CurrentSource -or $CurrentSource.Value.keccak256 -ne $Source.Value) {
            throw "Source differs from deployment: $($Source.Name)"
        }
    }

    $ConstructorArgs = & $Cast abi-encode 'constructor(string,string,uint8,address,uint256)' `
        $Record.constructor.tokenName $Record.constructor.tokenSymbol `
        $Record.constructor.tokenDecimals $Record.initialOwner $Record.constructor.initialSupplyRaw
    if ($LASTEXITCODE -ne 0) { throw 'Constructor argument encoding failed.' }

    if ([string]::IsNullOrWhiteSpace($env:ETHERSCAN_API_KEY)) {
        $env:ETHERSCAN_API_KEY = [System.Net.NetworkCredential]::new(
            '', (Read-Host 'Etherscan API Key (not your wallet private key)' -AsSecureString)
        ).Password
        $EnteredApiKey = $true
    }
    if ([string]::IsNullOrWhiteSpace($env:ETHERSCAN_API_KEY)) {
        throw 'An Etherscan API Key is required.'
    }

    & $Forge verify-contract $Record.contractAddress 'src/Solynea.sol:Solynea' `
        --root $ProjectRoot --profile default --chain $Record.chainId `
        --compiler-version $Record.compiler --constructor-args $ConstructorArgs `
        --verifier etherscan --watch
    if ($LASTEXITCODE -ne 0) {
        throw 'Verification failed; the deployment record has not been marked verified.'
    }

    $Record.verified = $true
    $Record | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $RecordPath -Encoding utf8
    Write-Output "Verification succeeded. Public deployment record updated: $RecordPath"
    Write-Output "$($Record.explorerUrl)#code"
}
finally {
    if ($EnteredApiKey) { Remove-Item Env:ETHERSCAN_API_KEY -ErrorAction SilentlyContinue }
    Pop-Location
}
