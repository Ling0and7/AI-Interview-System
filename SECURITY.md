# Security Policy

## Supported Usage

This project is local-first and may process resumes, OCR text, interview transcripts, and runtime credentials. Treat all local data and logs as potentially sensitive.

## Reporting A Vulnerability

Do not open a public issue for undisclosed security problems.

Report vulnerabilities privately to the project maintainer through a non-public channel and include:

- affected component
- impact
- reproduction steps
- proof of concept if available
- any suggested mitigation

If you do not have a private reporting channel yet, create one before making the repository public.

## Sensitive Data In This Repository

The following should not be committed:

- local `.env` files
- API keys and tokens
- uploaded resume files
- OCR preview assets
- local SQLite databases
- packaging output
- runtime logs

Documented configuration keys belong in `backend/.env.example`, not in real secret files.

## Operational Guidance

- Rotate keys immediately if a secret is ever committed.
- Remove exposed secrets from Git history before publishing the repository.
- Sanitize screenshots, logs, and database dumps before sharing them.
- Review desktop packaging output to ensure no local secrets are bundled.

## Pre-Open-Source Checklist

Before making the repository public, verify:

- `.gitignore` covers local data, uploads, logs, and build output
- no real credentials remain in source, history, or packaging scripts
- example config files contain placeholders only
- sample documents do not contain personal data
- release artifacts are not tracked
