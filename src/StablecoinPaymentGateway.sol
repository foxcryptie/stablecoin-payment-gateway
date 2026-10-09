// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @notice Single-token invoice payments. A merchant can settle or refund a paid invoice.
/// @dev Learning implementation. Only use with a conventional, non-rebasing ERC-20 token.
contract StablecoinPaymentGateway is ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum Status {
        Unset,
        Open,
        Paid,
        Settled,
        Refunded
    }

    struct Invoice {
        address payer;
        uint256 amount;
        uint64 deadline;
        Status status;
    }

    error ZeroAddress();
    error ZeroAmount();
    error ZeroInvoiceId();
    error InvalidDeadline();
    error FeeTooHigh();
    error InvoiceAlreadyExists();
    error InvalidStatus();
    error InvoiceExpired();
    error NotPayer();
    error InsufficientCredit();
    error UnsupportedTokenBehavior();
    error NotFeeRecipient();

    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint16 public constant MAX_FEE_BPS = 1_000;

    IERC20 public immutable token;
    address public immutable feeRecipient;
    uint16 public immutable feeBps;

    // Invoice IDs are unique per merchant, so merchants cannot reserve each other's IDs.
    mapping(address merchant => mapping(bytes32 invoiceId => Invoice)) private _invoices;
    mapping(address merchant => uint256) public merchantCredit;
    uint256 public totalMerchantCredit;
    uint256 public totalPending;
    uint256 public accruedFees;

    event InvoiceCreated(
        address indexed merchant, bytes32 indexed invoiceId, address indexed payer, uint256 amount, uint64 deadline
    );
    event InvoicePaid(address indexed merchant, bytes32 indexed invoiceId, address indexed payer, uint256 amount);
    event InvoiceSettled(address indexed merchant, bytes32 indexed invoiceId, uint256 merchantAmount, uint256 fee);
    event InvoiceRefunded(address indexed merchant, bytes32 indexed invoiceId, address indexed payer, uint256 amount);
    event MerchantWithdrawal(address indexed merchant, address indexed to, uint256 amount);
    event FeeWithdrawal(address indexed to, uint256 amount);

    constructor(IERC20 token_, address feeRecipient_, uint16 feeBps_) {
        if (address(token_) == address(0) || feeRecipient_ == address(0)) revert ZeroAddress();
        if (address(token_).code.length == 0) revert UnsupportedTokenBehavior();
        if (feeBps_ > MAX_FEE_BPS) revert FeeTooHigh();
        token = token_;
        feeRecipient = feeRecipient_;
        feeBps = feeBps_;
    }

    function getInvoice(address merchant, bytes32 invoiceId) external view returns (Invoice memory) {
        return _invoices[merchant][invoiceId];
    }

    function createInvoice(bytes32 invoiceId, address payer, uint256 amount, uint64 deadline) external {
        if (invoiceId == bytes32(0)) revert ZeroInvoiceId();
        if (payer == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (deadline <= block.timestamp) revert InvalidDeadline();
        Invoice storage invoice = _invoices[msg.sender][invoiceId];
        if (invoice.status != Status.Unset) revert InvoiceAlreadyExists();
        _invoices[msg.sender][invoiceId] = Invoice(payer, amount, deadline, Status.Open);
        emit InvoiceCreated(msg.sender, invoiceId, payer, amount, deadline);
    }

    function payInvoice(address merchant, bytes32 invoiceId) external nonReentrant {
        Invoice storage invoice = _invoices[merchant][invoiceId];
        if (invoice.status != Status.Open) revert InvalidStatus();
        if (msg.sender != invoice.payer) revert NotPayer();
        if (block.timestamp > invoice.deadline) revert InvoiceExpired();

        invoice.status = Status.Paid;
        totalPending += invoice.amount;

        uint256 beforeBalance = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), invoice.amount);
        uint256 afterBalance = token.balanceOf(address(this));
        if (afterBalance < beforeBalance || afterBalance - beforeBalance != invoice.amount) {
            revert UnsupportedTokenBehavior();
        }
        emit InvoicePaid(merchant, invoiceId, msg.sender, invoice.amount);
    }

    /// @notice Merchant finalizes payment. Once settled, this contract cannot refund it.
    function settleInvoice(bytes32 invoiceId) external {
        Invoice storage invoice = _invoices[msg.sender][invoiceId];
        if (invoice.status != Status.Paid) revert InvalidStatus();
        invoice.status = Status.Settled;
        totalPending -= invoice.amount;

        uint256 fee = Math.mulDiv(invoice.amount, feeBps, BPS_DENOMINATOR);
        uint256 merchantAmount = invoice.amount - fee;
        merchantCredit[msg.sender] += merchantAmount;
        totalMerchantCredit += merchantAmount;
        accruedFees += fee;
        emit InvoiceSettled(msg.sender, invoiceId, merchantAmount, fee);
    }

    /// @notice Merchant returns a payment before settlement. Payer cannot force a refund.
    function refundInvoice(bytes32 invoiceId) external nonReentrant {
        Invoice storage invoice = _invoices[msg.sender][invoiceId];
        if (invoice.status != Status.Paid) revert InvalidStatus();
        invoice.status = Status.Refunded;
        totalPending -= invoice.amount;
        token.safeTransfer(invoice.payer, invoice.amount);
        emit InvoiceRefunded(msg.sender, invoiceId, invoice.payer, invoice.amount);
    }

    function withdrawMerchant(uint256 amount, address to) external nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (amount > merchantCredit[msg.sender]) revert InsufficientCredit();
        merchantCredit[msg.sender] -= amount;
        totalMerchantCredit -= amount;
        token.safeTransfer(to, amount);
        emit MerchantWithdrawal(msg.sender, to, amount);
    }

    function withdrawFees(uint256 amount, address to) external nonReentrant {
        if (msg.sender != feeRecipient) revert NotFeeRecipient();
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (amount > accruedFees) revert InsufficientCredit();
        accruedFees -= amount;
        token.safeTransfer(to, amount);
        emit FeeWithdrawal(to, amount);
    }
}
