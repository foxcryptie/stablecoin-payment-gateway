# Trace a payment

Open [`testSettleSplitsFeeAndMerchantCredit`](test/StablecoinPaymentGateway.t.sol) beside [`StablecoinPaymentGateway.sol`](src/StablecoinPaymentGateway.sol). The test uses 100 mUSDC and a 250-basis-point fee.

Before reading each assertion, work out these four values:

| Action | Gateway token balance | `totalPending` | `totalMerchantCredit` | `accruedFees` |
| --- | ---: | ---: | ---: | ---: |
| Create invoice | | | | |
| Payer pays | | | | |
| Merchant settles | | | | |
| Merchant withdraws | | | | |
| Fee recipient withdraws | | | | |

Now read `testAccountingAcrossSettleRefundAndWithdraw` and check where the same identity is asserted. A direct token donation can make the gateway balance *greater* than the liabilities, so the invariant is `balance >= pending + merchant credit + fees`.

The trust decision is in `settleInvoice` and `refundInvoice`: both are merchant actions. Try writing a test where a paid invoice sits untouched past its original deadline. The deadline prevents a late payment; it does not give the payer a way to recover funds.

For a small change, add an explicit expiration path for an **unpaid** invoice. Test the boundary timestamp and prove that it cannot run after payment. This exercise should not be described as adding an escrow refund right; that would require a different state and trust model.
