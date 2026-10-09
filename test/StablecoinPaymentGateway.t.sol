// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StablecoinPaymentGateway} from "../src/StablecoinPaymentGateway.sol";
import {MockUSDC} from "./MockUSDC.sol";

contract StablecoinPaymentGatewayTest is Test {
    MockUSDC internal usdc;
    StablecoinPaymentGateway internal gateway;
    address internal merchant = makeAddr("merchant");
    address internal merchant2 = makeAddr("merchant2");
    address internal payer = makeAddr("payer");
    address internal outsider = makeAddr("outsider");
    address internal feeRecipient = makeAddr("feeRecipient");
    bytes32 internal constant INVOICE = keccak256("invoice-1");
    uint256 internal constant AMOUNT = 100_000_000; // 100 mUSDC, six decimals

    function setUp() public {
        usdc = new MockUSDC();
        gateway = new StablecoinPaymentGateway(IERC20(address(usdc)), feeRecipient, 250);
        usdc.mint(payer, 1_000_000_000);
        vm.prank(payer);
        usdc.approve(address(gateway), type(uint256).max);
        _create(INVOICE, AMOUNT);
    }

    function _create(bytes32 id, uint256 amount) internal {
        vm.prank(merchant);
        gateway.createInvoice(id, payer, amount, uint64(block.timestamp + 1 days));
    }

    function _pay(bytes32 id) internal {
        vm.prank(payer);
        gateway.payInvoice(merchant, id);
    }

    function testPaymentCannotBeRepeated() public {
        _pay(INVOICE);
        vm.prank(payer);
        vm.expectRevert(StablecoinPaymentGateway.InvalidStatus.selector);
        gateway.payInvoice(merchant, INVOICE);
        assertEq(gateway.totalPending(), AMOUNT);
        assertEq(usdc.balanceOf(address(gateway)), AMOUNT);
    }

    function testOnlyNamedPayerCanPay() public {
        vm.prank(outsider);
        vm.expectRevert(StablecoinPaymentGateway.NotPayer.selector);
        gateway.payInvoice(merchant, INVOICE);
    }

    function testExpiredInvoiceCannotBePaid() public {
        vm.warp(block.timestamp + 1 days + 1);
        vm.prank(payer);
        vm.expectRevert(StablecoinPaymentGateway.InvoiceExpired.selector);
        gateway.payInvoice(merchant, INVOICE);
    }

    function testIdsAreScopedToMerchant() public {
        vm.prank(merchant2);
        gateway.createInvoice(INVOICE, payer, AMOUNT, uint64(block.timestamp + 1 days));
        assertEq(uint256(gateway.getInvoice(merchant2, INVOICE).status), uint256(StablecoinPaymentGateway.Status.Open));
        vm.prank(merchant);
        vm.expectRevert(StablecoinPaymentGateway.InvoiceAlreadyExists.selector);
        gateway.createInvoice(INVOICE, payer, AMOUNT, uint64(block.timestamp + 1 days));
    }

    function testSettleSplitsFeeAndMerchantCredit() public {
        _pay(INVOICE);
        vm.prank(merchant);
        gateway.settleInvoice(INVOICE);
        assertEq(gateway.totalPending(), 0);
        assertEq(gateway.merchantCredit(merchant), 97_500_000);
        assertEq(gateway.accruedFees(), 2_500_000);
        assertEq(gateway.totalMerchantCredit() + gateway.accruedFees(), usdc.balanceOf(address(gateway)));

        vm.prank(merchant);
        gateway.withdrawMerchant(47_500_000, merchant);
        vm.prank(feeRecipient);
        gateway.withdrawFees(2_500_000, feeRecipient);
        assertEq(usdc.balanceOf(merchant), 47_500_000);
        assertEq(usdc.balanceOf(feeRecipient), 2_500_000);
        assertEq(gateway.merchantCredit(merchant), 50_000_000);
    }

    function testRefundBeforeSettlementRestoresPayerBalance() public {
        uint256 initialBalance = usdc.balanceOf(payer);
        _pay(INVOICE);
        vm.prank(merchant);
        gateway.refundInvoice(INVOICE);
        assertEq(usdc.balanceOf(payer), initialBalance);
        assertEq(gateway.totalPending(), 0);
        assertEq(uint256(gateway.getInvoice(merchant, INVOICE).status), uint256(StablecoinPaymentGateway.Status.Refunded));
    }

    function testSettlementAndRefundAreMutuallyExclusive() public {
        _pay(INVOICE);
        vm.prank(merchant);
        gateway.settleInvoice(INVOICE);
        vm.prank(merchant);
        vm.expectRevert(StablecoinPaymentGateway.InvalidStatus.selector);
        gateway.refundInvoice(INVOICE);
    }

    function testOnlyMerchantCanSettleOrRefundItsInvoice() public {
        _pay(INVOICE);
        vm.prank(outsider);
        vm.expectRevert(StablecoinPaymentGateway.InvalidStatus.selector);
        gateway.settleInvoice(INVOICE);
        vm.prank(outsider);
        vm.expectRevert(StablecoinPaymentGateway.InvalidStatus.selector);
        gateway.refundInvoice(INVOICE);
    }

    function testOnlyFeeRecipientCanWithdrawFees() public {
        _pay(INVOICE);
        vm.prank(merchant);
        gateway.settleInvoice(INVOICE);
        vm.prank(outsider);
        vm.expectRevert(StablecoinPaymentGateway.NotFeeRecipient.selector);
        gateway.withdrawFees(1, outsider);
    }

    function testFuzzAccountingAfterSettlement(uint96 rawAmount) public {
        uint256 amount = bound(uint256(rawAmount), 1, 1_000_000_000);
        bytes32 id = keccak256(abi.encode(rawAmount));
        _create(id, amount);
        _pay(id);
        vm.prank(merchant);
        gateway.settleInvoice(id);
        assertEq(
            usdc.balanceOf(address(gateway)),
            gateway.totalPending() + gateway.totalMerchantCredit() + gateway.accruedFees()
        );
    }
}
