# Stablecoin Payment Gateway

[![Foundry CI](https://github.com/foxcryptie/stablecoin-payment-gateway/actions/workflows/ci.yml/badge.svg)](https://github.com/foxcryptie/stablecoin-payment-gateway/actions/workflows/ci.yml)

A small invoice contract for one ERC-20 token. A merchant creates an invoice for a named payer. The payer can pay it once; the merchant then settles it or sends the payment back. Invoice IDs belong to the merchant that created them, so two merchants can use the same ID.

## Follow one payment

The tests use a six-decimal mock token. With a 100 mUSDC invoice and a 2.5% protocol fee:

| Step | Pending | Merchant credit | Fee credit |
| --- | ---: | ---: | ---: |
| Invoice created | 0 | 0 | 0 |
| Payer sends 100 | 100 | 0 | 0 |
| Merchant settles | 0 | 97.5 | 2.5 |

The merchant and fee recipient withdraw their credits separately. Before settlement, the merchant can instead refund the full 100 to the payer. The payment deadline stops *new payments*; it does not trigger a refund after payment. There is no payer-enforced refund path. This contract is therefore a merchant-controlled gateway, not an escrow.

The gateway checks that it received exactly the invoiced amount. It is built for a conventional, non-rebasing token; the fee-on-transfer test shows a taxed payment reverting. The accounting tests check that the token balance covers pending payments, merchant credits, and accrued fees.

## Run the tests

Install [Foundry](https://book.getfoundry.sh/getting-started/installation) and Git, then clone the pinned test dependencies:

```bash
mkdir -p lib
git clone --depth 1 --branch v5.6.1 https://github.com/OpenZeppelin/openzeppelin-contracts.git lib/openzeppelin-contracts
git clone --depth 1 --branch v1.17.0 https://github.com/foundry-rs/forge-std.git lib/forge-std
forge build
forge test -vv
```

Start with [`test/StablecoinPaymentGateway.t.sol`](test/StablecoinPaymentGateway.t.sol). It covers the state transitions, who may act on an invoice, fee splitting, refunds, and balance accounting. [`THREAT_MODEL.md`](THREAT_MODEL.md) records the trust assumptions; [`STUDY_GUIDE.md`](STUDY_GUIDE.md) walks through the numbers.

## Boundaries

The merchant can settle immediately and the payer cannot force a refund. Token issuers may freeze, pause, or change token behavior. There is no dispute process, emergency withdrawal, upgrade path, or independent audit. The mock token is test-only. Do not deploy this example with real funds.
