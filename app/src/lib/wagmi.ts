import { getDefaultWallets } from '@rainbow-me/rainbowkit';
import { configureChains, createConfig } from 'wagmi';
import { publicProvider } from 'wagmi/providers/public';
import { jsonRpcProvider } from 'wagmi/providers/jsonRpc';

// Somnia network configuration
const somnia = {
  id: parseInt(process.env.NEXT_PUBLIC_SOMNIA_CHAIN_ID || '50311'),
  name: 'Somnia',
  network: 'somnia',
  nativeCurrency: {
    decimals: 18,
    name: 'STT',
    symbol: 'STT',
  },
  rpcUrls: {
    public: { http: [process.env.NEXT_PUBLIC_SOMNIA_RPC_URL || 'https://rpc.somnia.network'] },
    default: { http: [process.env.NEXT_PUBLIC_SOMNIA_RPC_URL || 'https://rpc.somnia.network'] },
  },
  blockExplorers: {
    default: { name: 'Somnia Explorer', url: 'https://explorer.somnia.network' },
  },
} as const;

// Configure chains
const { chains, publicClient, webSocketPublicClient } = configureChains(
  [somnia],
  [
    jsonRpcProvider({
      rpc: (chain) => ({
        http: chain.rpcUrls.default.http[0],
      }),
    }),
    publicProvider(),
  ]
);

// Configure wallets
const { connectors } = getDefaultWallets({
  appName: 'Micro-DCA Vault',
  projectId: process.env.NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID || 'your-project-id',
  chains,
});

// Create wagmi config
export const config = createConfig({
  autoConnect: true,
  connectors,
  publicClient,
  webSocketPublicClient,
});

export { chains };
