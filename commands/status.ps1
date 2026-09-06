# Repository Health — what in the workspace needs attention?
# `dev status` keeps working and now opens the health screen.

ShowCommandScreen -Heading 'Repository Health' -Description @(
    'Reading local repository state.'
)

Invoke-RepositoryHealthFlow
