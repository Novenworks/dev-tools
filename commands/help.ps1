ShowCommandScreen -Heading 'Welcome to DevTools' -Description @(
    'DevTools helps you manage your development workspace from one place.'
    'Built for developers who want a calm, menu-first way to work with GitHub projects on Windows.'
)

ShowSection -Label 'What is DevTools?'
ShowInfo 'A friendly workspace manager for cloning, updating, checking, backing up, and opening your projects.'

ShowSection -Label 'Who is it for?'
ShowInfo 'Anyone who wants to spend less time managing repositories and more time building.'

ShowSection -Label 'Typical workflow'
ShowInfo '1. Configure your workspace.'
ShowInfo '2. Run Doctor.'
ShowInfo '3. Clone repositories.'
ShowInfo '4. Open a project.'
ShowInfo '5. Build.'
ShowInfo '6. Backup your work.'
ShowInfo '7. Update repositories regularly.'

ShowSection -Label 'Quick Actions'
ShowInfo 'Quick Actions are for the tasks you run most often:'
ShowInfo 'Update repositories, open a project, view status, or clone missing repos.'
ShowInfo 'Run: dev quick'

ShowSection -Label 'Open Project search'
ShowInfo 'When opening a project, search by partial name.'
ShowInfo 'Example: search "walk" to find WalkReplay and similar folders.'
ShowInfo 'Press Enter without typing to list all projects.'

ShowSection -Label 'Quick Commands'
ShowInfo 'dev'
ShowInfo 'dev quick'
ShowInfo 'dev doctor'
ShowInfo 'dev status'
ShowInfo 'dev update'
ShowInfo 'dev clone'
ShowInfo 'dev open'

ShowSection -Label 'Need more help?'
ShowInfo 'Visit the GitHub repository for documentation and updates:'
ShowInfo (Get-DevToolsRepositoryUrl)
