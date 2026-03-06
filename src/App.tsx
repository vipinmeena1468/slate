import Header from './components/Header'
import Editor from './components/Editor'
import { useTheme } from './hooks/useTheme'

export default function App() {
  const { theme, toggleTheme } = useTheme()

  return (
    <div className="app">
      <Header theme={theme} onToggleTheme={toggleTheme} />
      <Editor />
    </div>
  )
}
