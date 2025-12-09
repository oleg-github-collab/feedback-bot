// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"

// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// Import advanced chart hooks
import {
  HeatmapChart,
  TrendChart,
  ComparisonChart,
  WordCloud,
  VolumeSentimentChart,
  DistributionChart,
  TopicBarChart
} from "./hooks/charts"

// Import mobile navigation
import { MobileNav } from "./mobile_nav"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

let Hooks = {}

// Mobile Navigation Hook
Hooks.MobileNav = MobileNav

// Advanced Analytics Hooks
Hooks.HeatmapChart = HeatmapChart
Hooks.TrendChart = TrendChart
Hooks.ComparisonChart = ComparisonChart
Hooks.WordCloud = WordCloud
Hooks.VolumeSentimentChart = VolumeSentimentChart
Hooks.DistributionChart = DistributionChart
Hooks.TopicBarChart = TopicBarChart

// Simple chart hook for backward compatibility
Hooks.SentimentChart = {
  mounted() {
    this.renderChart()
  },
  updated() {
    this.renderChart()
  },
  renderChart() {
    const data = JSON.parse(this.el.dataset.chartData || "[]")
    console.log("Rendering chart with data:", data)
  }
}

// Audio Recorder Hook
Hooks.AudioRecorder = {
  mounted() {
    this.mediaRecorder = null
    this.audioChunks = []
    this.isRecording = false

    this.el.addEventListener('click', () => {
      if (!this.isRecording) {
        this.startRecording()
      } else {
        this.stopRecording()
      }
    })
  },

  async startRecording() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      this.mediaRecorder = new MediaRecorder(stream, {
        mimeType: 'audio/webm;codecs=opus'
      })

      this.audioChunks = []

      this.mediaRecorder.addEventListener('dataavailable', event => {
        this.audioChunks.push(event.data)
      })

      this.mediaRecorder.addEventListener('stop', () => {
        const audioBlob = new Blob(this.audioChunks, { type: 'audio/webm' })
        this.uploadAudio(audioBlob)
      })

      this.mediaRecorder.start()
      this.isRecording = true
      this.pushEvent('start_recording', {})
    } catch (error) {
      console.error('Error accessing microphone:', error)
      alert('Не вдалося отримати доступ до мікрофона. Переконайтеся що ви дозволили доступ.')
    }
  },

  stopRecording() {
    if (this.mediaRecorder && this.mediaRecorder.state === 'recording') {
      this.mediaRecorder.stop()
      this.mediaRecorder.stream.getTracks().forEach(track => track.stop())
      this.isRecording = false
      this.pushEvent('stop_recording', {})
    }
  },

  async uploadAudio(audioBlob) {
    const reader = new FileReader()
    reader.onloadend = () => {
      const base64Audio = reader.result.split(',')[1]
      this.pushEvent('audio_uploaded', { audio_data: base64Audio })
    }
    reader.readAsDataURL(audioBlob)
  }
}

let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
