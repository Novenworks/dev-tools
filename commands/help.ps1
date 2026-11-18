ShowScreenTitle -Title 'DevRepo by Novenworks'
ShowInfo (Get-ProductSubtitle)
ShowInfo 'Run devrepo to open Home or use a command below. The legacy dev launcher still works.'

ShowSection -Label 'Get started'
ShowInfo 'devrepo configure       Choose a workspace folder, GitHub accounts and an editor'
ShowInfo 'devrepo doctor          Check your setup and find GitHub sign-in options'
ShowInfo 'devrepo open [name]     Find a project and launch your editor'
ShowInfo 'devrepo recent          Open a project you used recently'
ShowInfo 'devrepo info [name]     See project details'

ShowSection -Label 'Manage projects'
ShowInfo 'devrepo status          Check local project health'
ShowInfo 'devrepo clone           Review and download missing GitHub projects'
ShowInfo 'devrepo sync            Approve an update of clean Git projects (alias: update)'
ShowInfo 'devrepo repos           Review issues and choose safe fixes'
ShowInfo 'devrepo backup          Review, commit and push changes after approval'

ShowSection -Label 'More actions'
ShowInfo 'devrepo menu            Open all workspace actions'
ShowInfo 'devrepo quick           Open frequently used actions'
ShowInfo 'devrepo settings        Edit workspace and editor preferences'
ShowInfo 'devrepo deploy          Audit, plan, verify and manage Vercel projects'
ShowInfo 'devrepo self            Manage your DevRepo installation'
ShowInfo 'devrepo test            Run automated validation'
ShowInfo 'Use arrows and Enter on supported menus, or type a shortcut. Esc or Back returns.'

ShowSection -Label 'Command reference'
ShowInfo "$(Get-DevToolsRepositoryUrl)/blob/main/docs/commands.md"
