# Stacks Multisig

A multi-signature wallet on Stacks blockchain using `@stacks/connect` and `@stacks/transactions`.

## Features

- 🔐 Multi-signature transaction approval
- 👥 Multiple owner management
- ✍️ Configurable signature threshold
- 📝 Transaction proposal and signing

## Tech Stack

- **Frontend**: Next.js 14, React 18, TypeScript
- **Blockchain**: Stacks Mainnet
- **Smart Contract**: Clarity
- **Libraries**: @stacks/connect, @stacks/transactions, @stacks/network

## Contract Functions

- `submit-transaction` - Propose a new transaction
- `sign-transaction` - Add signature to transaction
- `execute-transaction` - Execute after threshold met
- `is-owner` - Check if address is owner
- `get-required-signatures` - Get signature threshold

## Getting Started

```bash
npm install
npm run dev
```

## Contract Address

Deployed on Stacks Mainnet: `SP3E0DQAHTXJHH5YT9TZCSBW013YXZB25QFDVXXWY.multisig`

## License

MIT
