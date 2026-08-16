# ai-vibecode-lab

A deliberately vulnerable AI application — a patient-triage API that calls an LLM — built to demonstrate the **OWASP LLM Top 10** and to show what it looks like for a real product team to adopt a central security platform.

It is the showcase app that consumes the [SecureStack platform](https://github.com/baks7101/SecureStack-platform): every pull request is scanned by SecureStack's reusable 11-stage pipeline, and the app ships with a runtime AI firewall in front of the model.

> This app is intentionally insecure in specific, documented ways. The planted vulnerabilities are teaching cases, there to be caught by the pipeline and blocked by the runtime guard, not accidents.

---

## What it does

`MediTriage` is a small Node.js / Express API. A caller submits a patient's name, age, and symptoms; the app asks OpenAI's `gpt-3.5-turbo` to classify urgency (emergency / urgent / routine) with a rationale, and returns the result.

It's realistic enough to carry real AI-security lessons: user input flows into an LLM prompt, the response is acted on, and sensitive data passes through — exactly where AI apps get hurt.

---

## The deliberate vulnerabilities (OWASP LLM Top 10)

Planted on purpose as demonstration cases:

- **Prompt injection** — patient input is placed into the model prompt, so an attacker can smuggle instructions instead of symptoms.
- **Insecure output handling** — the model's response is trusted and acted upon.
- **Sensitive information disclosure** — an admin endpoint exposes stored triage logs (PHI), demonstrating data exposure.
- **Insecure JWT handling** — a hardcoded fallback signing secret (`process.env.JWT_SECRET || 'default_secret'`), which would let an attacker forge tokens if the environment variable were missing.

---

## The runtime defense: LLM-Guard

The app runs with an **AI firewall sidecar** (LLM-Guard) between it and the model:

- **Input scanning** — prompt injection and hidden-character detection.
- **Output scanning** — sensitive-data detection on the way back.
- **Fail-closed** — if the guard is unreachable, the app **rejects** the request rather than calling the model unscanned. For an app handling health data, refusing to serve beats serving unsafely.
- **Observability** — the guard exposes metrics (`llm_guard_blocks_total` and others) for Prometheus.

A blocked injection returns HTTP 400 and is logged for the SIEM.

---

## AI Bill of Materials (AI-BOM)

The app declares its AI components in `ai-bom.json` (the model, the AI library, and the runtime scanner protecting it). SecureStack's pipeline validates this against a central approved-components list and **fails the build** if the app uses an unapproved model or tool — defending against "shadow AI."

The approved list is conditional: the model is approved for health data *only if* a runtime scanner is deployed in front of it, and this app declares exactly that scanner, so policy and implementation line up.

---

## How it uses the SecureStack platform

This repo owns **no pipeline logic**. Its single workflow (`.github/workflows/pr-check.yml`) calls SecureStack's reusable pipeline via `workflow_call`, declaring what it contains:

```yaml
uses: baks7101/SecureStack-platform/.github/workflows/full-security-scan.yml@main
with:
  has-docker: true
  has-terraform: false   # no Terraform in this repo, it lives in the platform
  has-kubernetes: true
```

On every pull request, SecureStack scans this app for secrets, code flaws, vulnerable dependencies, container and Kubernetes misconfigurations, SBOM vulnerabilities, and AI-BOM violations — mirroring how, in a real company, one security team owns the pipeline and product teams consume it.

---

## Deployment

- **Containerized** (hardened multi-stage Dockerfile: minimal base, non-root user).
- **Kubernetes manifests** for deployment, config, secrets via the External Secrets Operator, a ServiceMonitor for Prometheus, and an ArgoCD application for GitOps delivery.
- Secrets are never committed — the local `.env` holds only a fake, correctly-formatted placeholder key and is gitignored.

---

## Honest notes

- A lab, built to production patterns, not production experience in a company.
- Triage logs are stored in memory for demo simplicity (no database persistence layer).
- `gpt-3.5-turbo` is used for cost; the vulnerabilities demonstrated are model-agnostic.
- The planted vulnerabilities are intentional teaching cases and are documented as such.

---

## Related repository

**[SecureStack platform](https://github.com/baks7101/SecureStack-platform)** — the reusable security platform (pipeline, infrastructure, detection engineering, governance) that scans and defends this app.
