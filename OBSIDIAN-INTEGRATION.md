# Obsidian Integration Guide for AI Persistent Memory

This guide explains how to connect your central Obsidian Vault to your individual projects. This setup allows Claude Code to use Obsidian as a persistent memory layer, reading Architecture Decision Records (ADRs), bug logs, and domain context.

## 1. The Strategy: The Symlink Bridge
AI agents running in IDEs typically operate strictly within the boundary of the current workspace directory. To allow them to read your central Obsidian vault without giving them full system access, you must bridge the vault and the project using symbolic links (symlinks).

## 2. Setting Up the Master Vault
1. Create or designate your master Obsidian Vault (e.g., `~/Documents/Obsidian_Brain`).
2. Inside this vault, create a dedicated directory for your engineering projects: `~/Documents/Obsidian_Brain/Projects/`.
3. For every new codebase you create, make a corresponding subfolder here (e.g., `~/Documents/Obsidian_Brain/Projects/axiriam-shop`).

## 3. Creating the Connection (Per Project)
Whenever you initialize a new project (e.g., `/Users/orla/dev/axiriam-shop`), open your terminal in the project root and create a symlink pointing to its specific Obsidian folder.

```bash
# Navigate to your project root
cd /Users/orla/dev/axiriam-shop

# Create a docs directory if it doesn't exist
mkdir -p docs

# Create the symlink to your Obsidian vault
ln -s ~/Documents/Obsidian_Brain/Projects/axiriam-shop ./docs/brain
```

**Why this works:** The AI agent sees a local directory named `docs/brain/` and automatically indexes all the markdown files inside it. Simultaneously, you can read, write, and link these files beautifully using the Obsidian application.

## 4. Structuring Project Memory
Inside your project's folder in Obsidian, maintain the following standardized structure:

- `ADR/` (Architecture Decision Records): Document *why* you chose specific technologies or patterns. The AI will read this to avoid suggesting contrary solutions.
- `Bugs/`: Log difficult bugs, the root causes, and how you resolved them.
- `Index.md`: The central hub file linking to the other notes.

## 5. AI Interaction
Because of the symlink, the AI reads the vault as local files. No skill is needed.

**Example Prompts:**
- *"Check the ADR notes in `docs/brain/` to understand our database schema before writing the new API."*
- *"Document the architecture decision we just made into a new note in `docs/brain/ADR/`."*

## 6. Git Configuration
You likely do not want to commit your personal Obsidian notes to the public or team repository. Ensure you add the symlinked directory to your project's `.gitignore`:

```text
# Obsidian Persistent Memory
docs/brain/
```
