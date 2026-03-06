import { Node, InputRule } from '@tiptap/core'

export const DashListItem = Node.create({
  name: 'dashListItem',
  group: 'block',
  content: 'inline*',

  parseHTML() {
    return [{ tag: 'p[data-type="dash-list-item"]' }]
  },

  renderHTML({ HTMLAttributes }) {
    return ['p', { ...HTMLAttributes, 'data-type': 'dash-list-item' }, 0]
  },

  addInputRules() {
    return [
      new InputRule({
        find: /^-\s$/,
        handler: ({ state, range, chain }) => {
          const { from } = range
          const $from = state.doc.resolve(from)
          // Only convert if we're in a plain paragraph at the start
          if ($from.parent.type.name !== 'paragraph') return null

          chain()
            .deleteRange(range)
            .setNode(this.name)
            .run()
        },
      }),
    ]
  },

  addKeyboardShortcuts() {
    return {
      Enter: () => {
        const { state, chain } = this.editor
        const { $from } = state.selection

        if ($from.parent.type.name !== this.name) return false

        // If current dash item is empty, exit to paragraph
        if ($from.parent.textContent === '') {
          return chain()
            .setNode('paragraph')
            .run()
        }

        // Otherwise split and continue as dashListItem
        return chain()
          .splitBlock()
          .setNode(this.name)
          .run()
      },

      Backspace: () => {
        const { state, chain } = this.editor
        const { $from, empty } = state.selection

        if ($from.parent.type.name !== this.name) return false
        if (!empty || $from.parentOffset !== 0) return false

        // At position 0 of a dash item — convert back to paragraph
        return chain().setNode('paragraph').run()
      },
    }
  },
})
