// Athanor LiveView hooks.
//
// Two hooks power the page-builder drag-and-drop:
//
//   • AthanorDragSource — marks an element as a drag source. Reads
//     `data-athanor-source` ("palette" | "tree") plus either
//     `data-athanor-type` (palette) or `data-athanor-node-id` (tree)
//     and stuffs them into the dataTransfer payload on `dragstart`.
//
//   • AthanorDropZone — marks an element as a drop target. Reads
//     `data-athanor-target-parent-id` ("root" or a node id),
//     `data-athanor-target-zone` (zone name, default "content"), and
//     optionally `data-athanor-target-index`. When the zone is a *list*
//     of child slots, the hook computes the insertion index from the
//     cursor's vertical midpoint against each direct child.
//
// On drop the hook pushes the LiveView event `athanor:dnd_drop` with:
//   { source, type?, node_id?,
//     target_parent_id, target_zone, target_index }
//
// Wire into your LiveSocket:
//
//   import { AthanorHooks } from "athanor"
//   let liveSocket = new LiveSocket("/live", Socket, {
//     hooks: { ...AthanorHooks }
//   })
//
// No external runtime deps. Uses native HTML5 DnD.

const PAYLOAD_MIME = "application/x-athanor-dnd"
const DROP_INDICATOR_CLASS = "athanor-drop-target"

const AthanorDragSource = {
  mounted() {
    this.el.setAttribute("draggable", "true")
    this.el.addEventListener("dragstart", (e) => {
      const payload = {
        source: this.el.dataset.athanorSource,
      }
      if (payload.source === "palette") {
        payload.type = this.el.dataset.athanorType
      } else if (payload.source === "tree") {
        payload.node_id = this.el.dataset.athanorNodeId
      }
      e.dataTransfer.effectAllowed = "move"
      e.dataTransfer.setData(PAYLOAD_MIME, JSON.stringify(payload))
      this.el.classList.add("athanor-dragging")
    })
    this.el.addEventListener("dragend", () => {
      this.el.classList.remove("athanor-dragging")
    })
  },
}

const AthanorDropZone = {
  mounted() {
    this.el.addEventListener("dragover", (e) => {
      // Allow drop. Required — without preventDefault, "drop" never fires.
      e.preventDefault()
      e.dataTransfer.dropEffect = "move"
      this.el.classList.add(DROP_INDICATOR_CLASS)
    })

    this.el.addEventListener("dragleave", (e) => {
      // Ignore dragleave that's just into a descendant.
      if (this.el.contains(e.relatedTarget)) return
      this.el.classList.remove(DROP_INDICATOR_CLASS)
    })

    this.el.addEventListener("drop", (e) => {
      e.preventDefault()
      this.el.classList.remove(DROP_INDICATOR_CLASS)

      const raw = e.dataTransfer.getData(PAYLOAD_MIME)
      if (!raw) return
      let source
      try {
        source = JSON.parse(raw)
      } catch (_err) {
        return
      }

      const targetParentId =
        this.el.dataset.athanorTargetParentId || "root"
      const targetZone =
        this.el.dataset.athanorTargetZone || "content"

      // If the data attr sets an explicit index, use it. Otherwise
      // compute by cursor Y vs each direct child's midpoint.
      let targetIndex
      if (this.el.dataset.athanorTargetIndex !== undefined) {
        targetIndex = parseInt(this.el.dataset.athanorTargetIndex, 10) || 0
      } else {
        targetIndex = computeDropIndex(this.el, e.clientY)
      }

      // Don't drop a node onto itself (the "I dragged but landed in the
      // same slot" case — server is idempotent but we avoid the round-trip).
      if (
        source.source === "tree" &&
        source.node_id &&
        this.el.dataset.athanorNodeId === source.node_id
      ) {
        return
      }

      this.pushEvent("athanor:dnd_drop", {
        source: source.source,
        type: source.type,
        node_id: source.node_id,
        target_parent_id: targetParentId,
        target_zone: targetZone,
        target_index: targetIndex,
      })
    })
  },
}

// Pick an insertion index inside a drop zone based on cursor Y.
// Direct children that themselves carry `data-athanor-drop-item` are
// treated as the slot list. The cursor's vertical position decides
// whether the new item lands before or after each child.
function computeDropIndex(zoneEl, clientY) {
  const items = Array.from(
    zoneEl.querySelectorAll(":scope > [data-athanor-drop-item]")
  )
  if (items.length === 0) return 0

  for (let i = 0; i < items.length; i++) {
    const rect = items[i].getBoundingClientRect()
    const midpoint = rect.top + rect.height / 2
    if (clientY < midpoint) return i
  }
  return items.length
}

export const AthanorHooks = {
  AthanorDragSource,
  AthanorDropZone,
}

export default AthanorHooks
