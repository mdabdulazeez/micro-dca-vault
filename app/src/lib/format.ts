import { formatUnits, parseUnits } from 'viem';

/**
 * Format token amount with decimals
 */
export function formatTokenAmount(
  amount: bigint | string,
  decimals: number = 18,
  displayDecimals: number = 4
): string {
  if (!amount || amount === 0n) return '0';
  
  const formatted = formatUnits(BigInt(amount), decimals);
  const num = parseFloat(formatted);
  
  if (num < 0.0001) return '< 0.0001';
  
  return num.toLocaleString('en-US', {
    minimumFractionDigits: 0,
    maximumFractionDigits: displayDecimals,
  });
}

/**
 * Parse token amount to BigInt
 */
export function parseTokenAmount(amount: string, decimals: number = 18): bigint {
  if (!amount || amount === '') return 0n;
  try {
    return parseUnits(amount, decimals);
  } catch {
    return 0n;
  }
}

/**
 * Format percentage from basis points
 */
export function formatBps(bps: bigint | number): string {
  const num = typeof bps === 'bigint' ? Number(bps) : bps;
  return (num / 100).toFixed(2) + '%';
}

/**
 * Format time duration in human-readable format
 */
export function formatDuration(seconds: number): string {
  if (seconds < 60) return `${seconds}s`;
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h`;
  return `${Math.floor(seconds / 86400)}d`;
}

/**
 * Format timestamp to human-readable date
 */
export function formatDate(timestamp: bigint | number): string {
  const date = new Date(Number(timestamp) * 1000);
  return date.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

/**
 * Format address for display (shortened)
 */
export function formatAddress(address: string): string {
  if (!address || address.length < 10) return address;
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

/**
 * Calculate time remaining until next execution
 */
export function getTimeUntilNext(nextExecTime: bigint): {
  seconds: number;
  isReady: boolean;
  formatted: string;
} {
  const now = Math.floor(Date.now() / 1000);
  const next = Number(nextExecTime);
  const remaining = Math.max(0, next - now);
  
  return {
    seconds: remaining,
    isReady: remaining === 0,
    formatted: remaining === 0 ? 'Ready' : formatDuration(remaining),
  };
}

/**
 * Truncate text with ellipsis
 */
export function truncateText(text: string, length: number): string {
  if (text.length <= length) return text;
  return text.slice(0, length) + '...';
}

/**
 * Format large numbers with K, M, B suffixes
 */
export function formatLargeNumber(num: number): string {
  if (num >= 1e9) return (num / 1e9).toFixed(1) + 'B';
  if (num >= 1e6) return (num / 1e6).toFixed(1) + 'M';
  if (num >= 1e3) return (num / 1e3).toFixed(1) + 'K';
  return num.toFixed(2);
}

/**
 * Validate Ethereum address
 */
export function isValidAddress(address: string): boolean {
  return /^0x[a-fA-F0-9]{40}$/.test(address);
}

/**
 * Get relative time (e.g., "2 minutes ago")
 */
export function getRelativeTime(timestamp: bigint | number): string {
  const now = Date.now();
  const then = Number(timestamp) * 1000;
  const diff = now - then;
  
  const seconds = Math.floor(diff / 1000);
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);
  const days = Math.floor(hours / 24);
  
  if (days > 0) return `${days}d ago`;
  if (hours > 0) return `${hours}h ago`;
  if (minutes > 0) return `${minutes}m ago`;
  return `${seconds}s ago`;
}

/**
 * Calculate APY from fill data (simplified estimate)
 */
export function estimateAPY(
  totalFilledQuote: bigint,
  totalFilledBase: bigint,
  timeElapsed: number
): number {
  if (totalFilledQuote === 0n || timeElapsed === 0) return 0;
  
  const quoteNum = Number(formatUnits(totalFilledQuote, 18));
  const baseNum = Number(formatUnits(totalFilledBase, 18));
  
  if (quoteNum === 0) return 0;
  
  const gain = baseNum - quoteNum; // Simplified 1:1 assumption
  const roi = gain / quoteNum;
  const annualizedROI = (roi * (365 * 24 * 3600)) / timeElapsed;
  
  return annualizedROI * 100;
}
