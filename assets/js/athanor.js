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
//     cursor's position against each direct child.
//
// On drop the hook pushes the LiveView event `athanor:dnd_drop` with:
//   { source, type?, node_id?,
//     target_parent_id, target_zone, target_index }
//
// Three things about the drop zone are configurable, because the editor
// canvas is not the only surface that wants HTML5 drag-and-drop:
//
//   • `data-athanor-drop-event` — the LiveView event name to push
//     (default "athanor:dnd_drop"). A host with its own editor handles
//     its own event rather than colliding with the library's.
//
//   • the drag payload is passed through verbatim. Whatever a drag
//     source put in `dataTransfer` beyond `source`/`type`/`node_id`
//     arrives on the pushed event untouched, so a host can carry its
//     own fields (a zone name, a scene id) without patching the hook.
//
//   • `data-athanor-drop-axis` — "y" (default) or "x". A row of
//     horizontal slots needs the insertion index computed against each
//     child's horizontal midpoint, not its vertical one. Setting
//     `data-athanor-drop-index="false"` skips index computation
//     altogether for zones that are a single slot rather than a list.
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
      if (indexingEnabled(this.el)) {
        updateIndicator(this.el, this.indicator, e, dropAxis(this.el))
      }
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

      // If the data attr sets an explicit index, use it. If indexing is
      // switched off (a single-slot zone), don't send one at all. Otherwise
      // compute it from the cursor against each direct child's midpoint on
      // the configured axis.
      let targetIndex
      if (this.el.dataset.athanorTargetIndex !== undefined) {
        targetIndex = parseInt(this.el.dataset.athanorTargetIndex, 10) || 0
      } else if (indexingEnabled(this.el)) {
        targetIndex = computeDropIndex(this.el, e, dropAxis(this.el))
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

      // Payload passthrough: everything the drag source put in the
      // dataTransfer rides along, so a host can carry its own fields without
      // the hook needing to know about them.
      const payload = {
        ...source,
        source: source.source,
        target_parent_id: targetParentId,
        target_zone: targetZone,
      }
      if (targetIndex !== undefined) payload.target_index = targetIndex

      this.pushEvent(dropEventName(this.el), payload)
    })
  },

  destroyed() {
    if (this.indicator && this.indicator.parentNode) {
      this.indicator.parentNode.removeChild(this.indicator)
    }
  },
}

// The LiveView event this zone pushes on drop. Defaults to the library's
// own event so the editor keeps working with no attribute at all.
function dropEventName(zoneEl) {
  return zoneEl.dataset.athanorDropEvent || "athanor:dnd_drop"
}

// "x" for a row of slots, "y" (default) for a document-flow column.
function dropAxis(zoneEl) {
  return zoneEl.dataset.athanorDropAxis === "x" ? "x" : "y"
}

// A zone that is one slot rather than a list opts out of index maths with
// `data-athanor-drop-index="false"`.
function indexingEnabled(zoneEl) {
  return zoneEl.dataset.athanorDropIndex !== "false"
}

function dropItems(zoneEl) {
  return Array.from(zoneEl.querySelectorAll(":scope > [data-athanor-drop-item]"))
}

// Position the insertion-line indicator inside the zone at the cursor's
// computed insertion point. For an empty zone the indicator is hidden —
// the zone-level highlight (outline + tinted background) carries the
// feedback alone.
function updateIndicator(zoneEl, indicator, event, axis) {
  const items = dropItems(zoneEl)
  if (items.length === 0) {
    indicator.style.display = "none"
    return
  }

  const zoneRect = zoneEl.getBoundingClientRect()
  const idx = insertionIndex(items, event, axis)

  if (axis === "x") {
    const x =
      idx < items.length
        ? items[idx].getBoundingClientRect().left - zoneRect.left
        : items[items.length - 1].getBoundingClientRect().right - zoneRect.left

    // A vertical rule between horizontal slots, rather than the
    // between-rows line the default axis draws.
    indicator.style.left = `${x + zoneEl.scrollLeft}px`
    indicator.style.right = "auto"
    indicator.style.top = "0"
    indicator.style.bottom = "0"
    indicator.style.height = "auto"
    indicator.style.width = "3px"
    indicator.style.transform = "translateX(-1.5px)"
  } else {
    const y =
      idx < items.length
        ? items[idx].getBoundingClientRect().top - zoneRect.top
        : items[items.length - 1].getBoundingClientRect().bottom - zoneRect.top

    indicator.style.top = `${y + zoneEl.scrollTop}px`
  }

  indicator.style.display = "block"
}

// Pick an insertion index inside a drop zone from the cursor position.
// Direct children carrying `data-athanor-drop-item` are the slot list; the
// cursor decides whether the new item lands before or after each one.
function computeDropIndex(zoneEl, event, axis) {
  const items = dropItems(zoneEl)
  if (items.length === 0) return 0
  return insertionIndex(items, event, axis)
}

function insertionIndex(items, event, axis) {
  const position = axis === "x" ? event.clientX : event.clientY

  for (let i = 0; i < items.length; i++) {
    const rect = items[i].getBoundingClientRect()
    const midpoint =
      axis === "x" ? rect.left + rect.width / 2 : rect.top + rect.height / 2
    if (position < midpoint) return i
  }
  return items.length
}

export const AthanorHooks = {
  AthanorDragSource,
  AthanorDropZone,
}

export default AthanorHooks
