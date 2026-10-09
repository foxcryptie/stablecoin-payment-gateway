# Stablecoin Payment Gateway

A single-token, on-chain invoice payment example using a six-decimal mock stablecoin in tests. Each merchant creates invoices with its own IDs. The named payer pays once; the merchant then either settles the payment or refunds it. Settlement allocates the merchant amount and protocol fee to separate withdrawable balances.

This is a study project. It is not audited, and it must not hold real funds.

## Payment flow

`Open -> Paid -> Settled` or `Open -> Paid -> Refunded`.

An invoice expires for **payment** at its deadline. It does not automatically refund or expire after payment. Only the merchant can choose settlement or refund. A settled invoice cannot be refunded through this contract.

The token, fee recipient, and fee rate are immutable. The fee is charged on settlement and rounded down to the token's smallest unit. IDs are unique per merchant, not globally.

## Accounting

For a conventional ERC-20 token, the intended accounting identity is:

```text
gateway token balance >= totalPending + totalMerchantCredit + accruedFees
```

The excess can be a direct token donation. A test checks equality in the absence of donations. Pending funds remain reserved until settlement or refund. Merchant and fee withdrawals reduce their respective credits before transferring tokens.

## Run

Requirements: Git and Foundry v1.8.5.

```bash
git clone --depth 1 --branch v5.6.1 https://github.com/OpenZeppelin/openzeppelin-contracts.git lib/openzeppelin-contracts
git clone --depth 1 --branch v1.17.0 https://github.com/foundry-rs/forge-std.git lib/forge-std
forge build
forge test -vv
```

CI runs the same commands. The mock token is under `test/`; it has an unrestricted mint function and is never suitable for deployment as a real stablecoin.

## Design and security limits

- This is a **payment gateway**, not an escrow: the merchant controls settlement and refunds. The payer cannot demand a refund.
- No chargeback, dispute process, timeout after payment, or merchant identity verification exists.
- A token can freeze, blacklist, pause, upgrade, or change transfer behavior outside this contract. The implementation is intended for a conventional, non-rebasing ERC-20 with exact transfers. It rejects an unexpected received amount on payment.
- Invoices and payer addresses are public on-chain.
- Anyone can create invoices for their own merchant address. Apps must display and verify the intended merchant address.
- No upgrade or emergency rescue path exists. Unsupported tokens or accidental transfers can leave funds inaccessible.

Read [THREAT_MODEL.md](THREAT_MODEL.md) before discussing deployment.

## Study questions

1. Why is invoice identity the pair `(merchant, invoiceId)`?
2. Why are funds kept pending before merchant settlement?
3. Which state updates occur before each token transfer, and why?
4. What changes would be needed to allow payer-enforced refunds after a deadline?
5. How would you safely support tokens with fees on transfer, if at all?
