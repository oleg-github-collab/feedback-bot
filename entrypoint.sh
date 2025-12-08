#!/bin/sh
set -e

echo "Running migrations..."
bin/feedback_bot eval "FeedbackBot.Release.migrate()"

echo "Running seeds..."
bin/feedback_bot eval "FeedbackBot.Release.seed()"

echo "Starting application..."
exec bin/feedback_bot start
