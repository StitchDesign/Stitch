# AI Graph Preservation Research - Node Position & Selection State

## Problem Statement

Currently, when an AI edit request comes in, we wipe the entire existing graph and start afresh. This creates undesired UX effects:
- Visual jumps in graph/node positioning
- Loss of sidebar selection state
- Jarring experience for simple edits like "make the rectangle bigger"

The core challenge: Node IDs change between edits, making it difficult to identify "the same" or "similar" nodes.

## Current System Analysis

### How `applyAIGraph` Works (AIPatchBuilderRequest.swift)

1. **ID Mapping**: Creates `idMap: [String : UUID]` to track AI string IDs to actual node UUIDs
2. **Node Reuse Check**: For each AI node, checks if existing node with same ID has compatible type
3. **Selective Creation**: Only creates new nodes when type doesn't match
4. **Bulk Deletion**: **Critical Issue** - Deletes ALL nodes not mentioned in AI response (lines 372-385)

### Node ID Generation Patterns

- **AI generates random UUIDs**: Each generation creates new UUIDs (not deterministic)
- **Variable naming pattern**: `{patchTypeName}_{nodeUUID}` (e.g., `addPatch_123-abc-456`)
- **Layer variables**: `layer_{layerUUID}_{gestureName}`

### Node Positioning System

- Uses **topological sorting** (Kahn's algorithm) to determine depth levels
- Positions nodes in columns based on depth
- Centers entire chain around viewport
- **Critical Issue**: Dictionary/Set iteration order causes non-deterministic positioning within same depth level

#### Non-Deterministic Positioning Problem
- Nodes at same topological depth are processed in arbitrary order
- This causes position differences even for identical graphs
- Root cause: Swift Set iteration is unordered
- Makes position-based node matching unreliable

## Edit Similarity Examples

### Very Similar Edits (parameter changes only)
- "make rectangle bigger" - only size changes
- "switch from blue to green" → "switch from yellow to red" - only colors change
- **Preserved**: Node types, count, topology, connection structure

### Medium Similar Edits (type changes)
- "oval" → "rectangle" - shape type changes but size/color preserved
- **Preserved**: Node count, topology, most parameters

### Very Dissimilar Edits (structural changes)
- "one oval" → "100 draggable rectangles"
- **Changed**: Everything - node count, topology, parameters

## Proposed Solutions

### Solution 1: Smart Node Matching System (Recommended)
**Approach**: Match old nodes with new nodes based on similarity scoring

**Matching Criteria** (in priority order):
1. **Exact Match**: Same NodeKind + same title + same input values
2. **Type + Title Match**: Same NodeKind + same title (ignoring values)
3. **Type Match**: Same NodeKind for common types
4. **Connection Pattern**: Similar upstream/downstream relationships

**Implementation**:
```swift
struct NodeSimilarityMatcher {
    func findBestMatch(oldNode: NodeViewModel, newNodes: [NodeViewModel]) -> NodeViewModel?
    func calculateSimilarity(node1: NodeViewModel, node2: NodeViewModel) -> Double
}
```

### Solution 2: Position & Selection Snapshot/Restore
**Approach**: Capture state before apply, restore after
- Snapshot all node positions and sidebar selection
- After graph creation, restore for matched nodes
- Use fuzzy matching based on properties

### Solution 3: Incremental Graph Updates
**Approach**: Diff and apply changes instead of wholesale replacement
- Identify nodes to: keep, update, add, delete
- Apply changes incrementally
- Most complex but most preserving

### Solution 4: AI-Guided Preservation
**Approach**: Have AI explicitly mark which nodes to preserve
- Modify prompts to include preservation hints
- AI returns old→new ID mapping
- Most accurate but requires AI changes

## Insights from Diff Algorithms

### Traditional Code Diff Tools
- **Line-based comparison**: Git diff, unified diff use line-by-line comparison
- **LCS (Longest Common Subsequence)**: Maximize unchanged parts
- **Myers Algorithm**: Used by Git, optimal for finding minimal edits
- **Key principle**: Match based on content similarity, not identity

### How This Applies to Nodes
- Nodes are like "lines" but with richer structure
- Can't rely on position (since it's recalculated)
- Must match on semantic properties instead of syntactic position
- Similar to how semantic diff tools compare ASTs rather than text

## Implementation Strategy

### Phase 1: Node Matching Infrastructure
1. Create `NodeSimilarityMatcher` with configurable matching rules
2. Score similarity based on:
   - Node type (patch vs layer)
   - Patch/layer specific type
   - Input port configuration
   - Constant values
   - Connection patterns

### Phase 2: Modify `applyAIGraph`
1. Before creating new nodes, run matching algorithm
2. Update `idMap` to reuse existing IDs for matched nodes
3. Preserve positions for matched nodes
4. Only delete truly obsolete nodes (no matches found)

### Phase 3: Sidebar Selection Preservation
1. Track selected layer IDs before update
2. Map old IDs to new IDs via matching
3. Restore selection using mapped IDs

## Key Technical Details

### Available Node Properties for Matching
- `NodeViewModel.kind`: Node type (patch/layer/group/component)
- `NodeViewModel.title`: Display title
- `NodeViewModel.inputs/outputs`: Port values
- Connection topology via `InputNodeRowObserver.upstreamOutputCoordinate`
- Position via `CanvasItemViewModel.position`

### Existing Infrastructure to Build On
- `idMap` system for ID tracking
- Node reuse logic (lines 183-184 check for `needsNewNodeCreation`)
- Position preservation when nodes are reused
- Sidebar update mechanism via `LayersSidebarViewModel.update()`

## Open Questions

1. **Matching Confidence Threshold**: What similarity score is "good enough" to reuse a node?
2. **Multiple Matches**: If multiple new nodes match one old node, how to choose?
3. **Orphaned Nodes**: Should we keep nodes not in the new graph but mark them somehow?
4. **Performance**: How expensive is similarity calculation for large graphs?

## Deterministic Positioning Solutions

### The Core Problem
Within the same topological depth level, nodes are processed in whatever order the dictionary/set iteration provides, which is non-deterministic.

### Solution 1: Sort by AI Generation Order (Recommended)
**Approach**: Use the order nodes appear in the AI's SwiftUI code generation

The AI generates nodes in a specific order:
- `javascript_patches` array
- `native_patches` array
- `layer_data_list` array

**Implementation**: Add creation order index when processing these arrays, then sort nodes at same depth level by this order.

### Solution 2: Semantic Ordering
**Approach**: Sort by meaningful node properties
- By node type: Sort patch types alphabetically ("Add", "Multiply", "Value")
- By layer hierarchy: Layers before patches, parent layers before children
- By connection role: Sources before processors before sinks

### Solution 3: Stable Hash-Based Ordering
**Approach**: Create deterministic but arbitrary ordering
- Sort by UUID string representation (deterministic across runs)
- Sort by node title/display name
- Sort by stable hash of node properties (type + input values)

### Solution 4: Graph-Aware Ordering
**Approach**: Use graph structure for sub-ordering
- Nodes with more upstream connections first
- Nodes with more downstream connections last
- Nodes with similar connection patterns grouped together

### Recommended Multi-Level Sorting
1. **Primary**: AI generation order (preserves intent)
2. **Secondary**: Node type alphabetical (semantic meaning)
3. **Tertiary**: UUID string (deterministic fallback)

## Next Steps

1. **Fix deterministic positioning** first - this solves position-based matching issues
2. Prototype `NodeSimilarityMatcher` with basic type + value matching
3. Test with provided examples (rectangle color change, size change, etc.)
4. Iterate on matching criteria based on results
5. Consider caching similarity scores for performance
6. Add configuration for matching strictness

## Notes for Future Implementation

- Start with conservative matching (high confidence only)
- Log matching decisions for debugging
- Consider making matching configurable per edit type
- May need special handling for group nodes and components
- Position preservation should account for new nodes needing space

## References

- Current implementation: `/Stitch/Graph/StitchAI/GraphPrompting/Model/RequestTypes/AIPatchBuilderRequest.swift`
- Node positioning: `/Stitch/Graph/StitchAI/GraphPrompting/Model/StepApplication.swift`
- Node structure: `/Stitch/Graph/ViewModel/GraphState.swift`
- Sidebar management: `/Stitch/Graph/Sidebar/LayersSidebar/LayersSidebarViewModel.swift`