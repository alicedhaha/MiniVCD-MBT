$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$tempCsv = Join-Path $env:TEMP 'minivcd_verify.csv'

Set-Location -LiteralPath $projectRoot

function Invoke-Checked {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Program,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $Arguments
  )

  & $Program @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "Command failed with exit code $LASTEXITCODE`: $Program $($Arguments -join ' ')"
  }
}

Invoke-Checked moon fmt --check
Invoke-Checked moon check --target all --deny-warn
Invoke-Checked moon build --target all
Invoke-Checked moon test --target all --deny-warn
Invoke-Checked moon info
Invoke-Checked git diff --exit-code

Invoke-Checked moon run cmd/minivcd -- info examples/demo.vcd
Invoke-Checked moon run cmd/minivcd -- signals examples/demo.vcd
Invoke-Checked moon run cmd/minivcd -- changes examples/demo.vcd top.clk
Invoke-Checked moon run cmd/minivcd -- stats examples/demo.vcd top.clk
Invoke-Checked moon run cmd/minivcd -- value examples/demo.vcd top.counter 20
Invoke-Checked moon run cmd/minivcd -- export examples/demo.vcd $tempCsv

if (Test-Path -LiteralPath $tempCsv) {
  Get-Content -LiteralPath $tempCsv
  Remove-Item -LiteralPath $tempCsv
}
