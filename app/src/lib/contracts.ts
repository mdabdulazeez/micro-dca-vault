import { Address } from 'viem';

// Contract addresses from environment variables
export const CONTRACT_ADDRESSES = {
  VAULT_FACTORY: (process.env.NEXT_PUBLIC_VAULT_FACTORY_ADDRESS || '0x') as Address,
  RELAYER: (process.env.NEXT_PUBLIC_RELAYER_ADDRESS || '0x') as Address,
  ROUTER: (process.env.NEXT_PUBLIC_ROUTER_ADDRESS || '0x') as Address,
} as const;

// VaultFactory ABI
export const VAULT_FACTORY_ABI = [
  {
    type: 'constructor',
    inputs: [{ name: '_router', type: 'address' }],
  },
  {
    type: 'function',
    name: 'createVault',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'base', type: 'address' },
      { name: 'quote', type: 'address' },
      { name: 'intervalSeconds', type: 'uint256' },
      { name: 'maxSlippageBps', type: 'uint256' },
      { name: 'perCycleQuoteCap', type: 'uint256' },
      { name: 'feeBps', type: 'uint256' },
      { name: 'keeper', type: 'address' },
    ],
    outputs: [{ name: 'vault', type: 'address' }],
  },
  {
    type: 'function',
    name: 'copyVault',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'src', type: 'address' }],
    outputs: [{ name: 'vault', type: 'address' }],
  },
  {
    type: 'function',
    name: 'getAllVaults',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'address[]' }],
  },
  {
    type: 'function',
    name: 'getVaultsPaginated',
    stateMutability: 'view',
    inputs: [
      { name: 'offset', type: 'uint256' },
      { name: 'limit', type: 'uint256' },
    ],
    outputs: [
      { name: 'vaults', type: 'address[]' },
      { name: 'total', type: 'uint256' },
    ],
  },
  {
    type: 'function',
    name: 'isVault',
    stateMutability: 'view',
    inputs: [{ name: '', type: 'address' }],
    outputs: [{ name: '', type: 'bool' }],
  },
  {
    type: 'event',
    name: 'VaultCreated',
    inputs: [
      { name: 'vault', type: 'address', indexed: true },
      { name: 'base', type: 'address', indexed: true },
      { name: 'quote', type: 'address', indexed: true },
      { name: 'creator', type: 'address', indexed: false },
    ],
  },
  {
    type: 'event',
    name: 'VaultCopied',
    inputs: [
      { name: 'src', type: 'address', indexed: true },
      { name: 'copy', type: 'address', indexed: true },
      { name: 'creator', type: 'address', indexed: true },
    ],
  },
] as const;

// MicroDcaVault ABI
export const MICRO_DCA_VAULT_ABI = [
  // ERC-4626 functions
  {
    type: 'function',
    name: 'deposit',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'assets', type: 'uint256' },
      { name: 'receiver', type: 'address' },
    ],
    outputs: [{ name: 'shares', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'withdraw',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'assets', type: 'uint256' },
      { name: 'receiver', type: 'address' },
      { name: 'owner', type: 'address' },
    ],
    outputs: [{ name: 'shares', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'redeem',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'shares', type: 'uint256' },
      { name: 'receiver', type: 'address' },
      { name: 'owner', type: 'address' },
    ],
    outputs: [{ name: 'assets', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'totalAssets',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'balanceOf',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'previewDeposit',
    stateMutability: 'view',
    inputs: [{ name: 'assets', type: 'uint256' }],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'previewRedeem',
    stateMutability: 'view',
    inputs: [{ name: 'shares', type: 'uint256' }],
    outputs: [{ name: '', type: 'uint256' }],
  },
  // Custom DCA functions
  {
    type: 'function',
    name: 'executeCycle',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'quoteAmount', type: 'uint256' },
      { name: 'minOut', type: 'uint256' },
      { name: 'beneficiary', type: 'address' },
    ],
    outputs: [{ name: 'baseOut', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'getConfig',
    stateMutability: 'view',
    inputs: [],
    outputs: [
      { name: 'intervalSeconds', type: 'uint256' },
      { name: 'maxSlippageBps', type: 'uint256' },
      { name: 'perCycleQuoteCap', type: 'uint256' },
      { name: 'feeBps', type: 'uint256' },
      { name: 'keeper', type: 'address' },
      { name: 'paused', type: 'bool' },
    ],
  },
  {
    type: 'function',
    name: 'nextExecTime',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'baseToken',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'address' }],
  },
  {
    type: 'function',
    name: 'quoteToken',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'address' }],
  },
  {
    type: 'function',
    name: 'lastExec',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'totalFilledQuote',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'totalFilledBase',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'owner',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'address' }],
  },
  {
    type: 'function',
    name: 'paused',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'bool' }],
  },
  // Events
  {
    type: 'event',
    name: 'Fill',
    inputs: [
      { name: 'ts', type: 'uint256', indexed: true },
      { name: 'quoteIn', type: 'uint256', indexed: false },
      { name: 'baseOut', type: 'uint256', indexed: false },
    ],
  },
] as const;

// ERC-20 ABI (minimal)
export const ERC20_ABI = [
  {
    type: 'function',
    name: 'balanceOf',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'approve',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'spender', type: 'address' },
      { name: 'amount', type: 'uint256' },
    ],
    outputs: [{ name: '', type: 'bool' }],
  },
  {
    type: 'function',
    name: 'allowance',
    stateMutability: 'view',
    inputs: [
      { name: 'owner', type: 'address' },
      { name: 'spender', type: 'address' },
    ],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'symbol',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'string' }],
  },
  {
    type: 'function',
    name: 'decimals',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint8' }],
  },
  {
    type: 'function',
    name: 'name',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'string' }],
  },
] as const;

// Relayer ABI
export const RELAYER_ABI = [
  {
    type: 'function',
    name: 'executeMetaCycle',
    stateMutability: 'nonpayable',
    inputs: [
      {
        name: 'executeCycle',
        type: 'tuple',
        components: [
          { name: 'vault', type: 'address' },
          { name: 'quoteAmount', type: 'uint256' },
          { name: 'minOut', type: 'uint256' },
          { name: 'beneficiary', type: 'address' },
          { name: 'deadline', type: 'uint256' },
          { name: 'nonce', type: 'uint256' },
        ],
      },
      { name: 'signature', type: 'bytes' },
    ],
    outputs: [{ name: 'baseOut', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'getNonce',
    stateMutability: 'view',
    inputs: [{ name: 'user', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'getTypedDataHash',
    stateMutability: 'view',
    inputs: [
      {
        name: 'executeCycle',
        type: 'tuple',
        components: [
          { name: 'vault', type: 'address' },
          { name: 'quoteAmount', type: 'uint256' },
          { name: 'minOut', type: 'uint256' },
          { name: 'beneficiary', type: 'address' },
          { name: 'deadline', type: 'uint256' },
          { name: 'nonce', type: 'uint256' },
        ],
      },
    ],
    outputs: [{ name: '', type: 'bytes32' }],
  },
  {
    type: 'function',
    name: 'verifySignature',
    stateMutability: 'view',
    inputs: [
      {
        name: 'executeCycle',
        type: 'tuple',
        components: [
          { name: 'vault', type: 'address' },
          { name: 'quoteAmount', type: 'uint256' },
          { name: 'minOut', type: 'uint256' },
          { name: 'beneficiary', type: 'address' },
          { name: 'deadline', type: 'uint256' },
          { name: 'nonce', type: 'uint256' },
        ],
      },
      { name: 'signature', type: 'bytes' },
    ],
    outputs: [
      { name: 'signer', type: 'address' },
      { name: 'isValid', type: 'bool' },
    ],
  },
] as const;

// Type definitions
export interface VaultConfig {
  intervalSeconds: bigint;
  maxSlippageBps: bigint;
  perCycleQuoteCap: bigint;
  feeBps: bigint;
  keeper: Address;
  paused: boolean;
}

export interface VaultInfo {
  address: Address;
  baseToken: Address;
  quoteToken: Address;
  owner: Address;
  config: VaultConfig;
  totalAssets: bigint;
  totalFilledQuote: bigint;
  totalFilledBase: bigint;
  lastExec: bigint;
  nextExecTime: bigint;
}

export interface TokenInfo {
  address: Address;
  name: string;
  symbol: string;
  decimals: number;
  balance?: bigint;
}
