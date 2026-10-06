\# git-it-done



\## Project Scope

This repository is the team's backup for Activity 1: Organization Creation for Application Development in GitHub. It documents the Git and GitHub workflow used by the team: repository setup, branching, pull requests, and merging.



\## Setup Instructions

1\. Install Git from git-scm.com (Windows).

2\. Set your identity:

&#x20;  - git config --global user.name "Your Name"

&#x20;  - git config --global user.email "your-github-email"

&#x20;  - git config --global init.defaultBranch main

3\. Clone this repository:

&#x20;  - git clone https://github.com/jessadondoyanolanguido8-bot/git-it-done.git

4\. Move into the folder:

&#x20;  - cd git-it-done



\## Contribution Guide

\- Never commit directly to main.

\- Branches:

&#x20; - main: production-ready, stable code

&#x20; - develop: integration branch for active development

&#x20; - feature/<feature-name>: short-lived branches for specific tasks

&#x20; - bugfix/<issue-name>: branches for fixing issues found by QA

\- Workflow:

&#x20; 1. Create a branch: git checkout -b feature/<feature-name>

&#x20; 2. Make changes, then: git add . and git commit -m "message"

&#x20; 3. Push the branch: git push -u origin feature/<feature-name>

&#x20; 4. Open a Pull Request on GitHub and wait for review and approval.

&#x20; 5. After the merge, update your local main: git checkout main, then git pull origin main

