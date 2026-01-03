# Contributing Guidelines

Thank you for your interest in contributing to **LiquidMonitor**. To maintain code quality and ensure the stability of this project, please adhere to the following guidelines strictly.

## 🌿 Branching Strategy

We follow a strict branching model. Never push directly to `main`.

* **`main`**: Contains the latest development code. Unstable.
* **Feature Branches**: Use for new features.
  * Format: `feature/your-feature-name`
* **Bug Fix Branches**: Use for bug fixes.
  * Format: `fix/bug-description`
* **Docs Branches**: Use for documentation updates.
  * Format: `docs/update-description`

## 💬 Commit Convention

We follow the **Conventional Commits** specification. Your commit messages must be structured as follows:

```text
<type>(<scope>): <subject>

[Optional body]

[Optional footer(s)]
```

### Types

* **`feat`**: A new feature
* **`fix`**: A bug fix
* **`docs`**: Documentation only changes
* **`style`**: Changes that do not affect the meaning of the code (white-space, formatting, etc)
* **`refactor`**: A code change that neither fixes a bug nor adds a feature
* **`perf`**: A code change that improves performance
* **`test`**: Adding missing tests or correcting existing tests
* **`chore`**: Changes to the build process or auxiliary tools and libraries

### Example

```text
feat(monitor): add support for GPU usage tracking

Implement a new sensor reading for M3 GPU usage using Metal metrics.
Includes unit tests for data parsing.
```

## 🔁 Pull Request Process

1. **Sync First**: Ensure your branch is up to date with `main` before opening a PR.
2. **Atomic PRs**: One feature or fix per PR. Do not bunch multiple unrelated changes together.
3. **Description**:
    * Clearly describe the **What** and the **Why**.
    * Link to any relevant issues or discussions.
    * If UI changes are involved, include **screenshots** or recordings.
4. **Self-Review**: Review your own code before requesting a review. Remove debug prints and commented-out code.
5. **Build**: Ensure the project builds successfully on macOS 14+ (Xcode 15+).

## 🧪 Code Quality

* **SwiftLint**: Ensure no linting errors are introduced.
* **Force Unwrapping**: Avoid `!` force unwrapping unless absolutely necessary and justified.
* **Comments**: Document complex logic, but aim for self-documenting code.

---
**Note:** PRs that do not follow these guidelines will be closed without review.
