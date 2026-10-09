# Study guide: payment gateway

Work through this before making the repository public. Read the contract first, then the tests, then the threat model.

## 1. Trace one payment

Use the 100 mUSDC test invoice and a 2.5% fee. Write down the token balance and the three liabilities (`totalPending`, `totalMerchantCredit`, `accruedFees`) after each action:

1. Merchant creates the invoice.
2. Payer pays it.
3. Merchant settles it.
4. Merchant withdraws 47.5 mUSDC.
5. Fee recipient withdraws 2.5 mUSDC.

Check your numbers against `testSettleSplitsFeeAndMerchantCredit`.

## 2. Explain the trust model

Answer in your own words: who decides whether a payment is refunded, and can a payer force a refund after paying? Why does the contract not qualify as an escrow?

## 3. Find the safety boundaries

Explain why `payInvoice` checks the token balance change. Find each external token call and identify the state updates immediately before it. Explain why invoice IDs are scoped by merchant.

## 4. Make a change yourself

Add an `Expired` or `Cancelled` state for an unpaid invoice, with a merchant-only cancel function and a test that proves it cannot be paid afterward. Run the CI and review the diff.

## 5. Readiness check

Before publishing, explain the state diagram, accounting identity, fee rounding, exact-token assumption, and the merchant's refund power without reading the source. Do not describe this as a security audit or production payment processor.
