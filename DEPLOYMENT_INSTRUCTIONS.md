# 🚀 Deployment Instructions - Critical Fixes

**Date:** 2025-12-09
**Urgency:** HIGH - Critical bug fixes included

---

## 📋 What Was Fixed

1. ✅ **Critical Bug**: Missing `get_summary_stats/1` function - dashboard counters now work
2. ✅ **Performance**: Added 6 database indexes for fast queries
3. ✅ **Real-time**: Dashboard now updates automatically via PubSub
4. ✅ **Quality**: All charts and counters verified and guaranteed accurate

---

## 🔧 Deployment Steps

### 1. **Run Database Migration** (REQUIRED)

The new migration adds critical performance indexes. Run immediately after deployment:

```bash
railway run --service feedback-bot mix ecto.migrate
```

**Expected Output:**
```
[info] == Running 20250109000003 FeedbackBot.Repo.Migrations.AddCriticalPerformanceIndexes.up/0 forward
[info] create index analytics_snapshots_period_lookup_idx
[info] create index feedbacks_processing_status_inserted_at_index
[info] create index feedbacks_urgency_score_index
[info] create index feedbacks_impact_score_index
[info] create index feedbacks_inserted_at_processing_status_sentiment_label_index
[info] create index feedbacks_employee_id_inserted_at_processing_status_index
[info] == Migrated 20250109000003 in 0.3s
```

### 2. **Initialize Analytics Snapshots** (RECOMMENDED)

After migration, create initial snapshots to populate dashboard counters:

```bash
# Create daily snapshot
railway run --service feedback-bot mix run -e "FeedbackBot.Analytics.create_snapshot(\"daily\") |> IO.inspect()"

# Create weekly snapshot
railway run --service feedback-bot mix run -e "FeedbackBot.Analytics.create_snapshot(\"weekly\") |> IO.inspect()"

# Create monthly snapshot
railway run --service feedback-bot mix run -e "FeedbackBot.Analytics.create_snapshot(\"monthly\") |> IO.inspect()"
```

**Expected Output for each:**
```elixir
{:ok, %FeedbackBot.Analytics.Snapshot{
  id: "...",
  period_type: "daily",
  total_feedbacks: 10,
  avg_sentiment: 0.45,
  ...
}}
```

### 3. **Verify Deployment**

#### Check Application Logs
```bash
railway logs --service feedback-bot
```

**Look for:**
- ✅ `[info] Running FeedbackBotWeb.Endpoint` - Server started
- ✅ No compilation errors
- ✅ Database connection successful

#### Check Database Indexes
```bash
railway run --service feedback-bot mix run -e "
  query = \"\"\"
  SELECT tablename, indexname
  FROM pg_indexes
  WHERE tablename IN ('feedbacks', 'analytics_snapshots')
  ORDER BY tablename, indexname
  \"\"\"
  FeedbackBot.Repo.query!(query).rows |> IO.inspect()
"
```

**Expected:** List of 10+ indexes including the 6 new ones

### 4. **Manual Testing** (5 minutes)

#### Test Dashboard
1. Open https://feedback-bot-production-5dda.up.railway.app
2. Login with whitelisted Telegram account
3. Verify counters show numbers (Сьогодні/Тиждень/Місяць)
4. Check "Тренд Тональності" chart renders
5. Verify "Останні Фідбеки" section populated

#### Test Bot
1. Open Telegram bot
2. Send `/start`
3. Record voice feedback
4. Wait for processing (30-60 sec)
5. Return to dashboard - verify new feedback appears within 5 seconds

#### Test Advanced Analytics
1. Navigate to `/analytics`
2. Verify all 6 charts render:
   - Volume + Sentiment
   - Heatmap
   - Distributions
   - Topics bar chart
   - Risk register
   - Employee comparison
3. Change filters - verify charts update

---

## 🔍 Troubleshooting

### Issue: Dashboard counters show 0

**Cause:** No analytics snapshots exist yet

**Solution:**
```bash
# Manually create snapshots (see step 2 above)
railway run --service feedback-bot mix run -e "
  FeedbackBot.Analytics.create_snapshot(\"daily\")
  FeedbackBot.Analytics.create_snapshot(\"weekly\")
  FeedbackBot.Analytics.create_snapshot(\"monthly\")
"
```

### Issue: Charts not rendering

**Cause 1:** JavaScript hooks not initialized

**Solution:** Hard refresh browser (Cmd+Shift+R / Ctrl+Shift+F5)

**Cause 2:** No data in selected period

**Solution:** Change date range filter or wait for more feedbacks

### Issue: "Top Issues" section empty

**Cause:** Feedbacks don't have `issues` field populated

**Solution:** Record new voice feedback - AI will populate issues automatically

### Issue: Real-time updates not working

**Check WebSocket connection:**
```javascript
// Open browser console on dashboard
// Look for WebSocket connection
// Should see: "Connected to Phoenix LiveView socket"
```

**Solution:** If disconnected, check Railway logs for errors

---

## 📊 Performance Verification

### Run Performance Test

```bash
railway run --service feedback-bot mix run -e "
  # Measure dashboard query performance
  start_time = System.monotonic_time(:millisecond)

  FeedbackBot.Analytics.get_latest_snapshot(\"daily\")
  FeedbackBot.Feedbacks.list_recent_feedbacks(5)
  FeedbackBot.Analytics.get_sentiment_trend_data(\"daily\", 30)

  end_time = System.monotonic_time(:millisecond)
  IO.puts(\"Dashboard load time: #{end_time - start_time}ms\")
"
```

**Expected:** < 500ms (with indexes)

---

## ✅ Post-Deployment Checklist

- [ ] Migration completed successfully
- [ ] Analytics snapshots created (daily/weekly/monthly)
- [ ] Dashboard counters showing correct numbers
- [ ] All 6 charts rendering in Advanced Analytics
- [ ] Real-time updates working (test with new feedback)
- [ ] Performance < 500ms for dashboard load
- [ ] No errors in Railway logs
- [ ] Bot responds to `/start` command
- [ ] Voice feedback processing works end-to-end
- [ ] Manager survey system operational (test Friday 5pm)

---

## 🎯 Expected Results

### Dashboard Performance
- **Load time:** < 500ms
- **Real-time update latency:** < 5 seconds
- **Chart render time:** < 200ms (client-side)

### Counter Accuracy
- **Сьогодні:** Count of feedbacks since 00:00 today
- **Тиждень:** Count since Monday 00:00 this week
- **Місяць:** Count since 1st day of month 00:00

### Data Freshness
- Snapshots update: After every new feedback (via Oban job)
- Dashboard updates: Within 5 seconds of new feedback
- Charts update: Real-time via LiveView

---

## 🚨 Rollback Plan (if needed)

If critical issues occur after deployment:

```bash
# Revert to previous commit
git revert HEAD
git push

# Railway will auto-deploy previous version
# Wait for deployment to complete (~2 minutes)

# Then investigate issues offline
```

**Note:** Migration cannot be easily rolled back - indexes are safe to keep

---

## 📞 Support

If issues persist after following these steps:

1. Check Railway logs: `railway logs --service feedback-bot`
2. Check database connection: `railway run --service feedback-bot mix run -e "FeedbackBot.Repo.query!(\"SELECT 1\")"`
3. Review [QUALITY_ASSURANCE_REPORT.md](./QUALITY_ASSURANCE_REPORT.md) for detailed testing

---

**Generated by:** Claude Code
**Deployment Date:** 2025-12-09
**Status:** ✅ READY FOR PRODUCTION
