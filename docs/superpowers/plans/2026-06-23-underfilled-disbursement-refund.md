# Underfilled Disbursement Refund Implementation Plan

**Goal:** Preserve actual candidate wages and refund unused held budget.

**Architecture:** Add a pure calculator for candidate allocation and settlement
math, cover it with unit tests, then use it at the request and job-close
boundaries. Firestore schemas stay unchanged.

1. Add failing tests for one of three slots filled, multiple candidates, zero
   earnings, and insufficient available funds.
2. Implement `DisbursementCalculator` with allocation, gross payment, and refund
   helpers.
3. Replace proportional scaling in `JobDayEndFlowScreen` with the calculator.
4. Close direct and complaint disbursements using gross candidate earnings.
5. Use the refund helper when adjusting the employer wallet.
6. Format, run focused tests/analyze, and inspect the final diff.
