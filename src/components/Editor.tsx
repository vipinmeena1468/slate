import { useEditor, EditorContent } from '@tiptap/react'
import { allExtensions } from '../extensions'
import { useAutoSave, loadSavedContent } from '../hooks/useAutoSave'

const defaultContent = {
  type: 'doc',
  content: [
    {
      type: 'paragraph',
    },
  ],
}

export default function Editor() {
  const editor = useEditor({
    extensions: allExtensions,
    content: loadSavedContent() ?? defaultContent,
    autofocus: 'end',
    editorProps: {
      attributes: {
        spellcheck: 'false',
        autocomplete: 'off',
        autocorrect: 'off',
        autocapitalize: 'off',
        'data-gramm': 'false',
        'data-gramm_editor': 'false',
      },
    },
  })

  useAutoSave(editor)

  return (
    <div className="editor-container">
      <EditorContent editor={editor} />
    </div>
  )
}
