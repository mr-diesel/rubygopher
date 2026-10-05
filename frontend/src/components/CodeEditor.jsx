import CodeMirror from "@uiw/react-codemirror";
import { StreamLanguage } from "@codemirror/language";
import { ruby } from "@codemirror/legacy-modes/mode/ruby";
import { darcula } from "@uiw/codemirror-theme-darcula";

// Ruby has no first-party CodeMirror 6 mode — the legacy stream parser is the standard bridge.
const extensions = [StreamLanguage.define(ruby)];

export default function CodeEditor({ value, onChange }) {
  return (
    <CodeMirror
      className="code-editor"
      value={value}
      onChange={onChange}
      theme={darcula}
      extensions={extensions}
      height="100%"
      basicSetup={{ foldGutter: false, autocompletion: false, highlightActiveLine: true }}
    />
  );
}
