import StarterKit from '@tiptap/starter-kit'
import BulletList from '@tiptap/extension-bullet-list'
import ListItem from '@tiptap/extension-list-item'
import TaskList from '@tiptap/extension-task-list'
import TaskItem from '@tiptap/extension-task-item'
import { DashListItem } from './DashList'
import { SlashCommands } from './SlashCommands'

export const allExtensions = [
  StarterKit.configure({
    heading: false,
    blockquote: false,
    code: false,
    codeBlock: false,
    horizontalRule: false,
    orderedList: false,
    strike: false,
    // Disable StarterKit's bulletList to prevent its "- " input rule from
    // conflicting with our DashListItem extension's input rule.
    // We re-add BulletList below without the input rule.
    bulletList: false,
    listItem: false,
  }),
  // Re-add BulletList without the default input rules (those are on StarterKit level)
  BulletList.configure({ HTMLAttributes: {} }),
  ListItem,
  TaskList,
  TaskItem.configure({ nested: false }),
  DashListItem,
  SlashCommands,
]
