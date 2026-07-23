# Sahara Club Spa as Spa & Wellness Blueprint

Sahara Club Spa remains the productive system for the business. This repository is a source of operational learning for NEXORA, not a ready NEXORA implementation and not a codebase to copy directly.

The value of Sahara is evidence: real spa workflows, appointment operations, ecommerce, Gift Cards, WhatsApp notifications, reception handoff, deposits, staff roles, and local business constraints. Future NEXORA work should extract patterns from this evidence and rebuild them through NEXORA foundations instead of transplanting Sahara-specific code or schema.

## Boundary

- Sahara-specific names, copy, prices, service catalog, branches, hardcoded settings, and customer-facing flows stay in Sahara.
- Productive behavior should be regularized first through migrations, tests, and documented domain ownership.
- NEXORA migration should be progressive: identify a stable capability, define the portable abstraction, migrate the implementation, then certify it with tests and security review.
- This blueprint does not introduce a new NEXORA architecture. It only classifies the current Sahara evidence.

## Current Baseline

The first reconstructed baseline covers the minimum transitive path needed for ecommerce and internal notifications:

payment/order confirmation -> order -> order item -> Gift Card -> reception alert -> admin notification delivery.

The baseline also includes the supporting objects needed to compile and validate that path locally: profiles, clients, services, staff, branches, bookings, sales, memberships, WhatsApp logs, WhatsApp business settings, AI settings, role helpers, timestamp helpers, RLS policies, grants, and realtime publication for reception alerts.

## Migration Principle

Sahara can teach NEXORA, but Sahara should not become NEXORA by copy-paste. Treat each domain as a reference sample:

1. Capture the productive behavior.
2. Classify what is universal, vertical-specific, or legacy.
3. Rebuild the portable part in NEXORA.
4. Keep Sahara-specific behavior behind configuration or adapters.
5. Certify the result with local reset, migration compatibility, security checks, and end-to-end workflow tests.
