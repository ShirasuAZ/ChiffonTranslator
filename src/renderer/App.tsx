import { useState, useEffect } from 'react'
import {
  Box, Container, Typography, Button, Stack, Select, MenuItem,
  FormControl, InputLabel, Paper, Switch, FormControlLabel, IconButton, Slider,
} from '@mui/material'
import {
  PlayArrow, Stop, OpenInNew, Translate,
} from '@mui/icons-material'
import { ThemeProvider, createTheme } from '@mui/material/styles'
import CssBaseline from '@mui/material/CssBaseline'
import SubtitlePanel from './components/SubtitlePanel'

const theme = createTheme({
  palette: {
    mode: 'dark',
    primary: { main: '#5b8def' },
    background: { default: '#1a1a2e', paper: '#16213e' },
  },
  typography: { fontFamily: '"Inter", "Noto Sans SC", sans-serif' },
})

const LANGUAGES = [
  { code: 'zh', label: '中文' },
  { code: 'en', label: 'English' },
  { code: 'ja', label: '日本語' },
  { code: 'ko', label: '한국어' },
  { code: 'fr', label: 'Français' },
  { code: 'de', label: 'Deutsch' },
  { code: 'es', label: 'Español' },
  { code: 'ru', label: 'Русский' },
]

const WS_URL = 'wss://translator.chiffon.cyou/ws/translate'

export default function App() {
  const hash = window.location.hash
  if (hash === '#/overlay') {
    return (
      <ThemeProvider theme={theme}>
        <CssBaseline />
        <OverlayView />
      </ThemeProvider>
    )
  }

  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <MainView />
    </ThemeProvider>
  )
}

function MainView() {
  const [sourceLang, setSourceLang] = useState('en')
  const [targetLang, setTargetLang] = useState('zh')
  const [isRunning, setIsRunning] = useState(false)
  const [showOverlay, setShowOverlay] = useState(false)
  const [overlayOpacity, setOverlayOpacity] = useState(0.7)
  const [settingsLoaded, setSettingsLoaded] = useState(false)
  const [subtitles, setSubtitles] = useState<{ original: string; translated: string }[]>([])
  const [ws, setWs] = useState<WebSocket | null>(null)
  const [mediaStream, setMediaStream] = useState<MediaStream | null>(null)

  // Load saved settings on mount
  useEffect(() => {
    window.electronAPI.getSettings().then((settings) => {
      setSourceLang(settings.sourceLang)
      setTargetLang(settings.targetLang)
      setOverlayOpacity(settings.overlayOpacity)
      setShowOverlay(settings.showOverlay)
      if (settings.showOverlay) {
        window.electronAPI.openOverlay()
      }
      setSettingsLoaded(true)
    })
  }, [])

  // Save language settings when changed
  useEffect(() => {
    if (!settingsLoaded) return
    window.electronAPI.saveSettings({ sourceLang, targetLang })
  }, [sourceLang, targetLang, settingsLoaded])

  // Save overlay state when changed
  useEffect(() => {
    if (!settingsLoaded) return
    window.electronAPI.saveSettings({ showOverlay })
  }, [showOverlay, settingsLoaded])

  const audioContextRef = { current: null as AudioContext | null }

  const startCapture = async () => {
    try {
      setIsRunning(true)

      // Check screen recording permission first (macOS)
      const screenPerm = await window.electronAPI.getScreenPermission()
      console.log('Screen recording permission:', screenPerm)
      if (screenPerm !== 'granted') {
        setIsRunning(false)
        alert('需要「屏幕与系统音频录制」权限。\n请前往：系统设置 → 隐私与安全性 → 屏幕与系统音频录制，授权本应用后重启。')
        return
      }

      // Connect WebSocket first — fail fast if backend unavailable
      const socket = await new Promise<WebSocket>((resolve, reject) => {
        const s = new WebSocket(WS_URL)
        s.binaryType = 'arraybuffer'
        s.onopen = () => resolve(s)
        s.onerror = () => reject(new Error('WebSocket 连接失败'))
        setTimeout(() => reject(new Error('WebSocket 连接超时')), 5000)
      })

      socket.send(JSON.stringify({
        source_lang: sourceLang,
        target_lang: targetLang,
        sample_rate: 16000,
      }))
      console.log('WebSocket connected, config sent')

      // Capture system audio via getDisplayMedia
      let stream: MediaStream
      try {
        stream = await navigator.mediaDevices.getDisplayMedia({
          audio: true,
          video: true,
        })
      } catch (mediaErr) {
        console.error('getDisplayMedia failed:', mediaErr)
        socket.close()
        setIsRunning(false)
        alert('未能获取系统音频，请检查系统权限设置')
        return
      }

      // Don't touch video tracks — disabling them can kill the loopback audio
      console.log('Audio tracks:', stream.getAudioTracks().length, 'Video tracks:', stream.getVideoTracks().length)
      stream.getAudioTracks().forEach(t => {
        console.log('Audio track:', t.label, t.readyState, t.getSettings())
        t.onended = () => console.error('Audio track ended unexpectedly!')
      })
      stream.getVideoTracks().forEach(t => {
        console.log('Video track:', t.label, t.readyState)
        t.onended = () => console.warn('Video track ended')
      })

      if (stream.getAudioTracks().length === 0 || stream.getAudioTracks()[0].readyState === 'ended') {
        console.error('Audio track is ended or missing')
        socket.close()
        setIsRunning(false)
        alert('未能获取系统音频（音频轨道已结束），请检查系统权限设置')
        return
      }

      setMediaStream(stream)

      // Use native sample rate from the audio track, resample in ScriptProcessor
      const trackSettings = stream.getAudioTracks()[0].getSettings()
      const nativeSampleRate = trackSettings.sampleRate || 48000
      console.log('Native sample rate:', nativeSampleRate)

      const audioContext = new AudioContext({ sampleRate: nativeSampleRate })
      audioContextRef.current = audioContext
      const source = audioContext.createMediaStreamSource(stream)
      const processor = audioContext.createScriptProcessor(4096, 1, 1)

      // Downsample from native rate to 16000 Hz
      const downsampleRatio = nativeSampleRate / 16000

      let chunksSent = 0
      processor.onaudioprocess = (e) => {
        if (socket.readyState === WebSocket.OPEN) {
          const float32 = e.inputBuffer.getChannelData(0)
          // Downsample to 16kHz
          const targetLen = Math.floor(float32.length / downsampleRatio)
          const pcm16 = new Int16Array(targetLen)
          let maxVal = 0
          for (let i = 0; i < targetLen; i++) {
            const srcIdx = Math.floor(i * downsampleRatio)
            const sample = float32[srcIdx]
            pcm16[i] = Math.max(-32768, Math.min(32767, Math.floor(sample * 32768)))
            maxVal = Math.max(maxVal, Math.abs(sample))
          }
          socket.send(pcm16.buffer)
          chunksSent++
          if (chunksSent % 50 === 1) {
            console.log(`Sent chunk #${chunksSent}, size=${pcm16.buffer.byteLength}, maxAmplitude=${maxVal.toFixed(4)}`)
          }
        }
      }

      source.connect(processor)
      processor.connect(audioContext.destination)

      socket.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data)
          console.log('WS message:', data.type, data.text?.substring(0, 50))
          if (data.type === 'asr' && data.is_final) {
            setSubtitles(prev => {
              const updated = [...prev]
              const last = updated[updated.length - 1]
              if (last && !last.translated) {
                last.original = data.text
              } else {
                updated.push({ original: data.text, translated: '' })
              }
              return updated.slice(-50)
            })
          } else if (data.type === 'translation_stream' || data.type === 'translation') {
            setSubtitles(prev => {
              const updated = [...prev]
              const entry = updated.find(e => e.original === data.original)
              if (entry) {
                entry.translated = data.text
              } else {
                updated.push({ original: data.original || '', translated: data.text })
              }
              return updated.slice(-50)
            })

            if (showOverlay) {
              window.electronAPI.sendSubtitleUpdate({
                original: data.original || '',
                translated: data.text,
              })
            }
          }
        } catch (parseErr) {
          console.error('Message parse error:', parseErr)
        }
      }

      socket.onerror = (err) => {
        console.error('WebSocket error:', err)
      }

      socket.onclose = () => {
        console.log('WebSocket closed')
        setIsRunning(false)
      }

      setWs(socket)
    } catch (err) {
      console.error('Failed to start capture:', err)
      setIsRunning(false)
      alert(`启动失败: ${err instanceof Error ? err.message : err}`)
    }
  }

  const stopCapture = () => {
    try {
      if (ws) {
        if (ws.readyState === WebSocket.OPEN) {
          ws.send(JSON.stringify({ action: 'stop' }))
        }
        ws.close()
        setWs(null)
      }
    } catch {}
    try {
      if (audioContextRef.current) {
        audioContextRef.current.close().catch(() => {})
        audioContextRef.current = null
      }
    } catch {}
    try {
      if (mediaStream) {
        mediaStream.getTracks().forEach(t => t.stop())
        setMediaStream(null)
      }
    } catch {}
    setIsRunning(false)
  }

  const toggleOverlay = (checked: boolean) => {
    setShowOverlay(checked)
    if (checked) {
      window.electronAPI.openOverlay()
    } else {
      window.electronAPI.closeOverlay()
    }
  }

  return (
    <Box sx={{ minHeight: '100vh', p: 2 }}>
      <Stack spacing={2}>
        {/* Header */}
        <Stack direction="row" alignItems="center" spacing={1}>
          <Translate sx={{ color: 'primary.main', fontSize: 28 }} />
          <Typography variant="h6" fontWeight={700}>ChiffonTranslator</Typography>
        </Stack>

        {/* Language Selection */}
        <Paper sx={{ p: 2, borderRadius: 2 }}>
          <Stack direction="row" spacing={2} alignItems="center">
            <FormControl size="small" sx={{ flex: 1 }}>
              <InputLabel>源语言</InputLabel>
              <Select
                value={sourceLang}
                label="源语言"
                onChange={e => setSourceLang(e.target.value)}
                disabled={isRunning}
              >
                {LANGUAGES.map(l => (
                  <MenuItem key={l.code} value={l.code}>{l.label}</MenuItem>
                ))}
              </Select>
            </FormControl>
            <Typography color="text.secondary">→</Typography>
            <FormControl size="small" sx={{ flex: 1 }}>
              <InputLabel>目标语言</InputLabel>
              <Select
                value={targetLang}
                label="目标语言"
                onChange={e => setTargetLang(e.target.value)}
                disabled={isRunning}
              >
                {LANGUAGES.map(l => (
                  <MenuItem key={l.code} value={l.code}>{l.label}</MenuItem>
                ))}
              </Select>
            </FormControl>
          </Stack>
        </Paper>

        {/* Controls */}
        <Stack direction="row" spacing={2} alignItems="center">
          <Button
            variant="contained"
            startIcon={isRunning ? <Stop /> : <PlayArrow />}
            onClick={isRunning ? stopCapture : startCapture}
            color={isRunning ? 'error' : 'primary'}
            sx={{ flex: 1, py: 1.5, borderRadius: 2, fontWeight: 600 }}
          >
            {isRunning ? '停止' : '开始翻译'}
          </Button>
          <FormControlLabel
            control={<Switch checked={showOverlay} onChange={(_, c) => toggleOverlay(c)} />}
            label="悬浮窗"
          />
        </Stack>

        {/* Overlay Opacity */}
        {showOverlay && (
          <Paper sx={{ p: 2, borderRadius: 2 }}>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
              悬浮窗透明度
            </Typography>
            <Slider
              value={overlayOpacity}
              min={0.1}
              max={1}
              step={0.01}
              valueLabelDisplay="auto"
              valueLabelFormat={(v) => `${Math.round(v * 100)}%`}
              onChange={(_, v) => {
                const val = v as number
                setOverlayOpacity(val)
                window.electronAPI.setOverlayOpacity(val)
              }}
              sx={{ color: '#5b8def' }}
            />
          </Paper>
        )}

        {/* Subtitle Display */}
        <SubtitlePanel subtitles={subtitles} />
      </Stack>
    </Box>
  )
}

function OverlayView() {
  const [original, setOriginal] = useState('')
  const [translated, setTranslated] = useState('')

  // Listen for subtitle updates from main window
  useState(() => {
    const cleanup = window.electronAPI.onSubtitleUpdate((data) => {
      setOriginal(data.original)
      setTranslated(data.translated)
    })
    return cleanup
  })

  return (
    <Box sx={{
      height: '100vh',
      display: 'flex',
      flexDirection: 'column',
      justifyContent: 'center',
      alignItems: 'center',
      px: 3,
      background: 'rgba(0,0,0,0.7)',
      borderRadius: 2,
      WebkitAppRegion: 'drag',
      cursor: 'move',
      userSelect: 'none',
    }}>
      <Typography
        variant="body1"
        sx={{
          color: '#ccc',
          textAlign: 'center',
          textShadow: '0 1px 4px rgba(0,0,0,0.8)',
          mb: 0.5,
          fontSize: 14,
        }}
      >
        {original || '等待语音输入...'}
      </Typography>
      <Typography
        variant="body1"
        sx={{
          color: '#fff',
          textAlign: 'center',
          textShadow: '0 1px 4px rgba(0,0,0,0.8)',
          fontWeight: 600,
          fontSize: 18,
        }}
      >
        {translated || ''}
      </Typography>
    </Box>
  )
}
