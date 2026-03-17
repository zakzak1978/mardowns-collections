# GitHub Copilot Chat Keywords Reference

This document lists the common keywords for GitHub Copilot Chat in Visual Studio Code (VS Code) and other supported IDEs. Use these keywords—chat participants (`@`), chat variables (`#`), and slash commands (`/`)—to provide context and streamline interactions with Copilot.

## Chat Participants (`@`)
Chat participants scope your prompt to specific contexts or tools. Type `@` in the chat prompt box to see available participants.

| Participant       | Description                                                                 | Example Usage                                                                 |
|-------------------|-----------------------------------------------------------------------------|-------------------------------------------------------------------------------|
| `@workspace`      | References your entire open project or workspace.                            | `@workspace Where is the `calculateTotal` function defined in my project?`    |
| `@terminal`       | Specializes in command-line questions and terminal tasks.                    | `@terminal Find the largest file in the src directory.`                       |
| `@github`         | (Enterprise only, VS 2022 v17.11+) Includes repository and web search context. | `@github Summarize the changes in my repository’s latest pull request.`       |
| `@vscode`         | Focuses on VS Code-specific features, APIs, and configurations.              | `@vscode How do I configure keybindings for Copilot in VS Code?`              |
| Custom Extensions | Varies by installed GitHub Copilot Extensions (e.g., `@npm`, `@docker`).     | `@npm How do I install Express in my project?`                                |

## Chat Variables (`#`)
Chat variables specify files, code selections, or other contextual elements. Type `#` in the chat prompt box to see options or use a file selector for `#file`.

| Variable                | Description                                                       | Example Usage                                                         |
|-------------------------|-------------------------------------------------------------------|-----------------------------------------------------------------------|
| `#file:<path>`          | References a specific file in your workspace.                      | `Explain the code in #file:src/index.js.`                             |
| `#selection`            | References the currently highlighted code in the active editor.    | `Refactor #selection to use arrow functions.`                         |
| `#editor`               | References the visible code in the active editor.                  | `What does the code in #editor do?`                                   |
| `#codebase`             | Includes the entire project codebase for context.                  | `Does my #codebase use any deprecated APIs?`                          |
| `#git`                  | References Git-related data (e.g., commit history).                | `Summarize the changes in #git for my last commit.`                   |
| `#solution`             | (Visual Studio) References the active solution file.               | `@workspace Analyze the dependencies in #solution.`                   |
| `#prompt:<name>`        | References a custom prompt file from `.github/prompts/`.           | `Use #prompt:code-style to format #file:src/app.ts`                   |
| `#terminalLastCommand`  | References the last command executed in the terminal.              | `@terminal Explain #terminalLastCommand.`                             |

## Slash Commands (`/`)
Slash commands are shortcuts for common development tasks. Type `/` in the chat prompt box to see available commands.

| Command                  | Description                                                       | Example Usage                                                        |
|--------------------------|-------------------------------------------------------------------|----------------------------------------------------------------------|
| `/explain`               | Explains the selected code or active file.                         | `/explain #file:src/utils.js`                                        |
| `/fix`                   | Suggests fixes for errors in the active file or selected code.     | `/fix #selection`                                                    |
| `/tests`                 | Generates unit tests for the active file or selected code.         | `/tests #file:src/calculator.js`                                     |
| `/docs`                  | Generates documentation for the active file or selected code.      | `/docs #file:src/api.js`                                             |
| `/newNotebook`           | Creates a new Jupyter notebook with specified functionality.       | `/newNotebook Create a notebook to analyze the Titanic dataset.`      |
| `/help`                  | Lists available slash commands and their descriptions.             | `/help`                                                              |
| `/new`                   | Creates a new file with specified content.                         | `/new Create a React component in #file:src/MyComponent.js`          |
| `/optimize`              | Suggests performance improvements for code.                        | `/optimize #file:src/performance.js`                                 |
| `/commit`                | Generates a commit message for staged changes.                     | `/commit`                                                            |

## Notes
- **Availability**: Some features (e.g., `@github`) require Copilot Enterprise or specific IDE versions (e.g., Visual Studio 2022 v17.11+).
- **Context**: Combine keywords with specific prompts for better results (e.g., `/explain #file:src/index.js`).
- **Interactive Responses**: Responses may include buttons to copy, insert, or preview code, and a “Used n references” dropdown to show context sources.
- **Custom Prompts**: Create reusable prompt files in `.github/prompts/*.prompt.md` and reference them with `#prompt:<name>`.

## Tips
- Use the file selector when typing `#file` to choose files easily.
- Check the “Used n references” dropdown to verify which files Copilot used.
- Experiment with combining keywords (e.g., `@workspace #file:src/index.js`) for precise context.
- Refer to the [GitHub Copilot documentation](https://docs.github.com/en/copilot) or [GitHub Blog](https://github.blog) for more details.