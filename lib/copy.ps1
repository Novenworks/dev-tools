function Get-ProductMission {
    return 'Help developers spend less time managing projects and more time building.'
}

function Get-OverallStatusLabel {
    param(
        [Parameter(Mandatory = $true)]
        [int]$NeedsAttention
    )

    if ($NeedsAttention -eq 0) {
        return 'Ready to Build'
    }

    if ($NeedsAttention -eq 1) {
        return 'Almost Ready'
    }

    return 'Setup Recommended'
}

function Get-DoctorCheckCatalog {
    return @{
        git = @{
            WhyItMatters    = 'Git tracks changes to your projects.'
            InstalledAction = 'Everything looks good.'
            MissingAction   = 'Install Git to clone, update, and back up repositories.'
        }
        gh = @{
            WhyItMatters    = 'GitHub CLI connects DevTools to your GitHub account.'
            InstalledAction = 'Everything looks good.'
            MissingAction   = 'Install GitHub CLI to clone repositories from GitHub.'
        }
        'gh-auth' = @{
            WhyItMatters    = 'Signing in allows DevTools to clone and update your repositories.'
            InstalledAction = 'Everything looks good.'
            MissingAction   = 'Sign in to GitHub to clone and sync your repositories.'
        }
        workspace = @{
            WhyItMatters    = 'Your workspace is where DevTools stores and manages projects.'
            InstalledAction = 'Everything looks good.'
            MissingAction   = 'Choose a workspace folder in Configure.'
        }
        configuration = @{
            WhyItMatters    = 'Your settings tell DevTools where to work and what to sync.'
            InstalledAction = 'Everything looks good.'
            MissingAction   = 'Complete the setup wizard to finish configuration.'
        }
        editor = @{
            WhyItMatters    = 'Your default editor opens projects with one command.'
            InstalledAction = 'Everything looks good.'
            MissingAction   = 'Choose a default editor in Configure or Settings.'
        }
        node = @{
            WhyItMatters    = 'Node.js is required by many JavaScript projects.'
            InstalledAction = 'Everything looks good.'
            MissingAction   = 'Install Node.js LTS.'
        }
        npm = @{
            WhyItMatters    = 'npm is included with Node.js and installs JavaScript packages.'
            InstalledAction = 'Everything looks good.'
            MissingAction   = 'npm installs with Node.js LTS.'
        }
        cursor = @{
            WhyItMatters    = 'Cursor is a popular AI-powered code editor.'
            InstalledAction = 'Everything looks good.'
            MissingAction   = 'Install Cursor if you want to open projects there.'
        }
        'claude-desktop' = @{
            WhyItMatters    = 'Claude Desktop helps you work with Claude outside the browser.'
            InstalledAction = 'Everything looks good.'
            MissingAction   = 'Download: https://claude.ai/download'
        }
        'claude-code' = @{
            WhyItMatters    = 'Claude Code lets you use Claude from your terminal.'
            InstalledAction = 'Everything looks good.'
            MissingAction   = 'Install Claude Code if you plan to use AI-assisted development from the command line.'
        }
    }
}
