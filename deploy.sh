#!/bin/bash -l

# This script will update the git repository to the latest revision in the
# origin's master branch. Then it restarts sidekiq using monit and does a zero
# downtime restart of the unicorn process.

post_message () {
  curl -X POST --data-urlencode 'payload={"attachments":[{
      "color": "#5DBCD2",
      "text": "'"$1"'",
      "fallback": "'"$1"'",
      "mrkdwn_in": ["text"]'"$3"'
    }]'"$2"'
  }' $SLACK_WEBHOOK_URL
}

if [ -z "$2" ] || [ -z "$3" ]; then
  post_message 'Deploy starting...' '' ', "author_name": "'"$1"'", "author_link": "https://hummingbird.me/users/'"$1"'", "author_icon": "'"$2"'"'
else
  post_message 'Deploy starting...'
fi

DIR=$(dirname "$0")
cd $DIR

# Update the git repo.
git fetch
git checkout master
git reset --hard HEAD@{upstream}
chown -R hummingbird:www-data .

# bundle install, precompile assets, migrate database
if [ $(whoami) = "hummingbird" ]
then
  cd $DIR && bundle install --deployment --without test
  cd $DIR && cd frontend && npm install
  cd $DIR && cd frontend && bower install
  cd $DIR && bundle exec rake assets:precompile EMBERCLI_COMPILE=1
  cd $DIR && bundle exec rake db:migrate
else
  su - hummingbird -c "cd $DIR && bundle install --deployment --without test"
  su - hummingbird -c "cd $DIR && cd frontend && npm install"
  su - hummingbird -c "cd $DIR && cd frontend && bower install"
  su - hummingbird -c "cd $DIR && bundle exec rake assets:precompile EMBERCLI_COMPILE=1"
  su - hummingbird -c "cd $DIR && bundle exec rake db:migrate"
fi

# restart sidekiq
monit restart sidekiq

# zero-downtime unicorn restart
kill -USR2 `cat tmp/pids/unicorn.pid`

post_message 'Deploy done.' 
