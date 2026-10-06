import { StateEffect, StateField } from "@codemirror/state";
import { Decoration, EditorView, WidgetType } from "@codemirror/view";

export const setRemoteCursors = StateEffect.define();

const PALETTE = 6;
const colorIndex = (id) => Math.abs(Number(id) || 0) % PALETTE;

class CursorWidget extends WidgetType {
  constructor(name, color) {
    super();
    this.name = name;
    this.color = color;
  }

  eq(other) {
    return other.name === this.name && other.color === this.color;
  }

  toDOM() {
    const el = document.createElement("span");
    el.className = `remote-cursor remote-cursor-${this.color}`;
    el.dataset.name = this.name;
    return el;
  }

  ignoreEvent() {
    return true;
  }
}

const decorationsFor = (cursors, doc) =>
  Decoration.set(
    Object.values(cursors)
      .map(({ by, name, pos }) => ({ pos: Math.min(pos, doc.length), widget: new CursorWidget(name, colorIndex(by)) }))
      .sort((a, b) => a.pos - b.pos)
      .map(({ pos, widget }) => Decoration.widget({ widget, side: 1 }).range(pos))
  );

// Other participants' carets. Positions are plain offsets, so they drift a little
// while someone else types; good enough for last-write-wins.
export const remoteCursors = StateField.define({
  create: () => Decoration.none,
  update(decorations, tr) {
    const effect = tr.effects.find((e) => e.is(setRemoteCursors));
    return effect ? decorationsFor(effect.value, tr.state.doc) : decorations.map(tr.changes);
  },
  provide: (field) => EditorView.decorations.from(field)
});
