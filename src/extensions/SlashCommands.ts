import { Extension, Range, Editor } from '@tiptap/core'
import Suggestion from '@tiptap/suggestion'
import { createRoot, Root } from 'react-dom/client'
import { createElement, createRef } from 'react'
import tippy, { Instance, Props } from 'tippy.js'
import SlashMenu, { SlashMenuHandle, SlashMenuItem } from '../components/SlashMenu'
import 'tippy.js/dist/tippy.css'

interface SlashCommandItem {
  title: string
  description: string
  icon: string
  command: (params: { editor: Editor; range: Range }) => void
}

const SLASH_ITEMS: SlashCommandItem[] = [
  {
    title: 'Bullet Point',
    description: 'Insert a • bullet list',
    icon: '•',
    command: ({ editor, range }) => {
      editor.chain().focus().deleteRange(range).toggleBulletList().run()
    },
  },
  {
    title: 'To-Do',
    description: 'Insert a task item',
    icon: '☐',
    command: ({ editor, range }) => {
      editor.chain().focus().deleteRange(range).toggleTaskList().run()
    },
  },
]

function filterItems(query: string): SlashCommandItem[] {
  return SLASH_ITEMS.filter((item) =>
    item.title.toLowerCase().includes(query.toLowerCase()),
  )
}

export const SlashCommands = Extension.create({
  name: 'slashCommands',

  addProseMirrorPlugins() {
    return [
      Suggestion({
        editor: this.editor,
        char: '/',
        allowSpaces: false,
        startOfLine: false,
        items: ({ query }: { query: string }) => filterItems(query),
        // This is the bridge: Tiptap calls this when props.command(item) is invoked from the menu
        command: ({ editor, range, props }: { editor: Editor; range: Range; props: SlashCommandItem }) => {
          props.command({ editor, range })
        },

        render: () => {
          let popup: Instance<Props> | null = null
          let reactRoot: Root | null = null
          let container: HTMLDivElement | null = null
          let refEl: HTMLDivElement | null = null
          const menuRef = createRef<SlashMenuHandle>()

          return {
            onStart(props) {
              container = document.createElement('div')
              reactRoot = createRoot(container)

              reactRoot.render(
                createElement(SlashMenu, {
                  ref: menuRef,
                  items: props.items as SlashMenuItem[],
                  command: (item: SlashMenuItem) => props.command(item),
                }),
              )

              refEl = document.createElement('div')
              document.body.appendChild(refEl)

              popup = tippy(refEl, {
                getReferenceClientRect: props.clientRect as () => DOMRect,
                appendTo: () => document.body,
                content: container,
                showOnCreate: true,
                interactive: true,
                trigger: 'manual',
                placement: 'bottom-start',
                arrow: false,
                offset: [0, 6],
              })
            },

            onUpdate(props) {
              if (reactRoot && container) {
                reactRoot.render(
                  createElement(SlashMenu, {
                    ref: menuRef,
                    items: props.items as SlashMenuItem[],
                    command: (item: SlashMenuItem) => props.command(item),
                  }),
                )
              }
              popup?.setProps({
                getReferenceClientRect: props.clientRect as () => DOMRect,
              })
            },

            onKeyDown(props) {
              if (props.event.key === 'Escape') {
                popup?.hide()
                return true
              }
              return menuRef.current?.onKeyDown(props.event) ?? false
            },

            onExit() {
              popup?.destroy()
              popup = null
              refEl?.remove()
              refEl = null
              setTimeout(() => {
                reactRoot?.unmount()
                reactRoot = null
                container = null
              }, 0)
            },
          }
        },
      }),
    ]
  },
})
