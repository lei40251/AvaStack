// src/state/state-machine.ts
// 会话状态机：校验并执行会话状态流转

import type { SessionStatus } from "../types/contracts.js";
import { VALID_STATUS_TRANSITIONS } from "../types/contracts.js";

export class InvalidTransitionError extends Error {
  public readonly code = "INVALID_TRANSITION";

  constructor(from: SessionStatus, to: SessionStatus) {
    super(`不允许从 ${from} 转换到 ${to}`);
    this.name = "InvalidTransitionError";
  }
}

// 校验状态流转是否合法，不合法抛出 InvalidTransitionError
export function validateTransition(
  from: SessionStatus,
  to: SessionStatus
): void {
  const allowed = VALID_STATUS_TRANSITIONS[from];
  if (!allowed || !allowed.includes(to)) {
    throw new InvalidTransitionError(from, to);
  }
}

// 执行状态流转，返回新状态和 closed_at 时间戳
export function applyTransition(
  currentStatus: SessionStatus,
  targetStatus: SessionStatus
): {
  status: SessionStatus;
  closed_at: string | null;
} {
  validateTransition(currentStatus, targetStatus);

  const now = new Date().toISOString();
  const closed_at = targetStatus === "closed" ? now : null;

  return { status: targetStatus, closed_at };
}
