import { useDate } from '../hooks/useDate'

interface HeaderProps {
  theme: 'dark' | 'light'
  onToggleTheme: () => void
}

export default function Header({ theme, onToggleTheme }: HeaderProps) {
  const date = useDate()

  return (
    <header className="header">
      <span className="header-logo">Slate</span>
      <div className="header-right">
        <span className="header-date">{date}</span>
        <button
          className="theme-toggle"
          onClick={onToggleTheme}
          aria-label={`Switch to ${theme === 'dark' ? 'light' : 'dark'} mode`}
          data-theme-active={theme === 'light' ? 'true' : 'false'}
        >
          <span className="theme-toggle-thumb" />
        </button>
      </div>
    </header>
  )
}
