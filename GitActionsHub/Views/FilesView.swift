```markdown
# GitActions Hub

An iOS app to manage GitHub Actions directly from your iPhone — no Mac, no signing certificate required.

## Features

- **Actions Monitoring** — View Workflow Runs live with auto-refresh every 30 seconds
- **Colorized Build Logs** — Every line numbered with automatic coloring for errors, warnings, and commands
- **Error Detection** — Auto-filter errors with copy button for each error and line number
- **File Management** — Add/delete/rename files
- **Import from Files** — Transfer files from the Files app
- **Commit & Push** — Push changes directly to GitHub via API
- **Liquid Glass UI** — Professional dark mode design with glass effects

## Requirements

- iOS 16.0+
- Xcode 15+
- GitHub Personal Access Token with: `repo`, `workflow`, `read:user`

## Build

### Via GitHub Actions (Recommended)

1. Fork the project on GitHub
2. Run the workflow from the Actions tab
3. Download the IPA from Artifacts
4. Install via TrollStore or AltStore

### Locally

```bash
git clone https://github.com/XFFF0/GitActionsHub
cd GitActionsHub
open GitActionsHub.xcodeproj
```

## Project Structure

```
GitActionsHub/
├── Models/
│   └── Models.swift
├── Services/
│   ├── GitHubService.swift
│   └── LocalFileManager.swift
├── DesignSystem/
│   └── DesignSystem.swift
├── Views/
│   ├── LoginView.swift
│   ├── ActionsView.swift
│   ├── ReposView.swift
│   └── FilesView.swift
└── ContentView.swift
```

## Icon Design

The icon represents a rocket inside a rounded square with a purple gradient, symbolizing fast deployment and build launching.

## Notes

- For personal use
- Token saved in UserDefaults
- Running Actions requires `workflow` permission
```
