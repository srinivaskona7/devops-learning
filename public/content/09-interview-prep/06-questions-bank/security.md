# Security Q&A Bank

These questions are the ones I've actually been asked / would ask. Security questions separate seniors from juniors — interviewers want defense-in-depth thinking, not checklist recitation. Always state the threat model before the control.

## How to use

Say each answer out loud, 60-second ceiling. For every control, be ready to answer "what does this NOT protect against?". Security is about layered failure, not silver bullets.

---

## RBAC & Identity

**Q1. Walk me through how a kubectl request is authenticated and authorized.**
TLS handshake with client cert (or bearer token for OIDC/SA). API server tries each authenticator in order until one succeeds, producing a user identity. Authorization runs each authorizer (RBAC, Node, Webhook); first to allow wins. Then admission controllers (mutating, validating). Then persisted to etcd.

**Q2. ClusterRole vs Role?**
Role: namespaced permissions. ClusterRole: cluster-scoped (or for non-namespaced resources like nodes, PVs). A ClusterRole can be bound by a RoleBinding to scope its perms to a single namespace — common pattern for "view" access to one namespace.

**Q3. Aggregate ClusterRoles?**
A ClusterRole with `aggregationRule` selects other ClusterRoles by label and unions their rules. Used by built-in `view`, `edit`, `admin` so operators can extend them by adding labeled ClusterRoles.

**Q4. What's the principle of least privilege in RBAC?**
Grant only the verbs and resources actually needed. No `*` on `*`. Prefer Role over ClusterRole. Tie ServiceAccounts to specific workloads, not shared. Audit with `kubectl auth can-i --list` per SA.

**Q5. Why is `cluster-admin` dangerous in prod?**
Full cluster compromise via one stolen credential. Can read all secrets, exec into any pod, modify any resource. Limit to break-glass accounts with hardware MFA + audit logging.

**Q6. How does IRSA (IAM Roles for Service Accounts) work?**
ServiceAccount annotated with IAM role ARN. AWS-injected webhook adds projected token volume + AWS env vars to pods. AWS SDK exchanges the projected JWT for IAM creds via STS AssumeRoleWithWebIdentity. OIDC trust between EKS and IAM.

**Q7. Workload Identity (GKE/AKS) similar concept?**
Yes — GCP Workload Identity binds K8s SA to GCP SA via OIDC; AKS Workload Identity uses Azure AD federated credentials. All achieve "no static cloud creds in pods".

**Q8. What's the SA token rotation story in modern K8s?**
Bound ServiceAccount tokens (BoundSA, projected volumes) — short-lived (default 1h), audience-scoped, auto-rotated by kubelet. Replaces legacy long-lived tokens stored as Secrets.

---

## Pod Security

**Q9. What is Pod Security Admission?**
Built-in admission controller (replaced PodSecurityPolicy in 1.25). Enforces three profiles per namespace via labels: privileged (no restriction), baseline (prevent obvious escapes), restricted (best practice). Modes: enforce, warn, audit.

**Q10. What does the Restricted profile prevent?**
HostNetwork/PID/IPC, privileged containers, hostPath volumes, allowPrivilegeEscalation, runAsRoot, dangerous capabilities, unsafe sysctls, /proc unmasking. Requires runAsNonRoot, seccomp RuntimeDefault.

**Q11. What's a securityContext you'd set on every pod?**
runAsNonRoot: true, runAsUser: 65534 (or specific non-zero), readOnlyRootFilesystem: true, allowPrivilegeEscalation: false, capabilities.drop: ["ALL"], seccompProfile.type: RuntimeDefault.

**Q12. Why drop ALL capabilities?**
Default container has ~14 caps; many enable network attacks (NET_RAW for ARP spoofing) or info disclosure. Add back only what's strictly needed (e.g., NET_BIND_SERVICE for ports <1024).

**Q13. What does `readOnlyRootFilesystem` break?**
Apps writing to /tmp, /var/log, package caches. Solution: mount emptyDir volumes at writable paths. Forces explicit declaration of mutable state.

**Q14. seccomp — what is it?**
Kernel feature filtering syscalls a process can make. RuntimeDefault profile blocks ~50 dangerous syscalls (e.g., mount, reboot, ptrace). Custom profiles narrow further. Major defense against kernel exploits.

**Q15. AppArmor/SELinux on K8s?**
AppArmor/SELinux profiles labeled per pod (annotations or securityContext.appArmorProfile). MAC layer beyond DAC perms. Adoption is operationally costly — many shops rely on PSA + seccomp instead.

**Q16. What is gVisor / Kata?**
Sandboxed runtimes. gVisor: userspace kernel intercepts syscalls (slower, strong isolation). Kata: lightweight VM per pod (true hardware isolation). Use for untrusted multi-tenant workloads.

---

## Network Security

**Q17. Default K8s network posture?**
All pods can reach all pods. Wide open. NetworkPolicy is opt-in. Without policies, a compromised pod can scan/attack the entire cluster.

**Q18. NetworkPolicy default-deny pattern.**
Per namespace, apply a NetworkPolicy selecting all pods with empty ingress + egress rules. Then layer specific allow rules on top. Forces explicit communication graph.

**Q19. What does a NetworkPolicy NOT do?**
Doesn't apply to host network pods. Doesn't filter by L7 (HTTP path/method) — that needs a service mesh or L7 policy (Cilium). Doesn't intercept egress to outside cluster unless CNI enforces egress.

**Q20. mTLS — what threats does it address?**
Encrypts pod-to-pod traffic (defeat passive sniff). Authenticates both ends (defeat MITM, identity spoofing). Service mesh (Istio/Linkerd) automates with cert rotation. Doesn't authorize — that's policy on top.

**Q21. Egress controls — why important?**
Limits blast radius of compromised pod (no exfil to attacker C2). Enforce via NetworkPolicy egress, egress gateway, or external firewall with namespace-aware proxy. Allowlist external endpoints.

**Q22. What is service mesh authz?**
Istio AuthorizationPolicy / Linkerd Server+ServerAuthorization — L7 ACLs based on workload identity (SPIFFE), method, path. Layered on top of mTLS to enforce who-can-call-what.

---

## Supply Chain

**Q23. What is SLSA?**
Supply-chain Levels for Software Artifacts — framework for build integrity. Levels 1–4 increasing rigor: build provenance, hermetic builds, isolated build envs, two-party review. Defends against tampering between source and runtime.

**Q24. What is an SBOM and why does it matter?**
Software Bill of Materials — list of all components in an artifact. Required for vulnerability response (when log4shell drops, you need to know who has it). Generated by syft, anchore, docker scout. Shipped alongside images.

**Q25. How do you verify image signatures?**
cosign signs images with keys (KMS) or keyless (Fulcio + OIDC). Verify in cluster via admission policy (Connaisseur, Kyverno, Sigstore policy controller). Block unsigned/untrusted images.

**Q26. What is an admission policy you'd write?**
"Reject pods using `:latest` or unsigned images from non-allowlisted registries." Implemented via Kyverno or OPA Gatekeeper. Standard supply-chain control.

**Q27. CVE scanning — when and where?**
Build time (fail PR on HIGH/CRITICAL): Trivy/Grype in CI. Registry scanning: nightly re-scan for new CVEs in stored images. Runtime: Falco, kube-bench. Layered — every stage catches different things.

**Q28. Base image strategy?**
Pin to digest, not tag. Prefer distroless or minimal (alpine, ubi-minimal). Rebuild weekly to absorb base updates. Maintain a small set of "golden" base images org-wide.

**Q29. What is dependency confusion?**
Attacker publishes a package with the same name as your private internal package on a public registry. Your build pulls the malicious public version (higher version number wins). Mitigate: scoped namespaces, lockfiles, internal proxy.

---

## Secrets Management

**Q30. Why are K8s Secrets not really secret?**
Base64 encoding ≠ encryption. Anyone with `get secret` RBAC sees plaintext. etcd stores them in plaintext unless encryption at rest is configured (KMS provider).

**Q31. How do you encrypt secrets at rest in etcd?**
Configure `EncryptionConfiguration` with a KMS provider (AWS KMS, GCP KMS, HashiVault). API server transparently encrypts on write, decrypts on read. Existing secrets need re-write to encrypt.

**Q32. Better than K8s Secrets?**
External Secrets Operator (ESO) — fetches from Vault/AWS Secrets Manager/GCP Secret Manager, materializes as K8s Secret. Versioning, audit, central rotation. Or CSI Secret Store Driver — mounts secrets directly without K8s Secret object.

**Q33. How do you rotate a database password used by 50 pods?**
Store in external secret manager (Vault/ASM), rotate at source. ESO syncs new value to K8s Secret. Trigger pod restart via Reloader (watches Secret hash), or app reads from a mounted file periodically.

**Q34. What's sealed-secrets?**
Bitnami project. Encrypts secrets with cluster-specific public key; ciphertext is committed to git. Controller in cluster decrypts to a real Secret. Solves "secrets in GitOps repos" problem.

---

## Compliance & Hardening

**Q35. What is CIS benchmark for Kubernetes?**
Center for Internet Security checklist of hardening recommendations (API server flags, kubelet config, RBAC defaults, etcd security). Run with kube-bench. Required for SOC2/PCI/FedRAMP.

**Q36. Audit logging — what should you capture?**
RequestResponse-level logs for: secrets access, RBAC changes, exec/portforward, namespace creation, privileged pod creation. Ship to SIEM. Critical for forensic timeline after breach.

**Q37. What is Falco?**
Runtime threat detection — eBPF taps syscalls and matches against rules ("shell spawned in container", "privilege escalation attempt"). Open-source CNCF project, raises alerts on suspicious behavior pods can't be policy-prevented from.

**Q38. Threat-model a typical microservice. What do you check?**
STRIDE: Spoofing (mTLS, SA identity), Tampering (admission policy on images, signed artifacts), Repudiation (audit logs), Info disclosure (encrypt in transit + at rest, secret hygiene), DoS (resource limits, rate limiting, HPA), Elevation (PSA restricted, drop caps, no host paths).

**Q39. What's defense in depth in K8s?**
Layered controls: network policy (L3/4) + service mesh authz (L7) + pod security (workload) + RBAC (API) + admission (policy as code) + image signing (supply chain) + audit + runtime detection. No single control should be sole barrier.

**Q40. How do you handle PII in logs?**
Don't log it. Strip at source (logger redaction filter), or at collector (OTel attribute processor regex masks). For data-residency needs, route logs by tenant region. Periodically scan logs for accidental PII (Macie, Presidio).

**Q41. What's an OWASP Top 10 you've seen exploited?**
Pick a real one: SSRF (server-side request forgery hitting cloud metadata 169.254.169.254 to steal creds — mitigate with IMDSv2). Or insecure deserialization. Don't recite the list — talk about a specific case with mitigation.

---

## Incident & Response

**Q42. A pod is compromised. Walk me through response.**
Isolate: NetworkPolicy deny-all on the pod's labels. Snapshot: capture process list, fs, memory if possible (debug pod, ephemeral container). Investigate: audit logs for what the SA accessed, container image SBOM for vuln. Eradicate: kill pod, rotate compromised credentials (SA tokens, IRSA roles, mounted secrets). Postmortem.

**Q43. Detected anomalous outbound traffic from a node — what next?**
Cordon node, drain workloads, take node offline. Investigate kubelet/audit logs, check for cryptominers (high CPU + outbound TLS to mining pools), check if any pod escaped. Reimage node — never trust a compromised host.

**Q44. What's the difference between vulnerability and exploit?**
Vulnerability: weakness (CVE-2024-X). Exploit: code/technique that uses it. Severity rating considers both exploitability and impact. Patch quickly when exploit is public + impact is high (e.g., log4shell).
