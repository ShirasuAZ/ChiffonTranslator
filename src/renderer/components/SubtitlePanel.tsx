import { Box, Typography, Paper } from '@mui/material'
import { useEffect, useRef } from 'react'

interface SubtitleEntry {
  original: string
  translated: string
}

interface Props {
  subtitles: SubtitleEntry[]
}

export default function SubtitlePanel({ subtitles }: Props) {
  const scrollRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight
    }
  }, [subtitles])

  return (
    <Paper
      ref={scrollRef}
      sx={{
        flex: 1,
        p: 2,
        borderRadius: 2,
        maxHeight: 360,
        overflowY: 'auto',
        '&::-webkit-scrollbar': { width: 4 },
        '&::-webkit-scrollbar-thumb': { bgcolor: 'rgba(255,255,255,0.2)', borderRadius: 2 },
      }}
    >
      {subtitles.length === 0 ? (
        <Typography color="text.secondary" textAlign="center" sx={{ py: 4 }}>
          点击"开始翻译"捕获系统音频
        </Typography>
      ) : (
        subtitles.map((s, i) => (
          <Box key={i} sx={{ mb: 1.5 }}>
            <Typography variant="body2" sx={{ color: '#aaa', fontSize: 13 }}>
              {s.original}
            </Typography>
            {s.translated && (
              <Typography variant="body1" sx={{ color: '#fff', fontWeight: 500, fontSize: 15 }}>
                {s.translated}
              </Typography>
            )}
          </Box>
        ))
      )}
    </Paper>
  )
}
