ShowCommandScreen -Heading 'Check my setup' -Description @(
    'See which tools are ready and what to do next.'
    'Any installation or GitHub sign-in requires approval.'
)

Show-DoctorCheckResults
$checksWithFixes = @(Get-DevToolsHealthChecks | Where-Object { -not $_.Passed -and $_.CanFixInteractively })
if ($checksWithFixes.Count -gt 0) {
    ShowSection -Label 'Optional next step'
    $choices = @(
        [pscustomobject]@{ Key = '0'; Label = 'Back' }
        [pscustomobject]@{ Key = '1'; Label = 'Review installation and GitHub sign-in options' }
    )
    if ((Read-DevRepoMenuChoice -Options $choices -BackKey '0') -eq '1') {
        Show-DoctorCheckResults -Interactive
    }
}
