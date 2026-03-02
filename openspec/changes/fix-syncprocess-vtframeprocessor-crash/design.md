## Context

`SystemVideoEnhancementAdapter` uses a serial queue to protect `VTFrameProcessor` session lifecycle and processing state. In `syncProcess(...)`, the current implementation creates a Swift concurrency `Task` and then blocks with `DispatchSemaphore` to simulate synchronous behavior.

The observed crash is at the `await processor.process(parameters:)` call inside that task closure. The task bridge introduces mixed execution models in a code path that is intended to be queue-serialized and deterministic.

## Goals / Non-Goals

**Goals:**
- Remove the `Task` bridge from `syncProcess(...)`.
- Keep synchronous call semantics for existing caller code.
- Preserve timeout, logging, and fallback behavior.

**Non-Goals:**
- Refactor `processSingleFrame(...)` to async API.
- Redesign LLFI processing flow.
- Change user-visible enhancement control behavior.

## Decisions

1. Use `VTFrameProcessor.process(parameters:completionHandler:)` in `syncProcess(...)`.
Reason: this API already provides async completion without creating a detached Swift concurrency task, reducing lifetime/execution ambiguity in the synchronous queue path.

Alternative considered: keep `Task` and add stronger cancellation/lifetime guards.
Rejected because it retains the same mixed-model execution risk and does not remove the crash-prone call site.

2. Keep existing semaphore timeout handling and session reset.
Reason: callers depend on bounded wait and non-ML fallback.

## Risks / Trade-offs

- [Risk] Completion may arrive after timeout and after function return.
  -> Mitigation: keep timeout-triggered session reset and ignore late completion result for returned value path.

- [Trade-off] Still uses blocking wait in a serial queue path.
  -> Mitigation: no behavior change in this patch; scope remains crash-focused.
