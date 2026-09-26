# ai-vibecode-lab - MediTriage

A self-contained AI patient-triage application that demonstrates the OWASP LLM Top 10 end to end: from a build-time security pipeline, through hardened infrastructure, to live runtime defences proven on AWS EKS.

It consumes the reusable pipeline from [SecureStack platform](https://github.com/baks7101/SecureStack-platform), the way a real product team consumes a central security platform, while owning its own code, infrastructure, and Kubernetes manifests.

> This app is intentionally insecure in specific, documented ways. The planted vulnerabilities are teaching cases, there to be caught by the pipeline and blocked by the runtime guard, not accidents.

## What it does

MediTriage is a Node.js / Express API. A caller submits a patient's name, age, and symptoms; the app asks OpenAI's gpt-3.5-turbo to classify urgency, with an llm-guard sidecar scanning prompts and responses. It runs as a 2-container pod (API + guard).

- POST /api/chat/triage takes {patientName, symptoms, age} and returns an urgency assessment.
- A prompt injection in the symptoms is blocked at the input scan with HTTP 400, before the model is ever called.
- The guard is fail-closed: if the scanner errors, the app rejects the request rather than calling the model unscanned.

## The deliberate vulnerabilities (OWASP LLM Top 10)

Planted on purpose as demonstration cases: prompt injection (user input flows into the model prompt), insecure output handling (model response acted upon), sensitive information disclosure (an endpoint exposing stored triage logs), and insecure secret handling (hardcoded fallback secrets, now remediated to fail-loudly patterns).

## What's proven

### Build time (via the SecureStack pipeline)
Every pull request is scanned by SecureStack's reusable 11-stage pipeline. Each stage was validated by deliberately planting the vulnerability it catches and watching it get caught: secrets, SAST (CodeQL + Semgrep), dependency/SCA, IaC (Checkov + custom OPA), container config, AI-agent governance, AI-BOM data-classification ceilings, SBOM, and DAST.

### Live on AWS EKS (deployed, proven, torn down)
- Kyverno admission control: a privileged pod is rejected by a custom policy (defense-in-depth with Pod Security Admission).
- SOAR: a GuardDuty finding triggers a Lambda that auto-disables compromised IAM keys, isolates EC2, and alerts via SNS (EventBridge-driven).
- Falco: runtime threat detection catches a shell spawned in a container at the syscall level (eBPF).
- AI-security: a live prompt injection returns HTTP 400 (blocked at input scan); a legitimate request returns a real triage.
- ArgoCD: GitOps with self-heal, manual cluster drift is automatically reverted to match git.
- DAST: OWASP ZAP scans the running app; missing security headers were found, fixed with Helmet, and re-verified. DAST also runs in the CI pipeline.
- SIEM centralisation: CloudTrail and GuardDuty ship into OpenSearch via event-driven Lambdas, searchable in one interface alongside application logs (single pane of glass), proven live in the OpenSearch Dashboards UI.
- Observability: Prometheus scrapes the app's security metrics (e.g. llm_guard_blocks_total) into Grafana.

## AI Bill of Materials (AI-BOM)

The app declares its AI components in ai-bom.json (the model, the AI library, the runtime scanner). SecureStack's pipeline validates this against a central approved-components list and fails the build on an unapproved model, or one used above its data-classification ceiling, defending against shadow AI. The approved list is conditional: the model is approved for health data only if a runtime scanner is declared in front of it, and this app declares exactly that.

## Infrastructure (this repo owns it)

- Terraform (modular: VPC, EKS, security, SOAR, SIEM) provisions a hardened EKS cluster with OpenSearch, GuardDuty, CloudTrail, KMS/CMK-encrypted secrets, and IRSA.
- Bootstrap stack (terraform/bootstrap/) holds the persistent GitHub OIDC role in its own state, so tearing down the ephemeral cluster never destroys the CI auth role: persistent identity separated from ephemeral workload.
- Remote state in an encrypted, versioned S3 bucket with a DynamoDB lock table, created out-of-band so it survives terraform destroy.
- Secrets flow keyless: AWS Secrets Manager to the External Secrets Operator (via a read-only IRSA role scoped to those secrets, with kms:Decrypt on the CMK) to Kubernetes. No secret touches git.
- Kubernetes hardening: non-root workloads, RBAC, network policies, IMDSv2 on nodes, KMS encryption at rest.

## How it uses the SecureStack platform

Its single workflow (.github/workflows/pr-check.yml) calls the reusable pipeline via workflow_call, declaring what it contains and passing its own OIDC role:

    uses: baks7101/SecureStack-platform/.github/workflows/full-security-scan.yml@main
    with:
      has-docker: true
      has-terraform: true
      has-kubernetes: true
      has-ai: true
      run-dast: true
      aws-role-arn: <this repo's own OIDC role>

## Repo layout

    src/                  the MediTriage API + llm-guard integration
    k8s/                  manifests (namespace, deployment, ESO, ServiceMonitor, Kyverno policy)
    terraform/            cluster infrastructure (modular: vpc, eks, security, soar, siem)
    terraform/bootstrap/  persistent OIDC identity (separate state)
    .zap/rules.tsv        DAST severity policy (high = fail, reviewed-low = ignore)
    .github/workflows/    calls the SecureStack reusable pipeline

## Honest notes

A lab, built to production patterns, not production experience in a company. Cost-sensitive infrastructure (EKS, OpenSearch, NAT) is provisioned per session and torn down, so live evidence is screenshots plus the ability to walk through each control. Triage logs are in-memory for demo simplicity; gpt-3.5-turbo is used for cost (the vulnerabilities are model-agnostic). Current known gaps: Falco alerts are not yet forwarded into the SIEM (Falcosidekick is the next step); Kustomize overlays and scheduled secret rotation are noted next steps.

## Related repository

[SecureStack platform](https://github.com/baks7101/SecureStack-platform) - the reusable security platform (pipeline, policies, governance, shared identity) that scans and defends this app.
