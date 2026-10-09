# Threat model

## Assets and roles

- **Payer:** owns tokens until paying; wants an invoice paid exactly once and possibly refunded.
- **Merchant:** creates invoices, decides whether a paid invoice is settled or refunded, and withdraws settled credit.
- **Fee recipient:** withdraws accrued protocol fees.
- **Token issuer:** controls the ERC-20 contract and may have freeze, pause, or upgrade powers outside this system.

## Trust assumptions

The payer trusts the merchant to handle refunds fairly. This is not trustless escrow. Users must verify the merchant address, token address, amount, and deadline before paying. The implementation assumes exact ERC-20 transfers and stable balance accounting.

## Main risks and controls

| Risk | Control or residual risk |
| --- | --- |
| Duplicate payment | Invoice state changes from Open before transfer; further payments revert. |
| Cross-merchant invoice collision | IDs are scoped by merchant address. |
| Reentrant token callback | Transfer-bearing functions use `nonReentrant` and update state before external calls. |
| Fee-on-transfer token | Payment checks the exact received amount and reverts on mismatch. |
| Merchant takes funds without refund | By design, a merchant may settle immediately; payer has no on-chain refund right. |
| Token freeze, pause, or blacklist | Residual risk controlled by token issuer. Withdrawals/refunds may fail. |
| Direct token donations | Not credited to any party; no recovery function. |
| Transaction ordering | Payer should verify invoice details before calling; an invoice cannot be edited after creation. |

## Out of scope

No independent security audit, production deployment, cross-chain replay protection, off-chain invoicing, tax/compliance logic, arbitration, or stablecoin issuer risk management.
