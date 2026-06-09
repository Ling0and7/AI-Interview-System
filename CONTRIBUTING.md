# Contributing

This project combines a Vue frontend, a Flask backend, and an Electron desktop shell in one repository.

## Before You Start

- Read [README.md](README.md) for local setup and runtime configuration.
- Do not commit secrets, local `.env` files, uploaded resumes, local databases, or build artifacts.
- Prefer small, focused pull requests over large mixed changes.

## Development Workflow

1. Install backend dependencies in `backend/`.
2. Install frontend dependencies in `frontend/`.
3. Install desktop dependencies in `desktop/` only if you are working on the Electron shell or packaging flow.
4. Run the backend first, then run the frontend.
5. If you touch desktop packaging, verify the desktop build path separately.

## Pull Request Scope

- Keep code changes and refactors separate when possible.
- Include a short summary of user-visible impact.
- Call out config changes, data migrations, or platform-specific behavior.
- If a feature depends on external services, document the fallback behavior when those services are unavailable.

## Validation

Before opening a pull request, run the checks relevant to your change:

- `frontend`: `npm run build`
- `backend`: targeted tests for the files you changed
- `desktop`: the packaging or smoke checks affected by your change

If you could not run a check, say so explicitly in the pull request description.

## Secrets And Local Data

Never commit:

- `backend/.env` or any other local secret file
- uploaded resumes or preview images
- local SQLite databases
- desktop packaging output
- runtime logs

Use `backend/.env.example` for documented configuration keys.

## Issue Reports

When reporting a bug, include:

- operating system
- whether you ran Web mode or Desktop mode
- exact page or route
- reproduction steps
- relevant logs with secrets removed

## Documentation

Update documentation when you change:

- setup steps
- runtime configuration
- packaging flow
- API behavior
- storage location or security expectations
