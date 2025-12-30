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

// Dashboard Sentiment Trend Chart - specialized for dashboard
export const SentimentTrendChart = {
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
    const data = JSON.parse(this.el.dataset.sentimentTrend || '[]');

    if (!data || data.length === 0) {
      this.el.innerHTML = '<div class="flex items-center justify-center h-full text-gray-500 text-sm font-bold">Немає даних для відображення</div>';
      return;
    }

    const canvas = document.createElement('canvas');
    this.el.innerHTML = '';
    this.el.appendChild(canvas);

    if (this.chart) this.chart.destroy();

    // Prepare data
    const labels = data.map(d => {
      const date = new Date(d.date);
      return date.toLocaleDateString('uk-UA', { day: '2-digit', month: 'short' });
    });

    const sentimentData = data.map(d => d.avg_sentiment || 0);
    const feedbackCounts = data.map(d => d.total_feedbacks || 0);

    this.chart = new Chart(canvas, {
      type: 'line',
      data: {
        labels: labels,
        datasets: [
          {
            label: 'Тональність',
            data: sentimentData,
            borderColor: 'rgb(139, 92, 246)',
            backgroundColor: 'rgba(139, 92, 246, 0.1)',
            tension: 0.4,
            borderWidth: 3,
            pointRadius: 5,
            pointHoverRadius: 7,
            pointBackgroundColor: 'rgb(139, 92, 246)',
            pointBorderColor: '#fff',
            pointBorderWidth: 2,
            fill: true,
            yAxisID: 'y'
          },
          {
            label: 'Кількість фідбеків',
            data: feedbackCounts,
            borderColor: 'rgb(234, 179, 8)',
            backgroundColor: 'rgba(234, 179, 8, 0.05)',
            tension: 0.4,
            borderWidth: 2,
            pointRadius: 4,
            pointHoverRadius: 6,
            pointBackgroundColor: 'rgb(234, 179, 8)',
            pointBorderColor: '#fff',
            pointBorderWidth: 2,
            borderDash: [5, 5],
            yAxisID: 'y1'
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          mode: 'index',
          intersect: false,
        },
        plugins: {
          legend: {
            position: 'top',
            labels: {
              font: {
                size: 12,
                weight: 'bold',
                family: 'system-ui'
              },
              padding: 15,
              usePointStyle: true,
              pointStyle: 'circle'
            }
          },
          tooltip: {
            backgroundColor: 'rgba(0, 0, 0, 0.8)',
            padding: 12,
            bodyFont: {
              size: 13
            },
            titleFont: {
              size: 14,
              weight: 'bold'
            },
            callbacks: {
              label: function(context) {
                let label = context.dataset.label || '';
                if (label) {
                  label += ': ';
                }
                if (context.parsed.y !== null) {
                  if (context.datasetIndex === 0) {
                    // Sentiment value
                    label += context.parsed.y.toFixed(2);
                    const sentiment = context.parsed.y;
                    if (sentiment > 0.3) label += ' (позитивна)';
                    else if (sentiment < -0.3) label += ' (негативна)';
                    else label += ' (нейтральна)';
                  } else {
                    // Feedback count
                    label += context.parsed.y + ' фідбеків';
                  }
                }
                return label;
              }
            }
          }
        },
        scales: {
          y: {
            type: 'linear',
            display: true,
            position: 'left',
            min: -1,
            max: 1,
            ticks: {
              callback: function(value) {
                return value.toFixed(1);
              },
              font: {
                size: 11,
                weight: 'bold'
              }
            },
            grid: {
              color: 'rgba(0, 0, 0, 0.05)'
            },
            title: {
              display: true,
              text: 'Тональність',
              font: {
                size: 12,
                weight: 'bold'
              }
            }
          },
          y1: {
            type: 'linear',
            display: true,
            position: 'right',
            min: 0,
            ticks: {
              stepSize: 1,
              font: {
                size: 11,
                weight: 'bold'
              }
            },
            grid: {
              drawOnChartArea: false,
            },
            title: {
              display: true,
              text: 'Кількість',
              font: {
                size: 12,
                weight: 'bold'
              }
            }
          },
          x: {
            ticks: {
              maxRotation: 45,
              minRotation: 0,
              font: {
                size: 11,
                weight: 'bold'
              }
            },
            grid: {
              display: false
            }
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

export const VolumeSentimentChart = {
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
    const data = JSON.parse(this.el.dataset.volumeSentiment || '[]');
    const labels = data.map(d => new Date(d.date).toLocaleDateString());
    const counts = data.map(d => d.count || 0);
    const sentiments = data.map(d => d.avg_sentiment || 0);

    const canvas = document.createElement('canvas');
    this.el.innerHTML = '';
    this.el.appendChild(canvas);

    if (this.chart) this.chart.destroy();

    this.chart = new Chart(canvas, {
      type: 'bar',
      data: {
        labels,
        datasets: [
          {
            type: 'bar',
            label: 'Кількість',
            data: counts,
            backgroundColor: 'rgba(16, 185, 129, 0.5)',
            borderColor: 'rgba(16, 185, 129, 0.9)',
            borderWidth: 1,
            yAxisID: 'y'
          },
          {
            type: 'line',
            label: 'Sentiment',
            data: sentiments,
            borderColor: 'rgba(59, 130, 246, 0.9)',
            backgroundColor: 'rgba(59, 130, 246, 0.15)',
            tension: 0.35,
            yAxisID: 'y1',
            fill: true
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          mode: 'index',
          intersect: false
        },
        plugins: {
          legend: {
            position: 'top'
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            grid: { color: 'rgba(148, 163, 184, 0.15)' }
          },
          y1: {
            position: 'right',
            min: -1,
            max: 1,
            grid: { drawOnChartArea: false }
          },
          x: {
            grid: { color: 'rgba(148, 163, 184, 0.15)' }
          }
        }
      }
    });
  }
};

export const DistributionChart = {
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
    const data = JSON.parse(this.el.dataset.distribution || '[]');
    const title = this.el.dataset.title || '';

    const canvas = document.createElement('canvas');
    this.el.innerHTML = '';
    this.el.appendChild(canvas);

    if (this.chart) this.chart.destroy();

    this.chart = new Chart(canvas, {
      type: 'bar',
      data: {
        labels: data.map(d => d.label),
        datasets: [
          {
            label: title,
            data: data.map(d => d.value || 0),
            backgroundColor: data.map(d => d.color || 'rgba(99, 102, 241, 0.6)'),
            borderColor: data.map(d => d.color || 'rgba(99, 102, 241, 0.9)'),
            borderWidth: 1
          }
        ]
      },
      options: {
        indexAxis: 'y',
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false }
        },
        scales: {
          x: {
            beginAtZero: true,
            grid: { color: 'rgba(148, 163, 184, 0.15)' }
          },
          y: {
            grid: { color: 'rgba(148, 163, 184, 0.1)' }
          }
        }
      }
    });
  }
};

export const TopicBarChart = {
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
    const data = JSON.parse(this.el.dataset.topics || '[]');
    const labels = data.map(d => d.label);
    const values = data.map(d => d.value || 0);

    const canvas = document.createElement('canvas');
    this.el.innerHTML = '';
    this.el.appendChild(canvas);

    if (this.chart) this.chart.destroy();

    this.chart = new Chart(canvas, {
      type: 'bar',
      data: {
        labels,
        datasets: [
          {
            label: 'Згадувань',
            data: values,
            backgroundColor: 'rgba(244, 114, 182, 0.7)',
            borderColor: 'rgba(244, 114, 182, 0.9)',
            borderWidth: 1
          }
        ]
      },
      options: {
        indexAxis: 'y',
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false }
        },
        scales: {
          x: {
            beginAtZero: true,
            grid: { color: 'rgba(148, 163, 184, 0.15)' }
          },
          y: {
            grid: { color: 'rgba(148, 163, 184, 0.1)' }
          }
        }
      }
    });
  }
};
