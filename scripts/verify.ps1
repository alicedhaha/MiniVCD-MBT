$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$tempCsv = Join-Path $env:TEMP 'minivcd_verify.csv'

Set-Location -LiteralPath $projectRoot

moon fmt --check
moon check --target all --deny-warn
moon build --target all
moon test --target all --deny-warn
moon info
git diff --exit-code

moon run cmd/minivcd -- info examples/demo.vcd
moon run cmd/minivcd -- signals examples/demo.vcd
moon run cmd/minivcd -- changes examples/demo.vcd top.clk
moon run cmd/minivcd -- stats examples/demo.vcd top.clk
moon run cmd/minivcd -- value examples/demo.vcd top.counter 20
moon run cmd/minivcd -- export examples/demo.vcd $tempCsv

if (Test-Path -LiteralPath $tempCsv) {
  Get-Content -LiteralPath $tempCsv
  Remove-Item -LiteralPath $tempCsv
}
