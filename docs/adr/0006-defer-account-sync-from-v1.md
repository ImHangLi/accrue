# Defer account sync from v1

Accrue v1 ships as a local-first Mac menu bar app without sign-in or **Account Sync**. The data model should still separate synced configuration from local-only state so account sync can be added later without rewriting the accrual calculation or setup flow.
