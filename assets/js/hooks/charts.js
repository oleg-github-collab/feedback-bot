import { Chart, registerables } from 'chart.js';
import cloud from 'd3-cloud';

Chart.register(...registerables);

export const HeatmapChart = {
  mounted() {
    this.renderChart();
  },
  updated() {
    this.renderChart();
  },
  renderChart() {
    const data = JSON.parse(this.el.dataset.heatmap || '[]');

    // Transform data for heatmap display
    const canvas = document.createElement('canvas');
    canvas.width = this.el.clientWidth;
    canvas.height = 400;
    this.el.innerHTML = '';
    this.el.appendChild(canvas);

    const employees = [...new Set(data.map(d => d.employee_name))];
    const dates = [...new Set(data.map(d => new Date(d.period).toLocaleDateString()))];

    const ctx = canvas.getContext('2d');

    // Simple heatmap using matrix
    const cellWidth = canvas.width / dates.length;
    const cellHeight = 400 / employees.length;

    data.forEach(item => {
      const dateIndex = dates.indexOf(new Date(item.period).toLocaleDateString());
      const empIndex = employees.indexOf(item.employee_name);

      const sentiment = item.avg_sentiment || 0;
      const color = sentiment > 0.3 ? `rgba(34, 197, 94, ${Math.abs(sentiment)})` :
                    sentiment < -0.3 ? `rgba(239, 68, 68, ${Math.abs(sentiment)})` :
                    `rgba(156, 163, 175, 0.5)`;

      ctx.fillStyle = color;
      ctx.fillRect(dateIndex * cellWidth, empIndex * cellHeight, cellWidth - 2, cellHeight - 2);

      ctx.fillStyle = '#000';
      ctx.font = '12px sans-serif';
      ctx.fillText(sentiment.toFixed(2), dateIndex * cellWidth + 5, empIndex * cellHeight + 20);
    });
  }
};

export const TrendChart = {
  mounted() {
    this.chart = null;
    this.renderChart();
  },
  updated() {
    this.renderChart();
  },
  destroyed() {
    if (this.chart) this.chart.destroy();
  },
  renderChart() {
    const data = JSON.parse(this.el.dataset.trend || '[]');

    const canvas = document.createElement('canvas');
    this.el.innerHTML = '';
    this.el.appendChild(canvas);

    if (this.chart) this.chart.destroy();

    this.chart = new Chart(canvas, {
      type: 'line',
      data: {
        labels: data.map(d => new Date(d.date).toLocaleDateString()),
        datasets: [
          {
            label: 'Sentiment',
            data: data.map(d => d.avg_sentiment),
            borderColor: 'rgb(59, 130, 246)',
            backgroundColor: 'rgba(59, 130, 246, 0.1)',
            tension: 0.4
          },
          {
            label: 'Urgency',
            data: data.map(d => d.avg_urgency),
            borderColor: 'rgb(239, 68, 68)',
            backgroundColor: 'rgba(239, 68, 68, 0.1)',
            tension: 0.4
          },
          {
            label: 'Impact',
            data: data.map(d => d.avg_impact),
            borderColor: 'rgb(34, 197, 94)',
            backgroundColor: 'rgba(34, 197, 94, 0.1)',
            tension: 0.4
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'top',
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            max: 1
          }
        }
      }
    });
  }
};

export const ComparisonChart = {
  mounted() {
    this.chart = null;
    this.renderChart();
  },
  updated() {
    this.renderChart();
  },
  destroyed() {
    if (this.chart) this.chart.destroy();
  },
  renderChart() {
    const data = JSON.parse(this.el.dataset.comparison || '[]');

    const canvas = document.createElement('canvas');
    this.el.innerHTML = '';
    this.el.appendChild(canvas);

    if (this.chart) this.chart.destroy();

    this.chart = new Chart(canvas, {
      type: 'bar',
      data: {
        labels: data.map(d => d.employee_name),
        datasets: [
          {
            label: 'Avg Sentiment',
            data: data.map(d => d.avg_sentiment || 0),
            backgroundColor: 'rgba(59, 130, 246, 0.7)'
          },
          {
            label: 'Avg Urgency',
            data: data.map(d => d.avg_urgency || 0),
            backgroundColor: 'rgba(239, 68, 68, 0.7)'
          },
          {
            label: 'Avg Impact',
            data: data.map(d => d.avg_impact || 0),
            backgroundColor: 'rgba(34, 197, 94, 0.7)'
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'top',
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            max: 1
          }
        }
      }
    });
  }
};

export const WordCloud = {
  mounted() {
    this.renderCloud();
  },
  updated() {
    this.renderCloud();
  },
  renderCloud() {
    const words = JSON.parse(this.el.dataset.words || '[]');

    if (words.length === 0) {
      this.el.innerHTML = '<p class="text-gray-500 text-center py-8">Недостатньо даних для word cloud</p>';
      return;
    }

    const maxCount = Math.max(...words.map(w => w[1]));

    const wordsData = words.slice(0, 50).map(([text, count]) => ({
      text,
      size: 10 + (count / maxCount) * 50
    }));

    const width = this.el.clientWidth;
    const height = 400;

    const layout = cloud()
      .size([width, height])
      .words(wordsData)
      .padding(5)
      .rotate(() => 0)
      .font("sans-serif")
      .fontSize(d => d.size)
      .on("end", (words) => this.drawCloud(words, width, height));

    layout.start();
  },
  drawCloud(words, width, height) {
    this.el.innerHTML = '';

    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('width', width);
    svg.setAttribute('height', height);
    svg.style.backgroundColor = '#f9fafb';

    const g = document.createElementNS('http://www.w3.org/2000/svg', 'g');
    g.setAttribute('transform', `translate(${width/2},${height/2})`);

    words.forEach(word => {
      const text = document.createElementNS('http://www.w3.org/2000/svg', 'text');
      text.textContent = word.text;
      text.setAttribute('font-size', word.size);
      text.setAttribute('font-family', word.font);
      text.setAttribute('fill', `hsl(${Math.random() * 360}, 70%, 50%)`);
      text.setAttribute('text-anchor', 'middle');
      text.setAttribute('transform', `translate(${word.x},${word.y}) rotate(${word.rotate})`);
      g.appendChild(text);
    });

    svg.appendChild(g);
    this.el.appendChild(svg);
  }
};
