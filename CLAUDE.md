# AI Agent Governance Policy

This file defines security rules for any AI coding agent working on this repository.
All rules are mandatory. The pipeline enforces compliance on every PR.

## Secrets and Credentials
- NEVER hardcode API keys, passwords, tokens, or secrets in any file
- ALL credentials must be loaded from environment variables
- NEVER fall back to a hardcoded default if an env var is missing — fail loudly
- The .env file must never be committed to git

## Authentication
- NEVER disable, comment out, or bypass authentication middleware
- NEVER add TODO comments deferring auth to later — implement it before merge
- ALL routes handling user data or PHI must require authentication
- JWT secrets must come from environment variables only — no hardcoded fallbacks

## Input Validation
- ALL user input must be validated before use
- NEVER concatenate user input directly into LLM prompts — use roles array
- NEVER pass LLM output to eval() or exec()
- Validate on the server — never trust client-side validation

## Rate Limiting
- ALL LLM endpoints must have rate limiting before merge
- Use express-rate-limit — no exceptions for "we'll add it later"

## Dependencies
- ALL dependencies must be pinned to exact versions
- No ^ or ~ prefixes in package.json
- No :latest tags in Docker images

## Error Handling
- NEVER return stack traces or internal error details in API responses
- Return generic error messages to clients
- Log full details internally with a correlation ID

## LLM Security (OWASP LLM Top 10)
- LLM01: Separate system instructions from user input using roles array
- LLM02: Treat all LLM output as untrusted — validate before use
- LLM04: Rate limit all LLM endpoints
- LLM05: Pin all dependencies — supply chain risk
- LLM06: Never expose secrets or PHI in responses
- LLM08: No excessive agency — auth required on all admin routes