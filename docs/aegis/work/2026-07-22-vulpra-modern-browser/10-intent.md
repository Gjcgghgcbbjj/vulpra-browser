# Vulpra Modern Browser Intent

- Requested outcome: implement all approved Phases 2A-2D and report only after continuous execution.
- Scope: browser client, native UI/animation, local product features, privacy/download/extensions surfaces, runtime and package GitHub workflows.
- Success evidence: portable contracts pass; source owners remain bounded; workflows are deterministic; Mac/device claims remain evidence-bound.
- Stop condition: source/portable scope complete, or a technical external blocker prevents required GitHub/device execution.
- Non-goals: inherited client copy, third-party UI/analytics, fake Phase 3 service features.
- BaselineReadSetHint: modern product design, runtime portable baseline, ADR-0002, efficiency policy.
- BaselineUsageDraft: all required refs acknowledged and cited; missing GitHub/macOS/device runtime evidence; decision continue.
- ImpactStatementDraft: replaces App root owner; adds tab and feature stores; adds GitHub distribution surface; preserves JIT/OpenIn/artifact contracts.
