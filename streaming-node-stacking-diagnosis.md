# Streaming Node Stacking Diagnosis - Enhanced Logging Guide

## 🔍 Problem: Nodes Stacking During Eager Streaming

When streaming AI requests on empty graphs, nodes appear to be getting stacked on top of each other instead of being properly spaced. This comprehensive logging system will help identify the root cause.

## 🔧 Enhanced Logging Added

### 1. **Node Similarity Matching Logs** (`AIPositioningHelpers.swift`)

**Key Log Patterns to Look For:**
```
🔍 performNodeSimilarityMatching: preserveUnmatched=true/false, existing nodes=X, new patch nodes=Y
📊 Using similarity thresholds - Patch: 0.8, Layer: 0.8  (streaming)
📊 Using similarity thresholds - Patch: 0.5, Layer: 0.5  (complete)
🆕 Creating X new patch nodes:
🆕   New patch node UUID: PatchType at initial position (x, y)
📱 Streaming mode: Preserving X unmatched existing nodes
📱   Preserving patch node UUID: PatchType at position (x, y)
🎯 Final matching results:
🎯   Total nodes: X, Matched node IDs: Y, Layer canvas positions: Z
🎯   Final patch node UUID: PatchType at position (x, y)
```

### 2. **Positioning Function Logs** (`StepApplication.swift`)

**Key Log Patterns to Look For:**
```
🚀 positionAIGeneratedNodesDuringApply called:
🚀   Input nodes: X, ViewPort center: (x, y)
🚀   Existing nodes: X, Matched nodes: Y - [UUIDs]
🚀   Layer canvas positions: X
🚀   Input patch node UUID: PatchType at (x, y)
🚀 positionAIGeneratedNodesDuringApply completed:
🚀   Output nodes: X
🚀   Final patch node UUID: PatchType at (x, y)
```

### 3. **Empty Graph Scenario Logs** (`AIPatchBuilderRequest.swift`)

**Key Log Patterns to Look For:**
```
📊 Initial graph state:
📊   Existing nodes: 0  ← Should be 0 for empty graph
📊   Previous sidebar selection: 0
📊   Is streaming: true/false
📊 🆕 EMPTY GRAPH SCENARIO: Starting with no existing nodes  ← Critical log
```

### 4. **Phase Transition Logs** (`ClaudeGraphGenRequest.swift`)

**Key Log Patterns to Look For:**
```
🔄 PHASE 1 (STREAMING): Attempting eager parse at X tokens
🔄 Current content length: X characters
✅ PHASE 1 SUCCESS: Eager parse successful - applying partial graph
✅   Found X patch nodes, Y layer groups
✅ PHASE 1 COMPLETE: Partial graph applied successfully

🎯 PHASE 2 START: Final reconciliation with complete content
🎯 Total content accumulated: X characters
✅ PHASE 2 SUCCESS: Final parse successful - applying complete graph with reconciliation
✅   Final X patch nodes, Y layer groups
✅ PHASE 2 COMPLETE: Complete graph applied with full reconciliation
📊 Streaming session complete - Total tokens: X, Parse attempts: Y, Success rate: Z%
```

### 5. **Node ID Stability Logs** (`StreamingParseContext.swift`)

**Key Log Patterns to Look For:**
```
✅ Parse SUCCESS in X.XXms - Found Y patch nodes, Z layer groups
✅   Patch node IDs: [UUID1, UUID2, UUID3, ...]
✅   Layer IDs: [UUID1, UUID2, UUID3, ...]
```

## 🕵️‍♀️ Diagnostic Analysis Strategy

### **For Empty Graph Scenarios:**

1. **Confirm Empty Start**: Look for `📊 🆕 EMPTY GRAPH SCENARIO`
2. **Check Initial Positions**: In first parse, all nodes should get `initial position (0, 0)` or some default
3. **Verify Positioning Logic**: `🚀 positionAIGeneratedNodesDuringApply` should spread nodes out from viewport center
4. **Track Node Creation**: Each eager parse should create nodes with unique positions

### **For Node Stacking Issues:**

1. **Position Inheritance**: Check if nodes are keeping `(0, 0)` positions throughout
2. **Matched Node Logic**: In empty graph, `Matched nodes: 0` - no position preservation should occur
3. **Viewport Center**: Verify `ViewPort center` is reasonable (not (0, 0))
4. **Final Positioning**: Compare input vs output positions in `positionAIGeneratedNodesDuringApply`

### **For Node ID Stability:**

1. **ID Consistency**: Same partial content should produce same node IDs
2. **Incremental Changes**: New tokens should add nodes, not recreate existing ones
3. **Phase Transitions**: Node IDs should be stable between Phase 1 and Phase 2

## 🔍 Key Questions These Logs Will Answer

**1. Are nodes being created with proper initial positions?**
- Look at `🆕 New patch node` logs

**2. Is the positioning function being called correctly?**
- Look at `🚀 positionAIGeneratedNodesDuringApply called` logs

**3. Are nodes getting repositioned or staying at (0,0)?**
- Compare input vs output positions in positioning logs

**4. Is the empty graph being handled differently?**
- Look for `📊 🆕 EMPTY GRAPH SCENARIO` and subsequent behavior

**5. Are node IDs stable between parse attempts?**
- Compare `✅ Patch node IDs` across multiple parse attempts

**6. Is streaming vs complete mode affecting positioning?**
- Compare logs between `PHASE 1 (STREAMING)` and `PHASE 2` sections

## 🎯 Expected Behavior vs Problem Indicators

### ✅ **Expected (Working) Logs:**
```
📊 🆕 EMPTY GRAPH SCENARIO: Starting with no existing nodes
🚀   ViewPort center: (400, 300)  ← Reasonable center point
🆕   New patch node UUID1: rectangle at initial position (0, 0)
🆕   New patch node UUID2: oval at initial position (0, 0)
🚀   Final patch node UUID1: rectangle at (200, 200)  ← Spread out
🚀   Final patch node UUID2: oval at (600, 200)       ← Different position
```

### ❌ **Problem (Stacking) Logs:**
```
📊 🆕 EMPTY GRAPH SCENARIO: Starting with no existing nodes
🚀   ViewPort center: (0, 0)  ← Bad center?
🆕   New patch node UUID1: rectangle at initial position (0, 0)
🆕   New patch node UUID2: oval at initial position (0, 0)
🚀   Final patch node UUID1: rectangle at (0, 0)  ← Still at origin
🚀   Final patch node UUID2: oval at (0, 0)       ← Same position = stacking
```

Run the streaming test and examine these logs to pinpoint exactly where the positioning logic is failing!