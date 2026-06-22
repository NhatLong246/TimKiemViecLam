# Underfilled Disbursement Refund Design

## Goal

When a part-time job fills fewer slots than requested, pay each participating
candidate only their calculated earnings and return the unused held budget to
the employer.

## Rules

- The held job budget is the available settlement fund, not the amount to
  distribute among candidates.
- `candidateAmounts` preserves each candidate's calculated salary; it must not
  be proportionally scaled to consume the full held budget.
- `totalEarned` is the sum of positive `candidateAmounts`.
- `excessRefund` is `availableAmount - totalEarned`, never below zero.
- A request is rejected if the available settlement amount is lower than the
  calculated total earnings.
- Direct disbursement closes the job using the gross sum of candidate earnings,
  so the existing wallet settlement returns `heldAmount - grossPayment`.
- Complaint deductions remain a separate employer refund. The job closes using
  gross earnings to avoid refunding a deduction twice.

## Required Regression

Given a held budget of 3,000,000 VND and one candidate whose calculated salary
is 1,000,000 VND:

- candidate payment: 1,000,000 VND;
- employer refund: 2,000,000 VND;
- employer actual spending: 1,000,000 VND.

## Scope

This change covers the mobile manual disbursement flow and shared wallet close
calculation. Automatic scheduled requests, complaint policy, and broader
transaction/idempotency redesign are outside this focused bug fix.
