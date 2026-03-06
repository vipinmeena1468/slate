import { useEffect } from 'react'
import { Editor } from '@tiptap/react'

const STORAGE_KEY = 'slate-content'
const DEBOUNCE_MS = 800

export function useAutoSave(editor: Editor | null) {
  useEffect(() => {
    if (!editor) return

    let timer: ReturnType<typeof setTimeout>

    const save = () => {
      clearTimeout(timer)
      timer = setTimeout(() => {
        const json = editor.getJSON()
        localStorage.setItem(STORAGE_KEY, JSON.stringify(json))
      }, DEBOUNCE_MS)
    }

    editor.on('update', save)
    return () => {
      editor.off('update', save)
      clearTimeout(timer)
    }
  }, [editor])
}

export function loadSavedContent() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    return raw ? JSON.parse(raw) : null
  } catch {
    return null
  }
}
