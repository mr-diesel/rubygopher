import { useEffect, useRef } from "react";
import CodeMirror from "@uiw/react-codemirror";
import { StreamLanguage } from "@codemirror/language";
import { ruby } from "@codemirror/legacy-modes/mode/ruby";
import { go } from "@codemirror/legacy-modes/mode/go";
import { darcula } from "@uiw/codemirror-theme-darcula";
import { remoteCursors, setRemoteCursors } from "../lib/remoteCursors";

// Neither language has a first-party CodeMirror 6 mode; the legacy stream parsers are the standard bridge.
const languages = {
  ruby: [StreamLanguage.define(ruby), remoteCursors],
  go: [StreamLanguage.define(go), remoteCursors]
};

export default function CodeEditor({ value, onChange, language = "ruby", cursors = {}, onCursor }) {
  const editor = useRef(null);

  useEffect(() => {
    editor.current?.view?.dispatch({ effects: setRemoteCursors.of(cursors) });
  }, [cursors]);

  return (
    <CodeMirror
      ref={editor}
      className="code-editor"
      value={value}
      onChange={onChange}
      onUpdate={(update) => update.selectionSet && onCursor?.(update.state.selection.main.head)}
      theme={darcula}
      extensions={languages[language]}
      height="100%"
      basicSetup={{ foldGutter: false, autocompletion: false, highlightActiveLine: true }}
    />
  );
}
