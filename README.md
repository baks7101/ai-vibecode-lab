# ai-vibecode-lab

A deliberately vulnerable AI-powered patient triage API — built to demonstrate 
how AI coding agents introduce OWASP LLM Top 10 vulnerabilities, and how a 
DevSecOps pipeline catches and blocks them before they hit production.

## The Story

A developer used an AI coding agent (Cursor) to build a patient triage API. 
It worked perfectly in local testing. When they raised a PR to merge to main, 
the SecureStack reusable security pipeline caught three OWASP LLM Top 10 
violations before a single line hit production.

The developer fixed all three. The pipeline went green. The PR merged.

That is shift-left AI security in practice.

---

## Architecture

```
ai-vibecode-lab (this repo)          securestack-platform (security team)
├── src/                             ├── .github/workflows/
│   ├── app.js                       │   └── ai-security-scan.yml
│   ├── routes/                      │       ├── Stage 1: Gitleaks
│   │   ├── chat.js                  │       ├── Stage 2: Semgrep AI rules
│   │   └── admin.js                 │       ├── Stage 3: Dependency pins
│   ├── services/                    │       ├── Stage 4: CLAUDE.md check
│   │   └── llm.js                   │       └── Stage 5: Cisco Skill Scanner
│   └── middleware/
│       └── auth.js
└── .github/workflows/
    └── pr-check.yml ──calls──────────────────────────────────────────────────►
```

The lab repo owns the application code.  
SecureStack owns the security pipeline.  
The lab calls SecureStack's reusable workflow on every PR.  
This mirrors how enterprise DevSecOps works — one security team, many product teams.

---

## The App

A Node.js Express API that accepts patient symptoms and returns a triage 
priority (emergency, urgent, routine) using OpenAI GPT-3.5-turbo.

**Endpoints:**
- `POST /api/chat/triage` — accepts `{ patientName, symptoms, age }`, returns LLM triage priority
- `GET /api/admin/logs` — returns all triage requests (protected)

---

## Vulnerabilities — Before Fixes

Three OWASP LLM Top 10 vulnerabilities deliberately embedded to simulate 
AI-generated code anti-patterns.

### LLM06 — Sensitive Information Disclosure
**File:** `src/middleware/auth.js`  
**Code:**
```javascript
const SECRET = process.env.JWT_SECRET || 'default_secret';
```
**Risk:** If JWT_SECRET is missing from the environment, the app falls back 
to a hardcoded string. An attacker who knows the default can forge valid JWT 
tokens without obtaining credentials.  
**Fix:** Remove the fallback — fail loudly if the secret is missing.

---

### LLM08 — Excessive Agency
**File:** `src/routes/admin.js`  
**Code:**
```javascript
// TODO: add auth later
router.get('/logs', (req, res) => {
  res.json({ logs: triageLogs });
});
```
**Risk:** The admin endpoint exposing patient triage records — PHI — is 
completely unauthenticated. Anyone can call GET /api/admin/logs and read 
all patient data.  
**Fix:** Add `requireAuth` middleware to the route before merge.

---

### LLM04 — Model Denial of Service
**File:** `src/routes/chat.js`  
**Code:**
```javascript
router.post('/triage', async (req, res) => {
  // no rate limiting
```
**Risk:** The LLM endpoint accepts unlimited requests. An attacker floods 
it — every request costs real OpenAI API money and compute. Model DoS.  
**Fix:** Add express-rate-limit middleware — 100 requests per 15 minutes.

---

## Pipeline Results

### Before fixes — PR blocked

| Stage | Tool | Result | Finding |
|-------|------|--------|---------|
| Stage 1 | Gitleaks | ✅ Pass | No secrets in tracked files |
| Stage 2 | Semgrep AI rules | ❌ Fail | 3 blocking findings (LLM04, LLM06, LLM08) |
| Stage 3 | Dependency pin check | ✅ Pass | All deps pinned |
| Stage 4 | CLAUDE.md check | ✅ Pass | Governance file present |
| Stage 5 | Cisco Skill Scanner | ✅ Pass | No agent skills found |

### After fixes — PR approved and merged

| Stage | Tool | Result |
|-------|------|--------|
| Stage 1 | Gitleaks | ✅ Pass |
| Stage 2 | Semgrep AI rules | ✅ Pass |
| Stage 3 | Dependency pin check | ✅ Pass |
| Stage 4 | CLAUDE.md check | ✅ Pass |
| Stage 5 | Cisco Skill Scanner | ✅ Pass |

---

## Security Controls Applied

| Vulnerability | OWASP LLM | Fix Applied | Control Type |
|--------------|-----------|-------------|--------------|
| JWT hardcoded fallback | LLM06 | Fail loudly if secret missing | Secrets governance |
| Unauthenticated admin route | LLM08 | requireAuth middleware | Access control |
| No rate limiting on LLM endpoint | LLM04 | express-rate-limit | DoS protection |

---

## IDE Security Tools

Two IDE-layer security tools were active in Cursor during development:

- **Arko** (DevSecAI) — architectural reasoning engine. Produced a 71/100 
  Hackability Score on the vulnerable code, flagging 8 findings including 
  prompt injection, unauthenticated PHI access, and missing rate limiting.
- **Aikido** — real-time SAST scanning as code is written.

The IDE tools flagged issues in real time. The developer raised the PR anyway. 
The pipeline enforced the gate — the PR could not merge until all findings 
were resolved. This demonstrates why both layers are needed: IDE tools advise, 
pipelines enforce.

---

## OWASP LLM Top 10 Mapping

| OWASP ID | Risk | Demonstrated |
|----------|------|--------------|
| LLM01 | Prompt Injection | Symptoms concatenated into system prompt (llm.js) |
| LLM04 | Model Denial of Service | No rate limiting on triage endpoint |
| LLM06 | Sensitive Information Disclosure | JWT hardcoded fallback |
| LLM08 | Excessive Agency | Unauthenticated admin endpoint exposing PHI |

---

## Frameworks

- OWASP LLM Top 10
- OWASP Agentic Top 10 (2026)
- MITRE ATLAS
- NIST AI RMF
- ISO 42001
- GDPR Article 22 (automated decision-making)
- NHS DSP Toolkit Standard 9 (PHI handling)

---

## Related Project

**SecureStack Platform** — github.com/baks7101/SecureStack-platform  
The enterprise DevSecOps platform that owns the reusable security pipeline 
consumed by this lab. 12 modules covering GitHub Actions CI/CD, Terraform, 
Kubernetes hardening, DAST, OPA, Secrets Manager, Prometheus monitoring, 
SOAR, and AI security (Module 13).

---

## Setup

```bash
git clone https://github.com/baks7101/ai-vibecode-lab.git
cd ai-vibecode-lab
npm install
cp .env.example .env
# Add your OPENAI_API_KEY and JWT_SECRET to .env
npm start
```

**Example triage request:**
```bash
curl -X POST http://localhost:3000/api/chat/triage \
  -H 'Content-Type: application/json' \
  -d '{"patientName":"Alex","symptoms":"chest pain and shortness of breath","age":52}'
```