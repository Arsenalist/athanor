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
const INDICATOR_ATTR = "data-athanor-indicator"
const STYLE_ELEMENT_ID = "athanor-dnd-styles"

// Inject the minimal CSS the hooks rely on (drop-zone highlight, source
// drag-ghost opacity, insertion-line indicator). Idempotent — safe to
// call from every hook mount.
function ensureStylesInjected() {
  if (document.getElementById(STYLE_ELEMENT_ID)) return
  const style = document.createElement("style")
  style.id = STYLE_ELEMENT_ID
  style.textContent = `
    .athanor-dragging { opacity: 0.5; }
    .${DROP_INDICATOR_CLASS} {
      outline: 2px dashed var(--color-primary, #3b82f6);
      outline-offset: 2px;
      background-color: color-mix(in srgb, var(--color-primary, #3b82f6) 6%, transparent);
    }
    [${INDICATOR_ATTR}] {
      position: absolute;
      left: 0;
      right: 0;
      height: 3px;
      background: var(--color-primary, #3b82f6);
      box-shadow: 0 0 0 1px color-mix(in srgb, var(--color-primary, #3b82f6) 35%, transparent);
      border-radius: 2px;
      pointer-events: none;
      transform: translateY(-1.5px);
      display: none;
      z-index: 20;
    }
    [${INDICATOR_ATTR}]::before,
    [${INDICATOR_ATTR}]::after {
      content: "";
      position: absolute;
      top: 50%;
      width: 8px;
      height: 8px;
      border-radius: 9999px;
      background: var(--color-primary, #3b82f6);
      transform: translateY(-50%);
    }
    [${INDICATOR_ATTR}]::before { left: -4px; }
    [${INDICATOR_ATTR}]::after  { right: -4px; }
  `
  document.head.appendChild(style)
}

const AthanorDragSource = {
  mounted() {
    ensureStylesInjected()
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
    ensureStylesInjected()

    // Indicator needs the zone as its positioning context.
    if (getComputedStyle(this.el).position === "static") {
      this.el.style.position = "relative"
    }

    this.indicator = document.createElement("div")
    this.indicator.setAttribute(INDICATOR_ATTR, "true")
    this.el.appendChild(this.indicator)

    this.el.addEventListener("dragover", (e) => {
      // Allow drop. Required — without preventDefault, "drop" never fires.
      e.preventDefault()
      e.dataTransfer.dropEffect = "move"
      this.el.classList.add(DROP_INDICATOR_CLASS)
      updateIndicator(this.el, this.indicator, e.clientY)
    })

    this.el.addEventListener("dragleave", (e) => {
      // Ignore dragleave that's just into a descendant.
      if (this.el.contains(e.relatedTarget)) return
      this.el.classList.remove(DROP_INDICATOR_CLASS)
      this.indicator.style.display = "none"
    })

    this.el.addEventListener("drop", (e) => {
      e.preventDefault()
      this.el.classList.remove(DROP_INDICATOR_CLASS)
      this.indicator.style.display = "none"

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

  destroyed() {
    if (this.indicator && this.indicator.parentNode) {
      this.indicator.parentNode.removeChild(this.indicator)
    }
  },
}

// Position the insertion-line indicator inside the zone at the cursor's
// computed insertion point. For an empty zone the indicator is hidden —
// the zone-level highlight (outline + tinted background) carries the
// feedback alone.
function updateIndicator(zoneEl, indicator, clientY) {
  const items = Array.from(
    zoneEl.querySelectorAll(":scope > [data-athanor-drop-item]")
  )
  if (items.length === 0) {
    indicator.style.display = "none"
    return
  }

  const zoneRect = zoneEl.getBoundingClientRect()
  let idx = items.length
  for (let i = 0; i < items.length; i++) {
    const rect = items[i].getBoundingClientRect()
    if (clientY < rect.top + rect.height / 2) {
      idx = i
      break
    }
  }

  let y
  if (idx < items.length) {
    y = items[idx].getBoundingClientRect().top - zoneRect.top
  } else {
    y = items[items.length - 1].getBoundingClientRect().bottom - zoneRect.top
  }

  indicator.style.top = `${y + zoneEl.scrollTop}px`
  indicator.style.display = "block"
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
