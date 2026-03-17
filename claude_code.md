
# Claude Code Overview

Claude Code is Anthropic’s agentic coding tool that lives in your terminal and helps you turn ideas into code faster than ever before.

---

## Get Started in 30 Seconds

**Prerequisites:**
- A [Claude subscription](https://claude.com/pricing) (Pro, Max, Teams, or Enterprise) or [Claude Console](https://console.anthropic.com/) account

**Install Claude Code:**

**Native Install (Recommended):**

- **macOS, Linux, WSL:**
	```sh
	curl -fsSL https://claude.ai/install.sh | bash
	```
- **Windows PowerShell:**
	```powershell
	irm https://claude.ai/install.ps1 | iex
	```
- **Windows CMD:**
	```cmd
	curl -fsSL https://claude.ai/install.cmd -o install.cmd && install.cmd && del install.cmd
	```

Native installations automatically update in the background to keep you on the latest version.

**Start using Claude Code:**
```sh
cd your-project
claude
```
You’ll be prompted to log in on first use. That’s it!

See [advanced setup](https://code.claude.com/docs/en/setup) for more installation options, manual updates, or uninstallation. Visit [troubleshooting](https://code.claude.com/docs/en/troubleshooting) if you hit issues.

---

## What Claude Code Does for You

- **Build features from descriptions:** Tell Claude what you want to build in plain English. It will make a plan, write the code, and ensure it works.
- **Debug and fix issues:** Describe a bug or paste an error message. Claude Code will analyze your codebase, identify the problem, and implement a fix.
- **Navigate any codebase:** Ask anything about your team’s codebase, and get a thoughtful answer back. Claude Code maintains awareness of your entire project structure, can find up-to-date information from the web, and with [MCP](https://code.claude.com/docs/en/mcp) can pull from external data sources like Google Drive, Figma, and Slack.
- **Automate tedious tasks:** Fix lint issues, resolve merge conflicts, and write release notes. Do all this in a single command from your developer machines, or automatically in CI.

---

## Why Developers Love Claude Code

- **Works in your terminal:** Not another chat window. Not another IDE. Claude Code meets you where you already work, with the tools you already love.
- **Takes action:** Claude Code can directly edit files, run commands, and create commits. With [MCP](https://code.claude.com/docs/en/mcp), Claude can read your design docs in Google Drive, update your tickets in Jira, or use your custom developer tooling.
- **Unix philosophy:** Claude Code is composable and scriptable. For example:
	```sh
	tail -f app.log | claude -p "Slack me if you see any anomalies appear in this log stream"
	```
	Or in CI:
	```sh
	claude -p "If there are new text strings, translate them into French and raise a PR for @lang-fr-team to review"
	```
- **Enterprise-ready:** Use the Claude API, or host on AWS or GCP. Enterprise-grade [security](https://code.claude.com/docs/en/security), [privacy](https://code.claude.com/docs/en/data-usage), and [compliance](https://trust.anthropic.com/) is built-in.

---

## Next Steps

- [Quickstart: See Claude Code in action with practical examples](https://code.claude.com/docs/en/quickstart)
- [Common workflows: Step-by-step guides for common workflows](https://code.claude.com/docs/en/common-workflows)
- [Troubleshooting: Solutions for common issues with Claude Code](https://code.claude.com/docs/en/troubleshooting)
- [IDE setup: Add Claude Code to your IDE](https://code.claude.com/docs/en/vs-code)

---

## Additional Resources

- [About Claude Code](https://claude.com/product/claude-code)
- [Build with the Agent SDK](https://docs.claude.com/en/docs/agent-sdk/overview)
- [Host on AWS or GCP](https://code.claude.com/docs/en/third-party-integrations)
- [Settings](https://code.claude.com/docs/en/settings)
- [Commands: CLI reference](https://code.claude.com/docs/en/cli-reference)
- [Reference implementation](https://github.com/anthropics/claude-code/tree/main/.devcontainer)
- [Security](https://code.claude.com/docs/en/security)
- [Privacy and data usage](https://code.claude.com/docs/en/data-usage)

---

# Claude Code Overview

Claude Code is Anthropic’s agentic coding tool that lives in your terminal and helps you turn ideas into code faster than ever before.

---

## Get Started in 30 Seconds

**Prerequisites:**
- A [Claude subscription](https://claude.com/pricing) (Pro, Max, Teams, or Enterprise) or [Claude Console](https://console.anthropic.com/) account

**Install Claude Code:**

**Native Install (Recommended):**

- **macOS, Linux, WSL:**
	```sh
	curl -fsSL https://claude.ai/install.sh | bash
	```
- **Windows PowerShell:**
	```powershell
	irm https://claude.ai/install.ps1 | iex
	```
- **Windows CMD:**
	```cmd
	curl -fsSL https://claude.ai/install.cmd -o install.cmd && install.cmd && del install.cmd
	```

Native installations automatically update in the background to keep you on the latest version.

**Start using Claude Code:**
```sh
cd your-project
claude
```
You’ll be prompted to log in on first use. That’s it!

See [advanced setup](https://code.claude.com/docs/en/setup) for more installation options, manual updates, or uninstallation. Visit [troubleshooting](https://code.claude.com/docs/en/troubleshooting) if you hit issues.

---

## What Claude Code Does for You

- **Build features from descriptions:** Tell Claude what you want to build in plain English. It will make a plan, write the code, and ensure it works.
- **Debug and fix issues:** Describe a bug or paste an error message. Claude Code will analyze your codebase, identify the problem, and implement a fix.
- **Navigate any codebase:** Ask anything about your team’s codebase, and get a thoughtful answer back. Claude Code maintains awareness of your entire project structure, can find up-to-date information from the web, and with [MCP](https://code.claude.com/docs/en/mcp) can pull from external data sources like Google Drive, Figma, and Slack.
- **Automate tedious tasks:** Fix lint issues, resolve merge conflicts, and write release notes. Do all this in a single command from your developer machines, or automatically in CI.

---

## Why Developers Love Claude Code

- **Works in your terminal:** Not another chat window. Not another IDE. Claude Code meets you where you already work, with the tools you already love.
- **Takes action:** Claude Code can directly edit files, run commands, and create commits. With [MCP](https://code.claude.com/docs/en/mcp), Claude can read your design docs in Google Drive, update your tickets in Jira, or use your custom developer tooling.
- **Unix philosophy:** Claude Code is composable and scriptable. For example:
	```sh
	tail -f app.log | claude -p "Slack me if you see any anomalies appear in this log stream"
	```
	Or in CI:
	```sh
	claude -p "If there are new text strings, translate them into French and raise a PR for @lang-fr-team to review"
	```
- **Enterprise-ready:** Use the Claude API, or host on AWS or GCP. Enterprise-grade [security](https://code.claude.com/docs/en/security), [privacy](https://code.claude.com/docs/en/data-usage), and [compliance](https://trust.anthropic.com/) is built-in.

---

## Next Steps

- [Quickstart: See Claude Code in action with practical examples](https://code.claude.com/docs/en/quickstart)
- [Common workflows: Step-by-step guides for common workflows](https://code.claude.com/docs/en/common-workflows)
- [Troubleshooting: Solutions for common issues with Claude Code](https://code.claude.com/docs/en/troubleshooting)
- [IDE setup: Add Claude Code to your IDE](https://code.claude.com/docs/en/vs-code)

---

## Additional Resources

- [About Claude Code](https://claude.com/product/claude-code)
- [Build with the Agent SDK](https://docs.claude.com/en/docs/agent-sdk/overview)
- [Host on AWS or GCP](https://code.claude.com/docs/en/third-party-integrations)
- [Settings](https://code.claude.com/docs/en/settings)
- [Commands: CLI reference](https://code.claude.com/docs/en/cli-reference)
- [Reference implementation](https://github.com/anthropics/claude-code/tree/main/.devcontainer)
- [Security](https://code.claude.com/docs/en/security)
- [Privacy and data usage](https://code.claude.com/docs/en/data-usage)

---

# Adding Claude to VS Code

To use Claude in Visual Studio Code, follow these steps:

1. **Install a Claude extension:**
	- Open VS Code.
	- Go to the Extensions view (Ctrl+Shift+X).
	- Search for "Claude" or "Anthropic Claude".
	- Click "Install" on the desired extension (if available).

2. **Configure the extension:**
	- Follow the extension's instructions to set up your API key or account, if required.

3. **Use Claude in VS Code:**
	- Access Claude features from the command palette (Ctrl+Shift+P) or from the extension's sidebar.

> **Note:** If there is no official Claude extension, you may need to use Claude via a web interface or integrate it using custom scripts or APIs.


# Using Resume Feature

If you want to use Claude or VS Code to work with your resume (CV), you can:

1. **Create or edit your resume in Markdown:**
	- Example:
	  ```markdown
	  # John Doe
	  ## Experience
	  - Software Engineer at ExampleCorp (2020–2025)
	  - Intern at TechStart (2019–2020)
	  ## Education
	  - B.Sc. in Computer Science, University X
	  ```

2. **Summarize your resume using Claude (if supported):**
	- Select your resume text.
	- Use the Claude extension command palette and search for "Summarize" or "Resume".
	- Example output:
	  > John Doe is a software engineer with experience at ExampleCorp and TechStart, holding a B.Sc. in Computer Science.

3. **Export your resume to PDF:**
	- Use a Markdown extension like "Markdown PDF" in VS Code.
	- Command: `Markdown PDF: Export (pdf)` from the command palette.

> **Tip:** You can use Claude or other AI tools to review, improve, or summarize your resume directly in VS Code if the extension supports it.

# Using To-Do List Feature

You can manage a to-do list in VS Code or with Claude by creating a checklist in Markdown or using an extension:

## Example Markdown To-Do List
```markdown
- [ ] Write project documentation
- [x] Install Claude extension
- [ ] Summarize resume
- [ ] Export resume to PDF
```

## Using Extensions
- Search for "to-do list" or "task list" extensions in VS Code Extensions view (Ctrl+Shift+X).
- Some AI extensions (including Claude, if supported) can help you generate, manage, or check off tasks using commands like "Create To-Do List" or "Update Tasks".

> **Tip:** You can use Claude to generate or update your to-do list by selecting your tasks and running a relevant command from the command palette.


# Bash Mode in Claude

Bash mode in Claude allows you to interact with the AI as if you were working in a Unix shell. In this mode, you can:

- Ask Claude to generate bash commands or scripts for specific tasks (e.g., “find all .log files and delete them”).
- Request explanations for what a particular bash command or script does.
- Get step-by-step shell scripts for automation, file management, networking, and more.
- Paste a command or script and ask Claude to review it for safety or correctness.
- Convert natural language instructions into ready-to-use bash commands.

Bash mode is especially useful for learning shell scripting, automating repetitive tasks, or quickly generating commands without memorizing syntax. You simply describe your goal, and Claude provides the appropriate bash solution, explanation, or script.

## Example Interactions

- **Generate a command:**
	> How do I list all files larger than 100MB?
	```bash
	find . -type f -size +100M
	```

- **Explain a command:**
	> What does `tar -czvf backup.tar.gz myfolder/` do?
	> Creates a compressed archive (backup.tar.gz) of the myfolder directory using tar with gzip compression.

- **Review a script:**
	> Is this script safe to run?
	```bash
	rm -rf /tmp/testfolder
	```
	> (Claude will review and warn if there are risks.)

> **Tip:** Bash mode is available in Claude’s web interface, API, or any platform that supports Claude’s interactive shell features.


# Auto Accept Mode in Claude

Auto accept mode in Claude refers to a setting or feature where Claude automatically applies or accepts suggestions, commands, or actions without requiring manual confirmation for each step. This can streamline workflows, especially when generating or executing multiple commands or making repetitive changes.

## How It Works
- When auto accept mode is enabled, Claude will proceed with its recommended actions (such as code edits, command generation, or task completions) without prompting you to approve each one.
- This is useful for batch operations, automation, or when you trust Claude’s suggestions and want to save time.

## Example Usage

- **Without auto accept:**
	> Claude suggests a command or code change, and you must manually approve it before it is applied.

- **With auto accept enabled:**
	> Claude generates a series of commands or edits and applies them immediately, notifying you of the changes.

> **Caution:** Use auto accept mode only when you are confident in the AI’s recommendations, as actions will be performed automatically.


# Model Switching in Claude

Model switching in Claude allows you to choose between different AI models (such as Claude 2, Claude Instant, or other available versions) depending on your needs. Each model may have different strengths, response times, or capabilities.

## How It Works
- You can select the desired model before starting a session or conversation, or switch models during use if the platform supports it.
- Some interfaces provide a dropdown or settings menu to pick the model.
- Switching models can help you balance between speed, cost, and quality of responses.

## Example Usage

- **Choosing a model:**
	> Select "Claude 2" for more accurate and detailed answers, or "Claude Instant" for faster, lightweight responses.

- **Switching models mid-session:**
	> If your current model is too slow or not detailed enough, switch to another available model in the settings or conversation options.

> **Note:** The availability of model switching depends on the platform or service you are using with Claude.


# Handling Long Prompts in Claude

Claude is designed to handle long prompts and large context windows, making it suitable for processing lengthy documents, conversations, or code. Here’s how Claude manages long prompts:

- **Large Context Window:** Claude models (such as Claude 2 and later) support very large context windows, allowing them to process and remember long inputs—often tens of thousands of tokens (words and symbols).
- **Summarization and Compression:** If a prompt exceeds the model’s maximum context size, Claude may summarize or compress earlier parts of the conversation to retain the most relevant information.
- **Truncation:** When the input is too long, the oldest or least relevant parts may be truncated to fit within the model’s context limit.
- **Structured Input:** For best results, organize long prompts with clear sections, bullet points, or headings. This helps Claude understand and prioritize information.

## Tips for Using Long Prompts
- Break up very large tasks into smaller, focused prompts when possible.
- Use headings or numbered lists to clarify structure.
- If you need Claude to remember specific details, restate them or reference them in your follow-up prompts.

> **Note:** The exact context window size depends on the Claude model and platform, but it is typically much larger than most other AI models.


# Message Queues

Message queues are systems that enable asynchronous communication between different parts of an application or between different services. They are commonly used to decouple producers (senders) and consumers (receivers) of data, improving scalability and reliability.

## How Message Queues Work
- **Producer:** Sends messages to the queue.
- **Queue:** Stores messages until they are processed.
- **Consumer:** Retrieves and processes messages from the queue.

## Common Use Cases
- Task scheduling and background processing
- Decoupling microservices
- Load balancing and buffering
- Reliable delivery of messages

## Popular Message Queue Systems
- RabbitMQ
- Apache Kafka
- Amazon SQS
- Redis (as a lightweight queue)

## Example (Pseudocode)
```python
# Producer
queue.send('process this task')

# Consumer
task = queue.receive()
process(task)
```

> **Note:** While Claude itself does not implement message queues, you can use message queues to manage requests to and from Claude in larger systems or workflows.
