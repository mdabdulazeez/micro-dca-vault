# Micro-DCA Vault

A minimal, production-lean micro-DCA vault dApp built for Somnia that enables automated dollar-cost averaging with social copying features.

## Overview

Micro-DCA Vault allows users to:
- **Automate DCA strategies**: Deposit quote tokens into ERC-4626 compliant vaults that execute tiny periodic swaps into base tokens
- **Social copy trading**: Copy successful strategies from other traders with one click via the factory contract
- **Gasless execution**: Optional meta-transaction relayer for gasless user experience
- **Real-time monitoring**: Track live fills, portfolio performance, and execution schedules

## Architecture

### Smart Contracts
- **MicroDcaVault.sol**: ERC-4626 compliant vault with automated DCA execution
- **VaultFactory.sol**: Factory for creating and copying vault strategies  
- **Relayer.sol**: Meta-transaction relayer for gasless operations
- **Libraries**: Custom errors and interfaces

### Frontend
- **Next.js** with TypeScript
- **wagmi + viem** for Web3 integration
- **RainbowKit** for wallet connections
- **Tailwind CSS** for styling
- **React Hook Form + Zod** for form validation

## Quick Start

### Prerequisites
- Node.js 18+
- Git
- A wallet with Somnia testnet tokens

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd micro-dca-vault
   ```

2. **Install dependencies**
   ```bash
   # Install contract dependencies
   cd contracts
   npm install
   
   # Install frontend dependencies  
   cd ../app
   npm install
   ```

3. **Set up environment variables**
   ```bash
   # Copy and configure environment files
   cp .env.example .env.local
   cp contracts/.env.example contracts/.env
   ```

4. **Deploy contracts (if needed)**
   ```bash
   cd contracts
   
   # Deploy to Somnia testnet
   forge script script/Deploy.s.sol --rpc-url $SOMNIA_RPC_URL --broadcast --verify
   
   # Or deploy mocks for local testing
   forge script script/Deploy.s.sol:DeployMocks --rpc-url $RPC_URL --broadcast
   ```

5. **Start the frontend**
   ```bash
   cd app
   npm run dev
   ```

6. **Open the app**
   Navigate to [http://localhost:3000](http://localhost:3000)

## Usage Guide

### Creating a Vault

1. **Connect your wallet** using the Connect button
2. **Navigate to Create** page
3. **Configure your DCA strategy**:
   - Select base and quote tokens
   - Set execution interval (e.g., every 60 seconds)
   - Define per-cycle swap amount cap
   - Set maximum slippage tolerance
   - Configure protocol fees
4. **Deploy your vault** - you'll become the owner
5. **Deposit tokens** to start the DCA strategy

### Copying a Vault

1. **Browse active vaults** on the home page
2. **Click the copy icon** on any vault you want to replicate
3. **Confirm the transaction** - a new vault with identical parameters will be created
4. **You become the owner** of the copied vault
5. **Deposit tokens** to activate your copy

### Managing Your Portfolio

1. **Visit the Portfolio page** to see all your vaults
2. **Monitor performance** including total value, fills executed, and estimated APY
3. **Deposit or withdraw** tokens using standard ERC-4626 functions
4. **Execute cycles manually** if needed (or wait for automated execution)

### Executing DCA Cycles

DCA cycles can be executed in three ways:

1. **Direct execution**: Call `executeCycle` on the vault
2. **Keeper execution**: If a keeper is set, only they can execute
3. **Meta-transaction**: Use the relayer for gasless execution

## Technical Details

### Contract Specifications

#### MicroDcaVault
- **Standard**: ERC-4626 compliant tokenized vault
- **Assets**: Quote tokens (what users deposit)  
- **Strategy**: Periodic swaps to base tokens via DEX router
- **Execution**: Time-interval gated with configurable parameters
- **Fees**: Configurable protocol fees on base token output
- **Access**: Optional keeper restriction or permissionless

#### VaultFactory  
- **Purpose**: Deploy and track vault instances
- **Features**: Create new vaults, copy existing strategies
- **Discovery**: Paginated vault listing for frontend

#### Relayer
- **Standard**: EIP-712 typed signatures for meta-transactions
- **Purpose**: Enable gasless vault execution
- **Security**: Nonce-based replay protection, deadline enforcement
- **Fees**: Configurable relayer fees

### Default Configuration
- **Interval**: 60 seconds (configurable)
- **Max Slippage**: 0.5% (50 basis points)
- **Per-Cycle Cap**: 100 tokens (configurable)
- **Protocol Fee**: 0.1% (10 basis points)
- **Relayer Fee**: 0.25% (25 basis points)

### Security Features
- **ReentrancyGuard**: Prevents reentrancy attacks
- **SafeERC20**: Secure token transfers
- **Access control**: Owner-based permissions with optional keeper
- **Pause mechanism**: Emergency pause functionality
- **Slippage protection**: Configurable maximum slippage tolerance
- **Cap enforcement**: Per-cycle swap amount limits

## Development

### Running Tests

```bash
cd contracts

# Run Foundry tests
forge test

# Run with gas reporting
forge test --gas-report

# Run specific test
forge test --match-test testExecuteCycle -v
```

### Contract Deployment

```bash
cd contracts

# Deploy to Somnia testnet
forge script script/Deploy.s.sol --rpc-url $SOMNIA_RPC_URL --broadcast --verify

# Deploy with custom parameters
ROUTER_ADDRESS=0x... BASE_TOKEN_ADDRESS=0x... QUOTE_TOKEN_ADDRESS=0x... forge script script/Deploy.s.sol --rpc-url $SOMNIA_RPC_URL --broadcast
```

### Frontend Development

```bash
cd app

# Start development server
npm run dev

# Build for production  
npm run build

# Type checking
npm run type-check

# Linting
npm run lint
```

## Somnia Integration

This dApp is specifically optimized for Somnia's high-throughput, low-latency environment:

- **Frequent execution**: Designed for short intervals (60s) leveraging Somnia's speed
- **Low gas costs**: Efficient contract design minimizes transaction costs
- **Real-time updates**: Frontend optimized for Somnia's fast block times
- **Meta-transactions**: Relayer system provides gasless UX

## Hackathon Demo

### Key Features to Highlight

1. **Automated micro-DCA**: Set-and-forget DCA with 60-second intervals
2. **Social copying**: One-click strategy replication 
3. **Gasless execution**: Meta-transaction relayer for smooth UX
4. **ERC-4626 compliant**: Standard tokenized vault interface
5. **Real-time monitoring**: Live fills and performance tracking

### Demo Flow

1. **Show vault creation** with custom parameters
2. **Demonstrate social copying** of existing strategies  
3. **Execute DCA cycles** both direct and gasless
4. **Monitor live fills** and portfolio performance
5. **Highlight Somnia benefits**: fast execution, low costs

## Architecture Decisions

### Why ERC-4626?
- **Composability**: Standard vault interface enables DeFi integrations
- **Familiar UX**: Users understand deposit/withdraw semantics
- **Tokenization**: Share-based accounting enables complex strategies

### Why Factory Pattern?
- **Gas efficiency**: Minimal deployment costs for new vaults
- **Social features**: Easy discovery and copying of strategies
- **Standardization**: Consistent vault implementations

### Why Meta-Transactions?
- **User experience**: Gasless execution removes friction
- **Accessibility**: Users don't need native tokens for execution
- **Scalability**: Relayers can batch transactions efficiently

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Security

This is hackathon/demo code. For production use:
- [ ] Complete security audit
- [ ] Formal verification of critical functions
- [ ] Time-locked governance for parameter changes
- [ ] Oracle integration for accurate pricing
- [ ] Insurance fund for potential losses

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Links

- **Somnia Network**: [https://somnia.network](https://somnia.network)
- **Documentation**: [https://docs.somnia.network](https://docs.somnia.network)
- **Explorer**: [https://explorer.somnia.network](https://explorer.somnia.network)

---

Built with ❤️ for Somnia DeFi ecosystem.
