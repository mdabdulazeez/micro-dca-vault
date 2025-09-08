/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  swcMinify: true,
  experimental: {
    appDir: false, // Using pages router as specified
  },
  webpack: (config) => {
    config.resolve.fallback = { fs: false, net: false, tls: false };
    config.externals.push('pino-pretty', 'lokijs', 'encoding');
    return config;
  },
  env: {
    NEXT_PUBLIC_SOMNIA_RPC_URL: process.env.NEXT_PUBLIC_SOMNIA_RPC_URL,
    NEXT_PUBLIC_SOMNIA_CHAIN_ID: process.env.NEXT_PUBLIC_SOMNIA_CHAIN_ID,
    NEXT_PUBLIC_VAULT_FACTORY_ADDRESS: process.env.NEXT_PUBLIC_VAULT_FACTORY_ADDRESS,
    NEXT_PUBLIC_RELAYER_ADDRESS: process.env.NEXT_PUBLIC_RELAYER_ADDRESS,
    NEXT_PUBLIC_ROUTER_ADDRESS: process.env.NEXT_PUBLIC_ROUTER_ADDRESS,
  },
};

module.exports = nextConfig;
